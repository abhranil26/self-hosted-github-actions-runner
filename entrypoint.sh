#!/bin/bash

set -e

RUNNER_NAME=${RUNNER_NAME:-"caprover-runner-$(hostname)"}
RUNNER_LABELS=${RUNNER_LABELS:-"self-hosted,linux,docker,caprover"}

# Register only on first boot. /home/runner is expected to be a persistent
# volume; once .runner and .credentials are written, subsequent restarts
# reconnect using the long-lived RSA keypair and never need a token again.
if [ ! -f /home/runner/.runner ]; then
    if [ -z "$GITHUB_URL" ]; then
        echo "Error: GITHUB_URL is required for first-time registration"
        exit 1
    fi
    if [ -z "$GITHUB_TOKEN" ]; then
        echo "Error: GITHUB_TOKEN is required for first-time registration"
        exit 1
    fi

    echo "First boot - registering runner..."
    echo "Repository: $GITHUB_URL"
    echo "Runner Name: $RUNNER_NAME"

    ./config.sh \
        --url "$GITHUB_URL" \
        --token "$GITHUB_TOKEN" \
        --name "$RUNNER_NAME" \
        --labels "$RUNNER_LABELS" \
        --unattended \
        --replace
else
    echo "Runner already configured - skipping registration."
    echo "To force re-registration: clear the persistent volume, or run './config.sh remove' inside the container."
fi

echo "Starting GitHub Actions Runner..."
./run.sh &
RUNNER_PID=$!

# Watchdog detects silent broker-listener death (upstream actions/runner bug)
# and kills the runner so CapRover can restart the container into a fresh state.
/home/runner/watchdog.sh "$RUNNER_PID" &
WATCHDOG_PID=$!

# Forward shutdown signals to the runner; let it stop gracefully.
trap 'kill -TERM "$RUNNER_PID" 2>/dev/null || true' TERM INT

wait "$RUNNER_PID"
RUNNER_EXIT=$?

kill "$WATCHDOG_PID" 2>/dev/null || true
exit "$RUNNER_EXIT"
