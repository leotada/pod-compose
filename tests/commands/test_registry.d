module tests.commands.test_registry;

import commands.registry;
import std.stdio;

unittest {
    writeln("Running CommandRegistry tests...");
    
    auto registry = new CommandRegistry();
    
    assert(registry.get("up") !is null);
    assert(registry.get("down") !is null);
    assert(registry.get("version") !is null);
    assert(registry.get("unknown") is null);
}
