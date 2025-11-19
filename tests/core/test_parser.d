module tests.core.test_parser;

import core.parser;
import core.models;
import std.file;
import std.path;
import std.stdio;

unittest {
    writeln("Running Parser tests...");
    
    string content = "version: '3'\nservices:\n  web:\n    image: nginx\n    ports:\n      - \"80:80\"\n";
    string tmpFile = buildPath(tempDir(), "docker-compose.test.yml");
    std.file.write(tmpFile, content);
    
    scope(exit) {
        if (exists(tmpFile)) remove(tmpFile);
    }
    
    auto parser = new ComposeParser(tmpFile);
    auto config = parser.parse();
    
    assert(config.version_ == "3");
    assert("web" in config.services);
    assert(config.services["web"].image.get == "nginx");
    assert(config.services["web"].ports[0] == "80:80");
}
