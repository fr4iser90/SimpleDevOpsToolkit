# SimpleDevOpsToolkit - Utility Suite

## Overview

This utility suite provides a generic framework for managing Docker-based applications. It offers tools for deploying, configuring, and maintaining projects defined in a `.project_config.sh` file located in the project's root directory, simplifying operations on local or remote servers through an interactive command-line interface.

## Key Features

- **Project Agnostic**: Designed to manage different projects by loading settings from `.project_config.sh` in the current project's root directory.
- **Intelligent Setup**: Automatic detection and initialization based on the loaded configuration.
- **Remote Server Management**: Deploy and manage applications on remote servers without manual SSH commands.
- **Container Management**: Control Docker containers with simple menu options.
- **Database Operations**: Perform backups, restores, and migrations with ease.
- **Configuration Management**: Edit environment variables through guided interfaces.
- **Logging Utilities**: View and download logs from all services.
- **Testing Framework**: Run and manage automated tests.
- **Auto-start Capabilities**: Automatic service initialization after deployment.
- **Interactive Feedback**: Real-time console output with customizable verbosity levels.

## Getting Started

### Prerequisites

- Git (to clone the toolkit repository).
- For remote use: SSH access to your target server.
- Docker and Docker Compose installed on the target machine (local or remote).
- A `.project_config.sh` file in the root directory of **each project** you want to manage.

### Initial Setup

1.  **Clone the Toolkit Repository:**
    ```bash
    git clone <repository_url> /path/to/SimpleDevOpsToolkit
    cd /path/to/SimpleDevOpsToolkit
    ```
    Replace `<repository_url>` with the actual URL of the toolkit's repository. Choose a suitable location like `~/tools/` or `~/bin/`.

2.  **Prepare Your Project:**
    *   Ensure each project you want to manage (e.g., `~/Documents/Git/FoundryCord`) has a `.project_config.sh` file in its **root directory**. You can copy and adapt the example file (if one exists in the toolkit) or create one based on your project's needs.
    *   Example `.project_config.sh` location: `~/Documents/Git/FoundryCord/.project_config.sh`

3.  **Run the Toolkit:**
    *   Navigate to your project's directory:
        ```bash
        cd ~/Documents/Git/FoundryCord
        ```
    *   Execute the toolkit script using its full path:
        ```bash
        /path/to/SimpleDevOpsToolkit/SimpleDevOpsToolkit.sh
        ```
    *   The first time you run the script, it will automatically set execute permissions for its internal scripts.

4.  **First Run within a Project Directory:** The utility will:
    *   Load settings from the `.project_config.sh` found in the current directory (`~/Documents/Git/FoundryCord/.project_config.sh` in this example).
    *   If running in remote mode (using the `--remote` flag or if configured in `.project_config.sh`), check SSH connection.
    *   Guide you through server environment initialization if needed (creating directories based on config).
    *   Offer deployment options based on your configuration.

### Making the Toolkit Globally Accessible (Optional)

To avoid typing the full path to `SimpleDevOpsToolkit.sh` every time, you can add it to your system's `PATH` by creating a symbolic link (symlink) in a directory that is already included in your `PATH`. This allows you to run the toolkit simply by typing `SimpleDevOpsToolkit` from within any project directory.

**Option 1: User-Specific Installation (Recommended for most users)**

This makes the command available only to the current user without requiring administrator privileges.

1.  Ensure `~/.local/bin` exists and is in your `PATH`. Most modern Linux distributions include this by default.
    *   Check your PATH: `echo $PATH`
    *   Create the directory if needed: `mkdir -p ~/.local/bin`
    *   If it's not in your PATH, add `export PATH="$HOME/.local/bin:$PATH"` to your shell configuration file (e.g., `~/.bashrc`, `~/.zshrc`) and restart your shell or run `source ~/.your_config_file`.
2.  Create the symlink (run this command from **within the cloned SimpleDevOpsToolkit directory**):
    ```bash
    ln -s "$(pwd)/SimpleDevOpsToolkit.sh" ~/.local/bin/SimpleDevOpsToolkit
    ```

**Option 2: System-Wide Installation (Requires Administrator Privileges)**

This makes the command available to all users on the system.

1.  Ensure `/usr/local/bin` exists and is in the `PATH` for all users (this is standard).
2.  Create the symlink using `sudo` (run this command from **within the cloned SimpleDevOpsToolkit directory**):
    ```bash
    sudo ln -s "$(pwd)/SimpleDevOpsToolkit.sh" /usr/local/bin/SimpleDevOpsToolkit
    ```

After setting up the symlink using either method, you can navigate to your project directory (e.g., `cd ~/Documents/Git/FoundryCord`) and run the toolkit simply by typing:

```bash
SimpleDevOpsToolkit
```

## Main Menu Options

### Deployment Tools

- **Quick Deploy**: Preserves database, auto-starts services.
- **Partial Deploy**: Rebuilds containers only.
- **Full Reset Deploy**: WARNING: destroys all persistent data (DB, models).
- **Deploy with Monitoring**: Shows real-time console output.

### Container Management

- Start/stop/restart all containers.
- Manage individual containers.
- View container status and health metrics.
- Watch container logs in real-time.

### Testing Tools

- Run automated tests.
- Upload test files.
- Verify server environment.
- Generate test reports.

### Database Tools

- Apply migrations (if applicable to the project).
- Backup database (using `DB_NAME`, `DB_CONTAINER_NAME` from config).
- Restore database.

### Development Tools

- Generate encryption keys.
- Initialize test environment.
- Create development certificates.
- Setup local development environment.

### Configuration Management

- Edit server connection settings.
- Manage environment variables.
- Configure auto-start behavior.
- Setup notification preferences.

### Logs & Monitoring

- View logs for specific services (names depend on `CONTAINER_NAMES` in `.project_config.sh`).
- Download log files.
- Set up log watching.
- Configure alert thresholds.

## Directory Structure

- **`config/`**: Base configuration files for the toolkit itself (like `auto_start.conf`). **Project-specific configuration lives in `.project_config.sh` within each project's root.**
- **`database/`**: Database management scripts (may need project-specific adaptation).
- **`functions/`**: Core functionality modules.
- **`lib/`**: Common libraries and utilities.
- **`menus/`**: Menu interface components.
- **`testing/`**: Test execution and management.
- **`ui/`**: User interface functions.
- **`init/`**: Initialization scripts for first-time setup.

## Configuration Files

The framework relies on configuration loaded from:
- **`.project_config.sh`**: **REQUIRED**. Must exist in the **root directory of the project** you are currently managing. Defines all project-specific settings (server, paths, project name, container names, DB names, etc.). You need to create/manage this file for each of your projects.
- `config/config.sh`: Internal script within the toolkit that loads the project's `.project_config.sh` and sets up runtime variables.
- `config/auto_start.conf`: Defines default auto-start behavior. Values can be overridden by settings in the project's `.project_config.sh`.
- `.env`: (Optional) If present in the project's root directory or its `docker/` subdirectory, environment variables will be loaded from here.

## Initialization Process

When run for the first time *within a specific project directory*:
1. Loads configuration from `.project_config.sh` in the current directory.
2. Detects local Git repository path from config.
3. If in remote mode, checks SSH connection using server details from config.
4. Creates necessary directory structure on the remote server based on paths in config.
5. Checks for `.env` file, helps create from template if missing.
6. Configures auto-start preferences based on defaults or user input.
7. Offers deployment and service start options.

## Auto-Start and Feedback Options

The utility includes enhanced deployment options, usable via CLI flags or the menu:
```bash
# Run from your project directory after setting up the global command (optional)
SimpleDevOpsToolkit --auto-start

# Or using the full path
/path/to/SimpleDevOpsToolkit/SimpleDevOpsToolkit.sh --watch-console

# Monitor specific services
SimpleDevOpsToolkit --watch=service1,service2
```

## Advanced Usage

### Command-line Arguments

The utility supports various command-line arguments. Run these from your project directory.
```bash
# Example using the global command
SimpleDevOpsToolkit --host=192.168.1.100 --user=admin --port=2222 --auto-start --watch-console

# Example using the full path
/path/to/SimpleDevOpsToolkit/SimpleDevOpsToolkit.sh --rebuild --quick-deploy
```

Common options:
- `--host=HOST`: Specify remote server hostname/IP.
- `--user=USER`: Specify SSH username.
- `--port=PORT`: Specify SSH port.
- `--no-restart`: Prevent automatic service restarts.
- `--rebuild`: Force container rebuilds during deployment.
- `--auto-start`: Enable automatic startup after deployment.
- `--watch-console`: Show real-time console output.
- `--watch=SERVICES`: Monitor specific services (comma-separated).
- `--init-only`: Run initialization without deployment.
- `--feedback=LEVEL`: Set feedback verbosity (minimal, normal, detailed).

### Local Mode

If SSH connection fails (when using `--remote` or if configured for remote), the toolkit may offer to run in local mode. Configuration for local paths should be present in `.project_config.sh`.
```bash
# Run from your project directory
SimpleDevOpsToolkit --remote
```

## Troubleshooting

### Connection Issues

If you encounter SSH connection problems:
1. Verify server address and credentials.
2. Check if SSH key authentication is set up correctly.
3. Confirm the server is online and accessible.
4. Run with `--debug` for detailed connection information.

### Deployment Failures

If deployment fails:
1. Check logs for specific errors (`Logs & Monitoring > View Deployment Logs`).
2. Verify Docker is running on the remote server.
3. Ensure required ports are not in use by other applications.
4. Try `--rebuild --force` to force a clean rebuild.

### Database Problems

For database issues related to your project's components:
1. Use the "Database Tools > Check Database Health" menu.
2. Consider running a database backup before attempting fixes.
3. Check logs for specific error messages.
4. Try "Database Tools > Rebuild Schema" (if applicable) for persistent issues.

## Best Practices

1. **Regular Backups**: Create database backups before major changes.
2. **Version Control**: Keep your local repository updated.
3. **Testing**: Run tests after configuration changes.
4. **Environment Files**: Secure your `.env` files as they contain sensitive information for your project's components.
5. **Auto-Start Config**: Regularly review auto-start configurations for security.
6. **Feedback Logs**: Check feedback logs after unattended deployments.
7. **Project Config per Project**: Maintain a separate, accurate `.project_config.sh` in the root of each project you manage with the toolkit.

## Getting Feedback

The utility now provides several ways to collect and analyze system feedback for your project stack:
1. **Live Console**: Watch real-time output during deployment.
2. **Service Logs**: Monitor specific service logs for issues.
3. **Health Reports**: Generate system health reports.
4. **Deployment Summary**: View summary after deployment completes.
5. **Notification Options**: Configure email or Discord notifications.

## Support

For issues with this utility, please open an issue in the project repository or visit our support channel.

## Contribute

We welcome contributions to improve this utility! See our contributing guidelines for more information.