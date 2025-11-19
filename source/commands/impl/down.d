module commands.impl.down;

import commands.base;
import core.config;
import podman.cli;
import std.stdio;

@safe:

class DownCommand : ICommand {
    override void execute(Config config, PodmanCLI cli, string[] args) {
        writeln("Bringing down Pod " ~ config.podName ~ "...");
        cli.removePod(config.podName);
    }
}
