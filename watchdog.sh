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

# Track the last successfully-parsed broker timestamp. If the regex never matches
# (e.g. diag format changes), fall back to LOOP_START so a blind watchdog still
# trips the silence threshold and restarts the container — instead of running
# forever as it did when the v1 regex was wrong but silently returned no matches.
LOOP_START=$(date -u +%s)
LAST_BROKER_EPOCH=""

while kill -0 "$RUNNER_PID" 2>/dev/null; do
    LATEST_LOG=$(ls -t "$DIAG_DIR"/Runner_*.log 2>/dev/null | head -1)
    if [ -z "${LATEST_LOG:-}" ]; then
        log "no diag log yet at $DIAG_DIR, skipping check"
        sleep "$CHECK_INTERVAL_SECS"
        continue
    fi

    # Diag log lines look like:
    #   [2026-04-27 04:30:24Z INFO BrokerMessageListener] Connecting to the Broker Server...
    #   [2026-04-27 08:31:18Z ERR  BrokerServer] Catch exception during request
    # The container's stdout adds a "[RUNNER ...]" wrapping prefix, but the diag
    # file itself does NOT — the regex must not require it.
    LAST_TS=$(grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9:]+Z +[A-Z]+ +Broker[A-Za-z]+' "$LATEST_LOG" 2>/dev/null \
              | tail -1 \
              | awk '{print $1, $2}')

    if [ -n "$LAST_TS" ]; then
        PARSED=$(date -u -d "$LAST_TS" +%s 2>/dev/null || echo "")
        if [ -n "$PARSED" ]; then
            LAST_BROKER_EPOCH="$PARSED"
        fi
    fi

    NOW_EPOCH=$(date -u +%s)
    REFERENCE_EPOCH=${LAST_BROKER_EPOCH:-$LOOP_START}
    SILENCE=$((NOW_EPOCH - REFERENCE_EPOCH))

    if [ "$SILENCE" -gt "$MAX_SILENCE_SECS" ]; then
        if [ -n "$LAST_BROKER_EPOCH" ]; then
            log "BROKER SILENT for ${SILENCE}s (threshold ${MAX_SILENCE_SECS}s). Last broker line: $LAST_TS. Killing runner pid=$RUNNER_PID."
        else
            log "WATCHDOG BLIND for ${SILENCE}s (no broker line ever matched in $(basename "$LATEST_LOG")). Killing runner pid=$RUNNER_PID as safety."
        fi
        kill -TERM "$RUNNER_PID" 2>/dev/null || true
        pkill -TERM -f "Runner.Listener" 2>/dev/null || true
        sleep 10
        kill -KILL "$RUNNER_PID" 2>/dev/null || true
        pkill -KILL -f "Runner.Listener" 2>/dev/null || true
        exit 0
    fi

    if [ -z "$LAST_TS" ]; then
        log "no broker line matched in $(basename "$LATEST_LOG") (blind ${SILENCE}s; will kill at ${MAX_SILENCE_SECS}s)"
    fi

    sleep "$CHECK_INTERVAL_SECS"
done

log "runner pid=$RUNNER_PID exited; watchdog shutting down"
