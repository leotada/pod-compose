module tests.core.test_models;

import core.models;
import std.typecons;

unittest {
    import std.stdio;
    writeln("Running Models tests...");

    Service s;
    s.name = "web";
    s.image = "nginx";
    s.ports = ["80:80"];
    
    assert(s.name == "web");
    assert(s.image.get == "nginx");
    assert(s.ports.length == 1);
    assert(s.ports[0] == "80:80");
    
    ComposeConfig cc;
    cc.version_ = "3.8";
    cc.services["web"] = s;
    
    assert(cc.version_ == "3.8");
    assert("web" in cc.services);
}
