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
export DEFAULT_PROFILE="cpu" # Default profile if none is specified
export DIRECT_ACTION=false # Initialize DIRECT_ACTION
export BYPASS_MENU=false # NEW global flag

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
    
    # --- Check if a direct action was performed and exit --- 
    if [ "$BYPASS_MENU" = true ]; then
        exit 0 # Exit successfully after direct action
    fi
    # --------------------------------------------------------
    
    # Validate configuration (only if no direct action occurred)
    validate_config
    
    # Handle special execution modes (WATCH_CONSOLE, INIT_ONLY) 
    # These are flags that modify behaviour but might lead to the menu OR exit
    # WATCH_CONSOLE and INIT_ONLY flags are set in parse_cli_args but exit here
    if [ "${WATCH_CONSOLE:-false}" = true ]; then
        if ! type print_info > /dev/null 2>&1; then echo "Error: print_info missing" >&2; exit 1; fi
        print_info "Starting deployment with console monitoring..."
        if ! type run_deployment_with_monitoring > /dev/null 2>&1; then echo "Error: run_deployment_with_monitoring missing" >&2; exit 1; fi
        run_deployment_with_monitoring "${WATCH_SERVICES:-all}"
        exit $? # Exit after monitoring finishes
    fi
    
    if [ "${INIT_ONLY:-false}" = true ]; then
        if ! type print_info > /dev/null 2>&1; then echo "Error: print_info missing" >&2; exit 1; fi
        print_info "Running initialization only..."
        if ! type run_initial_setup > /dev/null 2>&1; then echo "Error: run_initial_setup missing" >&2; exit 1; fi
        run_initial_setup
        exit $? # Exit after init finishes
    fi
        
    # Display main menu if no exit occurred earlier
    if ! type show_main_menu > /dev/null 2>&1; then echo "Error: show_main_menu missing" >&2; exit 1; fi
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
    BYPASS_MENU=false # Reset the new flag too

    while [[ $# -gt 0 ]]; do
        case $1 in
            # >>> Updated profile handling <<< 
            --profile=*) 
                DOCKER_PROFILE="${1#*=}"
                echo "Profile specified via --profile=*: ${DOCKER_PROFILE}"
                shift # Consume argument
                ;;
            --profile) # Handle case where value is separate
                if [[ -n "$2" && ! $2 =~ ^-- ]]; then
                    DOCKER_PROFILE="$2"
                    echo "Profile specified via --profile: ${DOCKER_PROFILE}"
                    shift # Consume argument name
                    shift # Consume argument value
                else
                    echo "Error: Argument for --profile is missing" >&2
                    exit 1
                fi
                ;;

            # Development hot-reload options (Generic)
            --hot-reload=*) 
                local target="${1#*=}"
                if [[ " ${HOT_RELOAD_TARGETS} " =~ " ${target} " ]]; then
                    RUN_REMOTE=true
                    print_info "Initiating hot-reload for target: ${target}..."
                    run_hot_reload "${target}"
                    BYPASS_MENU=true; return 0 # Set flag and return from function
                else
                    print_error "Invalid hot-reload target: '${target}'."
                    print_info "Valid targets are: ${HOT_RELOAD_TARGETS}"
                    exit 1 # Error exit is okay here
                fi
                ;;
            --hot-reload-all)
                RUN_REMOTE=true
                print_info "Initiating hot-reload for all targets: ${HOT_RELOAD_TARGETS}..."
                for target in ${HOT_RELOAD_TARGETS}; do
                    run_hot_reload "${target}"
                done
                BYPASS_MENU=true; return 0 # Set flag and return
                ;;

            # Direct Log Viewing
            --logs=*)
                DIRECT_ACTION=true # Mark that a direct action is happening
                VIEW_LOGS_TARGET="${1#*=}"
                shift # <<< ADDED TO CONSUME ARGUMENT
                ;;
            --lines=*)
                VIEW_LOGS_LINES="${1#*=}"
                shift # <<< ADDED TO CONSUME ARGUMENT
                ;;
            --follow)
                VIEW_LOGS_FOLLOW=true
                shift # <<< ADDED TO CONSUME ARGUMENT
                ;;

            # Existing options...
            --local)
                export RUN_REMOTE=true # Note: RUN_REMOTE was set to true before, should be false for local?
                echo "Running in local mode with project directory: $LOCAL_PROJECT_DIR"
                shift; continue # Consume arg and continue loop
                ;;
            --init-only)
                INIT_ONLY=true 
                DIRECT_ACTION=true # Keep this for potential future use? Or remove?
                shift; continue
                ;;
            --skip-confirmation)
                SKIP_CONFIRMATION=true
                shift; continue
                ;;
            --remove-volumes)
                REMOVE_VOLUMES=true
                shift; continue
                ;;
            --env-file=*) 
                ENV_FILE="${1#*=}"
                [ -f "$ENV_FILE" ] && source_env_file "$ENV_FILE"
                shift; continue 
                ;;
            
            # Deployment modes that should exit directly -> Now set flag and return
            --quick-deploy)
                DIRECT_ACTION=true; run_quick_deploy; BYPASS_MENU=true; return 0
                ;;
            --quick-deploy-attach)
                DIRECT_ACTION=true; run_quick_deploy_attach; BYPASS_MENU=true; return 0
                ;;
            --partial-deploy)
                DIRECT_ACTION=true; run_partial_deploy; BYPASS_MENU=true; return 0
                ;;
            --deploy-with-auto-start)
                DIRECT_ACTION=true; run_quick_deploy_with_auto_start; BYPASS_MENU=true; return 0
                ;;
            --full-reset)
                DIRECT_ACTION=true
                if [ "$SKIP_CONFIRMATION" != "true" ]; then
                    print_error "⚠️ WARNING: This will COMPLETELY ERASE your database!"
                    if ! get_confirmed_input "Are you ABSOLUTELY sure?" "DELETE"; then
                        print_info "Cancelled."
                        exit 1 # Exit on cancel
                    fi
                fi
                run_full_reset_deploy
                BYPASS_MENU=true; return 0
                ;;
            --deploy-with-monitoring)
                DIRECT_ACTION=true
                run_deployment_with_monitoring "all"
                BYPASS_MENU=true; return 0
                ;;
            --watch-console)
                WATCH_CONSOLE=true 
                DIRECT_ACTION=true
                shift; continue
                ;;
            --watch=*)
                WATCH_SERVICES="${1#*=}"; WATCH_CONSOLE=true 
                DIRECT_ACTION=true
                shift; continue
                ;;

            # --- ADD NEW SAFE DOWN FLAG ---    
            --safe-down-volumes)
                DIRECT_ACTION=true
                print_warning "Stopping containers and removing volumes (docker compose down -v)..."
                run_compose_down -v 
                BYPASS_MENU=true; return 0
                ;;

            # Testing flags that should exit directly -> Now set flag and return
            --test-ALL)
                DIRECT_ACTION=true; run_tests_with_docker_container "all"; BYPASS_MENU=true; return 0
                ;;
            --test-unit)
                DIRECT_ACTION=true; run_unit_tests; BYPASS_MENU=true; return 0
                ;;
            --test-integration)
                DIRECT_ACTION=true; run_integration_tests; BYPASS_MENU=true; return 0
                ;;
            --test-system)
                DIRECT_ACTION=true; run_system_tests; BYPASS_MENU=true; return 0
                ;;
            --test-ordered)
                DIRECT_ACTION=true; run_ordered_tests; BYPASS_MENU=true; return 0
                ;;
            --test-simple)
                DIRECT_ACTION=true; run_simple_test; BYPASS_MENU=true; return 0 
                ;;
            --test-dashboard)
                DIRECT_ACTION=true; run_dashboard_tests; BYPASS_MENU=true; return 0
                ;;
            --sequential-tests)
                DIRECT_ACTION=true; run_sequential_tests; BYPASS_MENU=true; return 0
                ;;
            --sync-results)
                DIRECT_ACTION=true; sync_test_results; BYPASS_MENU=true; return 0
                ;;

            # Unknown argument
            *)
                # Avoid erroring out if it's just the --local flag which is handled elsewhere?
                # No, unknown flags should cause an error or be ignored after shifting.
                echo "⚠️ Unknown argument: $1" >&2
                # exit 1 # Optional: exit on unknown flag
                shift # Consume unknown argument
                ;;
        esac
        # shift # Removed from here - shifting is handled within cases or specifically below
    done

    # === Set and validate profile AFTER loop ===
    # Set default profile if none was provided
    if [ -z "$DOCKER_PROFILE" ]; then
        echo "No profile specified, using default: $DEFAULT_PROFILE"
        DOCKER_PROFILE="$DEFAULT_PROFILE"
    fi

    # Validate profile
    case "$DOCKER_PROFILE" in
        cpu|gpu-nvidia|gpu-amd)
            # Valid profile
            ;;
        *)
            echo "Error: Invalid profile specified: '$DOCKER_PROFILE'. Valid profiles: cpu, gpu-nvidia, gpu-amd" >&2
            exit 1
            ;;
    esac

    # Echo the final profile being used
    echo "Running with Docker profile: ${DOCKER_PROFILE}"

    # === Handle Direct Log View Action After Loop ===
    if [ -n "$VIEW_LOGS_TARGET" ]; then
        # Ensure log_functions.sh is sourced if parse_cli_args is called before source lines in main
        if ! type run_direct_log_view > /dev/null 2>&1;
            then print_error "Log function 'run_direct_log_view' not found. Ensure log_functions.sh is sourced."; exit 1;
        fi
        run_direct_log_view "$VIEW_LOGS_TARGET" "$VIEW_LOGS_LINES" "$VIEW_LOGS_FOLLOW"
        BYPASS_MENU=true; return 0 # Set flag and return after viewing logs
    fi

    # If we reach here, no direct action caused an exit or return during the loop or log check
    # Return 1 indicates no direct action was performed that should cause an exit in main
    return 1 
}

# Run the main function with all command line arguments
main "$@"
