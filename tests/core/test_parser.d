module tests.core.test_parser;

import core.parser;
import core.models;
import std.file;
import std.path;
import std.stdio;

unittest
{
    writeln("Running Parser tests...");

    // Test 1: Basic Parsing with new models
    {
        string content = "version: '3'\nservices:\n  web:\n    image: nginx\n    ports:\n      - \"80:80\"\n";
        string tmpFile = buildPath(tempDir(), "docker-compose.test.yml");
        std.file.write(tmpFile, content);

        scope (exit)
        {
            if (exists(tmpFile))
                remove(tmpFile);
        }

        auto parser = new ComposeParser(tmpFile);
        auto config = parser.parse();

        assert(config.version_ == "3");
        assert("web" in config.services);
        assert(config.services["web"].image.get == "nginx");
        // Ports are now structs
        assert(config.services["web"].ports.length == 1);
        assert(config.services["web"].ports[0].published.get == "80");
        assert(config.services["web"].ports[0].target.get == "80");
    }

    // Test 2: Comprehensive Parsing
    {
        string yamlContent = `
version: "3.8"
services:
  web:
    image: nginx:latest
    container_name: my-web
    command: ["nginx", "-g", "daemon off;"]
    environment:
      - NODE_ENV=production
    deploy:
      replicas: 3
      resources:
        limits:
          cpus: 0.5
          memory: 512M
`;
        string filename = buildPath(tempDir(), "test_basic.yml");
        std.file.write(filename, yamlContent);
        scope (exit)
            if (exists(filename))
                std.file.remove(filename);

        ComposeParser parser = new ComposeParser(filename);
        ComposeConfig config = parser.parse();

        assert(config.version_ == "3.8");
        assert("web" in config.services);
        auto web = config.services["web"];
        assert(web.image == "nginx:latest");
        assert(web.containerName == "my-web");
        assert(web.command == ["nginx", "-g", "daemon off;"]);
        assert(web.environment["NODE_ENV"] == "production");
        assert(web.deploy.get.replicas == 3);
        assert(web.deploy.get.resources.limits.cpus == 0.5);
        assert(web.deploy.get.resources.limits.memory == "512M");
    }

    // Test 3: Short Syntax and Top Level
    {
        string yamlContent = `
services:
  db:
    image: postgres
    volumes:
      - "db_data:/var/lib/postgresql/data"
    networks:
      - backend
networks:
  backend:
    driver: bridge
volumes:
  db_data:
    external: true
`;
        string filename = buildPath(tempDir(), "test_short.yml");
        std.file.write(filename, yamlContent);
        scope (exit)
            if (exists(filename))
                std.file.remove(filename);

        ComposeParser parser = new ComposeParser(filename);
        ComposeConfig config = parser.parse();

        auto db = config.services["db"];
        assert(db.volumes.length == 1);
        assert(db.volumes[0].source == "db_data");
        assert(db.volumes[0].target == "/var/lib/postgresql/data");

        assert("backend" in db.networks);
        assert("backend" in config.networks);
        assert(config.networks["backend"].driver == "bridge");

        assert("db_data" in config.volumes);
        assert(config.volumes["db_data"].external == true);
    }
}
