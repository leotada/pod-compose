module podman.test_run_container_extended;

import podman.cli;
import std.stdio;
import std.algorithm : canFind;
import std.string;

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
    writeln("Running Run Container Extended tests...");

    auto m = new MockExecutor();
    auto cli = new PodmanCLI(m);

    PodmanCLI.ContainerRunOptions o;
    o.podName = "p";
    o.name = "c";
    o.image = "alpine";
    o.entrypoint = ["/bin/sh", "-c", "echo hi"];
    o.envs = ["FOO=BAR"];
    o.envFiles = ["/tmp/.env"];
    o.command = ["arg with space", "safe"];
    o.devices = ["/dev/ttyUSB0:/dev/ttyUSB0:rwm"];
    o.ulimits = ["nofile=65535"];
    o.sysctls = ["net.core.somaxconn=1024"];
    o.init = true;
    o.pid = "host";
    o.logDriver = "json-file";
    o.logOpts = ["max-size=10m"];

    cli.runContainer(o);
    string cmd = m.executedCommands[0];
    writeln("Generated: ", cmd);

    // entrypoint array form
    assert(cmd.canFind(`--entrypoint '["/bin/sh","-c","echo hi"]'`),
        "entrypoint array form: " ~ cmd);
    assert(cmd.canFind("--env-file /tmp/.env"));
    assert(cmd.canFind("--device /dev/ttyUSB0:/dev/ttyUSB0:rwm"));
    assert(cmd.canFind("--ulimit nofile=65535"));
    assert(cmd.canFind("--sysctl net.core.somaxconn=1024"));
    assert(cmd.canFind("--init"));
    assert(cmd.canFind("--pid host"));
    assert(cmd.canFind("--log-driver json-file"));
    assert(cmd.canFind("--log-opt max-size=10m"));
    // command args properly quoted
    assert(cmd.canFind("'arg with space'"), "quoted command arg: " ~ cmd);
    // safe arg not quoted
    assert(cmd.endsWith("safe"));

    // Single-element entrypoint -> string form (preserves backwards compat)
    m.executedCommands = [];
    PodmanCLI.ContainerRunOptions o2;
    o2.podName = "p";
    o2.name = "c2";
    o2.image = "alpine";
    o2.entrypoint = ["/bin/sh"];
    cli.runContainer(o2);
    assert(m.executedCommands[0].canFind(`--entrypoint "/bin/sh"`));

    // New verbs
    m.executedCommands = [];
    cli.pausePod("mypod");
    assert(m.executedCommands[$ - 1] == "podman pod pause mypod");
    cli.unpausePod("mypod");
    assert(m.executedCommands[$ - 1] == "podman pod unpause mypod");
    cli.killPod("mypod", "SIGTERM");
    assert(m.executedCommands[$ - 1] == "podman pod kill --signal SIGTERM mypod");
    cli.killPod("mypod");
    assert(m.executedCommands[$ - 1] == "podman pod kill mypod");
    cli.removeContainer("c", true);
    assert(m.executedCommands[$ - 1] == "podman rm -f c");
    cli.push("nginx:latest");
    assert(m.executedCommands[$ - 1] == "podman push nginx:latest");

    writeln("  [PASS] Run container extended");
}
