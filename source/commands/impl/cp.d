module commands.impl.cp;

import commands.base;
import core.config;
import core.models;
import core.parser;
import podman.cli;
import std.stdio;
import std.string : indexOf;

@safe:

/// Translate a `service:path` argument into a `container:path` form using
/// the project's container naming. If `arg` does not contain `:` or the
/// prefix is not a known service, the value is returned unchanged.
private string resolveServicePath(string arg, Config config, ComposeConfig cfg)
{
    auto colon = arg.indexOf(':');
    if (colon <= 0)
        return arg;
    string svc = arg[0 .. colon];
    string rest = arg[colon .. $];
    if (svc !in cfg.services)
        return arg;
    auto s = cfg.services[svc];
    string container = s.containerName.isNull ?
        config.projectName ~ "_" ~ svc : s.containerName.get;
    return container ~ rest;
}

class CpCommand : ICommand
{
    override void execute(Config config, PodmanCLI cli, string[] args)
    {
        if (args.length < 2)
        {
            writeln("Usage: pod-compose cp SRC DEST");
            writeln("  SRC/DEST may be SERVICE:PATH or a host path.");
            return;
        }
        auto parser = new ComposeParser(config.composeFile);
        auto cfg = parser.parse();
        string src = resolveServicePath(args[0], config, cfg);
        string dest = resolveServicePath(args[1], config, cfg);
        cli.cp(src, dest);
    }
}
