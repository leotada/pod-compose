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

@safe:

class CommandRegistry {
    ICommand[string] commands;

    this() {
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
    }

    ICommand get(string name) {
        if (name in commands) {
            return commands[name];
        }
        return null;
    }
}
