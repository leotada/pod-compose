module commands.impl.start;

import commands.base;
import core.config;
import podman.cli;

@safe:

class StartCommand : ICommand {
    override void execute(Config config, PodmanCLI cli, string[] args) {
        cli.startPod(config.podName);
    }
}
