module commands.impl.push;

import commands.base;
import core.config;
import core.parser;
import podman.cli;
import std.stdio;
import std.algorithm : canFind;

@safe:

class PushCommand : ICommand
{
    override void execute(Config config, PodmanCLI cli, string[] args)
    {
        auto parser = new ComposeParser(config.composeFile);
        auto composeConfig = parser.parse();

        foreach (name, service; composeConfig.services)
        {
            if (args.length > 0 && !args.canFind(name))
                continue;
            string image;
            if (!service.image.isNull)
                image = service.image.get;
            else if (!service.build.isNull)
                image = config.projectName ~ "_" ~ name ~ ":latest";
            else
                continue;
            writeln("Pushing image for service ", name, ": ", image);
            cli.push(image);
        }
    }
}
