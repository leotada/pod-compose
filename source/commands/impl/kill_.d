module commands.impl.kill_;

import commands.base;
import core.config;
import core.parser;
import podman.cli;
import std.stdio;
import std.string : startsWith;
import std.algorithm : canFind;

@safe:

class KillCommand : ICommand
{
    override void execute(Config config, PodmanCLI cli, string[] args)
    {
        string signal = "";
        string[] services;
        for (size_t i = 0; i < args.length; i++)
        {
            string a = args[i];
            if (a == "-s" || a == "--signal")
            {
                if (i + 1 < args.length)
                    signal = args[++i];
            }
            else if (a.startsWith("--signal="))
            {
                signal = a["--signal=".length .. $];
            }
            else
            {
                services ~= a;
            }
        }

        if (services.length == 0)
        {
            cli.killPod(config.podName, signal);
            return;
        }

        auto parser = new ComposeParser(config.composeFile);
        auto composeConfig = parser.parse();
        foreach (svc; services)
        {
            if (svc !in composeConfig.services)
            {
                writeln("Service not found: ", svc);
                continue;
            }
            auto service = composeConfig.services[svc];
            string containerName = service.containerName.isNull ?
                config.projectName ~ "_" ~ svc : service.containerName.get;
            cli.killContainer(containerName, signal);
        }
    }
}
