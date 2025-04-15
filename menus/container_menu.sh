#!/usr/bin/env bash

# =======================================================
# Container Menu
# =======================================================

# Show container management menu
show_container_menu() {
    # Get list of available containers from config/compose
    load_available_containers # Assumes this populates CONTAINER_ACTIONS
    
    show_header
    print_section_header "Container Management - Project: ${PROJECT_NAME}"
    
    print_menu_item "1" "Start All Containers"
    print_menu_item "2" "Stop All Containers"
    print_menu_item "3" "Restart All Containers"
    print_menu_item "4" "Rebuild All Containers"
    print_menu_item "5" "Show Container Status (docker compose ps)"
    echo ""
    print_section_header "Individual Container Management"
    
    # Show numbered options for each container found
    local counter=6
    if [ ${#CONTAINER_ACTIONS[@]} -gt 0 ]; then
        for container in "${CONTAINER_ACTIONS[@]}"; do
            print_menu_item "$counter" "Manage ${container} container"
            ((counter++))
        done
    else
        print_warning "No containers found or defined in CONTAINER_NAMES."
    fi
    
    echo ""
    print_back_option # Usually 0
    echo ""
    
    local choice=$(get_numeric_input "Select an option: ")
    
    case "$choice" in
        1) manage_all_containers "start" ;; # Generic functions
        2) manage_all_containers "stop" ;;  # Generic functions
        3) manage_all_containers "restart" ;;# Generic functions
        4) rebuild_containers ;;         # Generic functions
        5) show_container_status ;;      # Generic functions
        0) show_main_menu ;;             # Back to main
        *) 
            # Check if a container option was selected
            local container_index=$((choice - 6))
            if [ "$container_index" -ge 0 ] && [ "$container_index" -lt "${#CONTAINER_ACTIONS[@]}" ]; then
                local selected_container="${CONTAINER_ACTIONS[$container_index]}"
                manage_single_container "$selected_container"
            else
                print_error "Invalid option!"
                sleep 1
                show_container_menu
            fi
            ;;
    esac
}

# Show individual container management menu - Generic
manage_single_container() {
    local container="$1"
    show_header
    
    print_section_header "Managing Container: ${container}"
    print_menu_item "1" "Start container"
    print_menu_item "2" "Stop container"
    print_menu_item "3" "Restart container"
    print_menu_item "4" "View logs" # Calls generic view_container_logs_generic
    print_menu_item "5" "Rebuild container" # Calls generic rebuild_single_container
    print_menu_item "6" "Execute command in container" # Calls generic execute_in_container
    print_back_option
    echo ""
    
    local choice=$(get_numeric_input "Select an option: ")
    
    # No local mode check needed here, handled in the functions called

    case "$choice" in
        1) container_action "$container" "start" ;;   # Generic
        2) container_action "$container" "stop" ;;    # Generic
        3) container_action "$container" "restart" ;;  # Generic
        4) view_container_logs_generic "$container" ;; # Call generic log view
        5) rebuild_single_container "$container" ;; # Generic
        6) execute_in_container "$container" ;;      # Generic
        0) show_container_menu; return ;; # Back to container menu
        *) print_error "Invalid option" ;;
    esac
    
    press_enter_to_continue
    manage_single_container "$container" # Loop back to this menu
} 