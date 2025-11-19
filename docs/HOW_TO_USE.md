# How to Use Pod-Compose

`pod-compose` is a tool designed to simplify running multi-container applications using Podman Pods, inspired by `docker-compose`.

## Basic Workflow

1.  **Navigate to your project directory**:
    Ensure your `docker-compose.yml` (or `.yaml`) is present.

    ```bash
    cd /path/to/your/project
    ```

2.  **Build Images (Optional)**:
    If your services require building from a Dockerfile:

    ```bash
    pod-compose build
    ```

3.  **Start Services**:
    This will create a Podman Pod (named after your directory) and start all services inside it.

    ```bash
    pod-compose up
    ```

4.  **Check Status**:
    See running containers within the pod.

    ```bash
    pod-compose ps
    ```

5.  **View Logs**:
    See logs for all services or specific ones.

    ```bash
    # All logs
    pod-compose logs

    # Follow logs
    pod-compose logs -f

    # Specific service
    pod-compose logs web
    ```

6.  **Interact with Containers**:
    Run a command inside a container.

    ```bash
    # Syntax: pod-compose exec [service_name] [command]
    pod-compose exec web /bin/bash
    ```

7.  **Stop and Remove**:
    When you are done, bring everything down.

    ```bash
    pod-compose down
    ```

## Advanced Usage

### Lifecycle Management
You can stop, start, or restart the entire pod without removing it.

```bash
pod-compose stop
pod-compose start
pod-compose restart
```

### Image Management
To pull the latest images defined in your compose file:

```bash
pod-compose pull
```

### Custom Compose File
To use a specific compose file instead of the default `docker-compose.yml`:

```bash
pod-compose -f my-compose.yml up
```

### Version Check
To check which version of `pod-compose` you are running:

```bash
pod-compose version
```

## Troubleshooting

- **Pod already exists**: If `up` fails saying the pod exists, try `down` first or `start` if you just want to resume.
- **Image not found**: Ensure you run `build` or `pull` if the images are not available locally.
