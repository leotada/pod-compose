module commands.test_up;

import commands.impl.up;
import core.models;
import std.stdio;
import std.algorithm;
import std.typecons;

unittest
{
    writeln("Running UpCommand tests...");

    auto cmd = new UpCommand();

    // Setup services
    Service[string] services;

    Service db;
    db.name = "db";
    services["db"] = db;

    Service backend;
    backend.name = "backend";
    backend.dependsOn["db"] = ServiceDependency("service_started", Nullable!bool());
    services["backend"] = backend;

    Service frontend;
    frontend.name = "frontend";
    frontend.dependsOn["backend"] = ServiceDependency("service_started", Nullable!bool());
    services["frontend"] = frontend;

    // Test Sort
    string[] sorted = cmd.sortServices(services);

    writeln("Sorted order: ", sorted);

    assert(sorted.length == 3);
    assert(sorted[0] == "db");
    assert(sorted[1] == "backend");
    assert(sorted[2] == "frontend");

    // Test Circular Dependency
    services["db"].dependsOn["frontend"] = ServiceDependency("service_started", Nullable!bool());
    try
    {
        cmd.sortServices(services);
        assert(false, "Should have thrown circular dependency exception");
    }
    catch (Exception e)
    {
        assert(e.msg.canFind("Circular dependency"));
    }

    writeln("  [PASS] Dependency Sorting");
}
