module commands.impl.test_stop_start;

import commands.impl.stop;
import commands.impl.start;
import core.config;
import podman.cli;
import std.algorithm;
import std.string;
import std.stdio;

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
    writeln("Running StopCommand and StartCommand tests...");

    // Setup
    auto executor = new MockExecutor();
    auto cli = new PodmanCLI(executor);
    Config config;
    config.podName = "test_pod";

    // Test StopCommand
    auto stopCmd = new StopCommand();
    stopCmd.execute(config, cli, []);

    bool stopFound = false;
    foreach (cmd; executor.executedCommands)
    {
        if (cmd == "podman pod stop test_pod")
        {
            stopFound = true;
        }
    }
    assert(stopFound, "StopCommand did not execute 'podman pod stop test_pod' (found: " ~ (
            executor.executedCommands.length > 0 ? executor.executedCommands[0] : "none") ~ ")");

    // Clear commands for next test
    executor.executedCommands = [];

    // Test StartCommand
    auto startCmd = new StartCommand();
    startCmd.execute(config, cli, []);

    bool startFound = false;
    foreach (cmd; executor.executedCommands)
    {
        if (cmd == "podman pod start test_pod")
        {
            startFound = true;
        }
    }
    assert(startFound, "StartCommand did not execute 'podman pod start test_pod' (found: " ~ (
            executor.executedCommands.length > 0 ? executor.executedCommands[0] : "none") ~ ")");
}
