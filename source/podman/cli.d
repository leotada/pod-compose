module podman.cli;

import std.process;
import std.stdio;
import std.string;
import std.array;
import std.algorithm;
import std.conv;
import std.json;

@safe:

interface IExecutor
{
    int execute(string cmd);
    int executeStream(string cmd);
}

class ShellExecutor : IExecutor
{
    override int execute(string cmd)
    {
        writeln("DEBUG: Executing: ", cmd);
        auto res = executeShell(cmd);
        if (res.status != 0)
        {
            writeln("Error executing command: ", cmd);
            writeln(res.output);
        }
        else
        {
            if (res.output.strip.length > 0)
                writeln(res.output.strip);
        }
        return res.status;
    }

    override int executeStream(string cmd)
    {
        writeln("DEBUG: Executing (stream): ", cmd);
        auto pid = spawnShell(cmd);
        return wait(pid);
    }
}

class PodmanCLI
{
    IExecutor executor;

    this(IExecutor executor = null)
    {
        if (executor is null)
        {
            this.executor = new ShellExecutor();
        }
        else
        {
            this.executor = executor;
        }
    }

    int execute(string cmd)
    {
        return executor.execute(cmd);
    }

    int executeStream(string cmd)
    {
        return executor.executeStream(cmd);
    }

    bool podExists(string podName)
    {
        // For boolean checks, we might need to capture output or status.
        // executeShell returns Tuple!(int, "status", string, "output")
        // Our IExecutor returns int status.
        // We need to change IExecutor or handle it differently.
        // For simplicity, let's assume execute returns status.
        // But we lose output for parsing.
        // Let's stick to status for now.
        // Actually, pod exists returns 0 if exists, 1 if not.
        return execute("podman pod exists " ~ podName) == 0;
    }

    bool containerExists(string containerName)
    {
        return execute("podman container exists " ~ containerName) == 0;
    }

    bool imageExists(string imageName)
    {
        return execute("podman image exists " ~ imageName) == 0;
    }

    int createPod(string podName, string[] ports, string[] hostMaps, string[] networks = [
        ])
    {
        string args = "";
        foreach (p; ports)
            args ~= " -p " ~ p;
        foreach (h; hostMaps)
            args ~= " --add-host " ~ h;
        foreach (n; networks)
            args ~= " --network " ~ n;

        return execute("podman pod create --name " ~ podName ~ args);
    }

    int removePod(string podName)
    {
        return execute("podman pod rm -f " ~ podName);
    }

    int stopPod(string podName)
    {
        return execute("podman pod stop " ~ podName);
    }

    int startPod(string podName)
    {
        return execute("podman pod start " ~ podName);
    }

    int restartPod(string podName)
    {
        return execute("podman pod restart " ~ podName);
    }

    bool secretExists(string name)
    {
        return execute("podman secret exists " ~ name) == 0;
    }

    int createSecret(string name, string file)
    {
        return execute("podman secret create " ~ name ~ " " ~ file);
    }

    bool volumeExists(string name)
    {
        return execute("podman volume exists " ~ name) == 0;
    }

    int createVolume(string name, string driver = "", string[string] labels = null)
    {
        string cmd = "podman volume create " ~ name;
        if (driver != "")
            cmd ~= " --driver " ~ driver;
        foreach (k, v; labels)
            cmd ~= " --label " ~ k ~ "=" ~ v;
        return execute(cmd);
    }

    bool networkExists(string name)
    {
        return execute("podman network exists " ~ name) == 0;
    }

    int createNetwork(string name, string driver = "", string[string] labels = null)
    {
        string cmd = "podman network create " ~ name;
        if (driver != "")
            cmd ~= " --driver " ~ driver;
        foreach (k, v; labels)
            cmd ~= " --label " ~ k ~ "=" ~ v;
        return execute(cmd);
    }

    struct BuildOptions
    {
        string context;
        string dockerfile;
        string tag;
        string target;
        string network;
        string shmSize;
        string[] cacheFrom;
        string[string] args;
        string[string] labels;
    }

    int build(BuildOptions opts)
    {
        string cmd = "podman build -t " ~ opts.tag ~ " -f " ~ opts.dockerfile ~ " " ~ opts.context;
        if (opts.target != "")
            cmd ~= " --target " ~ opts.target;
        if (opts.network != "")
            cmd ~= " --network " ~ opts.network;
        if (opts.shmSize != "")
            cmd ~= " --shm-size " ~ opts.shmSize;
        foreach (c; opts.cacheFrom)
            cmd ~= " --cache-from " ~ c;
        foreach (k, v; opts.args)
            cmd ~= " --build-arg " ~ k ~ "=" ~ v;
        foreach (k, v; opts.labels)
            cmd ~= " --label " ~ k ~ "=" ~ v;

        return executeStream(cmd);
    }

    struct ContainerRunOptions
    {
        string podName;
        string name;
        string image;
        string[] envs;
        string[] volumes;
        string user;
        string[] command;
        string workdir;
        string entrypoint;
        string restartPolicy;
        string stopSignal;
        int stopTimeout;
        string hostname;
        string domainname;
        string[] labels;

        // Resources
        float cpus;
        string memory;
        string memoryReservation;

        // Healthcheck
        string healthCmd;
        string healthInterval;
        string healthTimeout;
        string healthStartPeriod;
        int healthRetries;
        bool noHealthcheck;

        // Security
        bool privileged;
        bool readOnly;
        string[] capAdd;
        string[] capDrop;
        string[] securityOpt;

        // Networking
        string[] dns;
        string[] dnsSearch;
        string[] extraHosts;

        // Secrets
        string[] secrets;
    }

    int runContainer(ContainerRunOptions opts)
    {
        string args = " --pod " ~ opts.podName ~ " --name " ~ opts.name ~ " -d";

        foreach (e; opts.envs)
            args ~= " -e \"" ~ e ~ "\"";
        foreach (v; opts.volumes)
            args ~= " -v " ~ v;
        if (opts.user != "")
            args ~= " --user " ~ opts.user;
        if (opts.workdir != "")
            args ~= " --workdir " ~ opts.workdir;
        if (opts.entrypoint != "")
            args ~= " --entrypoint \"" ~ opts.entrypoint ~ "\"";
        if (opts.restartPolicy != "")
            args ~= " --restart " ~ opts.restartPolicy;
        if (opts.stopSignal != "")
            args ~= " --stop-signal " ~ opts.stopSignal;
        if (opts.stopTimeout > 0)
            args ~= " --stop-timeout " ~ opts.stopTimeout.to!string;
        if (opts.hostname != "")
            args ~= " --hostname " ~ opts.hostname;
        if (opts.domainname != "")
            args ~= " --domainname " ~ opts.domainname;
        foreach (l; opts.labels)
            args ~= " --label " ~ l;

        // Resources
        if (opts.cpus > 0)
            args ~= " --cpus " ~ opts.cpus.to!string;
        if (opts.memory != "")
            args ~= " --memory " ~ opts.memory;
        if (opts.memoryReservation != "")
            args ~= " --memory-reservation " ~ opts.memoryReservation;

        // Healthcheck
        if (opts.noHealthcheck)
        {
            args ~= " --no-healthcheck";
        }
        else
        {
            if (opts.healthCmd != "")
                args ~= " --health-cmd \"" ~ opts.healthCmd ~ "\"";
            if (opts.healthInterval != "")
                args ~= " --health-interval " ~ opts.healthInterval;
            if (opts.healthTimeout != "")
                args ~= " --health-timeout " ~ opts.healthTimeout;
            if (opts.healthStartPeriod != "")
                args ~= " --health-start-period " ~ opts.healthStartPeriod;
            if (opts.healthRetries > 0)
                args ~= " --health-retries " ~ opts.healthRetries.to!string;
        }

        // Security
        if (opts.privileged)
            args ~= " --privileged";
        if (opts.readOnly)
            args ~= " --read-only";
        foreach (c; opts.capAdd)
            args ~= " --cap-add " ~ c;
        foreach (c; opts.capDrop)
            args ~= " --cap-drop " ~ c;
        foreach (s; opts.securityOpt)
            args ~= " --security-opt " ~ s;

        // Networking
        foreach (d; opts.dns)
            args ~= " --dns " ~ d;
        foreach (d; opts.dnsSearch)
            args ~= " --dns-search " ~ d;
        foreach (h; opts.extraHosts)
            args ~= " --add-host " ~ h;

        // Secrets
        foreach (s; opts.secrets)
            args ~= " --secret " ~ s;

        string commandStr = "";
        foreach (c; opts.command)
            commandStr ~= " " ~ c;

        return execute("podman run " ~ args ~ " " ~ opts.image ~ commandStr);
    }

    int startContainer(string containerName)
    {
        return execute("podman start " ~ containerName);
    }

    int pull(string image)
    {
        return executeStream("podman pull " ~ image);
    }

    int logs(string containerName, bool follow)
    {
        string cmd = "podman logs ";
        if (follow)
            cmd ~= "-f ";
        cmd ~= containerName;
        return executeStream(cmd);
    }

    int exec(string containerName, string[] command)
    {
        string cmdStr = command.join(" ");
        return executeStream("podman exec -it " ~ containerName ~ " " ~ cmdStr);
    }

    int ps(string podName = "", string[] args = [])
    {
        string cmd = "podman ps";
        if (podName != "")
        {
            cmd ~= " --filter pod=" ~ podName;
        }
        foreach (arg; args)
        {
            cmd ~= " " ~ arg;
        }
        return executeStream(cmd);
    }

    int podPs(string podName)
    {
        return executeStream("podman pod ps --filter name=" ~ podName);
    }

    string getInfraContainerId(string podName)
    {
        auto res = executeShell("podman pod inspect " ~ podName);
        if (res.status != 0)
        {
            return "";
        }
        try
        {
            auto json = parseJSON(res.output);
            if (json.type == JSONType.array)
            {
                auto arr = () @trusted { return json.array; }();
                if (arr.length > 0)
                {
                    return arr[0]["InfraContainerID"].str;
                }
            }
            // Fallback if it's not an array (unexpected but safe)
            if (json.type == JSONType.object)
            {
                return json["InfraContainerID"].str;
            }
            return "";
        }
        catch (Exception e)
        {
            writeln("Error parsing pod inspect output: ", e.msg);
            return "";
        }
    }

    int port(string containerId, string privatePort = "")
    {
        string cmd = "podman port " ~ containerId;
        if (privatePort != "")
        {
            cmd ~= " " ~ privatePort;
        }
        return executeStream(cmd);
    }
}
