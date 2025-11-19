module commands.impl.exec;

import commands.base;
import core.config;
import core.parser;
import podman.cli;
import std.stdio;

@safe:

class ExecCommand : ICommand {
    override void execute(Config config, PodmanCLI cli, string[] args) {
        if (args.length < 2) {
            writeln("Usage: pod-compose exec [service] [command]");
            return;
        }

        string serviceName = args[0];
        string[] command = args[1 .. $];

        auto parser = new ComposeParser(config.composeFile);
        auto composeConfig = parser.parse();

        if (serviceName in composeConfig.services) {
            auto service = composeConfig.services[serviceName];
            string containerName = service.containerName.isNull ? 
                                   config.projectName ~ "_" ~ serviceName : 
                                   service.containerName.get;
            
            cli.exec(containerName, command);
        } else {
            writeln("Service not found: ", serviceName);
        }
    }
}
