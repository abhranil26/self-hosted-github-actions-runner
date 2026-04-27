#!/bin/bash
# Monitors broker-listener health in /home/runner/_diag and kills the runner if
# the listener has been silent past WATCHDOG_MAX_SILENCE_SECS. Container exit
# triggers a CapRover restart, which (with the persistent volume in place)
# brings up a fresh, healthy listener without re-registering.

set -uo pipefail

RUNNER_PID="${1:?usage: watchdog.sh <runner-pid>}"

DIAG_DIR="/home/runner/_diag"
CHECK_INTERVAL_SECS="${WATCHDOG_INTERVAL_SECS:-60}"
MAX_SILENCE_SECS="${WATCHDOG_MAX_SILENCE_SECS:-900}"
GRACE_PERIOD_SECS="${WATCHDOG_GRACE_PERIOD_SECS:-300}"

log() { echo "[watchdog] $*"; }

log "starting (runner_pid=$RUNNER_PID interval=${CHECK_INTERVAL_SECS}s max_silence=${MAX_SILENCE_SECS}s grace=${GRACE_PERIOD_SECS}s)"
sleep "$GRACE_PERIOD_SECS"

while kill -0 "$RUNNER_PID" 2>/dev/null; do
    LATEST_LOG=$(ls -t "$DIAG_DIR"/Runner_*.log 2>/dev/null | head -1)
    if [ -z "${LATEST_LOG:-}" ]; then
        log "no diag log yet at $DIAG_DIR, skipping check"
        sleep "$CHECK_INTERVAL_SECS"
        continue
    fi

    # Match lines like: [RUNNER 2026-04-26 23:40:38Z INFO BrokerMessageListener] ...
    # or              : [RUNNER 2026-04-26 23:40:38Z WARN BrokerServer] ...
    # Extract just the timestamp from the most recent such line.
    LAST_TS=$(grep -oE '\[RUNNER [0-9-]+ [0-9:]+Z +[A-Z]+ +Broker[A-Za-z]+\]' "$LATEST_LOG" 2>/dev/null \
              | tail -1 \
              | awk '{print $2, $3}')

    if [ -z "${LAST_TS:-}" ]; then
        log "no broker activity yet in $(basename "$LATEST_LOG"), skipping check"
        sleep "$CHECK_INTERVAL_SECS"
        continue
    fi

    LAST_EPOCH=$(date -u -d "$LAST_TS" +%s 2>/dev/null || echo "")
    if [ -z "$LAST_EPOCH" ]; then
        log "could not parse timestamp '$LAST_TS', skipping check"
        sleep "$CHECK_INTERVAL_SECS"
        continue
    fi

    NOW_EPOCH=$(date -u +%s)
    SILENCE=$((NOW_EPOCH - LAST_EPOCH))

    if [ "$SILENCE" -gt "$MAX_SILENCE_SECS" ]; then
        log "BROKER SILENT for ${SILENCE}s (threshold ${MAX_SILENCE_SECS}s). Last broker line: $LAST_TS. Killing runner pid=$RUNNER_PID."
        kill -TERM "$RUNNER_PID" 2>/dev/null || true
        pkill -TERM -f "Runner.Listener" 2>/dev/null || true
        sleep 10
        kill -KILL "$RUNNER_PID" 2>/dev/null || true
        pkill -KILL -f "Runner.Listener" 2>/dev/null || true
        exit 0
    fi

    sleep "$CHECK_INTERVAL_SECS"
done

log "runner pid=$RUNNER_PID exited; watchdog shutting down"
