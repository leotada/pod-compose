module commands.impl.pull;

import commands.base;
import core.config;
import core.parser;
import podman.cli;
import std.stdio;

@safe:

class PullCommand : ICommand {
    override void execute(Config config, PodmanCLI cli, string[] args) {
        auto parser = new ComposeParser(config.composeFile);
        auto composeConfig = parser.parse();

        foreach (name, service; composeConfig.services) {
            if (!service.image.isNull) {
                writeln("Pulling image for service: ", name);
                cli.pull(service.image.get);
            }
        }
    }
}
