module commands.impl.stop;

import commands.base;
import core.config;
import podman.cli;

@safe:

class StopCommand : ICommand {
    override void execute(Config config, PodmanCLI cli, string[] args) {
        cli.stopPod(config.podName);
    }
}
