module commands.impl.logs;

import commands.base;
import core.config;
import core.parser;
import podman.cli;
import std.stdio;
import std.algorithm;

@safe:

class LogsCommand : ICommand {
    override void execute(Config config, PodmanCLI cli, string[] args) {
        bool follow = false;
        string[] services;
        
        foreach(arg; args) {
            if (arg == "-f" || arg == "--follow") follow = true;
            else services ~= arg;
        }

        if (services.length == 0) {
            // If no service specified, maybe log all? 
            // Podman logs takes a container name. 
            // We need to iterate all services.
            auto parser = new ComposeParser(config.composeFile);
            auto composeConfig = parser.parse();
            foreach(name, service; composeConfig.services) {
                 string containerName = service.containerName.isNull ? 
                                   config.projectName ~ "_" ~ name : 
                                   service.containerName.get;
                 writeln("--- Logs for " ~ name ~ " ---");
                 cli.logs(containerName, follow);
            }
        } else {
            auto parser = new ComposeParser(config.composeFile);
            auto composeConfig = parser.parse();
            
            foreach(s; services) {
                if (s in composeConfig.services) {
                    auto service = composeConfig.services[s];
                    string containerName = service.containerName.isNull ? 
                                   config.projectName ~ "_" ~ s : 
                                   service.containerName.get;
                    cli.logs(containerName, follow);
                } else {
                    writeln("Service not found: ", s);
                }
            }
        }
    }
}
