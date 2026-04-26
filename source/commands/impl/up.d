module commands.impl.up;

import commands.base;
import commands.impl.build;
import core.config;
import core.duration;
import core.models;
import core.parser;
import podman.cli;
import std.stdio;
import std.algorithm;
import std.array;
import std.path;
import std.file : exists, readText;
import std.math;
import std.conv;
import std.string;
import std.datetime.stopwatch : StopWatch, AutoStart;
import core.thread : Thread;
import core.time : msecs, seconds;

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

    /// Read an env_file and merge into the given map. Lines starting with `#`
    /// or empty are ignored. Existing keys are NOT overwritten so values
    /// already present (e.g. from `environment:`) take precedence.
    void loadEnvFile(string path, ref string[string] env)
    {
        if (!exists(path))
        {
            writeln("   WARNING: env_file not found: ", path);
            return;
        }
        string content;
        try
            content = readText(path);
        catch (Exception e)
        {
            writeln("   WARNING: failed to read env_file ", path, ": ", e.msg);
            return;
        }
        foreach (rawLine; content.splitLines)
        {
            string line = rawLine.strip;
            if (line.length == 0 || line.startsWith("#"))
                continue;
            auto eq = line.indexOf('=');
            if (eq < 0)
                continue;
            string key = line[0 .. eq].strip;
            string val = line[eq + 1 .. $].strip;
            // Strip matching surrounding quotes
            if (val.length >= 2 && ((val[0] == '"' && val[$ - 1] == '"')
                    || (val[0] == '\'' && val[$ - 1] == '\'')))
                val = val[1 .. $ - 1];
            if (key.length == 0)
                continue;
            if (key !in env)
                env[key] = val;
        }
    }

    /// Wait until container reaches the desired state for `depends_on`
    /// conditions. Returns true on success, false on timeout/error.
    bool waitForCondition(PodmanCLI cli, string containerName, string condition,
        int timeoutSeconds = 120)
    {
        if (condition == "service_started" || condition.length == 0)
            return true;

        auto sw = StopWatch(AutoStart.yes);
        while (sw.peek < timeoutSeconds.seconds)
        {
            if (condition == "service_healthy")
            {
                string h = cli.getContainerHealth(containerName);
                if (h == "healthy")
                    return true;
                if (h == "unhealthy")
                {
                    writeln("   ERROR: dependency '", containerName, "' is unhealthy");
                    return false;
                }
            }
            else if (condition == "service_completed_successfully")
            {
                if (!cli.isContainerRunning(containerName))
                {
                    int code = cli.getContainerExitCode(containerName);
                    if (code == 0)
                        return true;
                    writeln("   ERROR: dependency '", containerName,
                        "' exited with code ", code);
                    return false;
                }
            }
            else
            {
                // Unknown condition: behave like service_started.
                return true;
            }
            () @trusted { Thread.sleep(500.msecs); }();
        }
        writeln("   ERROR: timed out waiting for '", containerName, "' (", condition, ")");
        return false;
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
            bool hasBuild = !service.build.isNull && !service.build.get.context.isNull;
            if (!service.image.isNull)
            {
                image = service.image.get;
            }
            else if (hasBuild)
            {
                image = config.projectName ~ "_" ~ name ~ ":latest";
            }
            else
            {
                writeln("   -> Error: Service '" ~ name ~ "' has no image or build defined.");
                continue;
            }

            // Build automatically when a build is defined and the image is
            // either missing locally or no `image:` was specified. This avoids
            // the previous behavior of letting `podman run` try to pull a
            // non-existent image.
            if (hasBuild && (service.image.isNull || !cli.imageExists(image)))
            {
                writeln("   -> Building image " ~ image ~ " for service " ~ name ~ "...");
                auto bcfg = service.build.get;
                PodmanCLI.BuildOptions bopts;
                bopts.context = bcfg.context.get;
                bopts.dockerfile = bcfg.dockerfile.isNull ? "Dockerfile" : bcfg.dockerfile.get;
                bopts.tag = image;
                if (!bcfg.target.isNull)
                    bopts.target = bcfg.target.get;
                if (!bcfg.network.isNull)
                    bopts.network = bcfg.network.get;
                if (!bcfg.shmSize.isNull)
                    bopts.shmSize = bcfg.shmSize.get;
                bopts.cacheFrom = bcfg.cacheFrom;
                bopts.args = bcfg.args;
                bopts.labels = bcfg.labels;
                if (cli.build(bopts) != 0)
                {
                    writeln("   -> Build failed for " ~ name ~ ", skipping.");
                    continue;
                }
            }

            // Replicas > 1 are not supported under a single shared pod.
            if (!service.deploy.isNull && !service.deploy.get.replicas.isNull
                && service.deploy.get.replicas.get > 1)
            {
                writeln("   WARNING: deploy.replicas > 1 is not supported under "
                    ~ "a shared pod; running a single instance for '" ~ name ~ "'.");
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
            // 1) env_file (in declared order; values do NOT override later sources)
            string[string] envMap;
            foreach (k, v; service.environment)
                envMap[k] = v;
            foreach (ef; service.envFile)
            {
                string p = ef;
                if (!isAbsolute(p))
                    p = buildPath(config.projectDir, p);
                loadEnvFile(p, envMap);
            }
            foreach (k, v; envMap)
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
                opts.entrypoint = service.entrypoint;
            if (!service.restart.isNull)
                opts.restartPolicy = service.restart.get;
            if (!service.stopSignal.isNull)
                opts.stopSignal = service.stopSignal.get;
            if (!service.stopGracePeriod.isNull)
            {
                int secs = parseDurationSeconds(service.stopGracePeriod.get);
                if (secs >= 0)
                    opts.stopTimeout = secs;
                else
                    writeln("WARNING: Could not parse stop_grace_period: ",
                        service.stopGracePeriod.get);
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
            if (!service.init.isNull)
                opts.init = service.init.get;
            if (!service.pid.isNull)
                opts.pid = service.pid.get;
            if (!service.ipc.isNull)
                opts.ipc = service.ipc.get;
            foreach (c; service.capAdd)
                opts.capAdd ~= c;
            foreach (c; service.capDrop)
                opts.capDrop ~= c;
            foreach (s; service.securityOpt)
                opts.securityOpt ~= s;
            foreach (g; service.groupAdd)
                opts.groupAdd ~= g;
            foreach (d; service.devices)
            {
                string spec = d.source;
                if (!d.target.isNull)
                    spec ~= ":" ~ d.target.get;
                if (!d.permissions.isNull)
                    spec ~= ":" ~ d.permissions.get;
                opts.devices ~= spec;
            }
            foreach (k, u; service.ulimits)
            {
                if (u.isScalar && !u.soft.isNull)
                    opts.ulimits ~= k ~ "=" ~ u.soft.get.to!string;
                else
                {
                    string soft = u.soft.isNull ? "" : u.soft.get.to!string;
                    string hard = u.hard.isNull ? soft : u.hard.get.to!string;
                    opts.ulimits ~= k ~ "=" ~ soft ~ ":" ~ hard;
                }
            }
            foreach (k, v; service.sysctls)
                opts.sysctls ~= k ~ "=" ~ v;

            // Logging
            if (!service.logging.isNull)
            {
                auto lg = service.logging.get;
                if (!lg.driver.isNull)
                    opts.logDriver = lg.driver.get;
                foreach (k, v; lg.options)
                    opts.logOpts ~= k ~ "=" ~ v;
            }

            // Networking
            opts.dns = service.dns;
            opts.dnsSearch = service.dnsSearch;
            opts.extraHosts = service.extraHosts;
            opts.expose = service.expose;
            if (!service.networkMode.isNull)
                writeln("   WARNING: network_mode is ignored when running inside a shared pod.");

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

            // After spawning the container, satisfy any depends_on conditions
            // declared by services that depend on THIS one. We check the
            // condition on the just-started container so dependents that come
            // later in the sorted list see a consistent state.
            foreach (otherName, otherSvc; composeConfig.services)
            {
                if (otherName == name)
                    continue;
                if (name in otherSvc.dependsOn)
                {
                    auto cond = otherSvc.dependsOn[name].condition;
                    if (cond == "service_healthy" || cond == "service_completed_successfully")
                    {
                        writeln("   -> Waiting for '", name, "' to satisfy '", cond, "'...");
                        if (!waitForCondition(cli, containerName, cond))
                        {
                            writeln("   -> Aborting up due to failed dependency condition.");
                            return;
                        }
                        break;
                    }
                }
            }
        }

        writeln("--- Deploy Completed! ---");
        cli.podPs(config.podName);
    }
}
