module podman.cli;

import std.process;
import std.stdio;
import std.string;
import std.array;
import std.algorithm;

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

    int createPod(string podName, string[] ports, string[] hostMaps)
    {
        string args = "";
        foreach (p; ports)
            args ~= " -p " ~ p;
        foreach (h; hostMaps)
            args ~= " --add-host " ~ h;

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

    int build(string context, string dockerfile, string tag, string target = "")
    {
        string cmd = "podman build -t " ~ tag ~ " -f " ~ dockerfile ~ " " ~ context;
        if (target != "")
            cmd ~= " --target " ~ target;
        return executeStream(cmd);
    }

    int runContainer(
        string podName,
        string containerName,
        string image,
        string[] envs,
        string[] volumes,
        string user,
        string[] cmdArgs
    )
    {
        string args = " --pod " ~ podName ~ " --name " ~ containerName ~ " -d";
        foreach (e; envs)
            args ~= " -e \"" ~ e ~ "\"";
        foreach (v; volumes)
            args ~= " -v " ~ v;
        if (user != "")
            args ~= " --user " ~ user;

        string command = "";
        foreach (c; cmdArgs)
            command ~= " " ~ c;

        return execute("podman run " ~ args ~ " " ~ image ~ command);
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
}
