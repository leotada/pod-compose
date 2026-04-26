module commands.registry;

import commands.base;
import commands.impl.up;
import commands.impl.down;
import commands.impl.build;
import commands.impl.ps;
import commands.impl.logs;
import commands.impl.stop;
import commands.impl.start;
import commands.impl.restart;
import commands.impl.pull;
import commands.impl.exec;
import commands.impl.version_;
import commands.impl.port;
import commands.impl.rm;
import commands.impl.pause;
import commands.impl.unpause;
import commands.impl.kill_;
import commands.impl.top;
import commands.impl.push;
import commands.impl.events;
import commands.impl.cp;
import commands.impl.images;
import commands.impl.config_;
import commands.impl.run;

@safe:

class CommandRegistry
{
    ICommand[string] commands;

    this()
    {
        commands["up"] = new UpCommand();
        commands["down"] = new DownCommand();
        commands["build"] = new BuildCommand();
        commands["ps"] = new PsCommand();
        commands["logs"] = new LogsCommand();
        commands["stop"] = new StopCommand();
        commands["start"] = new StartCommand();
        commands["restart"] = new RestartCommand();
        commands["pull"] = new PullCommand();
        commands["exec"] = new ExecCommand();
        commands["version"] = new VersionCommand();
        commands["port"] = new PortCommand();
        commands["rm"] = new RmCommand();
        commands["pause"] = new PauseCommand();
        commands["unpause"] = new UnpauseCommand();
        commands["kill"] = new KillCommand();
        commands["top"] = new TopCommand();
        commands["push"] = new PushCommand();
        commands["events"] = new EventsCommand();
        commands["cp"] = new CpCommand();
        commands["images"] = new ImagesCommand();
        commands["config"] = new ConfigCommand();
        commands["run"] = new RunCommand();
    }

    ICommand get(string name)
    {
        if (name in commands)
        {
            return commands[name];
        }
        return null;
    }
}
