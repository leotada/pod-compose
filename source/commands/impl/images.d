module commands.impl.images;

import commands.base;
import core.config;
import core.parser;
import podman.cli;
import std.stdio;

@safe:

class ImagesCommand : ICommand
{
    override void execute(Config config, PodmanCLI cli, string[] args)
    {
        auto parser = new ComposeParser(config.composeFile);
        auto cfg = parser.parse();
        writeln("Images used by project '", config.projectName, "':");
        foreach (name, service; cfg.services)
        {
            string image;
            if (!service.image.isNull)
                image = service.image.get;
            else if (!service.build.isNull)
                image = config.projectName ~ "_" ~ name ~ ":latest";
            else
                image = "(no image)";
            writeln("  ", name, "\t", image);
        }
    }
}
