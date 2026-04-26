# pod-compose

A simple tool to run docker-compose files with Podman using pods.

## Description

`pod-compose` is a lightweight tool written in D that allows you to run `compose.yml` files using Podman. It orchestrates containers within a Podman Pod, providing a seamless experience for managing multi-container applications.

## Features

- **Podman Pods**: Automatically creates a Podman Pod for your services, ensuring they share the same network namespace.
- **Docker Compose Support**: Parses standard `compose.yml` files.
- **Build Support**: Can build images from `Dockerfile` as specified in the compose file.
- **Port Mapping**: Exposes ports defined in the compose file to the host.
- **Volume Mounting**: Mounts volumes with proper SELinux contexts (`:Z`).

## Usage

Compile the project using `dub` or run the binary directly.

```bash
./pod-compose [options] {command} [args...]
```

### Options

- `-f, --file FILE`: Specify an alternate compose file (default: docker-compose.yml and compose.yml).

### Commands

- `up`: Creates the pod (if not exists) and starts all services defined in `compose.yml`. Auto-builds images for services that declare `build:` and have no local image.
- `down`: Stops and removes the pod and all associated containers.
- `build`: Builds the container images for services that define a `build` context.
- `ps`: Lists containers in the pod.
- `logs`: View output from containers. Use `-f` to follow.
- `stop` / `start` / `restart`: Lifecycle for the pod (and all services).
- `pause` / `unpause`: Pause/resume all containers in the pod.
- `kill`: Send a signal to containers (`-s/--signal`, default `SIGKILL`).
- `rm`: Remove stopped service containers (`-f/--force`).
- `pull` / `push`: Pull/push images for services.
- `port`: Inspect public port mappings for a service.
- `exec`: Execute a command in a running service container.
- `run`: Run a one-off command for a service in a temporary container.
- `top`: Show running processes inside services.
- `cp`: Copy files between host and a service container.
- `images`: List images used by services.
- `events`: Stream pod/container events.
- `config`: Render the effective compose configuration.
- `version`: Show version information.

## Limitations

`pod-compose` deploys every service of a project into a **single Podman pod**.
This has a few consequences worth understanding:

- All containers share the pod's network namespace, so they reach each other
  on `127.0.0.1` (not via service-name DNS like Docker Compose).
- Networks declared in the compose file are unioned and attached to the pod
  via `podman pod create --network`. **Per-service network isolation is not
  supported.**
- `network_mode` on a service is ignored (a warning is printed); the pod's
  network applies to all containers.
- `deploy.replicas > 1` is not honored — the pod model runs a single instance
  per service. A warning is printed.
- `configs` and `secrets` referencing files are mounted as read-only bind
  mounts; they are not converted to `podman secret` objects.

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
