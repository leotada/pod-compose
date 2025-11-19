module commands.impl.build;

import commands.base;
import core.config;
import core.parser;
import podman.cli;
import std.stdio;

@safe:

class BuildCommand : ICommand {
    override void execute(Config config, PodmanCLI cli, string[] args) {
        writeln("--- Building Images ---");
        auto parser = new ComposeParser(config.composeFile);
        auto composeConfig = parser.parse();

        foreach (name, service; composeConfig.services) {
            if (!service.buildContext.isNull) {
                writeln("Building service: ", name);
                
                string context = service.buildContext.get;
                string dockerfile = service.dockerfile.isNull ? "Dockerfile" : service.dockerfile.get;
                string target = service.target.isNull ? "" : service.target.get;
                string imageName = config.projectName ~ "_" ~ name ~ ":latest";

                cli.build(context, dockerfile, imageName, target);
            } else {
                writeln("Service '", name, "' does not require build (uses image).");
            }
        }
    }
}
