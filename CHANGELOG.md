# Changelog

All notable changes to this project will be documented in this file.

## [0.4.0]

### Added
- **New Commands** (11): `rm`, `pause`, `unpause`, `kill` (with `-s/--signal`),
  `top`, `push`, `events`, `cp`, `images`, `config`, `run`.
- **Service Attributes**:
    - `env_file`: load env vars from files (existing `environment:` keys win).
    - `init`: run an init process inside the container.
    - `pid` and `ipc`: namespace sharing.
    - `devices`: short and long form (`source:target:permissions`).
    - `sysctls`: kernel parameters.
    - `ulimits`: scalar and `{soft,hard}` form.
    - `logging`: driver and options (`--log-driver`, `--log-opt`).
    - `tmpfs`, `group_add`, `expose`.
- **Helpers**:
    - `core.duration` parses Compose duration strings (`1m30s`, `500ms`, `2h`).
    - `core.util.shellQuoteIfNeeded` / `jsonStringArray` for safe shell escaping.
- **Tests**: end-to-end integration script `tests/integration.sh` exercising
  the compiled binary against a real Podman installation.

### Fixed
- `up` with a `build:` block (and no local image) no longer attempts to pull;
  the image is built automatically before starting the container.
- `entrypoint` accepts a list and is forwarded as JSON when it has multiple
  elements (e.g. `--entrypoint '["/bin/sh","-c","..."]'`).
- Command arguments containing spaces or shell metacharacters are now
  properly quoted.
- `depends_on` with `condition: service_healthy` /
  `service_completed_successfully` actually waits for the dependency to reach
  the requested state before starting the next service.
- `stop_grace_period` parses Compose duration strings instead of using a
  hard-coded value.
- Removed unconditional `DEBUG: Executing: ...` output (now gated by
  `POD_COMPOSE_DEBUG=1`).
- `podman {pod,container,image,secret,volume,network} exists` probes no longer
  print spurious error lines on the expected non-zero exit.

### Notes / Limitations
- `pod-compose` runs all services of a project in a single Podman pod, so all
  containers share the pod's infra network namespace. Networks declared in
  the compose file are unioned and attached to the pod via
  `podman pod create --network`; per-service network isolation is not
  supported.
- `configs` and `secrets` for files are mounted as bind mounts (read-only),
  not via `podman secret`.

## [0.3.0] - 2025-11-20

### Added
- **New Commands**:
    - `port`: Inspect public port mappings for services.
    - `stop`: Stop services/pod without removing them.
    - `start`: Start stopped services/pod.
    - `restart`: Restart services/pod.
    - `exec`: Execute commands inside running containers.
    - `pull`: Pull images for services defined in the compose file.
    - `logs`: View container logs (supports `-f` for follow).
    - `version`: Display version information.
- **CLI Enhancements**:
    - `ps`: Improved process listing.

## [0.2.0] - 2025-11-20

### Added
- **Comprehensive Compose Specification Support**:
    - Full parsing of `docker-compose.yml` including all major sections.
    - **Networks**: Support for creating and using top-level networks.
    - **Volumes**: Support for creating and using top-level named volumes.
    - **Secrets**: Support for creating secrets and mounting them into containers.
    - **Configs**: Support for mounting configs as read-only files.
- **Enhanced Build Command**:
    - Support for `build` arguments (`args`), `target`, `network`, `cache_from`, and `labels`.
- **Advanced Service Configuration**:
    - **Healthchecks**: Full support for `healthcheck` (test, interval, timeout, retries, start_period).
    - **Resources**: Support for CPU (`cpus`) and Memory (`mem_limit`, `mem_reservation`) limits.
    - **Security**: Support for `privileged`, `read_only`, `cap_add`, `cap_drop`, `security_opt`.
    - **Stop Options**: Support for `stop_signal` and `stop_grace_period`.
- **Dependency Management**:
    - Implemented topological sorting for `depends_on` to start services in the correct order.
- **CLI Improvements**:
    - Refactored `PodmanCLI` to use structured option objects (`ContainerRunOptions`, `BuildOptions`).
    - Added `secretExists`, `createSecret`, `volumeExists`, `createVolume`, `networkExists`, `createNetwork` methods.

### Changed
- **Refactoring**:
    - Major refactor of the parser into `ComposeParser` (top-level) and `ServiceParser` (service-specific) following SOLID principles.
    - Updated `UpCommand` to handle the new comprehensive data models.
    - Updated `BuildCommand` to use the new `BuildOptions` struct.

### Fixed
- Fixed compilation errors related to `Nullable` types and type conversions.
- Fixed issue where `depends_on` was ignored.

## [0.1.0] - 2025-11-18

### Added
- Initial release.
- Basic `up`, `down`, `ps`, `build` commands.
- Simple YAML parsing.
