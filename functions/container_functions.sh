#!/usr/bin/env bash

# =======================================================
# Container Functions
# =======================================================

# Global variable for container list
declare -a CONTAINER_ACTIONS

# Load available containers from config or docker-compose
load_available_containers() {
    # TODO: This function needs to be profile-aware
    # It currently gets ALL services from compose config, not just the active profile ones
    # Or falls back to CONTAINER_LIST which is also not profile-aware
    # For now, keep existing logic but add a warning
    print_warning "Container list loading might not be profile-aware yet."

    if [ "$RUN_REMOTE" = false ]; then
        # Use CONTAINER_LIST derived from CONTAINER_NAMES in config
        print_info "Loading containers from local config CONTAINER_LIST: ${CONTAINER_LIST[@]}"
        CONTAINER_ACTIONS=("${CONTAINER_LIST[@]}") # Use the array directly
    else
        # Attempt to get container names from docker compose config services for the CURRENT profile
        local compose_cmd=$(get_docker_compose_cmd) # Get base command with profile
        local services_cmd="${compose_cmd} config --services"
        print_info "Attempting to get services from remote Docker Compose config for current profile..."

        local containers=$(run_remote_command "cd ${EFFECTIVE_DOCKER_DIR} && ${services_cmd}" "silent")
        
        if [ -z "$containers" ]; then
            # Fallback to using CONTAINER_LIST from config if remote command fails
             print_warning "Failed to get services from remote docker-compose, using CONTAINER_NAMES from config: ${CONTAINER_LIST[@]}"
            CONTAINER_ACTIONS=("${CONTAINER_LIST[@]}")
        else
            # Convert string to array
            IFS=$'\n' read -r -d '' -a CONTAINER_ACTIONS <<< "$containers"
            print_info "Loaded active services for profile '${DOCKER_PROFILE:-default}': ${CONTAINER_ACTIONS[@]}"
        fi
    fi
}

# Show container status
show_container_status() {
    show_header
    print_section_header "Container Status (Profile: ${DOCKER_PROFILE:-default})"
    
    # Use helper function
    run_compose_ps
    
    press_enter_to_continue
    show_container_menu
}

# Manage all containers (respecting profile)
manage_all_containers() {
    local action="$1"
    show_header
    print_section_header "Managing all containers (Profile: ${DOCKER_PROFILE:-default})"
    
    case "$action" in
        "start")
            print_info "Starting all containers for the current profile..."
            run_compose_up -d # Use helper
            ;;
        "stop")
            print_info "Stopping all containers for the current profile..."
            run_compose_stop # Use helper
            ;;
        "restart")
            print_info "Restarting all containers for the current profile..."
            run_compose_restart # Use helper
            ;;
        *)
             print_error "Unknown action: $action"
             return 1
             ;;
    esac
    
    if [ $? -eq 0 ]; then
        print_success "Action '$action' completed for profile '${DOCKER_PROFILE:-default}'"
    else
         print_error "Action '$action' failed for profile '${DOCKER_PROFILE:-default}'"
         return 1
    fi
    
    press_enter_to_continue
    show_container_menu
}

# Container action for individual container
# NOTE: Individual actions might not work correctly with profiles if the container name
# doesn't match the service name exactly (e.g. due to profile suffix).
# Consider using 'manage_all_containers' or direct 'docker' commands for specifics.
container_action() {
    local container_service_name="$1" # This should be the SERVICE name from compose
    local action="$2"
    
    print_warning "Running action '$action' on individual service '$container_service_name'. This might ignore profile settings if container names differ."
    print_info "Performing '$action' on $container_service_name..."
    
    case "$action" in
        "start")
            # Use helper function, passing the service name
            run_compose_up -d "${container_service_name}"
            ;;
        "stop")
            run_compose_stop "${container_service_name}"
            ;;
        "restart")
            run_compose_restart "${container_service_name}"
            ;;
        *)
             print_error "Unknown action: $action"
             return 1
             ;;
    esac
    
    if [ $? -eq 0 ]; then
        print_success "Action completed for ${container_service_name}"
    else
         print_error "Action failed for ${container_service_name}"
         return 1
    fi
}

# View container logs (uses helper)
view_container_logs() {
    local container_service_name="$1"
    print_info "Viewing logs for service: ${container_service_name} (Profile: ${DOCKER_PROFILE:-default})"
    # Use logs helper, pass arguments like --tail and -f
    run_compose_logs --tail=100 -f "${container_service_name}"
}

# Rebuild single container (service)
# Similar caveats to container_action regarding profiles
rebuild_single_container() {
    local container_service_name="$1"
    
    print_warning "Rebuilding individual service '$container_service_name'. This might ignore profile settings if container names differ."
    print_info "Rebuilding ${container_service_name}..."
    
    local no_cache_flag=""
    if get_yes_no "Do you want to rebuild with no cache?"; then
        no_cache_flag="--no-cache"
    fi
    
    # Use helpers: stop, build, up
    print_info "Stopping ${container_service_name}..."
    run_compose_stop "${container_service_name}"
    print_info "Building ${container_service_name}..."
    run_compose_build ${no_cache_flag} "${container_service_name}"
    print_info "Starting ${container_service_name}..."
    run_compose_up -d "${container_service_name}"

    if [ $? -eq 0 ]; then
        print_success "${container_service_name} rebuilt and started successfully"
    else
        print_error "Failed to rebuild ${container_service_name}"
        return 1
    fi
    return 0
}

# Execute command in container (uses helper)
execute_in_container() {
    local container_service_name="$1"
    local command_to_run
    
    read -p "Enter command to execute in ${container_service_name}: " command_to_run
    print_info "Executing in ${container_service_name}: ${command_to_run}"
    
    # Use exec helper
    run_compose_exec "${container_service_name}" ${command_to_run}
    # Note: Return code handling might be tricky with interactive exec
    # return $?
}

# Rebuild all containers (respecting profile)
rebuild_containers() {
    show_header
    print_section_header "Container Rebuild (Profile: ${DOCKER_PROFILE:-default})"
    
    print_info "This will rebuild applicable Docker images for project: ${PROJECT_NAME} and the current profile."
    
    if [ "$RUN_REMOTE" = false ]; then
        # Handle local rebuild if needed
        print_info "Performing local rebuild..."
        run_compose_build --no-cache # Use helper
        if [ $? -ne 0 ]; then print_error "Local build failed."; return 1; fi
        print_info "Restarting local containers..."
        run_compose_stop && run_compose_up -d # Use helpers
        if [ $? -ne 0 ]; then print_error "Local restart failed."; return 1; fi
        print_success "Local rebuild completed."
        press_enter_to_continue
        show_container_menu
        return 0
    fi
    
    # Remote Rebuild Logic (Full Reset is in deployment_functions)
    # This function should probably just rebuild images and restart, not down/delete data
    print_warning "This rebuild function focuses on rebuilding images safely (no data loss)."
    print_warning "For a full reset with data deletion, use the Deployment Menu -> Full Reset option."

    local skip_confirmations=false # Simplified confirmation for safe rebuild
    if get_yes_no "Proceed with safe rebuild (stop -> build --no-cache -> up)?"; then
        print_info "Performing rebuild WITHOUT data deletion..."
        run_compose_stop && run_compose_build --no-cache && run_compose_up -d
        if [ $? -eq 0 ]; then
            print_success "Rebuild completed successfully!"
        else
            print_error "Rebuild failed."
            return 1
        fi
    else
        print_info "Rebuild cancelled."
        return 0
    fi

    press_enter_to_continue
    show_container_menu
}

# Start all containers (uses helper)
start_all_containers() {
    print_section_header "Starting All Project Containers (Profile: ${DOCKER_PROFILE:-default})"
    
    run_compose_up -d # Use helper
    
    if [ $? -eq 0 ]; then
        print_success "All containers started successfully!"
    else
        print_error "Failed to start containers"
        return 1
    fi
    return 0
} 