module core.config;

import std.file;
import std.path;
import std.process;
import std.stdio;
import std.string;

@safe:

struct Config {
    string composeFile;
    string projectDir;
    string projectName;
    string podName;

    static Config load(string[] args, string explicitFile = "") {
        string composeFile;
        
        if (explicitFile != "") {
            if (!exists(explicitFile)) {
                throw new Exception("Specified compose file not found: " ~ explicitFile);
            }
            composeFile = explicitFile;
        } else {
            composeFile = detectComposeFile();
            if (composeFile == "") {
                throw new Exception("No docker-compose.yaml/yml file found.");
            }
        }

        string absPath = absolutePath(composeFile);
        string projectDir = dirName(absPath);
        string projectName = baseName(projectDir);
        string podName = projectName ~ "_pod";

        // Change directory to project root to ensure relative paths in compose work
        try {
            chdir(projectDir);
        } catch (Exception e) {
            // Log warning but continue if possible, though usually fatal for relative paths
        }

        return Config(baseName(absPath), projectDir, projectName, podName);
    }

    private static string detectComposeFile() {
        if (exists("docker-compose.yaml")) return "docker-compose.yaml";
        if (exists("docker-compose.yml")) return "docker-compose.yml";
        if (exists("compose.yaml")) return "compose.yaml";
        if (exists("compose.yml")) return "compose.yml";
        
        // Check parent directory
        if (exists("../docker-compose.yml")) return "../docker-compose.yml";
        if (exists("../docker-compose.yaml")) return "../docker-compose.yaml";

        return "";
    }
}
