module core.test_parser_extended;

import core.parser;
import core.models;
import std.file;
import std.path;
import std.stdio;

unittest
{
    writeln("Running Extended Parser tests...");

    // env_file, devices, ulimits, sysctls, pid, init, logging, entrypoint array
    string yaml = `
services:
  app:
    image: alpine
    init: true
    pid: host
    env_file:
      - .env
      - extra.env
    entrypoint: ["/bin/sh", "-c", "echo hi"]
    sysctls:
      net.core.somaxconn: "1024"
      net.ipv4.tcp_syncookies: "0"
    devices:
      - "/dev/ttyUSB0:/dev/ttyUSB0:rwm"
      - source: /dev/snd
        target: /dev/snd
    ulimits:
      nofile: 65535
      nproc:
        soft: 1024
        hard: 2048
    logging:
      driver: json-file
      options:
        max-size: "10m"
`;
    string filename = buildPath(tempDir(), "test_extended.yml");
    std.file.write(filename, yaml);
    scope (exit)
        if (exists(filename))
            std.file.remove(filename);

    auto parser = new ComposeParser(filename);
    auto cfg = parser.parse();

    auto app = cfg.services["app"];
    assert(app.init.get == true);
    assert(app.pid.get == "host");
    assert(app.envFile.length == 2);
    assert(app.envFile[0] == ".env");
    assert(app.envFile[1] == "extra.env");
    assert(app.entrypoint == ["/bin/sh", "-c", "echo hi"]);
    assert(app.sysctls["net.core.somaxconn"] == "1024");
    assert(app.devices.length == 2);
    assert(app.devices[0].source == "/dev/ttyUSB0");
    assert(app.devices[0].target.get == "/dev/ttyUSB0");
    assert(app.devices[0].permissions.get == "rwm");
    assert(app.devices[1].source == "/dev/snd");
    assert(app.devices[1].target.get == "/dev/snd");
    assert(app.ulimits["nofile"].isScalar);
    assert(app.ulimits["nofile"].soft.get == 65535);
    assert(!app.ulimits["nproc"].isScalar);
    assert(app.ulimits["nproc"].soft.get == 1024);
    assert(app.ulimits["nproc"].hard.get == 2048);
    assert(app.logging.get.driver.get == "json-file");
    assert(app.logging.get.options["max-size"] == "10m");

    writeln("  [PASS] Extended fields parsing");
}
