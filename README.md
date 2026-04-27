# GitHub Actions Self-Hosted Runner for CapRover

A containerized GitHub Actions runner designed to be deployed as a CapRover application. This runner provides a secure, scalable way to run GitHub Actions workflows on your own infrastructure.

## Features

- **CapRover Integration**: Deploy as a native CapRover app with dashboard management
- **Reusable**: Single Docker image works for any GitHub repository
- **Configurable**: Environment variable-based configuration
- **Persistent registration**: Register once, survive restarts and redeploys without needing a fresh token
- **Self-healing**: Built-in watchdog detects the upstream "broker listener silently dies" bug and forces a restart so the runner doesn't sit idle missing jobs
- **Scalable**: Easy to deploy multiple runners for different repositories
- **Secure**: Network isolation through CapRover's container management

## How registration works (read this first)

GitHub registration tokens are valid for **only 1 hour**. If the runner had to re-register on every container restart, you'd need a fresh token every time — painful and easy to get wrong.

This image avoids that by using a **persistent volume on `/home/runner`**. The flow:

1. **First boot:** entrypoint sees no `/home/runner/.runner` file, runs `config.sh` with your one-time `GITHUB_TOKEN`, and writes `.runner` + `.credentials` (a long-lived RSA keypair) to the volume.
2. **Every boot after that:** entrypoint sees the existing config, skips registration entirely, and goes straight to `run.sh`. The runner reconnects to GitHub using the RSA keypair on the volume — no token needed.

You only ever supply a registration token **once per app**. After that you can clear the env var and restart freely.

## Prerequisites

- CapRover instance running and accessible (≥ v1.8.0 if you want to use the YAML override path; otherwise the dashboard UI is fine)
- GitHub repository with Actions enabled

## Quick Setup

### Step 1: Get a GitHub registration token

1. In your GitHub repository, go to **Settings → Actions → Runners**.
2. Click **"New self-hosted runner"**.
3. Select **Linux** as the operating system.
4. From the configure command, copy the value after `--token` (it looks like `AABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890`).
5. This is your `GITHUB_TOKEN`. It expires in 1 hour, so don't generate it until you're ready to deploy.

> **Security note:** Treat this token like an API key. Anyone who has it within the next hour can register a runner under your repo. Don't paste it into chat tools, screenshots, etc.

### Step 2: Create the CapRover app

1. Open your CapRover dashboard.
2. Go to **Apps → Create New App**.
3. App Name: `github-runner` (or any descriptive name — for multi-repo setups, name per repo, e.g. `github-runner-myproject`).
4. Click **Create New App**. Don't deploy code yet.

### Step 3: Configure the persistent volume (one-time, before first deploy)

This is the critical step that makes registration persistent. Do this **before** you first deploy the app.

1. Open the new app → **App Configs** tab.
2. Scroll to **Persistent Directories** and click **Add Persistent Directory**.
3. Fill in:
   - **Path in App:** `/home/runner` — **always exactly this**. Do not change it; the runner binary lives in this directory and expects to find `config.sh`, `run.sh`, `_diag/`, etc. here.
   - **Label:** any name you want, e.g. `runner-home`. CapRover scopes persistent volumes per-app (the actual Docker volume becomes `<appname>--<label>`), so using the same label across multiple runner apps is safe. If you prefer, use `runner-home-<reponame>` to make the volume name self-documenting.
4. Click **Save & Update**.

Skipping this step is the #1 cause of registration loops on redeploy.

### Step 4: Set environment variables

In the same **App Configs** tab, scroll to **Environmental Variables** and add:

| Variable | Required? | Value |
|----------|-----------|-------|
| `GITHUB_URL` | Yes (first boot only) | `https://github.com/your-username/your-repository` |
| `GITHUB_TOKEN` | Yes (first boot only) | The token from Step 1 |
| `RUNNER_NAME` | Optional | A unique name. Defaults to `caprover-runner-<hostname>`. |
| `RUNNER_LABELS` | Optional | Comma-separated labels. Defaults to `self-hosted,linux,docker,caprover`. |

Click **Save & Update**.

### Step 5: Deploy

Deploy the app via either:
- **Method A (Git):** Connect this repo via **Deployment → Method 3: Deploy from Github/Bitbucket/Gitlab**, then push.
- **Method B (Tar upload):** Run `caprover deploy` locally with the CapRover CLI, or upload a tarball via the dashboard.

Watch the logs (**App Configs → View Logs**) for:

```
First boot - registering runner...
...
√ Connected to GitHub
...
Listening for Jobs
```

That last line is the success signal.

### Step 6: Clear the registration token (recommended)

Once you see `Listening for Jobs`:

1. Go back to **App Configs → Environmental Variables**.
2. **Clear the `GITHUB_TOKEN` value** (delete it). The token has already been consumed and will be useless within an hour anyway. Leaving stale secrets in env vars is bad hygiene.
3. Click **Save & Update**. The container will restart, see the existing config on the volume, and reconnect without needing the token.

You can also clear `GITHUB_URL` if you like, but it's harmless to leave.

That's it. From here on, restarts and redeploys reuse the volume. No tokens, no clicks.

## Configuration reference

### Environment variables

| Variable | Description | Default |
|----------|-------------|---------|
| `GITHUB_URL` | GitHub repo or org URL. Only required on first boot (when `/home/runner/.runner` doesn't exist yet). | — |
| `GITHUB_TOKEN` | Registration token. Only required on first boot. | — |
| `RUNNER_NAME` | Unique name shown in GitHub's runners list. | `caprover-runner-$(hostname)` |
| `RUNNER_LABELS` | Comma-separated labels. | `self-hosted,linux,docker,caprover` |
| `WATCHDOG_MAX_SILENCE_SECS` | If no broker activity is logged for this many seconds, the watchdog kills the runner and lets CapRover restart it. | `900` (15 min) |
| `WATCHDOG_INTERVAL_SECS` | How often the watchdog checks the diag log. | `60` |
| `WATCHDOG_GRACE_PERIOD_SECS` | How long the watchdog waits after startup before its first check. | `300` (5 min) |

### Persistent volume

| Container path | Why it must persist |
|----------------|---------------------|
| `/home/runner` | Holds `.runner`, `.credentials`, `.credentials_rsaparams` (registration state) plus the runner's working directory. |

## Multiple runners for multiple repositories

Create one CapRover app per repo. Each app gets its **own persistent volume** — don't share volumes between apps, since each volume is bound to one repo's registration credentials.

What changes per runner:
- **App name:** must be unique (e.g. `github-runner-project1`, `github-runner-project2`).
- **`GITHUB_URL`:** the new repo URL.
- **`GITHUB_TOKEN`:** a fresh registration token from that repo.
- **`RUNNER_NAME`** (optional): handy if you want the runner to show up under a recognisable name in GitHub.

What stays the same per runner:
- **Path in App** for the persistent directory: always `/home/runner`.
- **Label** for the persistent directory: can be the same (`runner-home`) for every app — CapRover namespaces persistent volumes by app, so the actual Docker volumes don't collide. There's no need to invent a unique label per runner.
- The Docker image / source code: same for all of them.

So for each new runner: create app → add Persistent Directory (`/home/runner` → `runner-home`) → set the three env vars → deploy → clear `GITHUB_TOKEN` after `Listening for Jobs`. That's it.

```
github-runner-project1  → volume: github-runner-project1--runner-home  → registers to github.com/you/project1
github-runner-project2  → volume: github-runner-project2--runner-home  → registers to github.com/you/project2
```

## Switching an existing runner to a different repo

The persistent volume is tied to the original repo's credentials, so you can't just change `GITHUB_URL` and restart.

Either:
- **Cleaner:** create a new app for the new repo, leave the old one (or delete it).
- **In-place:** SSH into the container (`docker exec -it ...`), run `./config.sh remove --token <old-token-or-PAT>`, delete `/home/runner/.runner` and `.credentials*`, set the new `GITHUB_URL` + `GITHUB_TOKEN` env vars, restart.

## Usage in GitHub Actions

```yaml
name: CI/CD Pipeline
on: [push, pull_request]

jobs:
  build:
    runs-on: self-hosted   # or use specific labels: [self-hosted, caprover]
    steps:
      - uses: actions/checkout@v4
      - run: echo "Running on self-hosted runner!"
```

## Monitoring & Troubleshooting

### Where to look
- **CapRover Dashboard → your app → View Logs** for runner output.
- **GitHub Repository → Settings → Actions → Runners** to confirm Idle status.

### Common issues

**Registration loop on every restart (`POST /actions/runner-registration → 404 Not Found`)**
The persistent volume is missing or the registration token has expired. Confirm Step 3 was completed (volume mounted at `/home/runner`), generate a fresh token, set it as `GITHUB_TOKEN`, redeploy. After `Listening for Jobs` appears, clear the token env var.

**Runner shows "Idle" in GitHub but jobs aren't being picked up**
The included watchdog (`watchdog.sh`) is designed to catch this. It tails `/home/runner/_diag/Runner_*.log` for broker-listener activity and, if nothing has happened for `WATCHDOG_MAX_SILENCE_SECS` (default 15 min), kills the runner so CapRover restarts the container into a fresh state. If you're still seeing this, check the container logs for `[watchdog]` lines to see what it's observing — and consider lowering `WATCHDOG_MAX_SILENCE_SECS`.

**`Error: GITHUB_TOKEN is required for first-time registration`**
The persistent volume is empty (no prior registration) and you didn't set `GITHUB_TOKEN`. Generate a fresh token, set it, redeploy.

**Runner appears with a different random name every time**
Container is recreating without the persistent volume — the entrypoint is hitting the first-boot path on every restart. Verify Step 3.

### Viewing logs

```bash
caprover logs --appName github-runner
```

## Security best practices

1. **Token hygiene:** Set `GITHUB_TOKEN` only when registering, then clear it. Never commit a token. Don't paste it into chat / screenshots.
2. **Repo-scoped runners:** Prefer per-repo runners over org-level ones for blast-radius reasons.
3. **Resource limits:** Set CPU/memory limits in CapRover so a runaway workflow can't starve other apps.
4. **Don't run untrusted PRs:** GitHub's docs warn against using self-hosted runners for public-repo PR workflows; they're meant for trusted code.

## Updating

To update the runner image:

1. Pull latest changes to this repo.
2. Redeploy the CapRover app.
3. The volume is preserved, so no re-registration is needed. The runner will restart and reconnect using the existing credentials.

## Project Structure

```
.
├── captain-definition     # CapRover deployment configuration
├── Dockerfile             # Container definition
├── entrypoint.sh          # Runner startup script (skip-if-configured + run + watchdog)
├── watchdog.sh            # Listener-health watchdog
├── TO-FIX.md              # Reliability fixes log
└── README.md              # This file
```

## Why this approach?

- **Integrated:** works seamlessly with existing CapRover setup
- **Manageable:** dashboard + log viewer for everything
- **Reliable:** persistent volume means registration survives restarts and redeploys
- **Isolated:** network isolation for security
- **Scalable:** one app per repo, scriptable via the CapRover API for fleets
