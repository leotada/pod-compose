module commands.impl.ps;

import commands.base;
import core.config;
import podman.cli;

@safe:

class PsCommand : ICommand
{
    override void execute(Config config, PodmanCLI cli, string[] args)
    {
        cli.ps("", args);
    }
}
