#!/usr/bin/env bash

# =======================================================
# Logs Menu
# =======================================================

# Show logs menu
show_logs_menu() {
    show_header
    
    print_section_header "Logs Menu - Project: ${PROJECT_NAME}"
    print_menu_item "1" "View Main Container Logs (${MAIN_CONTAINER})"
    print_menu_item "2" "View Database Logs (${DB_CONTAINER_NAME})"
    
    # Dynamically add other containers from CONTAINER_LIST
    local counter=3
    local other_containers=()
    for container in "${CONTAINER_LIST[@]}"; do
        if [[ "$container" != "${MAIN_CONTAINER}" && "$container" != "${DB_CONTAINER_NAME}" ]]; then
            print_menu_item "$counter" "View ${container} Logs"
            other_containers+=("$container") # Store name for later use
            ((counter++))
        fi
    done

    # Add system/docker logs after dynamic entries
    local system_log_opt=$counter
    print_menu_item "$system_log_opt" "View System Logs (journalctl)"
    ((counter++))
    local docker_log_opt=$counter
    print_menu_item "$docker_log_opt" "View Docker Daemon Logs (journalctl)"
    ((counter++))
    local download_log_opt=$counter
    print_menu_item "$download_log_opt" "Download All Container Logs"
    print_back_option # Usually 0
    echo ""
    
    local choice=$(get_numeric_input "Select an option: ")
    
    case "$choice" in
        1) view_main_container_logs ;; # Generic function
        2) view_db_logs ;; # Generic function
        0) show_main_menu ;; # Back
        *) 
            # Check if it matches system/docker/download options first
            if [ "$choice" -eq "$system_log_opt" ]; then
                view_system_logs
            elif [ "$choice" -eq "$docker_log_opt" ]; then
                view_docker_logs
            elif [ "$choice" -eq "$download_log_opt" ]; then
                download_logs # Generic function
            else
                # Check if it's one of the dynamically added containers
                local dynamic_choice_index=$((choice - 3))
                if [ "$dynamic_choice_index" -ge 0 ] && [ "$dynamic_choice_index" -lt "${#other_containers[@]}" ]; then
                    local container_to_view="${other_containers[$dynamic_choice_index]}"
                    view_specific_container_logs "$container_to_view" # Generic function
                else
                    print_error "Invalid option!"
                    sleep 1
                    show_logs_menu
                fi
            fi
            ;;
    esac
} 