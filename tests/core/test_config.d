module tests.core.test_config;

import core.config;
import std.stdio;

unittest {
    writeln("Running Config tests...");
    // Since Config.load relies on file system, we can only test basic struct behavior or mock FS if we had dependency injection for FS.
    // For now, let's just instantiate Config and check fields.
    
    auto conf = Config("compose.yml", "/tmp", "testproject", "testproject_pod");
    assert(conf.composeFile == "compose.yml");
    assert(conf.projectDir == "/tmp");
    assert(conf.projectName == "testproject");
    assert(conf.podName == "testproject_pod");

    // Test explicit file loading (requires file to exist)
    import std.file;
    import std.path;
    string tmpFile = buildPath(tempDir(), "custom-compose.yml");
    std.file.write(tmpFile, "version: '3'");
    scope(exit) {
        if (exists(tmpFile)) remove(tmpFile);
    }

    // We need to mock args, but Config.load takes args and optional explicitFile
    // We are testing the logic inside load that uses explicitFile
    // However, Config.load does chdir, which might affect other tests if not careful.
    // For unit testing Config.load directly, we should be careful about side effects.
    // Let's just test that it accepts the file if it exists.
    
    // Note: Config.load changes global CWD. This is bad for unit tests running in parallel or sequence.
    // We should probably refactor Config to not change CWD globally or restore it.
    // For now, let's save and restore CWD.
    string originalCwd = getcwd();
    scope(exit) chdir(originalCwd);

    auto conf2 = Config.load(["pod-compose", "up"], tmpFile);
    assert(conf2.composeFile == "custom-compose.yml");
    assert(conf2.projectName == baseName(dirName(tmpFile)));
}
