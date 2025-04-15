#!/usr/bin/env bash

# =======================================================
# Unified Docker Application Configuration
# =======================================================

# Prevent multiple inclusion
if [ -n "$CONFIG_LOADED" ]; then
    return 0
fi
export CONFIG_LOADED=1

# ------------------------------------------------------
# Core Configuration Loading
# ------------------------------------------------------

# The main script (SimpleDevOpsToolkit.sh) should have set SCRIPT_CALLER_DIR
PROJECT_CONFIG_PATH="${SCRIPT_CALLER_DIR}/.project_config.sh"

if [ -z "$SCRIPT_CALLER_DIR" ]; then
    echo "❌ Error: SCRIPT_CALLER_DIR is not set. This should be set by SimpleDevOpsToolkit.sh" >&2
    exit 1 # Or return 1 if sourcing allows returning
elif [ -f "$PROJECT_CONFIG_PATH" ]; then
    echo "Attempting to load project config from: $PROJECT_CONFIG_PATH"
    source "$PROJECT_CONFIG_PATH"
else
    echo "❌ Error: Project configuration file not found at expected location: $PROJECT_CONFIG_PATH" >&2
    echo "Ensure you are running SimpleDevOpsToolkit.sh from your project's root directory" >&2
    echo "and that a '.project_config.sh' file exists there." >&2
    exit 1 # Or return 1
fi

# Project source directory (where the user ran the script)
export SOURCE_DIR="$SCRIPT_CALLER_DIR"

# Determine effective project directory based on mode
# This uses variables potentially set in the project_config.sh we just sourced
if [ "$RUN_REMOTE" = false ]; then
    # In local mode, the project directory *is* the caller directory
    export EFFECTIVE_PROJECT_DIR="${SOURCE_DIR}"
    # Update LOCAL_PROJECT_DIR if it wasn't explicitly set in project_config.sh
    export LOCAL_PROJECT_DIR="${LOCAL_PROJECT_DIR:-$SOURCE_DIR}"
else
    # In remote mode, SERVER_PROJECT_DIR must be set in project_config.sh
    if [ -z "$SERVER_PROJECT_DIR" ]; then
        echo "❌ Error: SERVER_PROJECT_DIR is not defined in $PROJECT_CONFIG_PATH, which is required for remote mode." >&2
        exit 1
    fi
    export EFFECTIVE_PROJECT_DIR="${SERVER_PROJECT_DIR}"
fi

# ------------------------------------------------------
# Effective Path Configuration (Relative to EFFECTIVE_PROJECT_DIR)
# ------------------------------------------------------

# Set effective paths based on deployment mode
export EFFECTIVE_DOCKER_DIR="${EFFECTIVE_PROJECT_DIR}/docker"
export EFFECTIVE_APP_DIR="${EFFECTIVE_PROJECT_DIR}/app"
# Toolkit config/scripts paths remain relative to the toolkit's location (where config.sh is)
export TOOLKIT_CONFIG_DIR="$(dirname "$0")"
export TOOLKIT_SCRIPTS_DIR="$(dirname "$0")/../scripts" # Adjust if scripts dir is elsewhere
# Load toolkit's auto_start.conf as a base
if [ -f "${TOOLKIT_CONFIG_DIR}/auto_start.conf" ]; then
    source "${TOOLKIT_CONFIG_DIR}/auto_start.conf"
fi
# NOTE: Project-specific overrides for auto-start should be in project_config.sh

# ------------------------------------------------------
# Docker Configuration
# ------------------------------------------------------

# Container Management
export CONTAINER_NAMES="${CONTAINER_NAMES:-$PROJECT_NAME}"
export CONTAINER_LIST=(${CONTAINER_NAMES//,/ })
export MAIN_CONTAINER="${MAIN_CONTAINER:-${PROJECT_NAME}}"

# Docker Commands
export DOCKER_CMD="docker"
export DOCKER_COMPOSE_CMD="docker compose"

# Compose File Configuration
export COMPOSE_FILE="${LOCAL_PROJECT_DIR}/docker-compose.yml"
export ENV_FILE="${EFFECTIVE_DOCKER_DIR}/.env"

# Basic Docker Compose Commands
export COMPOSE_UP="${DOCKER_COMPOSE_CMD} -f ${COMPOSE_FILE} up"
export COMPOSE_DOWN="${DOCKER_COMPOSE_CMD} -f ${COMPOSE_FILE} down"
export COMPOSE_BUILD="${DOCKER_COMPOSE_CMD} -f ${COMPOSE_FILE} build"
export COMPOSE_LOGS="${DOCKER_COMPOSE_CMD} -f ${COMPOSE_FILE} logs"
export COMPOSE_PS="${DOCKER_COMPOSE_CMD} -f ${COMPOSE_FILE} ps"

# ------------------------------------------------------
# Auto-start Configuration (Defaults loaded above, project can override)
# ------------------------------------------------------

export AUTO_START="${AUTO_START:-true}"
export AUTO_START_SERVICES="${AUTO_START_SERVICES:-all}"
export AUTO_START_WAIT="${AUTO_START_WAIT:-10}"
export AUTO_BUILD_ENABLED="${AUTO_BUILD_ENABLED:-true}"
export AUTO_START_FEEDBACK="${AUTO_START_FEEDBACK:-minimal}"

# Load auto-start config if exists (This path is potentially wrong now - remove or adjust)
# if [ -f "${EFFECTIVE_CONFIG_DIR}/auto_start.conf" ]; then
#     source "${EFFECTIVE_CONFIG_DIR}/auto_start.conf"
# fi
# The sourcing from TOOLKIT_CONFIG_DIR above handles the base defaults.
# Project specific auto-start settings should be variables in project_config.sh


# ------------------------------------------------------
# Configuration Complete
# ------------------------------------------------------

echo -e "\033[0;32mConfiguration loaded successfully for project: ${PROJECT_NAME}\033[0m"
echo -e "\033[0;33mEnvironment: ${ENVIRONMENT}\033[0m"
if [ "$RUN_REMOTE" = false ]; then
    echo -e "\033[0;34mMode: Local Development (Using LOCAL_PROJECT_DIR: ${LOCAL_PROJECT_DIR})\033[0m"
    echo -e "\033[0;34mUse '--remote' flag to target the server.\033[0m"
else
    echo -e "\033[0;34mMode: Remote Server Deployment (Using SERVER_PROJECT_DIR: ${SERVER_PROJECT_DIR})\033[0m"
fi 