module core.parsers.service;

import dyaml;
import core.models;
import std.conv;
import std.string;
import std.algorithm;
import std.typecons : Nullable;
import std.array;

@safe:

class ServiceParser
{
    static Service parse(string name, Node node)
    {
        Service service;
        service.name = name;

        // Basic
        if (node.containsKey("image"))
            service.image = node["image"].as!string;
        if (node.containsKey("container_name"))
            service.containerName = node["container_name"].as!string;
        if (node.containsKey("hostname"))
            service.hostname = node["hostname"].as!string;
        if (node.containsKey("domainname"))
            service.domainname = node["domainname"].as!string;
        if (node.containsKey("mac_address"))
            service.macAddress = node["mac_address"].as!string;
        if (node.containsKey("working_dir"))
            service.workingDir = node["working_dir"].as!string;
        if (node.containsKey("user"))
            service.user = node["user"].as!string;
        if (node.containsKey("profiles"))
        {
            foreach (Node p; node["profiles"])
                service.profiles ~= p.as!string;
        }

        // Build
        if (node.containsKey("build"))
        {
            service.build = parseBuild(node["build"]);
        }

        // Ports
        if (node.containsKey("ports"))
        {
            foreach (Node p; node["ports"])
            {
                service.ports ~= parsePort(p);
            }
        }

        // Networks
        if (node.containsKey("networks"))
        {
            service.networks = parseServiceNetworks(node["networks"]);
        }

        // Volumes
        if (node.containsKey("volumes"))
        {
            foreach (Node v; node["volumes"])
            {
                service.volumes ~= parseServiceVolume(v);
            }
        }

        // Environment
        if (node.containsKey("environment"))
        {
            service.environment = parseEnvironment(node["environment"]);
        }
        if (node.containsKey("env_file"))
        {
            service.envFile = parseStringOrList(node["env_file"]);
        }

        // Lifecycle
        if (node.containsKey("restart"))
            service.restart = node["restart"].as!string;
        if (node.containsKey("depends_on"))
            service.dependsOn = parseDependsOn(node["depends_on"]);
        if (node.containsKey("init"))
            service.init = node["init"].as!bool;
        if (node.containsKey("stop_grace_period"))
            service.stopGracePeriod = node["stop_grace_period"].as!string;
        if (node.containsKey("stop_signal"))
            service.stopSignal = node["stop_signal"].as!string;

        // Healthcheck
        if (node.containsKey("healthcheck"))
            service.healthcheck = parseHealthCheck(node["healthcheck"]);

        // Logging
        if (node.containsKey("logging"))
            service.logging = parseLogging(node["logging"]);

        // Resources
        if (node.containsKey("cpus"))
            service.cpus = node["cpus"].as!float;
        if (node.containsKey("mem_limit"))
            service.memLimit = node["mem_limit"].as!string;
        if (node.containsKey("mem_reservation"))
            service.memReservation = node["mem_reservation"].as!string;

        // Security
        if (node.containsKey("cap_add"))
            foreach (Node n; node["cap_add"])
                service.capAdd ~= n.as!string;
        if (node.containsKey("cap_drop"))
            foreach (Node n; node["cap_drop"])
                service.capDrop ~= n.as!string;
        if (node.containsKey("security_opt"))
            foreach (Node n; node["security_opt"])
                service.securityOpt ~= n.as!string;
        if (node.containsKey("privileged"))
            service.privileged = node["privileged"].as!bool;
        if (node.containsKey("read_only"))
            service.readOnly = node["read_only"].as!bool;

        // Networking
        if (node.containsKey("dns"))
            service.dns = parseStringOrList(node["dns"]);
        if (node.containsKey("dns_search"))
            service.dnsSearch = parseStringOrList(node["dns_search"]);
        if (node.containsKey("extra_hosts"))
            service.extraHosts = parseStringOrList(node["extra_hosts"]);
        if (node.containsKey("expose"))
            service.expose = parseStringOrList(node["expose"]);
        if (node.containsKey("network_mode"))
            service.networkMode = node["network_mode"].as!string;

        // Configs/Secrets
        if (node.containsKey("configs"))
        {
            foreach (Node n; node["configs"])
                service.configs ~= parseServiceConfig(n);
        }
        if (node.containsKey("secrets"))
        {
            foreach (Node n; node["secrets"])
                service.secrets ~= parseServiceSecret(n);
        }

        // Deploy
        if (node.containsKey("deploy"))
            service.deploy = parseDeploy(node["deploy"]);

        // Command/Entrypoint
        if (node.containsKey("command"))
            service.command = parseStringOrList(node["command"]);
        if (node.containsKey("entrypoint"))
            service.entrypoint = parseStringOrList(node["entrypoint"]);

        // Labels
        if (node.containsKey("labels"))
            service.labels = parseLabels(node["labels"]);

        return service;
    }

    private static Build parseBuild(Node node)
    {
        Build build;
        if (node.nodeID == NodeID.scalar)
        {
            build.context = node.as!string;
        }
        else if (node.nodeID == NodeID.mapping)
        {
            if (node.containsKey("context"))
                build.context = node["context"].as!string;
            if (node.containsKey("dockerfile"))
                build.dockerfile = node["dockerfile"].as!string;
            if (node.containsKey("args"))
                build.args = parseEnvironment(node["args"]);
            if (node.containsKey("target"))
                build.target = node["target"].as!string;
            if (node.containsKey("network"))
                build.network = node["network"].as!string;
            if (node.containsKey("shm_size"))
                build.shmSize = node["shm_size"].as!string;
            if (node.containsKey("cache_from"))
                build.cacheFrom = parseStringOrList(node["cache_from"]);
            if (node.containsKey("labels"))
                build.labels = parseLabels(node["labels"]);
        }
        return build;
    }

    private static Port parsePort(Node node)
    {
        Port port;
        if (node.nodeID == NodeID.scalar)
        {
            string s = node.as!string;
            auto parts = s.split(":");
            if (parts.length > 0)
                port.published = parts[0];
            if (parts.length > 1)
                port.target = parts[1];
        }
        else if (node.nodeID == NodeID.mapping)
        {
            if (node.containsKey("target"))
                port.target = node["target"].as!string;
            if (node.containsKey("published"))
                port.published = node["published"].as!string;
            if (node.containsKey("protocol"))
                port.protocol = node["protocol"].as!string;
            if (node.containsKey("mode"))
                port.mode = node["mode"].as!string;
        }
        return port;
    }

    private static NetworkAttachment[string] parseServiceNetworks(Node node)
    {
        NetworkAttachment[string] networks;
        if (node.nodeID == NodeID.sequence)
        {
            foreach (Node n; node)
            {
                NetworkAttachment net;
                net.name = n.as!string;
                networks[net.name] = net;
            }
        }
        else if (node.nodeID == NodeID.mapping)
        {
            foreach (string name, Node n; node)
            {
                NetworkAttachment net;
                net.name = name;
                if (n.containsKey("aliases"))
                {
                    foreach (Node a; n["aliases"])
                        net.aliases ~= a.as!string;
                }
                if (n.containsKey("ipv4_address"))
                    net.ipv4Address = n["ipv4_address"].as!string;
                if (n.containsKey("ipv6_address"))
                    net.ipv6Address = n["ipv6_address"].as!string;
                networks[name] = net;
            }
        }
        return networks;
    }

    private static ServiceVolume parseServiceVolume(Node node)
    {
        ServiceVolume vol;
        if (node.nodeID == NodeID.scalar)
        {
            string s = node.as!string;
            auto parts = s.split(":");
            if (parts.length >= 1)
                vol.source = parts[0];
            if (parts.length >= 2)
                vol.target = parts[1];
            if (parts.length >= 3)
            {
                if (parts[2] == "ro")
                    vol.readOnly = true;
            }
            if (parts.length == 1)
            {
                vol.target = parts[0];
                vol.source = null;
            }
            vol.type = "volume";
        }
        else if (node.nodeID == NodeID.mapping)
        {
            if (node.containsKey("type"))
                vol.type = node["type"].as!string;
            if (node.containsKey("source"))
                vol.source = node["source"].as!string;
            if (node.containsKey("target"))
                vol.target = node["target"].as!string;
            if (node.containsKey("read_only"))
                vol.readOnly = node["read_only"].as!bool;
        }
        return vol;
    }

    private static string[string] parseEnvironment(Node node)
    {
        string[string] env;
        if (node.nodeID == NodeID.mapping)
        {
            foreach (string k, Node v; node)
            {
                env[k] = v.as!string;
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
                    env[parts[0]] = parts[1 .. $].join("=");
                }
                else
                {
                    env[val] = "";
                }
            }
        }
        return env;
    }

    private static ServiceDependency[string] parseDependsOn(Node node)
    {
        ServiceDependency[string] deps;
        if (node.nodeID == NodeID.sequence)
        {
            foreach (Node n; node)
            {
                ServiceDependency dep;
                dep.condition = "service_started";
                deps[n.as!string] = dep;
            }
        }
        else if (node.nodeID == NodeID.mapping)
        {
            foreach (string name, Node n; node)
            {
                ServiceDependency dep;
                if (n.containsKey("condition"))
                    dep.condition = n["condition"].as!string;
                if (n.containsKey("restart"))
                    dep.restart = n["restart"].as!bool;
                deps[name] = dep;
            }
        }
        return deps;
    }

    private static HealthCheck parseHealthCheck(Node node)
    {
        HealthCheck hc;
        if (node.containsKey("test"))
            hc.test = parseStringOrList(node["test"]);
        if (node.containsKey("interval"))
            hc.interval = node["interval"].as!string;
        if (node.containsKey("timeout"))
            hc.timeout = node["timeout"].as!string;
        if (node.containsKey("retries"))
            hc.retries = node["retries"].as!int;
        if (node.containsKey("start_period"))
            hc.startPeriod = node["start_period"].as!string;
        if (node.containsKey("disable"))
            hc.disable = node["disable"].as!bool;
        return hc;
    }

    private static Logging parseLogging(Node node)
    {
        Logging log;
        if (node.containsKey("driver"))
            log.driver = node["driver"].as!string;
        if (node.containsKey("options"))
        {
            foreach (string k, Node v; node["options"])
                log.options[k] = v.as!string;
        }
        return log;
    }

    private static Deploy parseDeploy(Node node)
    {
        Deploy deploy;
        if (node.containsKey("mode"))
            deploy.mode = node["mode"].as!string;
        if (node.containsKey("replicas"))
            deploy.replicas = node["replicas"].as!int;
        if (node.containsKey("labels"))
            deploy.labels = parseLabels(node["labels"]);
        if (node.containsKey("resources"))
        {
            Node res = node["resources"];
            if (res.containsKey("limits"))
            {
                if (res["limits"].containsKey("cpus"))
                    deploy.resources.limits.cpus = res["limits"]["cpus"].as!float;
                if (res["limits"].containsKey("memory"))
                    deploy.resources.limits.memory = res["limits"]["memory"].as!string;
            }
            if (res.containsKey("reservations"))
            {
                if (res["reservations"].containsKey("cpus"))
                    deploy.resources.reservations.cpus = res["reservations"]["cpus"].as!float;
                if (res["reservations"].containsKey("memory"))
                    deploy.resources.reservations.memory = res["reservations"]["memory"].as!string;
            }
        }
        return deploy;
    }

    private static ServiceConfig parseServiceConfig(Node node)
    {
        ServiceConfig cfg;
        if (node.nodeID == NodeID.scalar)
        {
            cfg.source = node.as!string;
        }
        else if (node.nodeID == NodeID.mapping)
        {
            if (node.containsKey("source"))
                cfg.source = node["source"].as!string;
            if (node.containsKey("target"))
                cfg.target = node["target"].as!string;
            if (node.containsKey("uid"))
                cfg.uid = node["uid"].as!string;
            if (node.containsKey("gid"))
                cfg.gid = node["gid"].as!string;
            if (node.containsKey("mode"))
                cfg.mode = node["mode"].as!int;
        }
        return cfg;
    }

    private static ServiceSecret parseServiceSecret(Node node)
    {
        ServiceSecret sec;
        if (node.nodeID == NodeID.scalar)
        {
            sec.source = node.as!string;
        }
        else if (node.nodeID == NodeID.mapping)
        {
            if (node.containsKey("source"))
                sec.source = node["source"].as!string;
            if (node.containsKey("target"))
                sec.target = node["target"].as!string;
            if (node.containsKey("uid"))
                sec.uid = node["uid"].as!string;
            if (node.containsKey("gid"))
                sec.gid = node["gid"].as!string;
            if (node.containsKey("mode"))
                sec.mode = node["mode"].as!int;
        }
        return sec;
    }

    private static string[string] parseLabels(Node node)
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

    private static string[] parseStringOrList(Node node)
    {
        string[] list;
        if (node.nodeID == NodeID.scalar)
        {
            list ~= node.as!string;
        }
        else if (node.nodeID == NodeID.sequence)
        {
            foreach (Node v; node)
            {
                list ~= v.as!string;
            }
        }
        return list;
    }
}
