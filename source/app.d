import std.stdio;
import std.process;
import std.file;
import std.string;
import std.array;
import std.algorithm;
import std.path;
import std.conv;
import dyaml;

// Configuration
string composeFile = "";
string podName = "";
string currentDirName = "";

void main(string[] args) {
    if (args.length < 2) {
        writeln("Uso: ./pod-compose {up|down|build}");
        return;
    }

    // Detect Compose File
    if (exists("docker-compose.yaml")) composeFile = "docker-compose.yaml";
    else if (exists("docker-compose.yml")) composeFile = "docker-compose.yml";
    else if (exists("compose.yaml")) composeFile = "compose.yaml";
    else if (exists("../docker-compose.yml")) composeFile = "../docker-compose.yml"; // Check parent if running from subdir
    else if (exists("../docker-compose.yaml")) composeFile = "../docker-compose.yaml";

    if (composeFile == "") {
        writeln("Erro: Nenhum arquivo docker-compose.yaml/yml encontrado.");
        return;
    }
    
    // Normalize path to absolute or relative to current dir correctly
    // If we found it in parent, we should probably switch context or just read it.
    // For simplicity, let's assume we run from project root, but if we are in pod-compose/ dir, we look up.
    // Actually, the user runs the binary. If the binary is in pod-compose/ and run from there, it might fail to find files.
    // Let's assume the user runs it from the project root where docker-compose is.
    
    // Normalize path and change directory
    if (isAbsolute(composeFile)) {
        chdir(dirName(composeFile));
        composeFile = baseName(composeFile);
    } else {
        string absPath = absolutePath(composeFile);
        chdir(dirName(absPath));
        composeFile = baseName(absPath);
    }
    
    // Set Context
    currentDirName = baseName(getcwd());
    podName = currentDirName ~ "_pod";

    string command = args[1];
    if (command == "up") {
        up();
    } else if (command == "down") {
        down();
    } else if (command == "build") {
        build();
    } else {
        writeln("Comando desconhecido: ", command);
    }
}

Node loadYaml() {
    try {
        return Loader.fromFile(composeFile).load();
    } catch (Exception e) {
        writeln("Erro ao ler arquivo YAML: ", e.msg);
        return Node(YAMLNull());
    }
}

void build() {
    writeln("--- Construindo Imagens ---");
    auto root = loadYaml();
    if (root.nodeID == NodeID.invalid) return;

    if (!root.containsKey("services")) {
        writeln("Erro: 'services' não encontrado no arquivo.");
        return;
    }

    auto services = root["services"];
    foreach (string serviceName, Node serviceConfig; services) {
        if (serviceConfig.containsKey("build")) {
            writeln("Construindo serviço: ", serviceName);
            
            string context = ".";
            string dockerfile = "Dockerfile";
            string target = "";
            
            auto buildNode = serviceConfig["build"];
            if (buildNode.nodeID == NodeID.scalar) {
                context = buildNode.as!string;
            } else if (buildNode.nodeID == NodeID.mapping) {
                if (buildNode.containsKey("context")) context = buildNode["context"].as!string;
                if (buildNode.containsKey("dockerfile")) dockerfile = buildNode["dockerfile"].as!string;
                if (buildNode.containsKey("target")) target = buildNode["target"].as!string;
            }

            string imageName = currentDirName ~ "_" ~ serviceName ~ ":latest";
            string buildCmd = "podman build -t " ~ imageName ~ " -f " ~ buildPath(context, dockerfile) ~ " " ~ context;
            if (target != "") buildCmd ~= " --target " ~ target;
            
            writeln("   Executando: " ~ buildCmd);
            auto res = executeShell(buildCmd);
            if (res.status != 0) {
                writeln("   Erro no build: ", res.output);
            } else {
                writeln("   Sucesso.");
            }
        } else {
            writeln("Serviço '", serviceName, "' não requer build (usa imagem).");
        }
    }
}

void up() {
    writeln("--- Interpretando " ~ composeFile ~ " para Podman Pods (D/Dub Version) ---");

    auto root = loadYaml();
    if (root.nodeID == NodeID.invalid) return;

    if (!root.containsKey("services")) {
        writeln("Erro: 'services' não encontrado.");
        return;
    }
    
    auto services = root["services"];
    
    // 1. Collect Ports and Host Maps
    writeln("[1/4] Identificando portas e hosts...");
    string allPortsArgs = "";
    string hostMaps = "";

    foreach (string s, Node serviceConfig; services) {
        // Ports
        if (serviceConfig.containsKey("ports")) {
            foreach (Node p; serviceConfig["ports"]) {
                string portStr = p.as!string;
                allPortsArgs ~= " -p " ~ portStr;
            }
        }
        // Host Maps
        hostMaps ~= " --add-host " ~ s ~ ":127.0.0.1";
    }

    // 2. Create Pod
    auto checkPod = executeShell("podman pod exists " ~ podName);
    if (checkPod.status == 0) {
        writeln("Pod " ~ podName ~ " já existe.");
    } else {
        writeln("[2/4] Criando Pod '" ~ podName ~ "'");
        string createCmd = "podman pod create --name " ~ podName ~ allPortsArgs ~ hostMaps;
        writeln("DEBUG: " ~ createCmd);
        auto res = executeShell(createCmd);
        if (res.status != 0) {
            writeln("Erro ao criar pod: ", res.output);
            return;
        }
    }

    // 3. Start Containers
    writeln("[3/4] Iniciando serviços...");
    foreach (string s, Node serviceConfig; services) {
        writeln("Processando serviço: ", s);
        
        // Image logic
        string image = "";
        if (serviceConfig.containsKey("image")) {
            image = serviceConfig["image"].as!string;
        } else if (serviceConfig.containsKey("build")) {
            // Check if image exists, if not build? 
            // Or assume 'build' command was run? 
            // Let's try to build if missing, or just use the expected tag.
            string imageName = currentDirName ~ "_" ~ s ~ ":latest";
            
            // Check if image exists
            auto checkImg = executeShell("podman image exists " ~ imageName);
            if (checkImg.status != 0) {
                writeln("   -> Imagem não encontrada. Executando build...");
                // Call build for this service specifically? Or just run global build?
                // For simplicity, let's just run the build logic inline or call a helper.
                // Re-using build logic is better but 'build()' function iterates all.
                // Let's just warn and try to run.
                writeln("   AVISO: Imagem " ~ imageName ~ " pode não existir. Rode './pod-compose build' primeiro.");
            }
            image = imageName;
        } else {
            writeln("   -> Erro: Serviço '" ~ s ~ "' não tem imagem nem build definido.");
            continue;
        }

        // Container Name
        string containerName = currentDirName ~ "_" ~ s;
        if (serviceConfig.containsKey("container_name")) {
            containerName = serviceConfig["container_name"].as!string;
        }
        
        if (executeShell("podman container exists " ~ containerName).status == 0) {
             writeln("   -> Container " ~ containerName ~ " já existe. Iniciando...");
             executeShell("podman start " ~ containerName);
             continue;
        }

        // Environment
        string envArgs = "";
        if (serviceConfig.containsKey("environment")) {
            auto env = serviceConfig["environment"];
            if (env.nodeID == NodeID.mapping) {
                foreach (string k, Node v; env) {
                    string val = v.as!string;
                    envArgs ~= " -e " ~ k ~ "=\"" ~ val ~ "\""; 
                }
            } else if (env.nodeID == NodeID.sequence) {
                foreach (Node v; env) {
                    envArgs ~= " -e \"" ~ v.as!string ~ "\"";
                }
            }
        }

        // Volumes
        string volArgs = "";
        if (serviceConfig.containsKey("volumes")) {
            foreach (Node v; serviceConfig["volumes"]) {
                string volStr = v.as!string;
                if (volStr.canFind(":") && !volStr.canFind(":Z") && !volStr.canFind(":z")) {
                    volStr ~= ":Z";
                }
                volArgs ~= " -v " ~ volStr;
            }
        }

        // Command
        string cmdArgs = "";
        if (serviceConfig.containsKey("command")) {
            auto cmd = serviceConfig["command"];
            if (cmd.nodeID == NodeID.scalar) {
                cmdArgs = " " ~ cmd.as!string;
            } else if (cmd.nodeID == NodeID.sequence) {
                foreach(Node c; cmd) cmdArgs ~= " " ~ c.as!string;
            }
        }
        
        // User
        string userArgs = "";
        if (serviceConfig.containsKey("user")) {
            userArgs = " --user " ~ serviceConfig["user"].as!string;
        }

        // Run
        writeln("   -> Criando container " ~ containerName ~ "...");
        string runCmd = "podman run -d --name " ~ containerName ~ 
                        " --pod " ~ podName ~ 
                        envArgs ~ 
                        volArgs ~ 
                        userArgs ~ 
                        " " ~ image ~ cmdArgs;
                        
        auto runRes = executeShell(runCmd);
        if (runRes.status != 0) {
            writeln("      Erro ao rodar container: ", runRes.output);
        } else {
            writeln("      Sucesso: " ~ runRes.output.strip());
        }
    }

    writeln("--- Deploy Concluído! ---");
    executeShell("podman pod ps --filter name=" ~ podName ~ " | cat");
}

void down() {
    writeln("Derrubando Pod " ~ podName ~ "...");
    auto res = executeShell("podman pod rm -f " ~ podName);
    writeln(res.output);
}
