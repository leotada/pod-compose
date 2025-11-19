module commands.base;

import core.config;
import core.models;
import podman.cli;

interface ICommand {
    void execute(Config config, PodmanCLI cli, string[] args);
}
