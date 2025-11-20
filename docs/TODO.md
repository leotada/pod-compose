# Pod-Compose Missing Features TODO

This file tracks the implementation status of features defined in the [Compose Specification](docs/spec.md) but currently missing or incomplete in `pod-compose`.

## Top-Level Elements
- [ ] **`networks`**: Parse and support custom network definitions.
- [ ] **`volumes`**: Parse and support named volume definitions.
- [ ] **`configs`**: Support for config objects.
- [ ] **`secrets`**: Support for secret objects.
- [ ] **`name`**: Respect the top-level `name` property for project naming.

## Service Attributes

### Lifecycle & Orchestration
- [ ] **`depends_on`**: Implement dependency resolution and startup order.
    - [ ] Short syntax (list of names).
    - [ ] Long syntax (condition: `service_started`, `service_healthy`, `service_completed_successfully`).
- [ ] **`restart`**: Pass restart policies (`no`, `always`, `on-failure`, `unless-stopped`) to Podman.
- [ ] **`healthcheck`**: Support healthcheck configuration.
- [ ] **`deploy`**: Support deployment constraints (resources, replicas, etc.).
- [ ] **`stop_signal`**: Support custom stop signals.
- [ ] **`stop_grace_period`**: Support custom grace periods.

### Networking
- [ ] **`networks`**: Allow services to attach to specific networks (aliases, ipv4_address, etc.).
- [ ] **`dns`**: Support custom DNS servers.
- [ ] **`dns_search`**: Support custom DNS search domains.
- [ ] **`extra_hosts`**: Support adding host mappings (`--add-host`).

### Execution Environment
- [ ] **`entrypoint`**: Override image entrypoint.
- [ ] **`env_file`**: Load environment variables from files.
- [ ] **`working_dir`**: Set working directory.
- [ ] **`user`**: Ensure user mapping is correctly handled (already partially supported).
- [ ] **`init`**: Run an init inside the container.
- [ ] **`pid`**: PID namespace sharing.

### Security & Privileges
- [ ] **`cap_add`**: Add capabilities.
- [ ] **`cap_drop`**: Drop capabilities.
- [ ] **`security_opt`**: Security options (SELinux, AppArmor, etc.).
- [ ] **`privileged`**: Run container in privileged mode.
- [ ] **`devices`**: Device mappings.
- [ ] **`sysctls`**: Kernel parameters.
- [ ] **`ulimits`**: Resource limits.

### Logging
- [ ] **`logging`**: Configure logging driver and options.

## Build Configuration
- [ ] **`args`**: Support build arguments.
- [ ] **`cache_from`**: Cache sources.
- [ ] **`labels`**: Image metadata.
- [ ] **`network`**: Network mode during build.
- [ ] **`shm_size`**: Shared memory size.
- [ ] **`tags`**: Additional tags.

## CLI Commands
- [ ] **`build`**: Ensure full support for build options.
- [ ] **`pull`**: Ensure `pull` command respects service image definitions.
- [ ] **`push`**: Implement `push` command.
- [ ] **`rm`**: Implement `rm` command to remove stopped containers.
- [ ] **`pause` / `unpause`**: Implement pause commands.
- [ ] **`port`**: Implement port mapping inspection.
- [ ] **`events`**: Stream container events.
