module commands.impl.top;

import commands.base;
import core.config;
import podman.cli;

@safe:

class TopCommand : ICommand
{
    override void execute(Config config, PodmanCLI cli, string[] args)
    {
        cli.podTop(config.podName, args);
    }
}
