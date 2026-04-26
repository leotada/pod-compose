module commands.impl.rm;

import commands.base;
import core.config;
import core.parser;
import podman.cli;
import std.stdio;
import std.algorithm : canFind;

@safe:

class RmCommand : ICommand
{
    override void execute(Config config, PodmanCLI cli, string[] args)
    {
        bool force = false;
        string[] services;
        foreach (a; args)
        {
            if (a == "-f" || a == "--force")
                force = true;
            else
                services ~= a;
        }

        auto parser = new ComposeParser(config.composeFile);
        auto composeConfig = parser.parse();

        foreach (name, service; composeConfig.services)
        {
            if (services.length > 0 && !services.canFind(name))
                continue;
            string containerName = service.containerName.isNull ?
                config.projectName ~ "_" ~ name : service.containerName.get;
            if (cli.containerExists(containerName))
            {
                writeln("Removing container ", containerName, "...");
                cli.removeContainer(containerName, force);
            }
        }
    }
}
