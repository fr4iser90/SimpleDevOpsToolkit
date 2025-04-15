#!/usr/bin/env bash

# =======================================================
# Deployment Functions
# =======================================================

# Deploy application files to remote server or local directory
deploy_app() {
    # Restore original functionality for FoundryCord
    print_section_header "Deploying App Files"
    
    if [ "$RUN_REMOTE" = false ]; then
        print_info "Deploying app files to local directory..."
        
        # Ensure local directories exist
        mkdir -p "${LOCAL_APP_DIR}"
        
        # Copy application files from git directory to local development directory
        if [ -d "${LOCAL_GIT_DIR}/app" ]; then
            cp -r "${LOCAL_GIT_DIR}/app/"* "${LOCAL_APP_DIR}/"
            
            if [ $? -eq 0 ]; then
                print_success "Application files deployed locally to ${LOCAL_APP_DIR}!"
            else
                print_error "Failed to copy application files locally"
                return 1
            fi
        else
            print_error "Source directory ${LOCAL_GIT_DIR}/app not found!"
            return 1
        fi
    else
        # Create remote directories first
        print_info "Ensuring remote directories exist for app deployment..."
        ssh ${SERVER_USER}@${SERVER_HOST} "mkdir -p ${SERVER_PROJECT_DIR}/app"
        
        if [ $? -ne 0 ]; then
            print_error "Failed to create remote app directory"
            return 1
        fi
        
        # Copy application files to remote server
        print_info "Copying application files to remote server..."
        if [ -d "${LOCAL_GIT_DIR}/app" ]; then
            scp -r "${LOCAL_GIT_DIR}/app/"* "${SERVER_USER}@${SERVER_HOST}:${SERVER_PROJECT_DIR}/app/"
            
            if [ $? -eq 0 ]; then
                print_success "Application files deployed successfully to remote server!"
            else
                print_error "Failed to copy application files to remote server"
                return 1
            fi
        else
            print_error "Source directory ${LOCAL_GIT_DIR}/app not found!"
            return 1
        fi
    fi
    
    return 0
}

# Deploy Docker configuration files to remote server or local directory
deploy_docker() {
    print_section_header "Deploying Docker Configuration"
    
    if [ "$RUN_REMOTE" = false ]; then
        print_info "Deploying Docker configuration to local project directory: ${LOCAL_PROJECT_DIR}"
        
        # Ensure local project root and docker subdirectory exist
        mkdir -p "${LOCAL_PROJECT_DIR}"
        mkdir -p "${LOCAL_DOCKER_DIR}" # Target for docker subdirectory contents
        
        # 1. Copy docker-compose.yml from git root to local project root
        if [ -f "${LOCAL_GIT_DIR}/docker-compose.yml" ]; then
            cp "${LOCAL_GIT_DIR}/docker-compose.yml" "${LOCAL_PROJECT_DIR}/docker-compose.yml"
            if [ $? -ne 0 ]; then print_error "Failed to copy docker-compose.yml locally"; return 1; fi
            print_success "Copied docker-compose.yml to ${LOCAL_PROJECT_DIR}"
        else
            print_error "Source file ${LOCAL_GIT_DIR}/docker-compose.yml not found!"
            return 1
        fi

        # 2. Copy contents of the docker subdirectory from git into the target docker subdirectory
        local source_docker_dir="${LOCAL_GIT_DIR}/docker/"
        local target_docker_dir="${LOCAL_DOCKER_DIR}/" # Should be .../Development/FoundryCord/docker/

        if [ -d "${source_docker_dir}" ]; then
            # --- DEBUGGING --- 
            echo "DEBUG: Source docker dir: ${source_docker_dir}"
            echo "DEBUG: Target docker dir: ${target_docker_dir}"
            # --- END DEBUGGING ---
            print_info "Copying contents of ${source_docker_dir} to ${target_docker_dir} ..."
            # Use cp -a to copy contents recursively, preserving attributes. The trailing slashes are important.
            cp -a "${source_docker_dir}." "${target_docker_dir}"
            if [ $? -ne 0 ]; then print_error "Failed to copy contents of docker/ directory locally"; return 1; fi
            print_success "Copied contents of docker/ to ${target_docker_dir}"
        else
            print_warning "Source directory ${source_docker_dir} not found. Skipping content copy."
            # Ensure target docker dir exists anyway
             mkdir -p "${target_docker_dir}" 
        fi

        # 3. Handle .env file - prioritize root in git source, copy to target project root
        local env_copied=false
        if [ -f "${LOCAL_GIT_DIR}/.env" ]; then
            cp "${LOCAL_GIT_DIR}/.env" "${LOCAL_PROJECT_DIR}/.env"
            if [ $? -eq 0 ]; then print_success "Copied .env from git root to project root"; env_copied=true; else print_error "Failed to copy .env from git root"; fi
        elif [ -f "${LOCAL_GIT_DIR}/docker/.env" ]; then
             cp "${LOCAL_GIT_DIR}/docker/.env" "${LOCAL_PROJECT_DIR}/.env"
             if [ $? -eq 0 ]; then print_success "Copied .env from git docker/ to project root"; env_copied=true; else print_error "Failed to copy .env from docker/"; fi
        fi
        # Optionally copy example if no .env found
        if [ "$env_copied" = false ] && [ -f "${LOCAL_GIT_DIR}/docker/.env.example" ]; then
            print_warning "No .env file found in source, copying docker/.env.example to project root. You'll need to edit this!"
            cp "${LOCAL_GIT_DIR}/docker/.env.example" "${LOCAL_PROJECT_DIR}/.env"
        elif [ "$env_copied" = false ]; then
             print_error "No .env or .env.example file found in source! Deployment may fail."
        fi
    else
        # REMOTE EXECUTION (Similar logic, using scp)
        print_info "Deploying Docker configuration to remote project directory: ${EFFECTIVE_PROJECT_DIR}"

        # Ensure remote project root and docker subdirectory exist
        run_remote_command "mkdir -p ${EFFECTIVE_PROJECT_DIR}" "silent"
        run_remote_command "mkdir -p ${EFFECTIVE_DOCKER_DIR}" "silent"

        # 1. Copy docker-compose.yml from git root to remote project root
        if [ -f "${LOCAL_GIT_DIR}/docker-compose.yml" ]; then
            scp "${LOCAL_GIT_DIR}/docker-compose.yml" "${SERVER_USER}@${SERVER_HOST}:${EFFECTIVE_PROJECT_DIR}/docker-compose.yml"
            if [ $? -ne 0 ]; then print_error "Failed to copy docker-compose.yml remotely"; return 1; fi
            print_success "Copied docker-compose.yml to remote ${EFFECTIVE_PROJECT_DIR}"
        else
            print_error "Source file ${LOCAL_GIT_DIR}/docker-compose.yml not found!"
            return 1
        fi

        # 2. Copy contents of the docker subdirectory from git to remote docker subdirectory
        local source_docker_dir="${LOCAL_GIT_DIR}/docker/"
        local target_docker_dir="${EFFECTIVE_DOCKER_DIR}/" 

        if [ -d "${source_docker_dir}" ]; then
            # --- DEBUGGING --- 
            echo "DEBUG: Source docker dir: ${source_docker_dir}"
            echo "DEBUG: Target remote docker dir path: ${target_docker_dir}"
            # --- END DEBUGGING ---
            print_info "Copying contents of ${source_docker_dir} to remote ${target_docker_dir} ..."
            # Use SCP to copy contents. Note: SCP doesn't have a direct equivalent of cp -a .
            # We copy all files/dirs inside source docker/ into the remote docker dir.
            # The trailing slash on source is important for scp -r contents
            scp -r "${source_docker_dir}." "${SERVER_USER}@${SERVER_HOST}:${target_docker_dir}"
            if [ $? -ne 0 ]; then print_error "Failed to copy contents of docker/ directory remotely"; return 1; fi
            print_success "Copied contents of docker/ to remote ${target_docker_dir}"
        else
            print_warning "Source directory ${source_docker_dir} not found. Skipping content copy."
        fi

        # 3. Handle .env file - prioritize root, copy to remote project root
        local env_copied=false
        if [ -f "${LOCAL_GIT_DIR}/.env" ]; then
            scp "${LOCAL_GIT_DIR}/.env" "${SERVER_USER}@${SERVER_HOST}:${EFFECTIVE_PROJECT_DIR}/.env"
            if [ $? -eq 0 ]; then print_success "Copied .env from git root to remote project root"; env_copied=true; else print_error "Failed to copy .env from git root"; fi
        elif [ -f "${LOCAL_GIT_DIR}/docker/.env" ]; then
             scp "${LOCAL_GIT_DIR}/docker/.env" "${SERVER_USER}@${SERVER_HOST}:${EFFECTIVE_PROJECT_DIR}/.env"
             if [ $? -eq 0 ]; then print_success "Copied .env from git docker/ to remote project root"; env_copied=true; else print_error "Failed to copy .env from docker/"; fi
        fi
        # Optionally copy example if no .env found
        if [ "$env_copied" = false ] && [ -f "${LOCAL_GIT_DIR}/docker/.env.example" ]; then
            print_warning "No .env file found in source, copying docker/.env.example to remote project root. You'll need to edit this!"
            scp "${LOCAL_GIT_DIR}/docker/.env.example" "${SERVER_USER}@${SERVER_HOST}:${EFFECTIVE_PROJECT_DIR}/.env"
        elif [ "$env_copied" = false ]; then
             print_error "No .env or .env.example file found in source! Deployment may fail."
        fi
    fi
    
    return 0
}

# Deploy containers (start/build)
deploy_containers() {
    print_section_header "Deploying Containers"

    # Verify .env file exists (locally or remotely)
    if [ "$RUN_REMOTE" = false ]; then
        if [ ! -f "${LOCAL_DOCKER_DIR}/.env" ]; then
            print_error "No .env file found locally at ${LOCAL_DOCKER_DIR}/.env! Deployment might fail."
            # Ask if user wants to continue anyway
            if ! get_yes_no "Continue without .env file?"; then print_info "Deployment cancelled."; return 1; fi
        fi
    else
        if ! run_remote_command "test -f ${EFFECTIVE_DOCKER_DIR}/.env" "true"; then
            print_error "No .env file found on server at ${EFFECTIVE_DOCKER_DIR}/.env! Deployment might fail."
            # Ask if user wants to continue anyway
            if ! get_yes_no "Continue without .env file?"; then print_info "Deployment cancelled."; return 1; fi
        fi
    fi

    # Build if enabled (using helper function)
    if [ "${AUTO_BUILD_ENABLED}" = "true" ]; then
        print_info "Building containers (if applicable, this may take a while)..."
        run_compose_build # Use helper function
        if [ $? -ne 0 ]; then print_error "Docker compose build failed!"; return 1; fi
    fi

    # Start containers (using helper function)
    print_info "Starting Docker containers..."
    run_compose_up -d # Use helper function with -d flag

    if [ $? -eq 0 ]; then
        print_success "Containers started successfully!"
    else
        print_error "Failed to start containers"
        return 1
    fi

    return 0
}

# Check if services are running
check_deployed_services() {
    print_section_header "Checking Deployed Services Status"

    if [ "$RUN_REMOTE" = false ]; then
        print_info "Checking local container status..."
        run_compose_ps # Use helper function
        return $?
    fi

    print_info "Checking remote container status (via docker ps)..."
    # Keep the existing logic using docker ps filter as run_compose_ps might show non-running profile services
    sleep 5 # Give services time to start
    local all_running=true
    local service_status=""
    
    # TODO: Get the list of expected running services based on the profile?
    # For now, check services listed in CONTAINER_LIST from config (might not be profile-aware)
    print_warning "Service check might not be profile-aware yet. Checking based on CONTAINER_LIST: ${CONTAINER_LIST[@]}"
    for service in "${CONTAINER_LIST[@]}"; do
        local container_name="${service}" # Assuming service name matches container name prefix
        print_info "Checking status for expected container: ${container_name}..."

        # Use docker ps with filter for exact name match
        if run_remote_command "${DOCKER_CMD} ps --filter name=^/${container_name}$ --format '{{.Names}}' | grep -q ${container_name}" "true"; then
            print_success "✓ ${container_name} is running."
            service_status+="${container_name}: Running\n"
        else
            print_error "✗ ${container_name} is NOT running!"
            service_status+="${container_name}: Stopped\n"
            all_running=false
        fi
    done

    if [ "$all_running" = "false" ]; then
        print_warning "Some expected services for the current profile might not be running!"
        # Suggest using run_compose_logs helper
        echo "Check logs using the logs menu or: ./run.sh --profile ${DOCKER_PROFILE:-cpu} --logs"
        return 1
    fi

    print_success "All checked services appear to be running."
    return 0
}

# Full deployment function - combines all steps
full_deploy() {
    print_section_header "Full Deployment"

    # 1. Deploy app files (Skipped)
    if ! deploy_app; then
        # This function now just returns 0, but keep structure
        # print_error "Deployment failed at app deployment stage"
        # return 1
        : # No-op
    fi

    # 2. Deploy Docker configuration
    if ! deploy_docker; then
        print_error "Deployment failed at Docker configuration stage"
        return 1
    fi

    # 3. Deploy containers (uses helpers)
    if ! deploy_containers; then
        print_error "Deployment failed at container deployment stage"
        return 1
    fi

    # 4. Check services (updated)
    check_deployed_services

    print_success "Deployment completed successfully!"
    return 0
}

# Run quick deploy - SAFE, preserves database
run_quick_deploy() {
    print_section_header "Quick Deploy (Database Safe)"

    # 1. Deploy app files (Skipped)
    if ! deploy_app; then
        # print_error "Deployment failed at app deployment stage"
        # return 1
         : # No-op
    fi

    # 2. Deploy Docker configuration
    if ! deploy_docker; then
        print_error "Deployment failed at Docker configuration stage"
        return 1
    fi

    # 3. Deploy containers (uses helpers)
    if ! deploy_containers; then
        print_error "Deployment failed at container deployment stage"
        return 1
    fi

    # 4. Check services
    if [ "$RUN_REMOTE" = false ]; then
        print_info "Containers started locally."
    else
        check_deployed_services
    fi

    print_success "Quick deployment completed successfully!"
    return 0
}

# Run partial deploy - SAFE, rebuilds containers only without touching persistent data
run_partial_deploy() {
    clear
    print_section_header "Partial Deploy (Persistent Data Safe - Rebuilds Images)"

    if [ "$RUN_REMOTE" = false ]; then
        print_error "Partial deploy (rebuild) not typically needed in local mode if volumes are mapped. Use standard deploy."
        # Or implement local build/up if desired
        return 1
    fi

    print_info "Stopping, Removing, Rebuilding, and Starting containers without touching persistent data (volumes)..."
    print_info "This is a SAFE operation that preserves existing persistent data."

    # Use helper functions
    run_compose_stop && run_compose_rm -f && run_compose_build --no-cache && run_compose_up -d

    if [ $? -eq 0 ]; then
        print_success "Partial deployment completed successfully!"
    else
        print_error "Partial deployment failed."
        return 1
    fi
    return 0
}

# Run full RESET deployment - DANGER, will delete all data
run_full_reset_deploy() {
    clear
    print_section_header "⚠️ FULL RESET DEPLOYMENT - DATA WILL BE LOST ⚠️"

    print_error "Performing COMPLETE RESET with PERSISTENT DATA DELETION..."
    print_error "ALL DATA in volumes (DB, models, etc.) WILL BE LOST!"

    local volume_flag=""
    if [ "${REMOVE_VOLUMES}" = "true" ]; then
        print_warning "Volume removal flag set - ALL persistent data will be removed!"
        volume_flag="-v"
    fi

    # Use helper for down
    print_info "Bringing down containers and removing volumes (if selected)..."
    run_compose_down ${volume_flag}

    if [ "$RUN_REMOTE" = false ]; then
         print_info "Running in local mode..."
         # Consider if cleaning LOCAL_PROJECT_DIR is still desired
         # if [ -d "${LOCAL_PROJECT_DIR}" ]; then ... sudo rm ... fi
         # mkdir -p "${LOCAL_PROJECT_DIR}"
         # cp -r "${LOCAL_GIT_DIR}/"* "${LOCAL_PROJECT_DIR}/" # Copy only docker?
    else
        # Remove the project directory on the server
        print_info "Removing project directory on server: ${SERVER_PROJECT_DIR}"
        # Ensure SERVER_PROJECT_DIR is set and not empty/root before rm!
        if [[ -n "$SERVER_PROJECT_DIR" && "$SERVER_PROJECT_DIR" != "/" ]]; then
            run_remote_command "sudo rm -rf ${SERVER_PROJECT_DIR}"
        else
            print_error "SERVER_PROJECT_DIR is not set safely. Aborting directory removal."
            return 1
        fi
    fi

    # Deploy docker config (includes creating directories)
    print_info "Deploying Docker configuration..."
    if ! deploy_docker; then print_error "Failed to deploy docker configuration"; return 1; fi

    # Build and start using helpers
    print_info "Building images..."
    run_compose_build --no-cache
    if [ $? -ne 0 ]; then print_error "Build failed."; return 1; fi

    print_info "Starting containers..."
    run_compose_up -d
    if [ $? -ne 0 ]; then print_error "Container startup failed."; return 1; fi

    print_success "Full reset deployment completed."
    if [ "${REMOVE_VOLUMES}" = "true" ]; then
        print_warning "Your persistent data (volumes) have been completely removed."
    else
        print_warning "Your persistent data (volumes) have been reset (containers recreated)."
    fi

    return 0
}

# Check services - Use internal function
check_services() {
    clear
    print_section_header "Service Status Check"

    # Use run_compose_ps helper
    run_compose_ps
    return $?
}

# Update Docker configuration
update_docker_config() {
    clear
    print_section_header "Update Docker Configuration"

    if [ "$RUN_REMOTE" = false ]; then
        print_error "Cannot update Docker configuration in local mode"
        return 1
    fi

    print_info "This operation updates Docker files (e.g., docker-compose.yml) and restarts services."
    print_info "It is SAFE and preserves existing persistent data."

    # Deploy docker files
    if ! deploy_docker; then
        print_error "Failed to deploy Docker configuration"
        return 1
    fi

    print_info "Restarting containers to apply Docker configuration changes..."
    # Use helper function
    run_compose_restart

    if [ $? -eq 0 ]; then
        print_success "Docker configuration updated and services restarted."
        return 0
    else
        print_error "Failed to restart services after Docker config update."
        return 1
    fi
}

# Check Docker files - Remains mostly the same, uses run_remote_command for checks
check_docker_files() {
    clear
    print_section_header "Check Docker Files"

    if [ "$RUN_REMOTE" = false ]; then
        # Check local files
        print_info "Verifying essential Docker configuration files locally..."
        local docker_files_ok=true
        if [ ! -f "${LOCAL_DOCKER_DIR}/docker-compose.yml" ]; then
             print_error "Missing: ${LOCAL_DOCKER_DIR}/docker-compose.yml"
             docker_files_ok=false
        else
             print_success "Found: ${LOCAL_DOCKER_DIR}/docker-compose.yml"
        fi
        if [ ! -f "${LOCAL_DOCKER_DIR}/.env" ]; then
             print_error "Missing: ${LOCAL_DOCKER_DIR}/.env"
             docker_files_ok=false
        else
             print_success "Found: ${LOCAL_DOCKER_DIR}/.env"
        fi
        # Check Dockerfile.comfyui locally
        if [ ! -f "${LOCAL_DOCKER_DIR}/Dockerfile.comfyui" ]; then
             print_warning "Missing: ${LOCAL_DOCKER_DIR}/Dockerfile.comfyui (Needed for build)"
             # docker_files_ok=false # Optional: make it an error?
        else
             print_success "Found: ${LOCAL_DOCKER_DIR}/Dockerfile.comfyui"
        fi

        if [ "$docker_files_ok" = true ]; then
            print_success "Essential Docker files seem to be present locally."
        else
            print_error "Some essential Docker files are missing locally! Deployment may fail."
            return 1
        fi
        return 0
    fi

    # Remote check (existing logic is fine)
    print_info "Verifying essential Docker configuration files on remote server..."
    local docker_files_ok=true
    # Check for docker-compose.yml using EFFECTIVE_DOCKER_DIR
    if ! run_remote_command "test -f ${EFFECTIVE_DOCKER_DIR}/docker-compose.yml" "true"; then
        print_error "Missing: ${EFFECTIVE_DOCKER_DIR}/docker-compose.yml"
        docker_files_ok=false
    else
        print_success "Found: ${EFFECTIVE_DOCKER_DIR}/docker-compose.yml"
    fi
    # Check for .env using EFFECTIVE_DOCKER_DIR and EFFECTIVE_PROJECT_DIR as fallback
    if ! run_remote_command "test -f ${EFFECTIVE_DOCKER_DIR}/.env" "true"; then
        print_warning "Missing: ${EFFECTIVE_DOCKER_DIR}/.env. Checking project root..."
        if ! run_remote_command "test -f ${EFFECTIVE_PROJECT_DIR}/.env" "true"; then
             print_error "Missing: .env file in both ${EFFECTIVE_DOCKER_DIR} and ${EFFECTIVE_PROJECT_DIR}!"
             docker_files_ok=false
        else
             print_success "Found: ${EFFECTIVE_PROJECT_DIR}/.env (will be used if docker/.env missing)"
        fi
    else
        print_success "Found: ${EFFECTIVE_DOCKER_DIR}/.env"
    fi


    if [ "$docker_files_ok" = true ]; then
        print_success "Essential Docker files seem to be present remotely."
    else
        print_error "Some essential Docker files are missing remotely! Deployment may fail."
        return 1
    fi

    return 0
}

# Auto-start services after deployment
auto_start_services() {
    print_section_header "Auto-starting Services"

    if [ "$RUN_REMOTE" = false ]; then
        print_info "Running locally. Starting services directly..."
        run_compose_up -d # Use helper
        return $?
    fi

    # Remote auto-start
    # Source the auto_start config file to get latest settings
    local auto_start_config_file="${EFFECTIVE_CONFIG_DIR}/auto_start.conf"
    if run_remote_command "test -f ${auto_start_config_file}" "true"; then
        # Load remote config content into local variables
        # This is tricky, might need to scp the file down first or parse output
        print_warning "Loading remote auto_start.conf is complex. Using local defaults/cache if available."
        # For simplicity, assume config is loaded or use defaults
        # [ -f "./utils/config/auto_start.conf" ] && source "./utils/config/auto_start.conf"
    else
         print_warning "Remote auto-start config file not found at ${auto_start_config_file}. Using defaults."
    fi
    # Use local/cached variables if available, otherwise set defaults
    AUTO_START_ENABLED=${AUTO_START_ENABLED:-true}
    AUTO_START_SERVICES=${AUTO_START_SERVICES:-all}
    AUTO_START_WAIT=${AUTO_START_WAIT:-10}
    AUTO_BUILD_ENABLED=${AUTO_BUILD_ENABLED:-true}
    AUTO_START_FEEDBACK=${AUTO_START_FEEDBACK:-minimal}

    # Check if auto-start is enabled
    if [ "${AUTO_START_ENABLED}" != "true" ]; then
        print_info "Auto-start is disabled in config. Skipping service startup."
        return 0
    fi

    print_info "Auto-starting services based on config (${AUTO_START_SERVICES})..."

    local up_args="-d"
    case "${AUTO_START_SERVICES}" in
        "all")
            # No specific services needed for 'up'
            ;;
        "none")
            print_info "No services selected for auto-start."
            return 0
            ;;
        *)
            # Start only specified services (comma-separated)
            local services_to_start=$(echo "${AUTO_START_SERVICES}" | tr ',' ' ')
            print_info "Starting specific services: ${services_to_start}"
            up_args="${up_args} ${services_to_start}"
            ;;
    esac

    # Use helper function
    run_compose_up ${up_args}
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then print_error "Failed to start services."; return $exit_code; fi

    # Wait if configured
    if [ "${AUTO_START_WAIT}" -gt 0 ]; then
        print_info "Waiting ${AUTO_START_WAIT} seconds for services to initialize..."
        sleep "${AUTO_START_WAIT}"
    fi

    # Show service status if feedback is enabled
    if [ "${AUTO_START_FEEDBACK}" != "none" ]; then
        print_info "Checking service status..."
        run_compose_ps # Use helper

        if [ "${AUTO_START_FEEDBACK}" = "verbose" ]; then
            print_info "Displaying recent logs..."
            run_compose_logs --tail=20 # Use helper
        fi
    fi

    print_success "Auto-start process completed!"
    return 0
}

# Save auto-start configuration - Remains the same, saves locally or uploads
save_auto_start_config() {
    # ... (Keep existing implementation - it handles local/remote save correctly) ...
    # Get values passed as arguments, providing defaults from sourced config if available
    local auto_start="${1:-$AUTO_START_ENABLED}"
    local auto_start_services="${2:-$AUTO_START_SERVICES}"
    local auto_start_feedback="${3:-$AUTO_START_FEEDBACK}"
    local auto_build="${4:-$AUTO_BUILD_ENABLED}"
    local auto_wait="${5:-$AUTO_START_WAIT}"
    local local_auto_start="${6:-$LOCAL_AUTO_START_ENABLED}"
    local local_auto_start_services="${7:-$LOCAL_AUTO_START_SERVICES}"

    # Construct config content
    local config_content="#!/usr/bin/env bash
# Auto-start Configuration for Project: ${PROJECT_NAME}
# This file is managed by ApplicationCenter.sh

# Enable/disable auto-start (true/false)
AUTO_START_ENABLED=${auto_start:-true}

# Services to auto-start (comma-separated list or 'all'/'none')
# Example for project '${PROJECT_NAME}': all, ${CONTAINER_LIST// /, }, none
AUTO_START_SERVICES=${auto_start_services:-all}

# Wait time after startup in seconds (0 to disable)
AUTO_START_WAIT=${auto_wait:-10}

# Automatically rebuild containers before start (true/false)
AUTO_BUILD_ENABLED=${auto_build:-true}

# Show feedback during auto-start (none, minimal, verbose)
AUTO_START_FEEDBACK=${auto_start_feedback:-minimal}

# Local mode auto-start options
# Enable/disable local mode auto-start (true/false)
LOCAL_AUTO_START_ENABLED=${local_auto_start:-true}

# Local services to auto-start (comma-separated list or 'all'/'none')
# Example: all, ${CONTAINER_LIST// /, }, none
LOCAL_AUTO_START_SERVICES=${local_auto_start_services:-all}"

    # Define target config file path
    local target_config_file="./utils/config/auto_start.conf"
    local remote_config_path="${EFFECTIVE_CONFIG_DIR}/auto_start.conf"

    # Create a temporary file
    local temp_file="/tmp/${PROJECT_NAME}_auto_start_temp.conf"
    echo "$config_content" > "$temp_file"

    if [ "$RUN_REMOTE" = false ]; then
        print_info "Saving auto-start configuration locally..."
        mkdir -p "$(dirname "$target_config_file")"
        cp "$temp_file" "$target_config_file"
        print_success "Local auto-start configuration saved to ${target_config_file}!"
    else
        # Upload the file to the server config directory
        print_info "Uploading auto-start configuration to server..."
        run_remote_command "mkdir -p $(dirname "${remote_config_path}")" "silent"
        scp "$temp_file" "${SERVER_USER}@${SERVER_HOST}:${remote_config_path}"

        # Make it readable (not executable needed for conf)
        run_remote_command "chmod 644 ${remote_config_path}"
        print_success "Remote auto-start configuration saved to ${remote_config_path}!"
    fi

    # Remove the temporary file
    rm "$temp_file"
}

# Modify quick deploy to use auto-start
run_quick_deploy_with_auto_start() {
    clear
    print_section_header "Quick Deploy with Auto-Start"

    if [ "$RUN_REMOTE" = false ]; then
        print_error "Auto-start based on remote config not applicable in local mode. Use standard deploy."
        return 1
    fi

    print_info "Running quick deploy with auto-start configuration..."

    # 1. Deploy app files (Skipped)
    # if ! deploy_app; then return 1; fi
    : # No-op

    # 2. Deploy Docker configuration
    if ! deploy_docker; then
        print_error "Deployment failed at Docker configuration stage"
        return 1
    fi

    # 3. Build containers if auto-build is enabled in config
    print_section_header "Building Containers (if enabled)"
    # Reload config variables from local file (assuming remote config is complex to fetch/parse)
    # [ -f "./utils/config/auto_start.conf" ] && source "./utils/config/auto_start.conf"
    # Use existing AUTO_BUILD_ENABLED variable
    if [ "${AUTO_BUILD_ENABLED}" = "true" ]; then
        print_info "Auto-build is enabled. Building containers..."
        # Use helper function
        run_compose_stop # Stop first before build
        run_compose_build
        if [ $? -ne 0 ]; then print_error "Build failed."; return 1; fi
    else
        print_info "Auto-build is disabled. Using existing containers..."
    fi

    # 4. Auto-start services (uses helpers indirectly)
    auto_start_services

    # 5. Check services
    check_deployed_services

    print_success "Deployment with auto-start process completed!"
    return 0
}

# Run deployment with real-time monitoring
run_deployment_with_monitoring() {
    clear
    print_section_header "Deployment with Real-time Monitoring"

    if [ "$RUN_REMOTE" = false ]; then
        print_error "Cannot run remote monitoring in local mode" # Local monitoring could be added
        return 1
    fi

    print_info "Starting deployment with console feedback..."

    local monitor_services="${1:-all}" # Default to all services in compose file for the profile

    # 1. Deploy app files (Skipped)
    # if ! deploy_app; then return 1; fi
    : # No-op

    # 2. Deploy Docker configuration
    if ! deploy_docker; then
        print_error "Deployment failed at Docker configuration stage"
        return 1
    fi

    # 3. Build containers if enabled
    print_section_header "Building and Starting Containers"
    # Reload config or use existing AUTO_BUILD_ENABLED
    if [ "${AUTO_BUILD_ENABLED}" = "true" ]; then
        print_info "Building containers (this may take a while)..."
        run_compose_build # Use helper
        if [ $? -ne 0 ]; then print_error "Build failed."; return 1; fi
    fi

    # Start containers in background
    print_info "Starting containers..."
    run_compose_up -d # Use helper
    if [ $? -ne 0 ]; then print_error "Container startup failed."; return 1; fi

    # Determine services to monitor
    local log_args="-f --tail=50"
    if [ "$monitor_services" != "all" ]; then
        log_args="${log_args} $(echo "${monitor_services}" | tr ',' ' ')"
    fi

    print_info "Monitoring logs for services. Press Ctrl+C to stop monitoring..."
    run_compose_logs ${log_args} # Use helper

    # 4. Check services after user ends monitoring
    print_info "Monitoring ended. Checking service status..."
    check_deployed_services

    print_success "Deployment with monitoring completed successfully!"
    return 0
}

# Quick deploy and attach to MAIN_CONTAINER
run_quick_deploy_attach() {
    print_section_header "Quick Deploy and Attach to Main Container"

    # 1. Deploy app files (Skipped)
    # if ! deploy_app; then return 1; fi
    : # No-op

    # 2. Deploy Docker configuration
    if ! deploy_docker; then
        print_error "Deployment failed at Docker configuration stage"
        return 1
    fi

    # 3. Deploy containers (build if needed, start)
    if ! deploy_containers; then # Uses helpers now
        print_error "Deployment failed at container deployment stage"
        return 1
    fi

    # 4. Check services and Attach to MAIN_CONTAINER (from config)
    # MAIN_CONTAINER needs to be profile aware or we need a different approach
    local target_container="${MAIN_CONTAINER}" # Use config value
    print_info "Attempting to attach to container: ${target_container}"

    if [ "$RUN_REMOTE" = false ]; then
        print_info "Containers started locally."
        sleep 5 # Wait briefly
        # Use docker attach directly
        if docker ps --filter name=^/${target_container}$ --format '{{.Names}}' | grep -q "${target_container}"; then
            print_info "Attaching to ${target_container}... (Press Ctrl+P Ctrl+Q to detach)"
            docker attach "${target_container}"
        else
            print_error "Container ${target_container} not found or not running!"
            return 1
        fi
    else
        check_deployed_services
        # Use direct ssh for attach
        print_info "Attaching to remote container ${target_container}... (Press Ctrl+P Ctrl+Q to detach)"
        ssh "${SERVER_USER}@${SERVER_HOST}" -p "${SERVER_PORT}" "${DOCKER_CMD} attach ${target_container}"
    fi

    print_success "Quick deployment completed! Detached from container."
    return 0
}


