# GitHub Actions Self-Hosted Runner for CapRover

A containerized GitHub Actions runner designed to be deployed as a CapRover application. This runner provides a secure, scalable way to run GitHub Actions workflows on your own infrastructure.

## Features

- **CapRover Integration**: Deploy as a native CapRover app with dashboard management
- **Reusable**: Single Docker image works for any GitHub repository
- **Configurable**: Environment variable-based configuration
- **Auto-cleanup**: Graceful runner removal on container shutdown
- **Scalable**: Easy to deploy multiple runners for different repositories
- **Secure**: Network isolation through CapRover's container management

## Prerequisites

- CapRover instance running and accessible
- GitHub repository with Actions enabled
- GitHub Personal Access Token or App Token with appropriate permissions

## Quick Setup

### Step 1: Get GitHub Runner Token

#### Method 1: Repository Runner Token (Recommended)

1. Go to your GitHub repository
2. Navigate to **Settings** → **Actions** → **Runners**
3. Click **"New self-hosted runner"**
4. Select **Linux** as the operating system
5. Copy the token from the configuration command (it looks like `AABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890`)
6. Use this token as your `GITHUB_TOKEN` environment variable

> **Note**: Repository runner tokens are temporary and expire after 1 hour if not used, but once the runner is configured, it will continue to work.

#### Method 2: Personal Access Token (Alternative)

If you prefer using a Personal Access Token (useful for automation or multiple repositories):

1. Go to GitHub Settings → Developer settings → Personal access tokens
2. Create a new token with these permissions:
   - `repo` (for private repos) or `public_repo` (for public repos)
   - `workflow`
   - `admin:org` (if using organization-level runners)

### Step 2: Deploy to CapRover

1. **Create New App in CapRover**:
   - Open your CapRover dashboard
   - Go to "Apps" → "Create New App"
   - App Name: `github-runner` (or any descriptive name)

2. **Deploy the Application**:
   - Method 1: Upload this project as a tar file
   - Method 2: Connect to your Git repository containing this code

3. **Configure Environment Variables**:
   In the CapRover app settings, add these environment variables:

   ```bash
   GITHUB_URL=https://github.com/your-username/your-repository
   GITHUB_TOKEN=your_github_token_here
   RUNNER_NAME=caprover-runner-unique-name
   RUNNER_LABELS=self-hosted,linux,docker,caprover
   ```

4. **Deploy**: Click "Deploy" in CapRover dashboard

## Configuration

### Required Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `GITHUB_URL` | Full URL to your GitHub repository | `https://github.com/username/repo` |
| `GITHUB_TOKEN` | GitHub token with runner registration permissions | `ghp_xxxxxxxxxxxx` |

### Optional Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `RUNNER_NAME` | Unique name for the runner | `caprover-runner-$(hostname)` |
| `RUNNER_LABELS` | Comma-separated labels for the runner | `self-hosted,linux,docker,caprover` |

## Multiple Repository Setup

### Option 1: Single Runner (Switch Repositories)

To use the same runner for different repositories:

1. Stop the CapRover app
2. Update `GITHUB_URL` and `GITHUB_TOKEN` environment variables
3. Restart the app

### Option 2: Multiple Runners (Recommended)

Create separate CapRover apps for each repository:

```bash
# App 1: github-runner-project1
GITHUB_URL=https://github.com/username/project1
GITHUB_TOKEN=token_for_project1
RUNNER_NAME=caprover-project1-runner

# App 2: github-runner-project2  
GITHUB_URL=https://github.com/username/project2
GITHUB_TOKEN=token_for_project2
RUNNER_NAME=caprover-project2-runner
```

## Usage in GitHub Actions

Once deployed, use your self-hosted runner in workflows:

```yaml
name: CI/CD Pipeline
on: [push, pull_request]

jobs:
  build:
    runs-on: self-hosted  # or use specific labels
    # runs-on: [self-hosted, caprover]
    
    steps:
      - uses: actions/checkout@v4
      - name: Run tests
        run: |
          echo "Running on self-hosted runner!"
          # Your build/test commands here
```

## Monitoring & Troubleshooting

### Check Runner Status

1. **CapRover Dashboard**: Monitor app logs and status
2. **GitHub Repository**: Settings → Actions → Runners

### Common Issues

**Runner not appearing in GitHub**:
- Verify `GITHUB_TOKEN` has correct permissions
- Check `GITHUB_URL` is correct and accessible
- Review CapRover app logs for error messages

**Runner offline**:
- Check CapRover app status
- Restart the app if needed
- Verify network connectivity

**Token expired**:
- Generate new GitHub token
- Update `GITHUB_TOKEN` environment variable
- Restart the app

### Viewing Logs

```bash
# In CapRover dashboard, go to your app and click "View Logs"
# Or use CapRover CLI:
caprover logs --appName github-runner
```

## Security Best Practices

1. **Token Management**:
   - Use tokens with minimal required permissions
   - Rotate tokens regularly
   - Store tokens securely in CapRover environment variables

2. **Network Security**:
   - Leverage CapRover's network isolation
   - Consider using organization-level runners for better security

3. **Resource Limits**:
   - Set appropriate CPU/memory limits in CapRover
   - Monitor resource usage

## Updating

To update the runner:

1. Pull latest changes to this repository
2. Redeploy the CapRover app
3. The runner will automatically update and re-register

## Project Structure

```
.
├── captain-definition     # CapRover deployment configuration
├── Dockerfile            # Container definition
├── entrypoint.sh         # Runner startup script
└── README.md            # This file
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with your CapRover setup
5. Submit a pull request

## License

This project is open source. Please check the repository for license details.

---

## Why Use This Approach?

✓ **Integrated**: Works seamlessly with existing CapRover setup  
✓ **Manageable**: Easy management through CapRover dashboard  
✓ **Reliable**: Automatic restarts and monitoring  
✓ **Isolated**: Network isolation for security  
✓ **Scalable**: Easy to scale or remove runners  

Your GitHub runner becomes just another service in your CapRover ecosystem, without any risk to your existing Docker services.