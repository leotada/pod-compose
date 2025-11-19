module tests.podman.test_cli;

import podman.cli;
import std.stdio;

class MockExecutor : IExecutor {
    string lastCommand;
    
    override int execute(string cmd) {
        lastCommand = cmd;
        return 0;
    }
    
    override int executeStream(string cmd) {
        lastCommand = cmd;
        return 0;
    }
}

unittest {
    writeln("Running PodmanCLI tests...");
    
    auto mock = new MockExecutor();
    auto cli = new PodmanCLI(mock);
    
    cli.createPod("mypod", ["80:80"], ["host:127.0.0.1"]);
    assert(mock.lastCommand == "podman pod create --name mypod -p 80:80 --add-host host:127.0.0.1");
    
    cli.startContainer("mycontainer");
    assert(mock.lastCommand == "podman start mycontainer");
    
    cli.build(".", "Dockerfile", "myimage:latest");
    assert(mock.lastCommand == "podman build -t myimage:latest -f Dockerfile .");
}
