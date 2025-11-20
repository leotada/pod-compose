# Pod-Compose Missing Features TODO

This file tracks the implementation status of features defined in the [Compose Specification](docs/spec.md) but currently missing or incomplete in `pod-compose`.

## Top-Level Elements
- [x] **`networks`**: Parse and support custom network definitions.
- [x] **`volumes`**: Parse and support named volume definitions.
- [x] **`configs`**: Support for config objects.
- [x] **`secrets`**: Support for secret objects.
- [x] **`name`**: Respect the top-level `name` property for project naming.

## Service Attributes

### Lifecycle & Orchestration
- [x] **`depends_on`**: Implement dependency resolution and startup order.
    - [x] Short syntax (list of names).
    - [x] Long syntax (condition: `service_started`, `service_healthy`, `service_completed_successfully`).
- [x] **`restart`**: Pass restart policies (`no`, `always`, `on-failure`, `unless-stopped`) to Podman.
- [x] **`healthcheck`**: Support healthcheck configuration.
- [x] **`deploy`**: Support deployment constraints (resources, replicas, etc.).
    - [x] Resources (cpus, memory)
    - [ ] Replicas
- [x] **`stop_signal`**: Support custom stop signals.
- [x] **`stop_grace_period`**: Support custom grace periods.

### Networking
- [x] **`networks`**: Allow services to attach to specific networks (aliases, ipv4_address, etc.).
- [x] **`dns`**: Support custom DNS servers.
- [x] **`dns_search`**: Support custom DNS search domains.
- [x] **`extra_hosts`**: Support adding host mappings (`--add-host`).

### Execution Environment
- [x] **`entrypoint`**: Override image entrypoint.
- [x] **`env_file`**: Load environment variables from files.
- [x] **`working_dir`**: Set working directory.
- [x] **`user`**: Ensure user mapping is correctly handled (already partially supported).
- [ ] **`init`**: Run an init inside the container.
- [ ] **`pid`**: PID namespace sharing.

### Security & Privileges
- [x] **`cap_add`**: Add capabilities.
- [x] **`cap_drop`**: Drop capabilities.
- [x] **`security_opt`**: Security options (SELinux, AppArmor, etc.).
- [x] **`privileged`**: Run container in privileged mode.
- [ ] **`devices`**: Device mappings.
- [ ] **`sysctls`**: Kernel parameters.
- [ ] **`ulimits`**: Resource limits.

### Logging
- [ ] **`logging`**: Configure logging driver and options.

## Build Configuration
- [x] **`args`**: Support build arguments.
- [x] **`cache_from`**: Cache sources.
- [x] **`labels`**: Image metadata.
- [x] **`network`**: Network mode during build.
- [x] **`shm_size`**: Shared memory size.
- [ ] **`tags`**: Additional tags.

## CLI Commands
- [x] **`build`**: Ensure full support for build options.
- [x] **`pull`**: Ensure `pull` command respects service image definitions.
- [ ] **`push`**: Implement `push` command.
- [ ] **`rm`**: Implement `rm` command to remove stopped containers.
- [ ] **`pause` / `unpause`**: Implement pause commands.
- [x] **`port`**: Implement port mapping inspection.
- [ ] **`events`**: Stream container events.
