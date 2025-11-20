module commands.impl.port;

import commands.base;
import core.config;
import podman.cli;
import std.stdio;

@safe:

class PortCommand : ICommand
{
    override void execute(Config config, PodmanCLI cli, string[] args)
    {
        if (args.length < 1)
        {
            writeln("Usage: pod-compose port SERVICE [PRIVATE_PORT]");
            return;
        }

        // In pod-compose, we map services to a single pod.
        // The ports are exposed on the pod's infra container.
        // So we actually want to query the pod's infra container.
        // args[0] is the service name, but for now, since all services share the pod network (usually),
        // checking the pod's infra container is the way to go for "public" ports.
        // However, docker-compose port SERVICE PORT checks the mapping for a specific container.
        // If we are using a pod, the ports are on the infra container.

        // Let's check if the pod exists
        if (!cli.podExists(config.podName))
        {
            writeln("Pod " ~ config.podName ~ " does not exist.");
            return;
        }

        string infraId = cli.getInfraContainerId(config.podName);
        if (infraId == "")
        {
            writeln("Could not find infra container for pod " ~ config.podName);
            return;
        }

        string privatePort = "";
        if (args.length > 1)
        {
            privatePort = args[1];
        }

        cli.port(infraId, privatePort);
    }
}
