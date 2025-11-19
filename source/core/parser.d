module core.parser;

import dyaml;
import core.models;
import std.stdio;
import std.conv;
import std.string;
import std.algorithm;
import std.path;

@safe:

class ComposeParser {
    string filePath;

    this(string filePath) {
        this.filePath = filePath;
    }

    ComposeConfig parse() {
        ComposeConfig config;
        Node root;
        
        try {
            root = Loader.fromFile(filePath).load();
        } catch (Exception e) {
            writeln("Error reading YAML file: ", e.msg);
            return config;
        }

        if (root.containsKey("version")) {
            config.version_ = root["version"].as!string;
        }

        if (root.containsKey("services")) {
            foreach (string name, Node serviceNode; root["services"]) {
                config.services[name] = parseService(name, serviceNode);
            }
        }
        
        // Networks and Volumes parsing can be added here

        return config;
    }

    private Service parseService(string name, Node node) {
        Service service;
        service.name = name;

        if (node.containsKey("image")) {
            service.image = node["image"].as!string;
        }

        if (node.containsKey("build")) {
            auto buildNode = node["build"];
            if (buildNode.nodeID == NodeID.scalar) {
                service.buildContext = buildNode.as!string;
                service.dockerfile = "Dockerfile";
            } else if (buildNode.nodeID == NodeID.mapping) {
                if (buildNode.containsKey("context")) service.buildContext = buildNode["context"].as!string;
                else service.buildContext = ".";
                
                if (buildNode.containsKey("dockerfile")) service.dockerfile = buildNode["dockerfile"].as!string;
                else service.dockerfile = "Dockerfile";
                
                if (buildNode.containsKey("target")) service.target = buildNode["target"].as!string;
            }
        }

        if (node.containsKey("container_name")) {
            service.containerName = node["container_name"].as!string;
        }

        if (node.containsKey("ports")) {
            foreach (Node p; node["ports"]) {
                service.ports ~= p.as!string;
            }
        }

        if (node.containsKey("environment")) {
            auto env = node["environment"];
            if (env.nodeID == NodeID.mapping) {
                foreach (string k, Node v; env) {
                    service.environment[k] = v.as!string;
                }
            } else if (env.nodeID == NodeID.sequence) {
                foreach (Node v; env) {
                    string val = v.as!string;
                    auto parts = val.split("=");
                    if (parts.length >= 2) {
                        service.environment[parts[0]] = parts[1 .. $].join("=");
                    }
                }
            }
        }

        if (node.containsKey("volumes")) {
            foreach (Node v; node["volumes"]) {
                string volStr = v.as!string;
                // Auto-append :Z for SELinux if not present
                if (volStr.canFind(":") && !volStr.canFind(":Z") && !volStr.canFind(":z")) {
                    volStr ~= ":Z";
                }
                service.volumes ~= volStr;
            }
        }

        if (node.containsKey("command")) {
            auto cmd = node["command"];
            if (cmd.nodeID == NodeID.scalar) {
                service.command ~= cmd.as!string; // Treat as single string arg? Or split? 
                // Ideally we should respect shell parsing but for now let's just keep it simple.
                // Actually, if it's a string, we might want to pass it as is.
                // But our model uses string[].
                // Let's just store it.
            } else if (cmd.nodeID == NodeID.sequence) {
                foreach (Node c; cmd) {
                    service.command ~= c.as!string;
                }
            }
        }

        if (node.containsKey("user")) {
            service.user = node["user"].as!string;
        }
        
        if (node.containsKey("restart")) {
            service.restart = node["restart"].as!string;
        }

        return service;
    }
}
