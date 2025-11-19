module commands.impl.test_ps_down;

import commands.impl.ps;
import commands.impl.down;
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
    writeln("Running PsCommand and DownCommand tests...");

    // Setup
    auto executor = new MockExecutor();
    auto cli = new PodmanCLI(executor);
    Config config;
    config.podName = "test_pod";

    // Test PsCommand (Unfiltered)
    auto psCmd = new PsCommand();
    psCmd.execute(config, cli, []);

    bool psFound = false;
    foreach (cmd; executor.executedCommands)
    {
        if (cmd.startsWith("podman ps"))
        {
            psFound = true;
            // The requirement is "ps without filter"
            if (cmd.canFind("--filter pod=test_pod"))
            {
                assert(false, "PsCommand should not filter by pod name (found filter in: " ~ cmd ~ ")");
            }
        }
    }
    assert(psFound, "PsCommand did not execute 'podman ps'");

    // Clear commands for next test
    executor.executedCommands = [];

    // Test DownCommand
    auto downCmd = new DownCommand();
    downCmd.execute(config, cli, []);

    bool downFound = false;
    foreach (cmd; executor.executedCommands)
    {
        if (cmd == "podman pod rm -f test_pod")
        {
            downFound = true;
        }
    }
    assert(downFound, "DownCommand did not execute 'podman pod rm -f test_pod' (found: " ~ (
            executor.executedCommands.length > 0 ? executor.executedCommands[0] : "none") ~ ")");
}
