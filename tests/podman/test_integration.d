module podman.test_integration;

import commands.impl.up;
import core.config;
import core.models;
import podman.cli;
import std.stdio;
import std.string;
import std.algorithm;

// Mock Executor to capture commands
class MockExecutor : IExecutor
{
    string[] executedCommands;

    override int execute(string cmd)
    {
        executedCommands ~= cmd;
        return 0;
    }

    override int executeStream(string cmd)
    {
        executedCommands ~= cmd;
        return 0;
    }
}

unittest
{
    writeln("Running Integration Tests...");

    // Setup
    auto executor = new MockExecutor();
    auto cli = new PodmanCLI(executor);

    // Create a dummy config
    Config config;
    config.composeFile = "docker-compose.yml";
    config.projectName = "testproj";
    config.podName = "test_pod";

    // Manually construct a Service with various options
    Service s;
    s.name = "web";
    s.image = "nginx:latest";
    Port p;
    p.published = "80";
    p.target = "80";
    s.ports = [p];

    // Resources
    Deploy deploy;
    deploy.resources.limits.cpus = 0.5;
    deploy.resources.limits.memory = "512M";
    s.deploy = deploy;

    // Healthcheck
    HealthCheck hc;
    hc.test = ["CMD", "curl", "-f", "http://localhost"];
    hc.interval = "30s";
    s.healthcheck = hc;

    // Environment
    s.environment["FOO"] = "BAR";

    // We can't easily test UpCommand.execute because it parses a file.
    // Instead, let's test PodmanCLI.runContainer directly with options populated as UpCommand would.

    PodmanCLI.ContainerRunOptions opts;
    opts.podName = config.podName;
    opts.name = "test_container";
    opts.image = s.image.get;
    opts.envs = ["FOO=BAR"];

    // Map service fields to opts (logic from UpCommand)
    if (!s.deploy.isNull && !s.deploy.get.resources.limits.cpus.isNull)
        opts.cpus = s.deploy.get.resources.limits.cpus.get;
    if (!s.deploy.isNull && !s.deploy.get.resources.limits.memory.isNull)
        opts.memory = s.deploy.get.resources.limits.memory.get;

    if (!s.healthcheck.isNull)
    {
        auto h = s.healthcheck.get;
        if (h.test.length > 0)
            opts.healthCmd = h.test.join(" ");
        if (!h.interval.isNull)
            opts.healthInterval = h.interval.get;
    }

    // Execute
    cli.runContainer(opts);

    // Verify
    assert(executor.executedCommands.length == 1);
    string cmd = executor.executedCommands[0];

    writeln("Generated Command: ", cmd);

    assert(cmd.canFind("--pod test_pod"));
    assert(cmd.canFind("--name test_container"));
    assert(cmd.canFind("-e \"FOO=BAR\""));
    assert(cmd.canFind("--cpus 0.5"));
    assert(cmd.canFind("--memory 512M"));
    assert(cmd.canFind("--health-cmd \"CMD curl -f http://localhost\""));
    assert(cmd.canFind("--health-interval 30s"));
    assert(cmd.canFind("nginx:latest"));

    writeln("  [PASS] Integration Test (Run)");

    // Test Build
    PodmanCLI.BuildOptions buildOpts;
    buildOpts.context = ".";
    buildOpts.dockerfile = "Dockerfile.dev";
    buildOpts.tag = "myimage:latest";
    buildOpts.args["VERSION"] = "1.0";

    cli.build(buildOpts);

    assert(executor.executedCommands.length == 2);
    string buildCmd = executor.executedCommands[1];
    writeln("Generated Build Command: ", buildCmd);

    assert(buildCmd.canFind("podman build"));
    assert(buildCmd.canFind("-t myimage:latest"));
    assert(buildCmd.canFind("-f Dockerfile.dev"));
    assert(buildCmd.canFind("--build-arg VERSION=1.0"));

    writeln("  [PASS] Integration Test (Build)");

    // Test Configs (simulated via volumes)
    PodmanCLI.ContainerRunOptions configOpts;
    configOpts.podName = "pod_with_config";
    configOpts.name = "container_with_config";
    configOpts.image = "alpine";
    configOpts.volumes = ["./my_config.conf:/etc/my_config.conf:ro"];

    cli.runContainer(configOpts);

    assert(executor.executedCommands.length == 3);
    string configCmd = executor.executedCommands[2];
    writeln("Generated Config Command: ", configCmd);

    assert(configCmd.canFind("-v ./my_config.conf:/etc/my_config.conf:ro"));

    writeln("  [PASS] Integration Test (Configs)");

    // Test Stop Options
    PodmanCLI.ContainerRunOptions stopOpts;
    stopOpts.podName = "pod_stop";
    stopOpts.name = "container_stop";
    stopOpts.image = "alpine";
    stopOpts.stopSignal = "SIGTERM";
    stopOpts.stopTimeout = 10;

    cli.runContainer(stopOpts);

    assert(executor.executedCommands.length == 4);
    string stopCmd = executor.executedCommands[3];
    writeln("Generated Stop Command: ", stopCmd);

    assert(stopCmd.canFind("--stop-signal SIGTERM"));
    assert(stopCmd.canFind("--stop-timeout 10"));

    writeln("  [PASS] Integration Test (Stop Options)");

    // Test Pod Creation with Networks
    cli.createPod("net_pod", ["80:80"], [], ["my_net"]);
    assert(executor.executedCommands.length == 5);
    string podCmd = executor.executedCommands[4];
    writeln("Generated Pod Command: ", podCmd);
    assert(podCmd.canFind("--network my_net"));

    writeln("  [PASS] Integration Test (Pod Networks)");
}
