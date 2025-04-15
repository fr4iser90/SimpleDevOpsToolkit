#!/usr/bin/env bash
# DAS IST hier nur ein Beispiel, das nicht mehr verwendet wird. DIESE DATEI LIEGT REAL IN Git/FoundryCord/.project_config.sh
# Server Configuration
export SERVER_USER="docker"
export SERVER_HOST="192.168.178.33"
export SERVER_PORT="22"
export SERVER_KEY="$HOME/.ssh/id_rsa"

# Project Configuration
export PROJECT_NAME="FoundryCord"
export ENVIRONMENT="development"

# Remote Server Paths
export SERVER_ROOT="/home/docker/docker"
export SERVER_PROJECT_DIR="${SERVER_ROOT}/companion-management/FoundryCord"

# Local Development Configuration
export LOCAL_GIT_DIR="$HOME/Documents/Git/${PROJECT_NAME}"

export LOCAL_DEV_ROOT="$HOME/Documents/Development"
export LOCAL_PROJECT_DIR="${LOCAL_DEV_ROOT}/FoundryCord"
export LOCAL_DOCKER_DIR="${LOCAL_PROJECT_DIR}/docker"
export LOCAL_APP_DIR="${LOCAL_PROJECT_DIR}/app"

# Database Configuration (Anpassen für FoundryCord falls nötig, sonst entfernen?)
# export DB_NAME="${PROJECT_NAME}_db" # Beispiel, anpassen!
# export DB_CONTAINER_NAME="${PROJECT_NAME}-db" # Beispiel, anpassen!
export DB_NAME="foundrycord_db"

# Hot Reload Targets
export HOT_RELOAD_TARGETS="bot shared web tests"
