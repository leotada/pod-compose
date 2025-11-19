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

@safe:

class UpCommand : ICommand {
    override void execute(Config config, PodmanCLI cli, string[] args) {
        writeln("--- Interpreting " ~ config.composeFile ~ " for Podman Pods ---");
        
        auto parser = new ComposeParser(config.composeFile);
        auto composeConfig = parser.parse();
        
        if (composeConfig.services.length == 0) {
            writeln("Error: No services found.");
            return;
        }

        // 1. Identify ports and hosts
        writeln("[1/4] Identifying ports and hosts...");
        string[] allPorts;
        string[] hostMaps;
        
        foreach (name, service; composeConfig.services) {
            foreach (p; service.ports) allPorts ~= p;
            hostMaps ~= name ~ ":127.0.0.1";
        }

        // 2. Create Pod
        if (cli.podExists(config.podName)) {
            writeln("Pod " ~ config.podName ~ " already exists.");
        } else {
            writeln("[2/4] Creating Pod '" ~ config.podName ~ "'");
            if (cli.createPod(config.podName, allPorts, hostMaps) != 0) {
                return;
            }
        }

        // 3. Start Services
        writeln("[3/4] Starting services...");
        foreach (name, service; composeConfig.services) {
            writeln("Processing service: ", name);
            
            string image = "";
            if (!service.image.isNull) {
                image = service.image.get;
            } else if (!service.buildContext.isNull) {
                string imageName = config.projectName ~ "_" ~ name ~ ":latest";
                if (!cli.imageExists(imageName)) {
                    writeln("   WARNING: Image " ~ imageName ~ " may not exist. Run 'pod-compose build' first.");
                }
                image = imageName;
            } else {
                writeln("   -> Error: Service '" ~ name ~ "' has no image or build defined.");
                continue;
            }

            string containerName = service.containerName.isNull ? 
                                   config.projectName ~ "_" ~ name : 
                                   service.containerName.get;

            if (cli.containerExists(containerName)) {
                writeln("   -> Container " ~ containerName ~ " already exists. Starting...");
                cli.startContainer(containerName);
                continue;
            }

            string[] envs;
            foreach (k, v; service.environment) {
                envs ~= k ~ "=" ~ v;
            }

            string[] cmdArgs = service.command;
            string user = service.user.isNull ? "" : service.user.get;

            writeln("   -> Creating container " ~ containerName ~ "...");
            cli.runContainer(config.podName, containerName, image, envs, service.volumes, user, cmdArgs);
        }

        writeln("--- Deploy Completed! ---");
        cli.podPs(config.podName);
    }
}
