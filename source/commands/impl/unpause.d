module commands.impl.unpause;

import commands.base;
import core.config;
import podman.cli;

@safe:

class UnpauseCommand : ICommand
{
    override void execute(Config config, PodmanCLI cli, string[] args)
    {
        cli.unpausePod(config.podName);
    }
}
