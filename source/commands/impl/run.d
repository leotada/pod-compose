module commands.impl.run;

import commands.base;
import core.config;
import core.parser;
import podman.cli;
import std.stdio;
import std.algorithm : canFind;

@safe:

/// One-off command in a transient container attached to the project's pod.
/// Mirrors the most common `docker compose run` flags. The pod must already
/// exist (e.g. via a previous `up`).
class RunCommand : ICommand
{
    override void execute(Config config, PodmanCLI cli, string[] args)
    {
        bool removeOnExit = true;
        bool detach = false;
        bool noDeps = false;
        string entrypoint = "";
        string user = "";
        string[] envs;
        string serviceName = "";
        string[] cmd;

        for (size_t i = 0; i < args.length; i++)
        {
            string a = args[i];
            if (serviceName == "")
            {
                if (a == "--rm")
                {
                    removeOnExit = true;
                }
                else if (a == "--no-rm")
                {
                    removeOnExit = false;
                }
                else if (a == "-d" || a == "--detach")
                {
                    detach = true;
                }
                else if (a == "--no-deps")
                {
                    noDeps = true;
                }
                else if ((a == "-e" || a == "--env") && i + 1 < args.length)
                {
                    envs ~= args[++i];
                }
                else if ((a == "-u" || a == "--user") && i + 1 < args.length)
                {
                    user = args[++i];
                }
                else if (a == "--entrypoint" && i + 1 < args.length)
                {
                    entrypoint = args[++i];
                }
                else if (a.length > 0 && a[0] != '-')
                {
                    serviceName = a;
                }
                else
                {
                    writeln("Unknown option to run: ", a);
                    return;
                }
            }
            else
            {
                cmd ~= a;
            }
        }

        if (serviceName == "")
        {
            writeln("Usage: pod-compose run [--rm] [-d] [-e K=V] [--user U] "
                ~ "[--entrypoint X] SERVICE [COMMAND...]");
            return;
        }

        auto parser = new ComposeParser(config.composeFile);
        auto cfg = parser.parse();
        if (serviceName !in cfg.services)
        {
            writeln("Service not found: ", serviceName);
            return;
        }
        if (!cli.podExists(config.podName))
        {
            writeln("Pod ", config.podName, " does not exist. Run 'pod-compose up -d' first.");
            return;
        }

        auto svc = cfg.services[serviceName];
        string image = !svc.image.isNull ? svc.image.get
            : config.projectName ~ "_" ~ serviceName ~ ":latest";

        PodmanCLI.ContainerRunOptions opts;
        opts.podName = config.podName;
        // Use a unique timestamp-based name so multiple runs do not collide.
        import std.datetime.systime : Clock;
        import std.conv : to;
        opts.name = config.projectName ~ "_" ~ serviceName ~ "_run_"
            ~ Clock.currStdTime.to!string;
        opts.image = image;
        opts.removeOnExit = removeOnExit;
        opts.detach = detach;
        opts.interactive = !detach;
        opts.tty = !detach;
        opts.user = user;
        if (entrypoint.length > 0)
            opts.entrypoint = [entrypoint];
        opts.envs = envs;
        opts.command = cmd;

        cli.runContainer(opts);
    }
}
