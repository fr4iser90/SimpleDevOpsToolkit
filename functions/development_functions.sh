#!/usr/bin/env bash

# =======================================================
# Development Functions
# =======================================================

# Generate encryption keys
generate_encryption_keys() {
    clear
    print_section_header "Generate Encryption Keys"
    
    if command -v nix-shell >/dev/null 2>&1; then
        nix-shell ./utils/development/python-shell.nix
    else
        print_error "nix-shell not installed"
        echo "Please install Nix from https://nixos.org/download.html"
        
        # Fallback to python if available
        if command -v python3 >/dev/null 2>&1; then
            print_warning "Using python3 directly instead..."
            echo "AES_KEY: $(python3 -c 'import os, base64; print(base64.urlsafe_b64encode(os.urandom(32)).decode())')"
            
            if python3 -c "import cryptography" >/dev/null 2>&1; then
                echo "ENCRYPTION_KEY: $(python3 -c 'from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())')"
            else
                print_error "cryptography package not installed. Cannot generate Fernet key."
                echo "Install with: pip install cryptography"
            fi
        else
            print_error "Python 3 not found in path."
        fi
    fi
    
    press_enter_to_continue
    show_development_menu
}

# Initialize development environment
initialize_dev_environment() {
    clear
    print_section_header "Initialize Development Environment"
    
    ./utils/testing/init_test_env.sh
    
    press_enter_to_continue
    show_development_menu
}

# Update utility scripts
update_utility_scripts() {
    clear
    print_section_header "Update Utility Scripts"
    
    if [ "$RUN_REMOTE" = false ]; then
        print_error "Cannot update utility scripts in local mode"
        press_enter_to_continue
        show_development_menu
        return
    else
        print_info "Uploading utility scripts to server..."
        upload_utils_scripts
    fi
    
    press_enter_to_continue
    show_development_menu
}

# Upload utility scripts to server
upload_utils_scripts() {
    # Create remote directory if it doesn't exist
    run_remote_command "mkdir -p ${PROJECT_ROOT_DIR}/utils"
    
    # Upload all utility scripts
    print_info "Uploading utility scripts..."
    scp -r ./utils/* "${SERVER_USER}@${SERVER_HOST}:${PROJECT_ROOT_DIR}/utils/"
    
    if [ $? -eq 0 ]; then
        print_success "Utility scripts uploaded successfully"
        
        # Make scripts executable
        run_remote_command "find ${PROJECT_ROOT_DIR}/utils -name \"*.sh\" -type f -exec chmod +x {} \\;"
        run_remote_command "find ${PROJECT_ROOT_DIR}/utils -name \"*.py\" -type f -exec chmod +x {} \\;"
        
        print_success "Scripts made executable on server"
    else
        print_error "Failed to upload utility scripts"
    fi
}

# Create project templates - Generic, uses PROJECT_NAME
create_project_templates() {
    clear
    print_section_header "Create Project Templates"
    
    # Create templates directory if it doesn't exist
    mkdir -p ./templates
    
    # Define source and destination paths
    local base_template_path="./utils/config/env.template.base"
    local output_template_path="./templates/env.template"
    
    # Check if base template exists
    if [ ! -f "${base_template_path}" ]; then
        print_error "Base template file not found at ${base_template_path}"
        press_enter_to_continue
        show_development_menu
        return 1
    fi
    
    # Copy the base template to the output location
    print_info "Creating generic .env template from base (${base_template_path})..."
    cp "${base_template_path}" "${output_template_path}"
    
    if [ $? -ne 0 ]; then
        print_error "Failed to copy template file."
        press_enter_to_continue
        show_development_menu
        return 1
    fi
    
    
    print_success "Generic template created in ${output_template_path}"
    print_info "Customize this template and save it as .env in your project root or docker directory."
    
    press_enter_to_continue
    show_development_menu
}

# Function to hot-reload a specific target component
# Assumes source is $LOCAL_GIT_DIR/<target> and dest is $LOCAL_APP_DIR/<target>
run_hot_reload() {
    local target="$1"
    # Construct source/dest paths carefully using config variables
    # Use LOCAL_GIT_DIR for the source code checkout
    # Use LOCAL_APP_DIR for the target bind mount/volume location (for local dev)
    local source_path="${LOCAL_GIT_DIR}/app/${target}" # Adjusted: Source code is under app/ directory
    local dest_path="${LOCAL_APP_DIR}/${target}"   # Adjust if your destination structure is different

    if [ -z "$target" ]; then
        print_error "Hot-reload target name cannot be empty."
        return 1
    fi

    # Validate source directory exists
    if [ ! -d "$source_path" ]; then
        print_error "Source directory for hot-reload target '$target' not found: $source_path"
        print_info "Check your LOCAL_GIT_DIR setting in project_config.sh and the target name."
        return 1
    fi

    # Ensure destination base directory exists (e.g., LOCAL_APP_DIR)
    # This is important if the target dir doesn't exist yet in the dev volume
    print_info "Ensuring destination directory base exists: $(dirname "$dest_path")"
    # Use sudo for mkdir if permissions might be an issue, but chown later should handle it.
    mkdir -p "$(dirname "$dest_path")"
    if [ $? -ne 0 ]; then
        print_warning "Could not create destination base directory (might already exist or permissions issue): $(dirname "$dest_path")"
        # Continue, as chown might fix permissions anyway
    fi

    # Ensure the specific target directory exists before changing ownership
    print_info "Ensuring specific destination directory exists: $dest_path"
    sudo mkdir -p "$dest_path" # Ensure the final target directory exists, creating with sudo if needed
    if [ $? -ne 0 ]; then
        print_error "Failed to create specific destination directory with sudo: $dest_path"
        return 1
    fi
    
    # Change ownership of the destination directory recursively to the current user
    # This allows rsync --delete (running as the user) to remove container-created files
    print_info "Taking ownership of destination directory: $dest_path ..."
    sudo chown -R "$(id -u):$(id -g)" "$dest_path"
    if [ $? -ne 0 ]; then
        print_error "Failed to change ownership of destination directory: $dest_path"
        print_info "Make sure your user has sudo privileges."
        return 1
    fi

    print_info "Syncing (rsync) '$target' from '$source_path/' to '$dest_path/'..."
    # Using rsync: -a (archive), -v (verbose), --delete (remove extraneous files from dest)
    # Trailing slash on source_path/ is important: copies contents *into* dest_path
    rsync -av --delete "$source_path/" "$dest_path/"

    local sync_status=$?
    if [ $sync_status -eq 0 ]; then
        print_success "Hot-reload sync for '$target' completed successfully."
        return 0
    else
        print_error "Hot-reload sync for '$target' failed with rsync status: $sync_status."
        return $sync_status
    fi
} 