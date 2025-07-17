#!/bin/bash

set -e

# Configuration from environment variables only
RUNNER_NAME=${RUNNER_NAME:-"caprover-runner-$(hostname)"}
RUNNER_LABELS=${RUNNER_LABELS:-"self-hosted,linux,docker,caprover"}

echo "Configuring GitHub Actions Runner..."
echo "Repository: $GITHUB_URL"
echo "Runner Name: $RUNNER_NAME"

# Validate required environment variables
if [ -z "$GITHUB_URL" ]; then
    echo "Error: GITHUB_URL environment variable is required"
    exit 1
fi

if [ -z "$GITHUB_TOKEN" ]; then
    echo "Error: GITHUB_TOKEN environment variable is required"
    exit 1
fi

# Configure the runner
./config.sh \
    --url "$GITHUB_URL" \
    --token "$GITHUB_TOKEN" \
    --name "$RUNNER_NAME" \
    --labels "$RUNNER_LABELS" \
    --unattended \
    --replace

# Cleanup handler
cleanup() {
    echo "Removing runner..."
    ./config.sh remove --unattended --token "$GITHUB_TOKEN" || true
    exit 0
}

trap cleanup SIGTERM SIGINT

# Start the runner
echo "Starting GitHub Actions Runner..."
./run.sh &

wait $!