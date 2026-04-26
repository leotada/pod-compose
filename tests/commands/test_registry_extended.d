module commands.test_registry_extended;

import commands.registry;
import std.stdio;

unittest
{
    writeln("Running CommandRegistry Extended tests...");

    auto r = new CommandRegistry();
    foreach (name; [
        "up", "down", "build", "ps", "logs", "stop", "start", "restart",
        "pull", "exec", "version", "port", "rm", "pause", "unpause", "kill",
        "top", "push", "events", "cp", "images", "config", "run"
    ])
    {
        assert(r.get(name) !is null, "missing command: " ~ name);
    }
    assert(r.get("nonexistent") is null);
    writeln("  [PASS] All commands registered");
}
