#!/usr/bin/env bash

# =======================================================
# Main Menu
# =======================================================

# Show main menu
show_main_menu() {
    show_header
    
    # Check if this is a first run/setup situation
    local is_first_setup=false
    
    # Run a check to see if Docker files exist on remote server
    if [ "$RUN_REMOTE" = false ]; then
        if ! run_remote_command "test -d ${DOCKER_DIR}" "silent"; then
            is_first_setup=true
        fi
        
        if ! run_remote_command "test -f ${DOCKER_DIR}/docker-compose.yml" "silent"; then
            is_first_setup=true
        fi
    fi
    
    if [ "$is_first_setup" = true ]; then
        print_section_header "Initial Setup Required"
        print_info "It appears this is your first time running the Application Center for project: ${PROJECT_NAME}."
        print_info "Let's set up the environment on your remote server."
        echo ""
        
        print_menu_item "1" "Run Initial Setup (creates directories and copies files)"
        print_menu_item "2" "Configure Settings"
        print_menu_item "3" "Advanced Menu (skip setup)"
        print_menu_item "0" "Exit"
        
        echo ""
        
        local choice=$(get_numeric_input "Select an option: ")
        
        case $choice in
            1)
                run_initial_setup
                ;;
            2)
                configure_settings
                show_main_menu
                ;;
            3)
                show_regular_menu
                ;;
            0)
                clear
                echo "Exiting. Goodbye!"
                exit 0
                ;;
            *)
                print_error "Invalid option"
                press_enter_to_continue
                show_main_menu
                ;;
        esac
    else
        show_regular_menu
    fi
}

# Show regular main menu (when already set up)
show_regular_menu() {
    print_section_header "Main Menu - Project: ${PROJECT_NAME}"
    print_menu_item "1" "Deployment Tools"
    print_menu_item "2" "Container Management"
    print_menu_item "3" "Testing Tools"
    print_menu_item "4" "Database Tools" 
    print_menu_item "5" "Development Tools"
    print_menu_item "6" "Projektkonfiguration bearbeiten (öffnet Editor)"
    print_menu_item "7" "Manage Environment Files"
    print_menu_item "8" "View Logs"
    print_menu_item "9" "Real-time Monitoring"
    print_menu_item "0" "Exit"
    
    echo ""
    
    local choice=$(get_numeric_input "Select an option: ")
    
    case $choice in
        1)
            show_deployment_menu
            ;;
        2)
            show_container_menu
            ;;
        3)
            show_testing_menu
            ;;
        4)
            show_database_menu
            ;;
        5)
            show_development_menu
            ;;
        6)
            edit_project_config
            show_main_menu
            ;;
        7)
            show_env_files_menu
            ;;
        8)
            show_logs_menu
            ;;
        9)
            show_watch_menu
            ;;
        0)
            clear
            echo "Exiting. Goodbye!"
            exit 0
            ;;
        *)
            print_error "Invalid option"
            press_enter_to_continue
            show_main_menu
            ;;
    esac
}

# Run initial setup to properly configure the remote server
run_initial_setup() {
    clear
    print_section_header "Initial Setup for Project: ${PROJECT_NAME}"
    
    print_info "Setting up the Application Environment on your remote server..."
    
    # Check if server is accessible
    if ! check_ssh_connection; then
        print_error "Cannot connect to server. Please check your connection settings."
        
        if get_yes_no "Would you like to configure connection settings now?"; then
            configure_settings
            
            # Try again
            if ! check_ssh_connection; then
                print_error "Still cannot connect to server."
                return 1
            fi
        else
            return 1
        fi
    fi
    
    # Check if Docker is installed on remote server
    print_info "Checking for Docker installation..."
    if ! run_remote_command "command -v docker" "silent" | grep -q docker; then
        print_error "Docker is not installed on the remote server."
        print_info "Please install Docker on your server before continuing."
        return 1
    else
        print_success "Docker is installed on the remote server."
    fi
    
    # Check if Docker Compose is installed
    print_info "Checking for Docker Compose installation..."
    if ! run_remote_command "command -v docker compose" "silent" | grep -q docker; then
        print_warning "Docker Compose V2 not found, checking for docker-compose..."
        
        if ! run_remote_command "command -v docker-compose" "silent" | grep -q docker-compose; then
            print_error "Docker Compose is not installed on the remote server."
            print_info "Please install Docker Compose on your server before continuing."
            return 1
        else
            print_success "Docker Compose V1 is installed on the remote server."
            print_info "Consider upgrading to Docker Compose V2 for better performance."
            # Update DOCKER_COMPOSE_CMD for V1
            export DOCKER_COMPOSE_CMD="docker-compose"
        fi
    else
        print_success "Docker Compose V2 is installed on the remote server."
    fi
    
    # 1. Create necessary directories on remote server with proper permissions
    print_info "Creating directory structure with proper permissions..."
    run_remote_command "mkdir -p ${SERVER_PROJECT_DIR}/{docker,backups,utils/config} && chmod -R 775 ${SERVER_PROJECT_DIR}"
    
    # 2. Copy Docker configuration files
    print_info "Copying Docker configuration files..."
    if [ -d "${LOCAL_GIT_DIR}/docker" ]; then
        # First ensure the target directory has proper permissions
        run_remote_command "mkdir -p ${SERVER_PROJECT_DIR}/docker && chmod -R 775 ${SERVER_PROJECT_DIR}/docker"
        # Copy the files
        scp -r "${LOCAL_GIT_DIR}/docker/"* "${SERVER_USER}@${SERVER_HOST}:${SERVER_PROJECT_DIR}/docker/"
        
        # Copy .env file if it exists
        if [ -f "${LOCAL_GIT_DIR}/.env" ]; then
            print_info "Copying main .env file from project root..."
            scp "${LOCAL_GIT_DIR}/.env" "${SERVER_USER}@${SERVER_HOST}:${SERVER_PROJECT_DIR}/.env"
        fi
        
        if [ -f "${LOCAL_GIT_DIR}/docker/.env" ]; then
            print_info "Copying docker/.env file..."
            scp "${LOCAL_GIT_DIR}/docker/.env" "${SERVER_USER}@${SERVER_HOST}:${SERVER_PROJECT_DIR}/docker/.env"
        fi
    else
        print_error "Local docker directory not found at ${LOCAL_GIT_DIR}/docker"
        print_info "Creating empty Docker directory structure..."
        run_remote_command "mkdir -p ${SERVER_PROJECT_DIR}/docker && chmod -R 775 ${SERVER_PROJECT_DIR}/docker"
    fi
    
    # 3. Copy application files (Commented out/Skipped)
    # print_info "Copying application files..."
    # if [ -d "${LOCAL_GIT_DIR}/app" ]; then
    #     # First ensure the target directory has proper permissions
    #     # Remove app-specific paths like {bot,web,postgres}
    #     run_remote_command "mkdir -p ${SERVER_PROJECT_DIR}/app && chmod -R 775 ${SERVER_PROJECT_DIR}/app"
    #     # Copy the files
    #     scp -r "${LOCAL_GIT_DIR}/app/"* "${SERVER_USER}@${SERVER_HOST}:${SERVER_PROJECT_DIR}/app/"
    # else
    #     print_error "Local app directory not found at ${LOCAL_GIT_DIR}/app"
    #     # print_info "Creating empty app directory structure..."
    #     # run_remote_command "mkdir -p ${SERVER_PROJECT_DIR}/app && chmod -R 775 ${SERVER_PROJECT_DIR}/app"
    # fi
    print_info "Skipping app directory deployment (not needed for this stack)."
    
    # 4. Check if we have .env files, create them if needed
    local need_env_setup=true
    
    # Check if the main .env file was copied earlier (check project root first)
    if run_remote_command "test -f ${SERVER_PROJECT_DIR}/.env" "silent"; then
        print_success ".env file found in project root (${SERVER_PROJECT_DIR})"
        need_env_setup=false
        
        # Copy to docker directory as well if it doesn't exist there
        local server_docker_dir="${SERVER_PROJECT_DIR}/docker"
        if ! run_remote_command "test -f ${server_docker_dir}/.env" "silent"; then
            print_info "Copying .env file to Docker directory (${server_docker_dir})..."
            run_remote_command "cp ${SERVER_PROJECT_DIR}/.env ${server_docker_dir}/.env"
        fi
    elif run_remote_command "test -f ${SERVER_PROJECT_DIR}/docker/.env" "silent"; then
        local server_docker_dir="${SERVER_PROJECT_DIR}/docker"
        print_success ".env file found in Docker directory (${server_docker_dir})"
        need_env_setup=false
        
        # Copy to project root as well if it doesn't exist there
        if ! run_remote_command "test -f ${SERVER_PROJECT_DIR}/.env" "silent"; then
             print_info "Copying .env file to project root (${SERVER_PROJECT_DIR})..."
             run_remote_command "cp ${server_docker_dir}/.env ${SERVER_PROJECT_DIR}/.env"
        fi
    fi
    
    # Ask if user wants to create .env files if they don't exist
    if [ "$need_env_setup" = true ]; then
        if get_yes_no "No .env file found. Would you like to create one now from the template?"; then
            # Call the generic template function
            create_project_templates # Assumes this creates ./templates/env.template
            # Offer to upload the template as .env
            if [ -f "./templates/env.template" ]; then
                 if get_yes_no "Upload the generated template (./templates/env.template) as .env to the server project root?"; then
                     # Upload to project root
                     scp "./templates/env.template" "${SERVER_USER}@${SERVER_HOST}:${SERVER_PROJECT_DIR}/.env"
                     # Also copy to docker dir on server
                     local server_docker_dir="${SERVER_PROJECT_DIR}/docker"
                     run_remote_command "cp ${SERVER_PROJECT_DIR}/.env ${server_docker_dir}/.env"
                     print_success ".env file uploaded and copied to docker directory."
                     print_warning "Remember to edit the server's .env file with your actual secrets!"
                 else
                     print_warning "No .env file created on server. You'll need to create one manually."
                 fi
            else
                 print_error "Template file ./templates/env.template not found locally."
            fi
        else
            print_warning "No .env file created. You'll need to create one manually before starting services."
        fi
    fi
    
    # 5. Initialize auto-start configuration
    print_info "Setting up auto-start configuration..."
    # Load defaults before asking
    local current_auto_start="${AUTO_START_ENABLED:-true}"
    local current_auto_services="${AUTO_START_SERVICES:-all}"
    local current_feedback="${AUTO_START_FEEDBACK:-minimal}"
    local current_auto_build="${AUTO_BUILD_ENABLED:-true}"
    local current_auto_wait="${AUTO_START_WAIT:-10}"
    local current_local_auto_start="${LOCAL_AUTO_START_ENABLED:-true}"
    local current_local_auto_services="${LOCAL_AUTO_START_SERVICES:-all}"

    if get_yes_no "Do you want to configure auto-start options now? (Current: Enabled=${current_auto_start})" "y"; then
        # Use the dedicated auto_start_menu function for configuration
        show_auto_start_menu # This function should handle saving
        # Re-load the config after the menu potentially saves it
        source "${EFFECTIVE_CONFIG_DIR}/auto_start.conf" 2>/dev/null || true
    else
         print_info "Keeping existing auto-start settings (or defaults)."
         # Ensure default config is saved if none exists
         if ! run_remote_command "test -f ${EFFECTIVE_CONFIG_DIR}/auto_start.conf" "silent"; then
              print_info "No remote auto_start.conf found, saving defaults..."
              save_auto_start_config "$current_auto_start" "$current_auto_services" "$current_feedback" "$current_auto_build" "$current_auto_wait" "$current_local_auto_start" "$current_local_auto_services"
         fi
    fi
    
    # 6. Ask if user wants to build and start containers
    if get_yes_no "Would you like to build and start the containers now?"; then
        print_info "Building and starting containers..."
        run_partial_deploy
    fi
    
    print_success "Initial setup completed for project: ${PROJECT_NAME}!"
    print_info "You can now use the main menu to manage your application."
    
    press_enter_to_continue
    show_main_menu
}

# Function to open project_config.sh in an editor
edit_project_config() {
    local config_file="./utils/config/project_config.sh"
    local editor=""

    # Check for preferred editors
    if command -v nano >/dev/null 2>&1; then
        editor="nano"
    elif command -v vim >/dev/null 2>&1; then
        editor="vim"
    elif command -v vi >/dev/null 2>&1; then
        editor="vi"
    elif [ -n "$EDITOR" ]; then # Check environment variable
        editor="$EDITOR"
    else
        print_error "Could not find a suitable text editor (nano, vim, vi)."
        print_info "Please edit '${config_file}' manually."
        press_enter_to_continue
        return 1
    fi

    if [ ! -f "$config_file" ]; then
        print_error "Configuration file not found: ${config_file}"
        print_info "Ensure the project setup has been run or the file exists."
        press_enter_to_continue
        return 1
    fi

    clear
    print_section_header "Projektkonfiguration bearbeiten"
    print_info "Öffne ${config_file} mit ${editor}..."
    echo "Bitte bearbeite die Datei, speichere deine Änderungen und schließe den Editor."
    press_enter_to_continue

    # Run the editor
    ${editor} "${config_file}"

    # Check if the file still exists after editing (user might delete it)
    if [ ! -f "$config_file" ]; then
         print_warning "Configuration file ${config_file} seems to be missing after editing."
         press_enter_to_continue
         return 1
    fi

    print_info "Editor geschlossen. Lade Konfiguration neu..."
    # Re-source the main config loader which sources project_config.sh
    # Reset CONFIG_LOADED flag to allow re-sourcing
    unset CONFIG_LOADED 
    source "./utils/config/config.sh"
    
    if [ -z "$CONFIG_LOADED" ]; then
         print_error "Konnte die Konfiguration nach dem Bearbeiten nicht neu laden!"
    else
         print_success "Konfiguration neu geladen."
    fi
    press_enter_to_continue
}
