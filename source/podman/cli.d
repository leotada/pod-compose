module podman.cli;

import std.process;
import std.stdio;
import std.string;
import std.array;
import std.algorithm;
import std.conv;
import std.json;
import core.util;

@safe:

private bool debugEnabled() @trusted
{
    auto v = environment.get("POD_COMPOSE_DEBUG", "");
    return v.length > 0 && v != "0" && v != "false";
}

interface IExecutor
{
    int execute(string cmd);
    int executeStream(string cmd);
}

private void debugLog(string cmd) @trusted
{
    if (debugEnabled())
        stderr.writeln("[pod-compose] $ ", cmd);
}

private void errorLog(string cmd, string output) @trusted
{
    stderr.writeln("Error executing command: ", cmd);
    stderr.writeln(output);
}

class ShellExecutor : IExecutor
{
    override int execute(string cmd)
    {
        debugLog(cmd);
        auto res = executeShell(cmd);
        if (res.status != 0)
        {
            errorLog(cmd, res.output);
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
        debugLog(cmd);
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

    /// Like execute() but does not let the executor print error output for
    /// expected non-zero exits (e.g. `podman X exists` probes).
    int executeQuiet(string cmd) @trusted
    {
        // Bypass the executor's error printing entirely. Tests using a
        // MockExecutor will still see the command via the executor when we
        // are not the default ShellExecutor.
        if (auto _ = cast(ShellExecutor) executor)
        {
            auto res = executeShell(cmd ~ " >/dev/null 2>&1");
            return res.status;
        }
        return executor.execute(cmd);
    }

    bool podExists(string podName)
    {
        return executeQuiet("podman pod exists " ~ podName) == 0;
    }

    bool containerExists(string containerName)
    {
        return executeQuiet("podman container exists " ~ containerName) == 0;
    }

    bool imageExists(string imageName)
    {
        return executeQuiet("podman image exists " ~ imageName) == 0;
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

    int pausePod(string podName)
    {
        return execute("podman pod pause " ~ podName);
    }

    int unpausePod(string podName)
    {
        return execute("podman pod unpause " ~ podName);
    }

    int killPod(string podName, string signal = "")
    {
        string cmd = "podman pod kill";
        if (signal != "")
            cmd ~= " --signal " ~ signal;
        cmd ~= " " ~ podName;
        return execute(cmd);
    }

    int podTop(string podName, string[] args = [])
    {
        string cmd = "podman pod top " ~ podName;
        foreach (a; args)
            cmd ~= " " ~ a;
        return executeStream(cmd);
    }

    int killContainer(string containerName, string signal = "")
    {
        string cmd = "podman kill";
        if (signal != "")
            cmd ~= " --signal " ~ signal;
        cmd ~= " " ~ containerName;
        return execute(cmd);
    }

    int pauseContainer(string containerName)
    {
        return execute("podman pause " ~ containerName);
    }

    int unpauseContainer(string containerName)
    {
        return execute("podman unpause " ~ containerName);
    }

    int removeContainer(string containerName, bool force = false)
    {
        string cmd = "podman rm";
        if (force)
            cmd ~= " -f";
        cmd ~= " " ~ containerName;
        return execute(cmd);
    }

    int push(string image)
    {
        return executeStream("podman push " ~ image);
    }

    int cp(string source, string dest)
    {
        return execute("podman cp " ~ shellQuoteIfNeeded(source) ~ " " ~ shellQuoteIfNeeded(dest));
    }

    int events(string[] filters = [])
    {
        string cmd = "podman events";
        foreach (f; filters)
            cmd ~= " --filter " ~ shellQuoteIfNeeded(f);
        return executeStream(cmd);
    }

    int images(string[] filters = [])
    {
        string cmd = "podman images";
        foreach (f; filters)
            cmd ~= " --filter " ~ shellQuoteIfNeeded(f);
        return executeStream(cmd);
    }

    /// Inspect health status of a container. Returns one of
    /// "healthy", "unhealthy", "starting", "none", or "" on error.
    string getContainerHealth(string containerName) @trusted
    {
        auto res = executeShell(
            "podman inspect --format '{{.State.Health.Status}}' " ~ containerName);
        if (res.status != 0)
            return "";
        return res.output.strip;
    }

    /// Inspect exit code of a stopped container, or -1 on error.
    int getContainerExitCode(string containerName) @trusted
    {
        auto res = executeShell(
            "podman inspect --format '{{.State.ExitCode}}' " ~ containerName);
        if (res.status != 0)
            return -1;
        try
            return res.output.strip.to!int;
        catch (Exception)
            return -1;
    }

    /// Returns true when the container's State.Status is "running".
    bool isContainerRunning(string containerName) @trusted
    {
        auto res = executeShell(
            "podman inspect --format '{{.State.Status}}' " ~ containerName);
        if (res.status != 0)
            return false;
        return res.output.strip == "running";
    }

    bool secretExists(string name)
    {
        return executeQuiet("podman secret exists " ~ name) == 0;
    }

    int createSecret(string name, string file)
    {
        return execute("podman secret create " ~ name ~ " " ~ file);
    }

    bool volumeExists(string name)
    {
        return executeQuiet("podman volume exists " ~ name) == 0;
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
        return executeQuiet("podman network exists " ~ name) == 0;
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
        string[] envFiles;
        string[] volumes;
        string user;
        string[] command;
        string workdir;
        string[] entrypoint;
        string restartPolicy;
        string stopSignal;
        int stopTimeout;
        string hostname;
        string domainname;
        string[] labels;
        bool detach = true;
        bool removeOnExit;
        bool interactive;
        bool tty;

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
        string[] devices;
        string[] ulimits;
        string[] groupAdd;
        bool init;
        string pid;
        string ipc;
        string[] sysctls;

        // Networking
        string[] dns;
        string[] dnsSearch;
        string[] extraHosts;
        string[] expose;

        // Logging
        string logDriver;
        string[] logOpts;

        // Secrets
        string[] secrets;
    }

    int runContainer(ContainerRunOptions opts)
    {
        string args = " --pod " ~ opts.podName ~ " --name " ~ opts.name;
        if (opts.detach)
            args ~= " -d";
        if (opts.removeOnExit)
            args ~= " --rm";
        if (opts.interactive)
            args ~= " -i";
        if (opts.tty)
            args ~= " -t";

        foreach (e; opts.envs)
            args ~= " -e \"" ~ e ~ "\"";
        foreach (f; opts.envFiles)
            args ~= " --env-file " ~ shellQuoteIfNeeded(f);
        foreach (v; opts.volumes)
            args ~= " -v " ~ v;
        if (opts.user != "")
            args ~= " --user " ~ opts.user;
        if (opts.workdir != "")
            args ~= " --workdir " ~ shellQuoteIfNeeded(opts.workdir);
        if (opts.entrypoint.length == 1)
            args ~= " --entrypoint \"" ~ opts.entrypoint[0] ~ "\"";
        else if (opts.entrypoint.length > 1)
            args ~= " --entrypoint " ~ shellQuote(jsonStringArray(opts.entrypoint));
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
            args ~= " --label " ~ shellQuoteIfNeeded(l);

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
        if (opts.init)
            args ~= " --init";
        if (opts.pid != "")
            args ~= " --pid " ~ shellQuoteIfNeeded(opts.pid);
        if (opts.ipc != "")
            args ~= " --ipc " ~ shellQuoteIfNeeded(opts.ipc);
        foreach (c; opts.capAdd)
            args ~= " --cap-add " ~ c;
        foreach (c; opts.capDrop)
            args ~= " --cap-drop " ~ c;
        foreach (s; opts.securityOpt)
            args ~= " --security-opt " ~ shellQuoteIfNeeded(s);
        foreach (d; opts.devices)
            args ~= " --device " ~ shellQuoteIfNeeded(d);
        foreach (u; opts.ulimits)
            args ~= " --ulimit " ~ shellQuoteIfNeeded(u);
        foreach (g; opts.groupAdd)
            args ~= " --group-add " ~ g;
        foreach (s; opts.sysctls)
            args ~= " --sysctl " ~ shellQuoteIfNeeded(s);

        // Networking
        foreach (d; opts.dns)
            args ~= " --dns " ~ d;
        foreach (d; opts.dnsSearch)
            args ~= " --dns-search " ~ d;
        foreach (h; opts.extraHosts)
            args ~= " --add-host " ~ h;
        foreach (e; opts.expose)
            args ~= " --expose " ~ e;

        // Logging
        if (opts.logDriver != "")
            args ~= " --log-driver " ~ opts.logDriver;
        foreach (o; opts.logOpts)
            args ~= " --log-opt " ~ shellQuoteIfNeeded(o);

        // Secrets
        foreach (s; opts.secrets)
            args ~= " --secret " ~ s;

        string commandStr = "";
        foreach (c; opts.command)
            commandStr ~= " " ~ shellQuoteIfNeeded(c);

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
