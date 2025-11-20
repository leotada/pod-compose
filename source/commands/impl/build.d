module commands.impl.build;

import commands.base;
import core.config;
import core.parser;
import podman.cli;
import std.stdio;

@safe:

class BuildCommand : ICommand
{
    override void execute(Config config, PodmanCLI cli, string[] args)
    {
        writeln("--- Building Images ---");
        auto parser = new ComposeParser(config.composeFile);
        auto composeConfig = parser.parse();

        foreach (name, service; composeConfig.services)
        {
            if (!service.build.isNull && !service.build.get.context.isNull)
            {
                writeln("Building service: ", name);

                auto buildConfig = service.build.get;
                PodmanCLI.BuildOptions opts;
                opts.context = buildConfig.context.get;
                opts.dockerfile = buildConfig.dockerfile.isNull ? "Dockerfile"
                    : buildConfig.dockerfile.get;
                opts.tag = config.projectName ~ "_" ~ name ~ ":latest";

                if (!buildConfig.target.isNull)
                    opts.target = buildConfig.target.get;
                if (!buildConfig.network.isNull)
                    opts.network = buildConfig.network.get;
                if (!buildConfig.shmSize.isNull)
                    opts.shmSize = buildConfig.shmSize.get;
                opts.cacheFrom = buildConfig.cacheFrom;
                opts.args = buildConfig.args;
                opts.labels = buildConfig.labels;

                cli.build(opts);
            }
            else
            {
                writeln("Service '", name, "' does not require build (uses image).");
            }
        }
    }
}
