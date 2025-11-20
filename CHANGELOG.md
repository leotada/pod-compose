# Changelog

All notable changes to this project will be documented in this file.

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
