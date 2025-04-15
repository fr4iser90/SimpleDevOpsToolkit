#!/usr/bin/env bash

# =======================================================
# Application Center - Central Management Interface
# =======================================================

# Store the original directory where the script was called from
export SCRIPT_CALLER_DIR=$(pwd)

# --- Robust way to find the script's real directory --- 
SOURCE=${BASH_SOURCE[0]}
while [ -L "$SOURCE" ]; do # Resolve $SOURCE until the file is no longer a symlink
  DIR=$( cd -P "$( dirname "$SOURCE" )" &> /dev/null && pwd )
  SOURCE=$(readlink "$SOURCE")
  [[ $SOURCE != /* ]] && SOURCE=$DIR/$SOURCE # If readlink -f doesn't exist, resolve relative symlink
done
SCRIPT_DIR=$( cd -P "$( dirname "$SOURCE" )" &> /dev/null && pwd )
# --- End of script directory finding ---

# NO automatic cd here anymore - sourcing uses absolute paths based on SCRIPT_DIR
# cd "$SCRIPT_DIR" || exit 1 

# Apply permissions to all scripts first (using absolute paths)
echo "Setting executable permissions for all utility scripts..."
find "$SCRIPT_DIR" -maxdepth 2 -path '*/functions/*.sh' -exec chmod +x {} \;
find "$SCRIPT_DIR" -maxdepth 2 -path '*/lib/*.sh' -exec chmod +x {} \;
find "$SCRIPT_DIR" -maxdepth 2 -path '*/menus/*.sh' -exec chmod +x {} \;
find "$SCRIPT_DIR" -maxdepth 2 -path '*/ui/*.sh' -exec chmod +x {} \;
# Keep Python permission setting if needed
# find utils -name "*.py" -type f -exec chmod +x {} \;
echo "Permissions set successfully."

# Ensure project_config.sh exists *in the caller's directory* before running.
# This check is now effectively handled within config.sh, removing the old check.
# if [ ! -f "./utils/config/project_config.sh" ]; then
#     echo "❌ Error: Project configuration file ./utils/config/project_config.sh not found!"
#     echo "Please create this file (e.g., by copying from another project or manually) before running the Application Center."
#     exit 1
# fi

# Check for Docker .env file and load if it exists from the *caller's* directory
if [ -f "${SCRIPT_CALLER_DIR}/.env" ]; then
    echo "Loading environment variables from ${SCRIPT_CALLER_DIR}/.env..."
    set -a
    # Source using the full path
    source <(grep -vE '^\s*(#|$)' "${SCRIPT_CALLER_DIR}/.env")
    set +a
elif [ -f "${SCRIPT_CALLER_DIR}/docker/.env" ]; then
    echo "Loading environment variables from ${SCRIPT_CALLER_DIR}/docker/.env..."
    set -a
    # Source using the full path
    source <(grep -vE '^\s*(#|$)' "${SCRIPT_CALLER_DIR}/docker/.env")
    set +a
fi

# Global Variables
export RUN_REMOTE=false
export AUTO_START=true
export AUTO_BUILD=true
export REMOVE_VOLUMES=false
export SKIP_CONFIRMATION=false
export DIRECT_DEPLOY=false
export DOCKER_PROFILE="" # Initialize Docker profile variable
export DIRECT_ACTION=false # Initialize DIRECT_ACTION

# Parse command line arguments for local mode
for arg in "$@"; do
    case $arg in
        --remote)
            export RUN_REMOTE=true
            echo "Running in remote mode with server: $SERVER_HOST"
            shift
            ;;
    esac
done

# Source common utilities and configuration *using absolute paths*
source "$SCRIPT_DIR/config/config.sh"
source "$SCRIPT_DIR/lib/common.sh"

# Source UI modules *using absolute paths*
source "$SCRIPT_DIR/ui/display_functions.sh"
source "$SCRIPT_DIR/ui/input_functions.sh"

# Source function modules *using absolute paths*
source "$SCRIPT_DIR/functions/deployment_functions.sh"
source "$SCRIPT_DIR/functions/container_functions.sh"
source "$SCRIPT_DIR/functions/database_functions.sh"
source "$SCRIPT_DIR/functions/testing_functions.sh"
source "$SCRIPT_DIR/functions/development_functions.sh"
source "$SCRIPT_DIR/functions/log_functions.sh"

# Source menu modules *using absolute paths*
source "$SCRIPT_DIR/menus/main_menu.sh"
source "$SCRIPT_DIR/menus/deployment_menu.sh"
source "$SCRIPT_DIR/menus/container_menu.sh"
source "$SCRIPT_DIR/menus/database_menu.sh"
source "$SCRIPT_DIR/menus/testing_menu.sh"
source "$SCRIPT_DIR/menus/development_menu.sh"
source "$SCRIPT_DIR/menus/logs_menu.sh"
source "$SCRIPT_DIR/menus/env_files_menu.sh"
source "$SCRIPT_DIR/menus/auto_start_menu.sh"
source "$SCRIPT_DIR/menus/watch_menu.sh"

# ------------------------------------------------------
# Main function
# ------------------------------------------------------
main() {
    # Parse command line arguments first to potentially set RUN_REMOTE etc.
    parse_cli_args "$@"
    
    # Validate configuration (which is now loaded via config.sh -> project_config.sh)
    validate_config
    
    # Handle direct deployment options first (bypass menus)
    # If parse_cli_args handled a direct action and exited, this won't be reached.
    # This check might need refinement depending on how DIRECT_DEPLOY is set/used.
    # if [ "$DIRECT_DEPLOY" = true ]; then
    #     exit $?
    # fi
    
    # Handle special execution modes (WATCH_CONSOLE, INIT_ONLY)
    # These also might need to exit directly from parse_cli_args if passed as flags
    if [ "${WATCH_CONSOLE:-false}" = true ]; then
        print_info "Starting deployment with console monitoring..."
        run_deployment_with_monitoring "${WATCH_SERVICES:-all}"
        exit $?
    fi
    
    if [ "${INIT_ONLY:-false}" = true ]; then
        print_info "Running initialization only..."
        run_initial_setup
        exit $?
    fi
        
    # Display main menu if no direct action caused an exit earlier
    show_main_menu
}

# Parse command line arguments
parse_cli_args() {
    # Initialize variables for direct log viewing
    local VIEW_LOGS_TARGET=""
    local VIEW_LOGS_LINES="50" # Default lines
    local VIEW_LOGS_FOLLOW=false
    # Reset DIRECT_ACTION at the start of parsing
    DIRECT_ACTION=false 

    while [[ $# -gt 0 ]]; do
        case $1 in
            # >>> Add profile handling here <<<
            --profile=*) 
                DOCKER_PROFILE="${1#*=}"
                # Validate profile maybe? (cpu, gpu-nvidia, gpu-amd)
                # TODO: Add validation if needed
                echo "Using Docker profile: ${DOCKER_PROFILE}"
                ;;

            # Development hot-reload options (Generic)
            --hot-reload=*) 
                local target="${1#*=}"
                # Check if target is valid (from HOT_RELOAD_TARGETS in config)
                if [[ " ${HOT_RELOAD_TARGETS} " =~ " ${target} " ]]; then
                    RUN_REMOTE=true # Hot-reload only makes sense locally
                    print_info "Initiating hot-reload for target: ${target}..."
                    run_hot_reload "${target}" # Assumes this function exists in development_functions.sh
                    exit $?
                else
                    print_error "Invalid hot-reload target: '${target}'."
                    print_info "Valid targets are: ${HOT_RELOAD_TARGETS}"
                    exit 1
                fi
                ;;
            --hot-reload-all)
                RUN_REMOTE=true # Hot-reload only makes sense locally
                print_info "Initiating hot-reload for all targets: ${HOT_RELOAD_TARGETS}..."
                for target in ${HOT_RELOAD_TARGETS}; do
                    run_hot_reload "${target}" # Assumes this function exists
                done
                exit $?
                ;;

            # Direct Log Viewing
            --logs=*)
                DIRECT_ACTION=true # Mark that a direct action is happening
                VIEW_LOGS_TARGET="${1#*=}"
                ;;
            --lines=*)
                VIEW_LOGS_LINES="${1#*=}"
                ;;
            --follow)
                VIEW_LOGS_FOLLOW=true
                ;;

            # Existing options...
            --local) # Ensure --local is handled *after* --profile and hot-reload
                export RUN_REMOTE=true
                echo "Running in local mode with project directory: $LOCAL_PROJECT_DIR"
                ;;
            --init-only)
                INIT_ONLY=true # Flag for main loop
                DIRECT_ACTION=true
                ;;
            --skip-confirmation)
                SKIP_CONFIRMATION=true
                ;;
            --remove-volumes)
                REMOVE_VOLUMES=true
                ;;
            --env-file=*) 
                ENV_FILE="${1#*=}"
                [ -f "$ENV_FILE" ] && source_env_file "$ENV_FILE"
                ;;
            
            # Deployment modes that should exit directly
            --quick-deploy)
                DIRECT_ACTION=true; run_quick_deploy; exit $?
                ;;
            --quick-deploy-attach)
                DIRECT_ACTION=true; run_quick_deploy_attach; exit $?
                ;;
            --partial-deploy)
                DIRECT_ACTION=true; run_partial_deploy; exit $?
                ;;
            --deploy-with-auto-start)
                DIRECT_ACTION=true; run_quick_deploy_with_auto_start; exit $?
                ;;
            --full-reset)
                DIRECT_ACTION=true
                if [ "$SKIP_CONFIRMATION" != "true" ]; then
                    print_error "⚠️ WARNING: This will COMPLETELY ERASE your database!"
                    if ! get_confirmed_input "Are you ABSOLUTELY sure?" "DELETE"; then
                        print_info "Cancelled."
                        exit 1
                    fi
                fi
                run_full_reset_deploy
                exit $?
                ;;
            --deploy-with-monitoring)
                DIRECT_ACTION=true
                run_deployment_with_monitoring "all"
                exit $?
                ;;
            --watch-console)
                WATCH_CONSOLE=true # Flag for main loop
                DIRECT_ACTION=true
                ;;
            --watch=*)
                WATCH_SERVICES="${1#*=}"; WATCH_CONSOLE=true # Flag for main loop
                DIRECT_ACTION=true
                ;;

            # --- ADD NEW SAFE DOWN FLAG ---    
            --safe-down-volumes)
                DIRECT_ACTION=true
                print_warning "Stopping containers and removing volumes (docker compose down -v)..."
                run_compose_down -v # Call helper with -v flag
                exit $? # Exit immediately
                ;;

            # Testing flags that should exit directly
            --test-ALL)
                DIRECT_ACTION=true; run_tests_with_docker_container "all"; exit $?
                ;;
            --test-unit)
                DIRECT_ACTION=true; run_unit_tests; exit $?
                ;;
            --test-integration)
                DIRECT_ACTION=true; run_integration_tests; exit $?
                ;;
            --test-system)
                DIRECT_ACTION=true; run_system_tests; exit $?
                ;;
            --test-ordered)
                DIRECT_ACTION=true; run_ordered_tests; exit $?
                ;;
            --test-simple)
                DIRECT_ACTION=true; run_simple_test; exit $? # run_simple_test already exits with 0 on success
                ;;
            --test-dashboard)
                DIRECT_ACTION=true; run_dashboard_tests; exit $?
                ;;
            --sequential-tests)
                DIRECT_ACTION=true; run_sequential_tests; exit $?
                ;;
            --sync-results)
                DIRECT_ACTION=true; sync_test_results; exit $?
                ;;

            # Unknown argument
            *)
                # Avoid erroring out if it's just the --local flag which is handled elsewhere
                if [ "$1" != "--local" ]; then 
                    echo "⚠️ Unknown argument: $1"
                fi
                ;;
        esac
        shift
    done

    # === Handle Direct Log View Action After Loop ===
    # Check if --logs was specified (and no other direct action already exited)
    if [ -n "$VIEW_LOGS_TARGET" ]; then
        # Ensure log_functions.sh is sourced if parse_cli_args is called before source lines in main
        if ! type run_direct_log_view > /dev/null 2>&1;
            then print_error "Log function 'run_direct_log_view' not found. Ensure log_functions.sh is sourced."; exit 1;
        fi
        run_direct_log_view "$VIEW_LOGS_TARGET" "$VIEW_LOGS_LINES" "$VIEW_LOGS_FOLLOW"
        exit $? # Exit after viewing logs
    fi

    # If we reach here, no direct action caused an exit during the loop or log check
}

# Run the main function with all command line arguments
main "$@"
