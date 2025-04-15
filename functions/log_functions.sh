#!/usr/bin/env bash

# =======================================================
# Log Functions
# =======================================================

# View logs for a specific container
view_container_logs_generic() {
    local container_name="$1"
    local log_type_name="${2:-$container_name}" # Optional friendly name for header

    clear
    print_section_header "${log_type_name} Logs"
    
    if [ "$RUN_REMOTE" = false ]; then
        print_error "Cannot view logs in local mode"
    else
        # Check if the container exists
        if ! run_remote_command "${DOCKER_CMD} ps -a --filter name=^/${container_name}$ --format '{{.Names}}' | grep -q ${container_name}" "silent"; then
            print_error "Container '${container_name}' not found."
            press_enter_to_continue
            show_logs_menu
            return
        fi

        local lines=$(get_string_input "Number of log lines to show" "100")
        local follow=false
        
        if get_yes_no "Follow logs in real time (Ctrl+C to exit)?"; then
            follow=true
        fi
        
        if [ "$follow" = true ]; then
            print_info "Viewing ${log_type_name} logs (Press Ctrl+C to exit)..."
            run_remote_command "${DOCKER_CMD} logs --tail=${lines} -f ${container_name}"
        else
            print_info "Viewing last ${lines} lines of ${log_type_name} logs..."
            run_remote_command "${DOCKER_CMD} logs --tail=${lines} ${container_name}"
        fi
    fi
    
    press_enter_to_continue
    show_logs_menu
}

# --- Specific log view functions now call the generic one --- 

# View logs for the main container (defined in config)
view_main_container_logs() {
    view_container_logs_generic "${MAIN_CONTAINER}" "Main Container (${MAIN_CONTAINER})"
}

# View database logs (using DB_CONTAINER_NAME from config)
view_db_logs() {
    view_container_logs_generic "${DB_CONTAINER_NAME}" "Database (${DB_CONTAINER_NAME})"
}

# View logs for an arbitrary container from the list
# This requires the logs menu to pass the container name
view_specific_container_logs() {
    local container_to_view="$1"
    if [ -z "$container_to_view" ]; then
        print_error "No container name provided to view_specific_container_logs"
        return
    fi
    view_container_logs_generic "${container_to_view}" "Container (${container_to_view})"
}

# View system logs
view_system_logs() {
    clear
    print_section_header "System Logs"
    
    if [ "$RUN_REMOTE" = false ]; then
        print_error "Cannot view system logs in local mode"
    else
        print_info "Viewing system journal logs (last 100 lines)..."
        run_remote_command "sudo journalctl -n 100 --no-pager"
    fi
    
    press_enter_to_continue
    show_logs_menu
}

# View Docker logs
view_docker_logs() {
    clear
    print_section_header "Docker Logs"
    
    if [ "$RUN_REMOTE" = false ]; then
        print_error "Cannot view Docker daemon logs in local mode"
    else
        print_info "Viewing Docker daemon logs (last 100 lines)..."
        run_remote_command "sudo journalctl -u docker -n 100 --no-pager"
    fi
    
    press_enter_to_continue
    show_logs_menu
}

# Download logs - Generic implementation
download_logs() {
    clear
    print_section_header "Download All Container Logs"
    
    if [ "$RUN_REMOTE" = false ]; then
        print_error "Cannot download logs in local mode"
        press_enter_to_continue
        show_logs_menu
        return
    fi
    
    # Create local logs directory if it doesn't exist
    mkdir -p "./logs"
    
    # Get timestamp for unique filenames
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    
    print_info "Downloading logs for all containers defined in config (${CONTAINER_LIST[@]})..."
    
    local remote_temp_dir="/tmp/${PROJECT_NAME}_logs_${timestamp}"
    run_remote_command "mkdir -p ${remote_temp_dir}"

    # Iterate through CONTAINER_LIST from config
    for container_name in "${CONTAINER_LIST[@]}"; do
        print_info "Downloading ${container_name} logs..."
        # Save logs to a temporary file on the remote server
        run_remote_command "${DOCKER_CMD} logs ${container_name} > ${remote_temp_dir}/${container_name}.log 2>&1"
    done

    # Download the directory
    print_info "Transferring logs to local ./logs/ directory..."
    scp -r "${SERVER_USER}@${SERVER_HOST}:${remote_temp_dir}" "./logs/"

    # Rename the downloaded directory locally
    mv "./logs/$(basename ${remote_temp_dir})" "./logs/project_${PROJECT_NAME}_logs_${timestamp}"

    print_success "Logs downloaded to ./logs/project_${PROJECT_NAME}_logs_${timestamp}/ directory"
    
    # Clean up remote temp directory
    run_remote_command "rm -rf ${remote_temp_dir}"
    
    press_enter_to_continue
    show_logs_menu
}

# Run log view directly based on arguments (non-interactive)
run_direct_log_view() {
    
    local container_name="$1"
    local lines="${2:-50}" # Default 50 lines
    local follow="${3:-false}"
    local log_type_name="${container_name}" # Use container name for logs

    print_section_header "Viewing Logs: ${log_type_name}"

    if [ "$RUN_REMOTE" = false ]; then
        # Local Mode Check
        print_info "[LOCAL MODE] Attempting to view logs for ${container_name}..."
        # Use local docker command
        local local_log_cmd="${DOCKER_CMD} logs --tail=${lines}"
        if [ "$follow" = true ]; then
            local_log_cmd="${local_log_cmd} -f"
            print_info "Following logs for ${log_type_name} (Press Ctrl+C to exit)..."
        else
            print_info "Viewing last ${lines} lines for ${log_type_name}..."
        fi
        local_log_cmd="${local_log_cmd} ${container_name}"
        # Execute directly - NO EVAL <<< CHANGED
        ${local_log_cmd} # <<< CHANGED
        local exit_code=$? # <<< ADDED
        set +x # <<< ADDED FOR DEBUGGING
        return ${exit_code} # <<< CHANGED
    fi

    # Remote Mode Check
    # Check if the container exists remotely
    if ! run_remote_command "${DOCKER_CMD} ps -a --filter name=^/${container_name}$ --format '{{.Names}}' | grep -q ${container_name}" "silent"; then
        print_error "Container '${container_name}' not found on remote server."
        set +x # <<< ADDED FOR DEBUGGING
        return 1
    fi

    local log_cmd="${DOCKER_CMD} logs --tail=${lines}"
    if [ "$follow" = true ]; then
        log_cmd="${log_cmd} -f"
        print_info "Following logs for ${log_type_name} (Press Ctrl+C to exit)..."
        # Use direct ssh for follow to work correctly
        ssh "${SERVER_USER}@${SERVER_HOST}" -p "${SERVER_PORT}" "${log_cmd} ${container_name}"
        local exit_code=$? # <<< ADDED
        set +x # <<< ADDED FOR DEBUGGING
        return ${exit_code} # <<< CHANGED
    else
        print_info "Viewing last ${lines} lines for ${log_type_name}..."
        log_cmd="${log_cmd} ${container_name}"
        # Use run_remote_command for non-following logs
        run_remote_command "${log_cmd}"
        local exit_code=$? # <<< ADDED
        set +x # <<< ADDED FOR DEBUGGING
        return ${exit_code} # <<< CHANGED
    fi
    
    # No "press enter" or menu loop for direct action
} 