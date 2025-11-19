module commands.impl.restart;

import commands.base;
import core.config;
import podman.cli;

@safe:

class RestartCommand : ICommand {
    override void execute(Config config, PodmanCLI cli, string[] args) {
        cli.restartPod(config.podName);
    }
}
