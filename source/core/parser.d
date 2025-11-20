module core.parser;

import dyaml;
import core.models;
import core.parsers.service;
import std.stdio;
import std.conv;
import std.string;
import std.algorithm;
import std.path;
import std.array;
import std.typecons : Nullable;

@safe:

class ComposeParser
{
    string filePath;

    this(string filePath)
    {
        this.filePath = filePath;
    }

    ComposeConfig parse()
    {
        ComposeConfig config;
        Node root;

        try
        {
            root = Loader.fromFile(filePath).load();
        }
        catch (Exception e)
        {
            writeln("Error reading YAML file: ", e.msg);
            return config;
        }

        if (root.containsKey("version"))
        {
            config.version_ = root["version"].as!string;
        }

        if (root.containsKey("name"))
        {
            config.name = root["name"].as!string;
        }

        if (root.containsKey("services"))
        {
            foreach (string name, Node serviceNode; root["services"])
            {
                config.services[name] = parseService(name, serviceNode);
            }
        }

        if (root.containsKey("networks"))
        {
            foreach (string name, Node netNode; root["networks"])
            {
                config.networks[name] = parseNetwork(name, netNode);
            }
        }

        if (root.containsKey("volumes"))
        {
            foreach (string name, Node volNode; root["volumes"])
            {
                config.volumes[name] = parseVolume(name, volNode);
            }
        }

        if (root.containsKey("configs"))
        {
            foreach (string name, Node cfgNode; root["configs"])
            {
                config.configs[name] = parseConfig(name, cfgNode);
            }
        }

        if (root.containsKey("secrets"))
        {
            foreach (string name, Node secNode; root["secrets"])
            {
                config.secrets[name] = parseSecret(name, secNode);
            }
        }

        return config;
    }

    private Service parseService(string name, Node node)
    {
        return ServiceParser.parse(name, node);
    }

    // --- Helper Parsers ---

    private TopLevelNetwork parseNetwork(string name, Node node)
    {
        TopLevelNetwork net;
        net.name = name;
        if (node.nodeID == NodeID.mapping)
        {
            if (node.containsKey("driver"))
                net.driver = node["driver"].as!string;
            if (node.containsKey("external"))
                net.external = node["external"].as!bool;
            if (node.containsKey("internal"))
                net.internal = node["internal"].as!bool;
            if (node.containsKey("attachable"))
                net.attachable = node["attachable"].as!bool;
            if (node.containsKey("labels"))
                net.labels = parseLabels(node["labels"]);
            if (node.containsKey("name"))
                net.name = node["name"].as!string;
        }
        return net;
    }

    private TopLevelVolume parseVolume(string name, Node node)
    {
        TopLevelVolume vol;
        vol.name = name;
        if (node.nodeID == NodeID.mapping)
        {
            if (node.containsKey("driver"))
                vol.driver = node["driver"].as!string;
            if (node.containsKey("external"))
                vol.external = node["external"].as!bool;
            if (node.containsKey("labels"))
                vol.labels = parseLabels(node["labels"]);
            if (node.containsKey("name"))
                vol.name = node["name"].as!string;
        }
        return vol;
    }

    private TopLevelConfig parseConfig(string name, Node node)
    {
        TopLevelConfig cfg;
        cfg.name = name;
        if (node.nodeID == NodeID.mapping)
        {
            if (node.containsKey("file"))
                cfg.file = node["file"].as!string;
            if (node.containsKey("external"))
                cfg.external = node["external"].as!bool;
            if (node.containsKey("name"))
                cfg.name = node["name"].as!string;
        }
        return cfg;
    }

    private TopLevelSecret parseSecret(string name, Node node)
    {
        TopLevelSecret sec;
        sec.name = name;
        if (node.nodeID == NodeID.mapping)
        {
            if (node.containsKey("file"))
                sec.file = node["file"].as!string;
            if (node.containsKey("external"))
                sec.external = node["external"].as!bool;
            if (node.containsKey("name"))
                sec.name = node["name"].as!string;
        }
        return sec;
    }

    private string[string] parseLabels(Node node)
    {
        string[string] labels;
        if (node.nodeID == NodeID.mapping)
        {
            foreach (string k, Node v; node)
            {
                labels[k] = v.as!string;
            }
        }
        else if (node.nodeID == NodeID.sequence)
        {
            foreach (Node v; node)
            {
                string val = v.as!string;
                auto parts = val.split("=");
                if (parts.length >= 2)
                {
                    labels[parts[0]] = parts[1 .. $].join("=");
                }
                else
                {
                    labels[val] = "";
                }
            }
        }
        return labels;
    }
}
