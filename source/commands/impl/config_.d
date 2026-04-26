module commands.impl.config_;

import commands.base;
import core.config;
import core.parser;
import core.models;
import podman.cli;
import std.stdio;
import std.array : appender;

@safe:

private string yamlIndent(int level)
{
    string s;
    foreach (i; 0 .. level)
        s ~= "  ";
    return s;
}

/// Print a normalized view of the parsed compose file. This is intentionally
/// minimal (it is not a full YAML emitter) but useful for debugging what
/// `pod-compose` actually understood from the input.
class ConfigCommand : ICommand
{
    override void execute(Config config, PodmanCLI cli, string[] args)
    {
        auto parser = new ComposeParser(config.composeFile);
        auto cfg = parser.parse();

        if (cfg.version_.length > 0)
            writeln("version: \"", cfg.version_, "\"");
        if (!cfg.name.isNull)
            writeln("name: ", cfg.name.get);
        else
            writeln("name: ", config.projectName);

        if (cfg.services.length > 0)
        {
            writeln("services:");
            foreach (name, svc; cfg.services)
            {
                writeln(yamlIndent(1), name, ":");
                if (!svc.image.isNull)
                    writeln(yamlIndent(2), "image: ", svc.image.get);
                if (!svc.containerName.isNull)
                    writeln(yamlIndent(2), "container_name: ", svc.containerName.get);
                if (svc.command.length > 0)
                {
                    write(yamlIndent(2), "command: [");
                    foreach (i, c; svc.command)
                    {
                        if (i > 0)
                            write(", ");
                        write("\"", c, "\"");
                    }
                    writeln("]");
                }
                if (svc.entrypoint.length > 0)
                {
                    write(yamlIndent(2), "entrypoint: [");
                    foreach (i, c; svc.entrypoint)
                    {
                        if (i > 0)
                            write(", ");
                        write("\"", c, "\"");
                    }
                    writeln("]");
                }
                if (svc.ports.length > 0)
                {
                    writeln(yamlIndent(2), "ports:");
                    foreach (p; svc.ports)
                    {
                        string pub = p.published.isNull ? "" : p.published.get;
                        string tgt = p.target.isNull ? "" : p.target.get;
                        writeln(yamlIndent(3), "- \"", pub, ":", tgt, "\"");
                    }
                }
                if (svc.environment.length > 0 || svc.envFile.length > 0)
                {
                    writeln(yamlIndent(2), "environment:");
                    foreach (k, v; svc.environment)
                        writeln(yamlIndent(3), k, ": ", v);
                }
                if (svc.envFile.length > 0)
                {
                    writeln(yamlIndent(2), "env_file:");
                    foreach (f; svc.envFile)
                        writeln(yamlIndent(3), "- ", f);
                }
                if (svc.dependsOn.length > 0)
                {
                    writeln(yamlIndent(2), "depends_on:");
                    foreach (d, dep; svc.dependsOn)
                        writeln(yamlIndent(3), d, ": { condition: ", dep.condition, " }");
                }
            }
        }

        if (cfg.networks.length > 0)
        {
            writeln("networks:");
            foreach (k, n; cfg.networks)
            {
                writeln(yamlIndent(1), k, ":");
                if (!n.driver.isNull)
                    writeln(yamlIndent(2), "driver: ", n.driver.get);
                if (!n.external.isNull && n.external.get)
                    writeln(yamlIndent(2), "external: true");
            }
        }
        if (cfg.volumes.length > 0)
        {
            writeln("volumes:");
            foreach (k, v; cfg.volumes)
            {
                writeln(yamlIndent(1), k, ":");
                if (!v.external.isNull && v.external.get)
                    writeln(yamlIndent(2), "external: true");
            }
        }
    }
}
