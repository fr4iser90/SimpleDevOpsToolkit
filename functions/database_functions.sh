#!/usr/bin/env bash

# =======================================================
# Database Functions (Generic)
# =======================================================
# Relies on DB_* variables from project_config.sh:
# DB_TYPE, DB_CONTAINER_NAME, DB_NAME, DB_USER
# DB_DUMP_COMMAND_TEMPLATE, DB_RESTORE_COMMAND_TEMPLATE
# DB_DROP_COMMAND_TEMPLATE, DB_CREATE_COMMAND_TEMPLATE
# DB_MIGRATION_COMMAND, DB_BACKUP_DIR

# Run Database migration (if configured)
run_database_migration() {
    clear
    print_section_header "Database Migration"

    if [ "$RUN_REMOTE" = false ]; then
        print_error "Cannot apply migration in local mode"
        return 1
    fi

    if [ -z "${DB_MIGRATION_COMMAND}" ]; then
        print_info "No DB_MIGRATION_COMMAND configured in project_config.sh. Skipping."
        return 0
    fi

    print_info "Running database migration command inside container ${DB_CONTAINER_NAME}..."
    print_info "Command: ${DB_MIGRATION_COMMAND}"

    # Execute the command within the DB container
    run_remote_command "docker exec ${DB_CONTAINER_NAME} sh -c '${DB_MIGRATION_COMMAND}'"
    local exit_code=$?

    if [ $exit_code -eq 0 ]; then
        print_success "Database migration command executed successfully."
    else
        print_error "Database migration command failed with exit code ${exit_code}."
    fi
    return $exit_code
}

# Update remote database (placeholder - might be same as migration?)
# Keeping the function signature for now, but it might be redundant
update_remote_database() {
    print_warning "'update_remote_database' function is potentially redundant. Use 'run_database_migration'."
    run_database_migration
    return $?
}

# Backup database (Generic)
backup_database() {
    show_header
    print_section_header "Database Backup"

    if [ "${DB_TYPE:-none}" == "none" ]; then print_error "DB_TYPE is 'none' or not set. Cannot perform DB backup."; return 1; fi
    if [ -z "${DB_CONTAINER_NAME}" ]; then print_error "DB_CONTAINER_NAME not set."; return 1; fi
    if [ -z "${DB_DUMP_COMMAND_TEMPLATE}" ]; then print_error "DB_DUMP_COMMAND_TEMPLATE not set."; return 1; fi

    if [ "$RUN_REMOTE" = false ]; then print_error "Cannot backup database in local mode"; return 1; fi

    export DB_BACKUP_DIR="${DB_BACKUP_DIR:-${EFFECTIVE_PROJECT_DIR}/backups}"
    run_remote_command "mkdir -p ${DB_BACKUP_DIR}"

    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_name="${PROJECT_NAME}_${DB_NAME}_backup_${timestamp}.sql" # Assume .sql for now, might need config
    local remote_backup_path="${DB_BACKUP_DIR}/${backup_name}"

    print_info "Creating database backup: ${backup_name}"
    # Evaluate the template to get the final command
    local dump_command=$(eval echo "${DB_DUMP_COMMAND_TEMPLATE}")

    print_info "Executing dump command inside ${DB_CONTAINER_NAME}..."
    # Execute the dump command, redirecting output to the backup file on the host
    run_remote_command "docker exec ${DB_CONTAINER_NAME} sh -c '${dump_command}' > ${remote_backup_path}"
    local exit_code=$?

    if [ $exit_code -ne 0 ]; then
        print_error "Database backup command failed! Exit code: ${exit_code}."
        run_remote_command "rm -f ${remote_backup_path}" # Clean up failed backup file
        return 1
    fi

    # Ask if user wants to download backup (rest is same)
    if get_yes_no "Do you want to download the backup to your local machine?"; then
        mkdir -p "./backups"
        print_info "Downloading backup..."
        scp "${SERVER_USER}@${SERVER_HOST}:${remote_backup_path}" "./backups/"
        if [ $? -eq 0 ]; then print_success "Backup downloaded successfully to ./backups/${backup_name}"; else print_error "Failed to download backup"; fi
    fi

    print_success "Database backup completed successfully!"
    return 0
}

# Restore database (Generic)
restore_database() {
    show_header
    print_section_header "Database Restore"

    if [ "${DB_TYPE:-none}" == "none" ]; then print_error "DB_TYPE is 'none' or not set. Cannot restore DB."; return 1; fi
    if [ -z "${DB_CONTAINER_NAME}" ]; then print_error "DB_CONTAINER_NAME not set."; return 1; fi
    if [ -z "${DB_DROP_COMMAND_TEMPLATE}" ]; then print_error "DB_DROP_COMMAND_TEMPLATE not set."; return 1; fi
    if [ -z "${DB_CREATE_COMMAND_TEMPLATE}" ]; then print_error "DB_CREATE_COMMAND_TEMPLATE not set."; return 1; fi
    if [ -z "${DB_RESTORE_COMMAND_TEMPLATE}" ]; then print_error "DB_RESTORE_COMMAND_TEMPLATE not set (must accept data via stdin)."; return 1; fi

    if [ "$RUN_REMOTE" = false ]; then print_error "Cannot restore database in local mode"; return 1; fi

    export DB_BACKUP_DIR="${DB_BACKUP_DIR:-${EFFECTIVE_PROJECT_DIR}/backups}"
    local backup_file=""
    local backup_source_path=""
    local uploaded_temp_path=""

    # List available backups (same logic as before)
    print_info "Available backups on server:"
    local available_backups=$(run_remote_command "ls -1tr ${DB_BACKUP_DIR}/${PROJECT_NAME}_${DB_NAME}_backup_*.sql 2>/dev/null || echo 'No backups found'" "true") # List newest last

    if [[ "$available_backups" == "No backups found" ]]; then
        print_info "No remote backups found."
        if [ -d "./backups" ] && [ "$(ls -A ./backups/*.sql 2>/dev/null)" ]; then
            print_info "Available local backups (in ./backups/):"
            ls -1tr ./backups/${PROJECT_NAME}_${DB_NAME}_backup_*.sql
            read -p "Enter the name of the local backup file to upload and restore: " local_backup
            if [ -f "./backups/${local_backup}" ]; then
                backup_file="${local_backup}"
                backup_source_path="./backups/${local_backup}"
                uploaded_temp_path="${DB_BACKUP_DIR}/${backup_file}" # Target path for upload
                print_info "Uploading backup ${backup_file} to ${uploaded_temp_path}..."
                scp "${backup_source_path}" "${SERVER_USER}@${SERVER_HOST}:${uploaded_temp_path}"
                if [ $? -ne 0 ]; then print_error "Failed to upload backup."; return 1; fi
                backup_source_path="${uploaded_temp_path}" # Restore from uploaded path
            else
                print_error "Local backup file not found."; return 1
            fi
        else
            print_error "No suitable backups found locally or remotely."; return 1
        fi
    else
        echo "${available_backups}"
        read -p "Enter the name of the server backup file to restore: " backup_file
        backup_source_path="${DB_BACKUP_DIR}/${backup_file}"
        if ! run_remote_command "test -f ${backup_source_path}" "true"; then
            print_error "Remote backup file not found: ${backup_source_path}"; return 1
        fi
    fi

    if ! get_confirmed_input "⚠️ This will OVERWRITE the current '${DB_NAME}' database. Are you sure?" "yes"; then
        print_info "Restore cancelled."
        # Clean up uploaded file if necessary
        [ -n "$uploaded_temp_path" ] && run_remote_command "rm -f ${uploaded_temp_path}"
        return 0
    fi

    print_info "Restoring database from ${backup_file}..."

    # Stop relevant containers (e.g., MAIN_CONTAINER or others depending on DB)
    # This needs careful consideration based on the actual stack dependencies
    print_warning "Stopping main container (${MAIN_CONTAINER}) before restore..."
    run_remote_command "cd ${EFFECTIVE_DOCKER_DIR} && ${DOCKER_COMPOSE_CMD} stop ${MAIN_CONTAINER}"

    # Evaluate command templates
    local drop_command=$(eval echo "${DB_DROP_COMMAND_TEMPLATE}")
    local create_command=$(eval echo "${DB_CREATE_COMMAND_TEMPLATE}")
    local restore_command=$(eval echo "${DB_RESTORE_COMMAND_TEMPLATE}")

    print_info "Executing Drop DB command..."
    run_remote_command "docker exec ${DB_CONTAINER_NAME} sh -c '${drop_command}'"
    # Ignore error code for drop, as DB might not exist

    print_info "Executing Create DB command..."
    run_remote_command "docker exec ${DB_CONTAINER_NAME} sh -c '${create_command}'"
    if [ $? -ne 0 ]; then print_error "Failed to create database!"; run_remote_command "cd ${EFFECTIVE_DOCKER_DIR} && ${DOCKER_COMPOSE_CMD} start ${MAIN_CONTAINER}"; return 1; fi

    print_info "Executing Restore DB command (piping data from ${backup_source_path})..."
    # Pipe the backup file content into the restore command executed inside the container
    run_remote_command "cat ${backup_source_path} | docker exec -i ${DB_CONTAINER_NAME} sh -c '${restore_command}'"
    local restore_exit_code=$?

    # Clean up uploaded file if necessary
    [ -n "$uploaded_temp_path" ] && run_remote_command "rm -f ${uploaded_temp_path}"

    if [ $restore_exit_code -ne 0 ]; then
        print_error "Database restore command failed! Exit code: ${restore_exit_code}."
        # Attempt to restart container anyway? Or leave stopped?
        print_info "Restarting main container (${MAIN_CONTAINER}) despite restore failure..."
        run_remote_command "cd ${EFFECTIVE_DOCKER_DIR} && ${DOCKER_COMPOSE_CMD} start ${MAIN_CONTAINER}"
        return 1
    fi

    # Restart the main container
    print_info "Restarting main container (${MAIN_CONTAINER})..."
    run_remote_command "cd ${EFFECTIVE_DOCKER_DIR} && ${DOCKER_COMPOSE_CMD} start ${MAIN_CONTAINER}"

    print_success "Database restored successfully!"
    return 0
} 