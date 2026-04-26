module commands.impl.pause;

import commands.base;
import core.config;
import podman.cli;

@safe:

class PauseCommand : ICommand
{
    override void execute(Config config, PodmanCLI cli, string[] args)
    {
        cli.pausePod(config.podName);
    }
}
