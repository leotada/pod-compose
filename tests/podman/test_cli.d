module tests.podman.test_cli;

import podman.cli;
import std.stdio;

class MockExecutor : IExecutor
{
    string lastCommand;

    override int execute(string cmd)
    {
        lastCommand = cmd;
        return 0;
    }

    override int executeStream(string cmd)
    {
        lastCommand = cmd;
        return 0;
    }
}

unittest
{
    writeln("Running PodmanCLI tests...");

    auto mock = new MockExecutor();
    auto cli = new PodmanCLI(mock);

    cli.createPod("mypod", ["80:80"], ["host:127.0.0.1"]);
    assert(mock.lastCommand == "podman pod create --name mypod -p 80:80 --add-host host:127.0.0.1");

    cli.startContainer("mycontainer");
    assert(mock.lastCommand == "podman start mycontainer");

    PodmanCLI.BuildOptions buildOpts;
    buildOpts.context = ".";
    buildOpts.dockerfile = "Dockerfile";
    buildOpts.tag = "myimage:latest";
    cli.build(buildOpts);
    assert(mock.lastCommand == "podman build -t myimage:latest -f Dockerfile .");

    cli.ps("mypod");
    assert(mock.lastCommand == "podman ps --filter pod=mypod");

    cli.ps();
    assert(mock.lastCommand == "podman ps");

    cli.ps("mypod", ["-a"]);
    assert(mock.lastCommand == "podman ps --filter pod=mypod -a");

    cli.ps("", ["-a"]);
    assert(mock.lastCommand == "podman ps -a");

    cli.secretExists("mysecret");
    assert(mock.lastCommand == "podman secret exists mysecret");

    cli.createSecret("mysecret", "secret.txt");
    assert(mock.lastCommand == "podman secret create mysecret secret.txt");
}
