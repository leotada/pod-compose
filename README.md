# pod-compose

A simple tool to run docker-compose files with Podman using pods.

## Description

`pod-compose` is a lightweight tool written in D that allows you to run `docker-compose.yml` files using Podman. It orchestrates containers within a Podman Pod, providing a seamless experience for managing multi-container applications.

## Features

- **Podman Pods**: Automatically creates a Podman Pod for your services, ensuring they share the same network namespace.
- **Docker Compose Support**: Parses standard `docker-compose.yml` files.
- **Build Support**: Can build images from `Dockerfile` as specified in the compose file.
- **Port Mapping**: Exposes ports defined in the compose file to the host.
- **Volume Mounting**: Mounts volumes with proper SELinux contexts (`:Z`).

## Usage

Compile the project using `dub` or run the binary directly.

```bash
./pod-compose [options] {command} [args...]
```

### Options

- `-f, --file FILE`: Specify an alternate compose file (default: docker-compose.yml).

### Commands

- `up`: Creates the pod (if not exists) and starts all services defined in `docker-compose.yml`.
- `down`: Stops and removes the pod and all associated containers.
- `build`: Builds the container images for services that define a `build` context.
- `ps`: Lists containers in the pod.
- `logs`: View output from containers. Use `-f` to follow.
- `stop`: Stop the pod (and all services).
- `start`: Start the pod (and all services).
- `restart`: Restart the pod.
- `pull`: Pull images for services.
- `exec`: Execute a command in a running container.
- `version`: Show version information.

## Requirements

- **Podman**: Must be installed and available in your PATH.
- **D Compiler (DMD/LDC)**: Required if you want to build the tool from source.
- **Dub**: D package manager.

## Building from Source

```bash
dub build
```

### Release Build

To build an optimized release binary:

```bash
dub build --build=release
```

This will generate the `pod-compose` executable.

## Documentation

For more detailed usage instructions, see [HOW_TO_USE.md](docs/HOW_TO_USE.md).
