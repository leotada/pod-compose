module commands.impl.version_;

import commands.base;
import core.config;
import core.version_;
import podman.cli;
import std.stdio;

@safe:

class VersionCommand : ICommand {
    override void execute(Config config, PodmanCLI cli, string[] args) {
        writeln("pod-compose version ", AppVersion);
    }
}
