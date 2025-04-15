# SimpleDevOpsToolkit - Utility Suite

**GitHub Repository:** [https://github.com/fr4iser90/SimpleDevOpsToolkit](https://github.com/fr4iser90/SimpleDevOpsToolkit)

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
- A `.project_config.sh` file in the **root directory** of **each project** you want to manage. See the [Configuration Files](#configuration-files) section and the example file `examples/.project_config.sh`.

### Initial Setup

1.  **Clone the Toolkit Repository:**
    ```bash
    git clone <repository_url> /path/to/SimpleDevOpsToolkit
    cd /path/to/SimpleDevOpsToolkit
    ```
    Replace `<repository_url>` with the actual URL of the toolkit's repository. Choose a suitable location like `~/tools/` or `~/bin/`.

2.  **Prepare Your Project:**
    *   Ensure each project you want to manage (e.g., `~/Documents/Git/FoundryCord`) has a `.project_config.sh` file in its **root directory**. 
    *   Copy or adapt the example configuration from `examples/.project_config.sh` within this repository.
    *   Make sure to set essential variables like `PROJECT_NAME`, `SERVER_HOST`, `SERVER_USER`, `SERVER_PROJECT_DIR`, `LOCAL_PROJECT_DIR`, etc., according to your project's needs.
    *   Example location: `~/Documents/Git/FoundryCord/.project_config.sh`

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

**Option 3: NixOS / Home Manager Installation**

If you are using NixOS or Home Manager, you should manage your PATH and installed tools declaratively through your Nix configuration instead of creating manual symlinks and exporting PATH variables in `.zshrc`.

*(See also the example NixOS module `devopstoolkit.nix` in the repository root, although the Home Manager approach below is generally preferred for user tools.)*

1.  **Ensure `$HOME/.local/bin` is managed by Nix (Optional but Recommended):**
    While Home Manager might add `$HOME/.local/bin` to your PATH by default depending on your setup, it's cleaner to let Nix manage the symlink location as well. A common pattern is to have Nix manage links in a dedicated profile directory that *is* added to your path.

2.  **Create the Symlink Declaratively (Example using Home Manager):**
    You need to add an entry to your `home.nix` (or equivalent Home Manager configuration file) to create the symlink. The exact path to your cloned `SimpleDevOpsToolkit.sh` script is needed here. Replace `/path/to/your/SimpleDevOpsToolkit` with the actual absolute path where you cloned the repository.

    ```nix
    { config, pkgs, ... }:

    let
      # Define the absolute path to the toolkit script
      simpleDevOpsToolkitScript = "/path/to/your/SimpleDevOpsToolkit/SimpleDevOpsToolkit.sh";
    in
    {
      # ... your other home-manager configuration ...

      # Ensure the target directory for the link exists and is in PATH
      # Home Manager usually puts packages in ~/.nix-profile/bin which is in PATH
      # Or you might manage ~/.local/bin via home.file as well.
      # Let's assume you want the link in ~/.local/bin managed by home-manager:
      xdg.enable = true; # Needed for xdg.dataFile
      home.file.".local/bin/SimpleDevOpsToolkit" = {
        source = simpleDevOpsToolkitScript;
        executable = true; # Make the link itself executable
      };

      # Alternative: Link into nix profile bin (often preferred)
      # home.file.".nix-profile/bin/SimpleDevOpsToolkit" = {
      #   source = simpleDevOpsToolkitScript;
      #   executable = true;
      # };

      # Make sure the *source script* itself has execute permissions.
      # You might need to run `chmod +x /path/to/your/SimpleDevOpsToolkit/SimpleDevOpsToolkit.sh` 
      # after cloning if git doesn't preserve permissions, or find a Nix-native way.

      # Ensure the PATH includes the directory where the link is created
      # (e.g., ~/.local/bin). Home Manager often handles this automatically
      # for ~/.nix-profile/bin. If linking to ~/.local/bin, ensure it's added:
      home.sessionPath = [
        "$HOME/.local/bin" # Add this line if linking to .local/bin
      ];

      # ... rest of your configuration ...
    }
    ```
    **Note:** This is a conceptual example. The exact implementation (`home.file`, `home.sessionPath`, handling executability) might differ based on your specific Home Manager setup and preferences. Consult the Home Manager documentation.

3.  **Apply the Configuration:**
    After editing your Nix configuration, apply the changes by running:
    ```bash
    home-manager switch
    ```
    Or, if managing system-wide with NixOS:
    ```bash
    sudo nixos-rebuild switch
    ```

This approach ensures that the `SimpleDevOpsToolkit` command is correctly integrated into your Nix-managed environment.

## Basic Usage

Once set up (either via PATH or by calling the full script path), navigate to your project's root directory (where your `.project_config.sh` resides) and run the toolkit:

```bash
# If installed to PATH
cd /path/to/your/project
SimpleDevOpsToolkit

# Or using the full path
cd /path/to/your/project
/path/to/cloned/SimpleDevOpsToolkit/SimpleDevOpsToolkit.sh
```

The interactive menu will guide you through the available options. You can also use command-line flags for direct actions.

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
- **`.project_config.sh`**: **REQUIRED**. Must exist in the **root directory of the project** you are currently managing. Defines all project-specific settings. 
    *   **Key Variables:** `PROJECT_NAME`, `SERVER_HOST`, `SERVER_USER`, `SERVER_PROJECT_DIR` (for remote), `LOCAL_PROJECT_DIR` (for local/hot-reload), `CONTAINER_NAMES`, `DB_NAME`, `HOT_RELOAD_TARGETS` (optional), etc.
    *   See the example: `examples/.project_config.sh`
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
# Example using the global command (remote deploy with specific profile)
SimpleDevOpsToolkit --remote --profile=gpu-nvidia --quick-deploy

# Example for viewing logs directly
SimpleDevOpsToolkit --logs=your_service_name --lines=100

# Example for running tests directly
SimpleDevOpsToolkit --test-simple

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

## About

 Simple local / remote deployment toolkit for Docker-based projects.

**Repository:** [https://github.com/fr4iser90/SimpleDevOpsToolkit](https://github.com/fr4iser90/SimpleDevOpsToolkit)

### Resources