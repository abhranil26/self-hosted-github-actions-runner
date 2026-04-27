# Reliability fixes log

## Resolved

### Broker listener silently dies; runner shows "Idle" but stops picking up jobs

**Symptom.** Runner shows Idle in GitHub UI; scheduled/dispatched workflows queue but never start. Container is alive; logs show only periodic auth-token refreshes (`RSAFileKeyManager` every ~50 min). No `Listening for Jobs` line after the last completed job.

**Root cause.** The `actions/runner` listener has two independent loops: an auth-refresh loop and a broker long-poll loop. When the broker long-poll's HTTP connection gets cancelled in the wrong state (typically a transient network blip), the listener throws `TaskCanceledException` / `SocketException(125)`, logs `Back off N seconds before next retry. 4 attempt left.`, and then never resumes. Auth refresh keeps working, so GitHub still considers the runner online — but no jobs get dispatched. Observed at `2026-04-26 23:40:38Z` with 2.5+ hours of silent failure before manual restart.

**Fix.** Added `watchdog.sh`, a sibling process started by `entrypoint.sh`. It periodically scans the latest `/home/runner/_diag/Runner_*.log` for broker-related lines (`BrokerMessageListener`, `BrokerServer`, etc.) and parses the most recent timestamp. If broker activity has been silent past `WATCHDOG_MAX_SILENCE_SECS` (default 15 min), it sends SIGTERM to the runner process and the underlying `Runner.Listener` binary, escalating to SIGKILL after 10s. The runner exits, `entrypoint.sh` exits, the container exits, and CapRover restarts it — with the persistent volume in place, the new container reconnects cleanly and resumes job dispatch.

Tunable via env vars: `WATCHDOG_MAX_SILENCE_SECS`, `WATCHDOG_INTERVAL_SECS`, `WATCHDOG_GRACE_PERIOD_SECS`.

### Container restart triggered a registration-token loop (404 Not Found)

**Symptom.** After restarting/redeploying, repeated `POST /actions/runner-registration → 404 Not Found` in logs, container exits, CapRover restarts, repeat.

**Root cause.** The old `entrypoint.sh` ran `config.sh` unconditionally on every container start, *and* the SIGTERM trap called `config.sh remove`. With no persistent volume, the registration state was wiped on every restart, requiring a fresh registration token — which expires in 1 hour, hence the 404.

**Fix.** `entrypoint.sh` now skips `config.sh` if `/home/runner/.runner` already exists, and the auto-deregister trap was removed. Combined with mounting `/home/runner` as a persistent volume in CapRover (see README Step 3), the runner registers once and reuses the long-lived RSA credentials forever. `GITHUB_TOKEN` is only required on the very first boot.

---

## Open

(none currently)
