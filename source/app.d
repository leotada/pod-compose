import std.stdio;
import core.config;
import podman.cli;
import commands.registry;
import std.algorithm;
import std.string;

void main(string[] args) {
    if (args.length < 2) {
        writeln("Usage: ./pod-compose {up|down|build|ps|logs|stop|start|restart|pull|exec} [args...]");
        return;
    }

    string commandName = "";
    string[] commandArgs;
    string explicitFile = "";

    // Manual argument parsing
    for (size_t i = 1; i < args.length; i++) {
        string arg = args[i];
        if (arg == "-f" || arg == "--file") {
            if (i + 1 < args.length) {
                explicitFile = args[++i];
            } else {
                writeln("Error: -f/--file requires an argument.");
                return;
            }
        } else if (arg.startsWith("-")) {
             // Other flags? For now assume flags belong to the command if command is set, 
             // or global flags if not. 
             // But wait, if commandName is empty, this is a global flag.
             // If we don't recognize it, maybe it's for the command?
             // Standard docker-compose puts options before command.
             // pod-compose -f file up
             if (commandName == "") {
                 writeln("Unknown global option: ", arg);
                 return;
             } else {
                 commandArgs ~= arg;
             }
        } else {
            if (commandName == "") {
                commandName = arg;
            } else {
                commandArgs ~= arg;
            }
        }
    }

    if (commandName == "") {
        writeln("Usage: ./pod-compose [options] {command} [args...]");
        return;
    }

    try {
        auto config = Config.load(args, explicitFile);
        auto cli = new PodmanCLI();
        auto registry = new CommandRegistry();
        
        auto cmd = registry.get(commandName);
        if (cmd !is null) {
            cmd.execute(config, cli, commandArgs);
        } else {
            writeln("Unknown command: ", commandName);
        }
    } catch (Exception e) {
        writeln("Error: ", e.msg);
    }
}
