module commands.impl.up;

import commands.base;
import core.config;
import core.models;
import core.parser;
import podman.cli;
import std.stdio;
import std.algorithm;
import std.array;
import std.path;
import std.math;
import std.conv;

@safe:

class UpCommand : ICommand
{
    string[] sortServices(Service[string] services)
    {
        string[] sorted;
        bool[string] visited;
        bool[string] visiting;

        void visit(string name) @safe
        {
            if (name in visited)
                return;
            if (name in visiting)
                throw new Exception("Circular dependency detected: " ~ name);

            visiting[name] = true;

            if (name in services)
            {
                foreach (depName, _; services[name].dependsOn)
                {
                    visit(depName);
                }
            }

            visiting.remove(name);
            visited[name] = true;
            sorted ~= name;
        }

        // Sort keys to ensure deterministic order for independent nodes
        auto serviceNames = services.keys.sort();
        foreach (name; serviceNames)
        {
            visit(name);
        }

        return sorted;
    }

    override void execute(Config config, PodmanCLI cli, string[] args)
    {
        writeln("--- Interpreting " ~ config.composeFile ~ " for Podman Pods ---");

        auto parser = new ComposeParser(config.composeFile);
        auto composeConfig = parser.parse();

        if (composeConfig.services.length == 0)
        {
            writeln("Error: No services found.");
            return;
        }

        // 1. Identify ports and hosts
        writeln("[1/4] Identifying ports and hosts...");
        string[] allPorts;
        string[] hostMaps;

        foreach (name, service; composeConfig.services)
        {
            foreach (p; service.ports)
            {
                if (!p.published.isNull && !p.target.isNull)
                {
                    allPorts ~= p.published.get ~ ":" ~ p.target.get;
                }
            }
            hostMaps ~= name ~ ":127.0.0.1";
        }

        // 1.5 Create Secrets
        writeln("[1.5/4] Creating secrets...");
        string[string] secretNameMap;
        foreach (key, secret; composeConfig.secrets)
        {
            string secretName = secret.name.isNull ? config.projectName ~ "_" ~ key
                : secret.name.get;
            secretNameMap[key] = secretName;

            bool isExternal = !secret.external.isNull && secret.external.get;
            if (isExternal)
            {
                if (!cli.secretExists(secretName))
                {
                    writeln("WARNING: External secret '", secretName, "' not found.");
                }
            }
            else if (!secret.file.isNull)
            {
                if (!cli.secretExists(secretName))
                {
                    writeln("Creating secret: ", secretName);
                    cli.createSecret(secretName, secret.file.get);
                }
            }
        }

        // 1.6 Create Networks
        writeln("[1.6/4] Creating networks...");
        string[] podNetworks;
        string[string] networkNameMap;
        foreach (key, network; composeConfig.networks)
        {
            string netName = network.name.isNull ? config.projectName ~ "_" ~ key : network
                .name.get;
            networkNameMap[key] = netName;
            podNetworks ~= netName;

            bool isExternal = !network.external.isNull && network.external.get;
            if (isExternal)
            {
                if (!cli.networkExists(netName))
                    writeln("WARNING: External network '", netName, "' not found.");
            }
            else
            {
                if (!cli.networkExists(netName))
                {
                    writeln("Creating network: ", netName);
                    string driver = network.driver.isNull ? "" : network.driver.get;
                    cli.createNetwork(netName, driver, network.labels);
                }
            }
        }

        // 1.7 Create Volumes
        writeln("[1.7/4] Creating volumes...");
        string[string] volumeNameMap;
        foreach (key, volume; composeConfig.volumes)
        {
            string volName = volume.name.isNull ? config.projectName ~ "_" ~ key : volume.name.get;
            volumeNameMap[key] = volName;

            bool isExternal = !volume.external.isNull && volume.external.get;
            if (isExternal)
            {
                if (!cli.volumeExists(volName))
                    writeln("WARNING: External volume '", volName, "' not found.");
            }
            else
            {
                if (!cli.volumeExists(volName))
                {
                    writeln("Creating volume: ", volName);
                    string driver = volume.driver.isNull ? "" : volume.driver.get;
                    cli.createVolume(volName, driver, volume.labels);
                }
            }
        }

        // 2. Create Pod
        if (cli.podExists(config.podName))
        {
            writeln("Pod " ~ config.podName ~ " already exists.");
        }
        else
        {
            writeln("[2/4] Creating Pod '" ~ config.podName ~ "'");
            // If no networks defined, use default (empty list)
            if (cli.createPod(config.podName, allPorts, hostMaps, podNetworks) != 0)
            {
                return;
            }
        }

        // 3. Start Services
        writeln("[3/4] Starting services...");

        // Sort services by dependency
        string[] sortedServices;
        try
        {
            sortedServices = sortServices(composeConfig.services);
        }
        catch (Exception e)
        {
            writeln("Error resolving dependencies: " ~ e.msg);
            return;
        }

        foreach (name; sortedServices)
        {
            auto service = composeConfig.services[name];
            writeln("Processing service: ", name);

            string image = "";
            if (!service.image.isNull)
            {
                image = service.image.get;
            }
            else if (!service.build.isNull && !service.build.get.context.isNull)
            {
                string imageName = config.projectName ~ "_" ~ name ~ ":latest";
                if (!cli.imageExists(imageName))
                {
                    writeln(
                        "   WARNING: Image " ~ imageName ~ " may not exist. Run 'pod-compose build' first.");
                }
                image = imageName;
            }
            else
            {
                writeln("   -> Error: Service '" ~ name ~ "' has no image or build defined.");
                continue;
            }

            string containerName = service.containerName.isNull ?
                config.projectName ~ "_" ~ name : service.containerName.get;

            if (cli.containerExists(containerName))
            {
                writeln("   -> Container " ~ containerName ~ " already exists. Starting...");
                cli.startContainer(containerName);
                continue;
            }

            string[] envs;
            foreach (k, v; service.environment)
            {
                envs ~= k ~ "=" ~ v;
            }

            string[] cmdArgs = service.command;
            string user = service.user.isNull ? "" : service.user.get;

            string[] volumeStrings;
            foreach (v; service.volumes)
            {
                string volStr = "";
                if (!v.source.isNull)
                {
                    string src = v.source.get;
                    if (src in volumeNameMap)
                    {
                        volStr ~= volumeNameMap[src] ~ ":";
                    }
                    else
                    {
                        volStr ~= src ~ ":";
                    }
                }
                if (!v.target.isNull)
                    volStr ~= v.target.get;
                if (!v.readOnly.isNull && v.readOnly.get)
                    volStr ~= ":ro";
                if (volStr.length > 0)
                    volumeStrings ~= volStr;
            }

            // Configs (mapped as bind mounts)
            foreach (c; service.configs)
            {
                if (!c.source.isNull)
                {
                    string configName = c.source.get;
                    if (configName in composeConfig.configs)
                    {
                        auto topConfig = composeConfig.configs[configName];
                        if (!topConfig.file.isNull)
                        {
                            string sourcePath = topConfig.file.get;
                            string targetPath = "/" ~ configName; // Default target
                            if (!c.target.isNull)
                                targetPath = c.target.get;

                            // If it's a relative path, make it absolute based on compose file location?
                            // For now, assume user provides valid paths or we rely on Podman/Docker semantics.
                            // But we should probably resolve it relative to project dir if it's a file.
                            // Let's just pass it as is for now.

                            volumeStrings ~= sourcePath ~ ":" ~ targetPath ~ ":ro";
                        }
                    }
                }
            }

            writeln("   -> Creating container " ~ containerName ~ "...");

            PodmanCLI.ContainerRunOptions opts;
            opts.podName = config.podName;
            opts.name = containerName;
            opts.image = image;
            opts.envs = envs;
            opts.volumes = volumeStrings;
            opts.user = user;
            opts.command = cmdArgs;

            if (!service.workingDir.isNull)
                opts.workdir = service.workingDir.get;
            if (service.entrypoint.length > 0)
                opts.entrypoint = service.entrypoint[0]; // Simplified: take first
            if (!service.restart.isNull)
                opts.restartPolicy = service.restart.get;
            if (!service.stopSignal.isNull)
                opts.stopSignal = service.stopSignal.get;
            if (!service.stopGracePeriod.isNull)
            {
                // Parse duration string (e.g., "10s") to seconds. 
                // For simplicity, assuming it ends with 's' or is just a number.
                // A proper duration parser would be better, but let's do basic parsing.
                string val = service.stopGracePeriod.get;
                if (val.endsWith("s"))
                    val = val[0 .. $ - 1];
                try
                {
                    opts.stopTimeout = val.to!int;
                }
                catch (Exception e)
                {
                    writeln("WARNING: Could not parse stop_grace_period: ", val);
                }
            }
            if (!service.hostname.isNull)
                opts.hostname = service.hostname.get;
            if (!service.domainname.isNull)
                opts.domainname = service.domainname.get;

            foreach (k, v; service.labels)
                opts.labels ~= k ~ "=" ~ v;

            // Resources
            if (!service.deploy.isNull && !service.deploy.get.resources.limits.cpus.isNull)
                opts.cpus = service.deploy.get.resources.limits.cpus.get;
            else if (!service.cpus.isNull)
                opts.cpus = service.cpus.get;

            if (!service.deploy.isNull && !service.deploy.get.resources.limits.memory.isNull)
                opts.memory = service.deploy.get.resources.limits.memory.get;
            else if (!service.memLimit.isNull)
                opts.memory = service.memLimit.get;

            // Healthcheck
            if (!service.healthcheck.isNull)
            {
                auto hc = service.healthcheck.get;
                if (!hc.disable.isNull && hc.disable.get)
                {
                    opts.noHealthcheck = true;
                }
                else
                {
                    if (hc.test.length > 0)
                        opts.healthCmd = hc.test.join(" ");
                    if (!hc.interval.isNull)
                        opts.healthInterval = hc.interval.get;
                    if (!hc.timeout.isNull)
                        opts.healthTimeout = hc.timeout.get;
                    if (!hc.startPeriod.isNull)
                        opts.healthStartPeriod = hc.startPeriod.get;
                    if (!hc.retries.isNull)
                        opts.healthRetries = hc.retries.get;
                }
            }

            // Security
            if (!service.privileged.isNull)
                opts.privileged = service.privileged.get;
            if (!service.readOnly.isNull)
                opts.readOnly = service.readOnly.get;
            foreach (c; service.capAdd)
                opts.capAdd ~= c;
            foreach (c; service.capDrop)
                opts.capDrop ~= c;
            foreach (s; service.securityOpt)
                opts.securityOpt ~= s;

            // Networking
            opts.dns = service.dns;
            opts.dnsSearch = service.dnsSearch;
            opts.extraHosts = service.extraHosts;

            // Secrets
            foreach (s; service.secrets)
            {
                if (!s.source.isNull)
                {
                    string sourceKey = s.source.get;
                    if (sourceKey in secretNameMap)
                    {
                        opts.secrets ~= secretNameMap[sourceKey];
                    }
                    else
                    {
                        opts.secrets ~= sourceKey;
                    }
                }
            }

            cli.runContainer(opts);
        }

        writeln("--- Deploy Completed! ---");
        cli.podPs(config.podName);
    }
}
