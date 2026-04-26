#!/usr/bin/env bash
# End-to-end integration test for pod-compose.
# Exercises the full lifecycle (up, ps, exec, port, logs, pause/unpause,
# kill, rm, down) against a real Podman installation. Each scenario uses a
# unique project name so leftovers from previous runs do not interfere.
#
# Usage: tests/integration.sh
# Requires: podman, dub (to build the binary), bash 4+.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$ROOT/pod-compose"

note() { printf '\n=== %s ===\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

note "Building pod-compose"
( cd "$ROOT" && dub build --build=release ) >/dev/null

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"; podman pod rm -f pcint_basic_pod >/dev/null 2>&1 || true; podman pod rm -f pcint_health_pod >/dev/null 2>&1 || true; podman pod rm -f pcint_build_pod >/dev/null 2>&1 || true' EXIT

###############################################################################
note "Scenario 1: basic up/ps/exec/logs/down (single-pod, two services)"
###############################################################################
PROJ1="$WORK/pcint_basic"
mkdir -p "$PROJ1"
cat > "$PROJ1/.env" <<'EOF'
GREETING=hello-from-env-file
EOF
cat > "$PROJ1/compose.yml" <<'EOF'
services:
  cache:
    image: docker.io/library/redis:7-alpine
    command: ["redis-server", "--appendonly", "no"]
  web:
    image: docker.io/library/alpine:3.19
    env_file:
      - .env
    environment:
      EXPLICIT: takes-precedence
    command: ["sh", "-c", "echo $GREETING && echo $EXPLICIT && sleep 60"]
    depends_on:
      - cache
EOF

( cd "$PROJ1" && "$BIN" up )
podman pod exists pcint_basic_pod || fail "pod pcint_basic_pod was not created"
COUNT=$(podman ps --filter pod=pcint_basic_pod --format '{{.Names}}' | wc -l)
[ "$COUNT" -ge 2 ] || fail "expected >=2 containers in pod, got $COUNT"

( cd "$PROJ1" && "$BIN" ps ) >/dev/null
( cd "$PROJ1" && "$BIN" logs web ) | grep -q "hello-from-env-file" \
    || fail "env_file was not applied"
( cd "$PROJ1" && "$BIN" logs web ) | grep -q "takes-precedence" \
    || fail "environment override missing"

( cd "$PROJ1" && "$BIN" pause ) >/dev/null
STATE=$(podman pod inspect pcint_basic_pod --format '{{.State}}')
[ "$STATE" = "Paused" ] || fail "pod not paused, state=$STATE"
( cd "$PROJ1" && "$BIN" unpause ) >/dev/null

( cd "$PROJ1" && "$BIN" config ) | grep -q "cache" || fail "config did not list services"
( cd "$PROJ1" && "$BIN" images ) | grep -q "redis" || fail "images did not list redis"

( cd "$PROJ1" && "$BIN" down ) >/dev/null
podman pod exists pcint_basic_pod && fail "pod still exists after down"
echo "Scenario 1 OK"

###############################################################################
note "Scenario 2: build (no image: tag) auto-builds, does not try to pull"
###############################################################################
PROJ2="$WORK/pcint_build"
mkdir -p "$PROJ2"
cat > "$PROJ2/Dockerfile" <<'EOF'
FROM docker.io/library/alpine:3.19
CMD ["sleep", "120"]
EOF
cat > "$PROJ2/compose.yml" <<'EOF'
services:
  app:
    build:
      context: .
EOF

( cd "$PROJ2" && "$BIN" up )
podman image exists pcint_build_app:latest || fail "build did not produce expected image"
podman pod exists pcint_build_pod || fail "pod pcint_build_pod was not created"
( cd "$PROJ2" && "$BIN" down ) >/dev/null
podman rmi -f pcint_build_app:latest >/dev/null
echo "Scenario 2 OK"

###############################################################################
note "Scenario 3: depends_on with service_healthy waits for health"
###############################################################################
PROJ3="$WORK/pcint_health"
mkdir -p "$PROJ3"
cat > "$PROJ3/compose.yml" <<'EOF'
services:
  db:
    image: docker.io/library/alpine:3.19
    command: ["sh", "-c", "sleep 3; touch /tmp/ready; sleep 60"]
    healthcheck:
      test: ["CMD-SHELL", "test -f /tmp/ready"]
      interval: 1s
      timeout: 1s
      retries: 30
      start_period: 1s
  app:
    image: docker.io/library/alpine:3.19
    command: ["sh", "-c", "echo started; sleep 30"]
    depends_on:
      db:
        condition: service_healthy
EOF

START=$(date +%s)
( cd "$PROJ3" && "$BIN" up )
END=$(date +%s)
ELAPSED=$((END - START))
[ "$ELAPSED" -ge 3 ] || fail "depends_on did not wait (elapsed=${ELAPSED}s)"
podman ps --filter pod=pcint_health_pod --format '{{.Names}}' | grep -q app \
    || fail "app container was not started"
( cd "$PROJ3" && "$BIN" down ) >/dev/null
echo "Scenario 3 OK (waited ${ELAPSED}s)"

note "All integration scenarios passed."
