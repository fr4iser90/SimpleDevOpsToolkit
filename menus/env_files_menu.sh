#!/usr/bin/env bash

# =======================================================
# Environment Files Menu
# =======================================================

# Show environment files menu
show_env_files_menu() {
    show_header
    print_section_header "Environment File (.env) Management - Project: ${PROJECT_NAME}"
    
    print_menu_item "1" "Edit Server .env File (Remote)"
    print_menu_item "2" "Upload Local .env File to Server"
    print_menu_item "3" "Download Server .env File"
    print_menu_item "4" "Generate Generic Template (.env.template)"
    print_menu_item "5" "Sync/Load Server .env Values Locally (Temporary)"
    
    print_back_option
    echo ""
    
    local choice=$(get_numeric_input "Select an option: ")
    
    case $choice in
        1)
            edit_env_file # Function needs to be generic
            press_enter_to_continue
            show_env_files_menu
            ;;
        2)
            upload_env_file # Function needs to be generic
            press_enter_to_continue
            show_env_files_menu
            ;;
        3)
            download_env_file # Function needs to be generic
            press_enter_to_continue
            show_env_files_menu
            ;;
        4)
            create_project_templates # Calls generic template function
            press_enter_to_continue
            show_env_files_menu
            ;;
        5)
            sync_env_values # Function needs to be generic
            press_enter_to_continue
            show_env_files_menu
            ;;
        0) # Back
            show_main_menu
            ;;
        *)
            print_error "Invalid option!"
            sleep 1
            show_env_files_menu
            ;;
    esac
}

# Edit .env file - Generic
edit_env_file() {
    clear
    
    if [ "$RUN_REMOTE" = false ]; then
        print_error "Cannot edit remote .env file in local mode. Edit ./docker/.env or ./.env manually."
        press_enter_to_continue
        return
    fi
    
    # Prioritize .env in project root, fallback to docker dir
    local remote_env_path="${EFFECTIVE_PROJECT_DIR}/.env"
    local remote_docker_env_path="${EFFECTIVE_DOCKER_DIR}/.env"
    local effective_remote_path=""

    print_info "Checking for .env file on server..."
    if run_remote_command "test -f ${remote_env_path}" "silent"; then
        print_info "Found .env in project root: ${remote_env_path}"
        effective_remote_path="$remote_env_path"
    elif run_remote_command "test -f ${remote_docker_env_path}" "silent"; then
        print_info "Found .env in Docker directory: ${remote_docker_env_path}"
        effective_remote_path="$remote_docker_env_path"
    else
        print_error ".env file not found in ${remote_env_path} or ${remote_docker_env_path}"
        if get_yes_no "Would you like to create a new .env from template and upload?"; then
            create_project_templates # Generate template locally
             if [ -f "./templates/env.template" ]; then
                 print_info "Uploading template as .env to server..."
                 run_remote_command "mkdir -p ${EFFECTIVE_PROJECT_DIR}" "silent"
                 scp "./templates/env.template" "${SERVER_USER}@${SERVER_HOST}:${remote_env_path}"
                 run_remote_command "mkdir -p ${EFFECTIVE_DOCKER_DIR}" "silent"
                 scp "./templates/env.template" "${SERVER_USER}@${SERVER_HOST}:${remote_docker_env_path}"
                 print_success ".env file uploaded from template."
                 print_warning "IMPORTANT: You MUST edit the .env file now!"
                 effective_remote_path="$remote_env_path" # Proceed to edit the newly uploaded file
             else
                 print_error "Template file ./templates/env.template not found."
                 return
             fi
        else
            press_enter_to_continue
            return
        fi
    fi
    
    # Download .env file to a temporary file
    local temp_env_file="/tmp/${PROJECT_NAME}_env_edit_$$"
    print_info "Downloading ${effective_remote_path}..."
    scp "${SERVER_USER}@${SERVER_HOST}:${effective_remote_path}" "$temp_env_file"
    if [ $? -ne 0 ]; then print_error "Failed to download .env file."; rm -f "$temp_env_file"; return; fi

    # Open the file in the user's preferred editor
    local editor="${EDITOR:-nano}"
    print_info "Opening .env file in ${editor}... (Save and exit editor to proceed)"
    if ! command -v "$editor" > /dev/null; then
        print_error "Editor '$editor' not found. Trying nano/vim/vi..."
        if command -v nano > /dev/null; then editor=nano; 
        elif command -v vim > /dev/null; then editor=vim; 
        elif command -v vi > /dev/null; then editor=vi; 
        else print_error "No suitable editor found."; rm -f "$temp_env_file"; return; 
        fi
        print_info "Using editor: $editor"
    fi
    "$editor" "$temp_env_file"

    # Upload the edited file back to the server
    if get_yes_no "Save changes to remote .env file (${effective_remote_path})?" "y"; then
        print_info "Uploading changes..."
        scp "$temp_env_file" "${SERVER_USER}@${SERVER_HOST}:${effective_remote_path}"
        if [ $? -ne 0 ]; then print_error "Failed to upload changes."; else print_success "Changes saved to ${effective_remote_path}."; fi
        
        # Also copy to the other location (docker dir or project root) if it exists
        local other_path=""
        if [ "$effective_remote_path" == "$remote_env_path" ]; then
            other_path="$remote_docker_env_path"
        else
            other_path="$remote_env_path"
        fi
        if run_remote_command "test -d $(dirname ${other_path})" "silent"; then
            print_info "Copying updated .env to ${other_path} for consistency..."
            run_remote_command "cp ${effective_remote_path} ${other_path}"
        fi
        
        # Ask if services should be restarted
        if get_yes_no "Do you want to restart services to apply changes?"; then
            print_info "Restarting services..."
            run_remote_command "cd ${EFFECTIVE_DOCKER_DIR} && ${DOCKER_COMPOSE_CMD} restart"
            print_success "Services restarted"
        fi
    else
        print_info "Changes discarded."
    fi
    
    # Clean up
    rm -f "$temp_env_file"
    press_enter_to_continue # Already called inside functions called
}

# Upload a local .env file to server - Generic
upload_env_file() {
    clear
    print_section_header "Upload Local .env File to Server"
    
    if [ "$RUN_REMOTE" = false ]; then
        print_error "Cannot upload files in local mode. Place your .env in ./ or ./docker/ manually."
        press_enter_to_continue
        return
    fi
    
    # Look for .env in common local locations relative to git dir
    local local_env_file=""
    local git_root_env="${LOCAL_GIT_DIR}/.env"
    local git_docker_env="${LOCAL_GIT_DIR}/docker/.env"

    print_info "Searching for local .env file..."
    if [ -f "$git_root_env" ]; then
        print_info "Found: ${git_root_env}"
        local_env_file="$git_root_env"
    elif [ -f "$git_docker_env" ]; then
        print_info "Found: ${git_docker_env}"
        local_env_file="$git_docker_env"
    else
        print_warning "No .env found in ${LOCAL_GIT_DIR} or ${LOCAL_GIT_DIR}/docker/"
    fi

    # Ask user to confirm or provide path
    if [ -n "$local_env_file" ]; then
         if ! get_yes_no "Use this file (${local_env_file})?" "y"; then
             local_env_file=""
         fi
    fi

    if [ -z "$local_env_file" ]; then
        read -e -p "Enter the full path to your local .env file: " local_env_file
        if [ ! -f "$local_env_file" ]; then
            print_error "File not found: $local_env_file"
            return
        fi
    fi
    
    print_info "Uploading ${local_env_file} to server..."
    
    # Define remote paths
    local remote_project_path="${EFFECTIVE_PROJECT_DIR}/.env"
    local remote_docker_path="${EFFECTIVE_DOCKER_DIR}/.env"
    
    # Ensure remote directories exist
    run_remote_command "mkdir -p $(dirname ${remote_project_path})" "silent"
    run_remote_command "mkdir -p $(dirname ${remote_docker_path})" "silent"

    # Upload the file to both project root and docker directory for consistency
    local upload_ok=true
    scp "$local_env_file" "${SERVER_USER}@${SERVER_HOST}:${remote_project_path}"
    if [ $? -ne 0 ]; then print_error "Failed to upload to ${remote_project_path}"; upload_ok=false; fi
    scp "$local_env_file" "${SERVER_USER}@${SERVER_HOST}:${remote_docker_path}"
     if [ $? -ne 0 ]; then print_error "Failed to upload to ${remote_docker_path}"; upload_ok=false; fi

    if [ "$upload_ok" = true ]; then
        print_success ".env file uploaded successfully to both locations on server!"
        
        # Ask if services should be restarted
        if get_yes_no "Do you want to restart services to apply changes?"; then
            print_info "Restarting services..."
            run_remote_command "cd ${EFFECTIVE_DOCKER_DIR} && ${DOCKER_COMPOSE_CMD} restart"
            print_success "Services restarted"
        fi
    else
        print_error "File upload failed."
    fi
    
    # press_enter_to_continue # Already called inside functions called
}

# Download .env file from server - Generic
download_env_file() {
    clear
    print_section_header "Download Server .env File"
    
    if [ "$RUN_REMOTE" = false ]; then
        print_error "Cannot download files in local mode."
        press_enter_to_continue
        return
    fi
    
    # Prioritize project root, fallback to docker dir
    local remote_env_path="${EFFECTIVE_PROJECT_DIR}/.env"
    local remote_docker_env_path="${EFFECTIVE_DOCKER_DIR}/.env"
    local effective_remote_path=""

    print_info "Checking for .env file on server..."
    if run_remote_command "test -f ${remote_env_path}" "silent"; then
        print_info "Found .env in project root: ${remote_env_path}"
        effective_remote_path="$remote_env_path"
    elif run_remote_command "test -f ${remote_docker_env_path}" "silent"; then
        print_info "Found .env in Docker directory: ${remote_docker_env_path}"
        effective_remote_path="$remote_docker_env_path"
    else
        print_error ".env file not found on server in expected locations."
        return
    fi
    
    # Get timestamp for unique local filename
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local output_dir="./env_backups"
    local output_file="${output_dir}/${PROJECT_NAME}_env_${timestamp}"
    mkdir -p "$output_dir"
    
    # Download the file
    print_info "Downloading ${effective_remote_path} to ${output_file}..."
    scp "${SERVER_USER}@${SERVER_HOST}:${effective_remote_path}" "$output_file"
    
    if [ $? -eq 0 ]; then
        print_success ".env file downloaded successfully to ${output_file}"
    else
        print_error "Failed to download .env file"
    fi
    
    # press_enter_to_continue # Already called inside functions called
}

# Generate template .env file - Now just calls create_project_templates
generate_template_env() {
    create_project_templates # This is now the generic template creator
}

# Sync environment values between server .env and local shell - Generic
sync_env_values() {
    print_section_header "Sync Server .env Values to Local Shell (Temporary)"
    
    if [ "$RUN_REMOTE" = false ]; then
        print_error "Cannot sync from remote server in local mode."
        return 1
    fi
    
    # Prioritize project root, fallback to docker dir on server
    local remote_env_path="${EFFECTIVE_PROJECT_DIR}/.env"
    local remote_docker_env_path="${EFFECTIVE_DOCKER_DIR}/.env"
    local effective_remote_path=""

    print_info "Checking for .env file on server..."
    if run_remote_command "test -f ${remote_env_path}" "silent"; then
        effective_remote_path="$remote_env_path"
    elif run_remote_command "test -f ${remote_docker_env_path}" "silent"; then
        effective_remote_path="$remote_docker_env_path"
    else
        print_error ".env file not found on server."
        return 1
    fi

    print_info "Loading environment variables from ${effective_remote_path} into current shell..."
    
    # Create a temporary local file to store the .env content
    local temp_env_file="/tmp/${PROJECT_NAME}_env_sync_$$"
    scp "${SERVER_USER}@${SERVER_HOST}:${effective_remote_path}" "$temp_env_file"
    if [ $? -ne 0 ]; then print_error "Failed to download .env file for sync."; rm -f "$temp_env_file"; return 1; fi
    
    # Export values to current environment, skipping comments and empty lines
    # Using set -a / +a ensures variables are exported
    set -a 
    source <(grep -vE '^\s*(#|$)' "$temp_env_file")
    set +a

    # Verify a known variable was loaded (e.g., PROJECT_NAME, if expected in .env)
    # Or just check if any variables were sourced
    if [ -n "${PROJECT_NAME}" ]; then # Simple check 
        print_success "Environment variables sourced successfully into current shell!"
        print_warning "These variables are available for this terminal session only."
    else
         print_warning "Attempted to source variables, but validation check failed. Check .env content."
    fi

    # Ask if the user wants to apply these values to a local file (e.g., overwrite local .env)
    if get_yes_no "Save these sourced values to a local file (e.g., overwrite ./ .env)?" "n"; then
        # Choose location (e.g., project root .env)
        local target_local_env="./.env"
        print_info "Saving values to ${target_local_env}..."
        cp "$temp_env_file" "$target_local_env"
        print_success "Values saved to ${target_local_env}"
    fi
    
    # Cleanup
    rm "$temp_env_file"
    
    return 0
} 