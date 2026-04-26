module commands.impl.events;

import commands.base;
import core.config;
import podman.cli;

@safe:

class EventsCommand : ICommand
{
    override void execute(Config config, PodmanCLI cli, string[] args)
    {
        string[] filters = ["pod=" ~ config.podName];
        foreach (a; args)
            filters ~= a;
        cli.events(filters);
    }
}
