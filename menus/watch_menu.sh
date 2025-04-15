#!/usr/bin/env bash

# =======================================================
# Watch Menu (Real-time Monitoring)
# =======================================================

# Show watch menu for real-time monitoring
show_watch_menu() {
    show_header
    print_section_header "Real-time Monitoring - Project: ${PROJECT_NAME}"
    
    # Get list of available containers from config/compose
    load_available_containers # Assumes this populates CONTAINER_ACTIONS
    
    print_menu_item "1" "Watch All Service Logs"
    print_menu_item "2" "Watch Main Container Logs (${MAIN_CONTAINER})"
    print_menu_item "3" "Watch Database Logs (${DB_CONTAINER_NAME})"
    print_menu_item "4" "Watch System Resources (stats, free, df)"
    print_menu_item "5" "Watch Specific Service Logs"
    print_menu_item "6" "Interactive Dashboard (tmux - experimental)"
    
    print_back_option # Usually 0
    echo ""
    
    local choice=$(get_numeric_input "Select an option: ")
    
    if [ "$RUN_REMOTE" = false ]; then
        print_error "Cannot monitor remote services in local mode."
        # Maybe offer local `docker stats`?
        if get_yes_no "Show local docker stats instead?" "n"; then
             watch -n 1 docker stats
        fi
        press_enter_to_continue
        show_main_menu
        return
    fi
    
    case $choice in
        1) # Watch all logs
            print_info "Watching logs for all services defined in compose file. Press Ctrl+C to stop..."
            run_remote_command "cd ${EFFECTIVE_DOCKER_DIR} && ${DOCKER_COMPOSE_CMD} logs -f --tail=50"
            ;; 
        2) # Watch main container
            print_info "Watching logs for main container (${MAIN_CONTAINER}). Press Ctrl+C to stop..."
            run_remote_command "cd ${EFFECTIVE_DOCKER_DIR} && ${DOCKER_COMPOSE_CMD} logs -f --tail=50 ${MAIN_CONTAINER}"
            ;; 
        3) # Watch database container
            print_info "Watching logs for database container (${DB_CONTAINER_NAME}). Press Ctrl+C to stop..."
            run_remote_command "cd ${EFFECTIVE_DOCKER_DIR} && ${DOCKER_COMPOSE_CMD} logs -f --tail=50 ${DB_CONTAINER_NAME}"
            ;; 
        4) # Watch system resources
            print_info "Watching system resources (docker stats, free, df). Press Ctrl+C to stop..."
            run_remote_command "watch -n 2 'echo \"=== DOCKER STATS ===\" && docker stats --no-stream ; echo ; echo \"=== MEMORY ===\" && free -h ; echo ; echo \"=== DISK USAGE ===\" && df -h | grep -vE \"tmpfs|overlay\"'"
            ;; 
        5) # Custom service selection
            show_header
            print_section_header "Select Services to Monitor Logs"
            
            # Show available services from CONTAINER_ACTIONS
            local counter=1
            local available_services=("${CONTAINER_ACTIONS[@]}")
            if [ ${#available_services[@]} -eq 0 ]; then
                print_error "No containers found."
                press_enter_to_continue
                show_watch_menu
                return
            fi

            for container in "${available_services[@]}"; do
                print_menu_item "$counter" "$container"
                ((counter++))
            done
            
            echo ""
            echo "Enter service numbers separated by commas (e.g., 1,3):"
            read -p "> " service_numbers
            
            # Parse service numbers
            local selected_services_str=""
            IFS=',' read -ra NUMS <<< "$service_numbers"
            for num in "${NUMS[@]}"; do
                num=$(echo "$num" | tr -d ' ')
                if [[ $num =~ ^[0-9]+$ ]]; then
                    local index=$((num - 1))
                    if [ $index -ge 0 ] && [ $index -lt ${#available_services[@]} ]; then
                        if [ -z "$selected_services_str" ]; then
                            selected_services_str="${available_services[$index]}"
                        else
                            selected_services_str="$selected_services_str ${available_services[$index]}" # Space separated for compose logs
                        fi
                    fi
                fi
            done
            
            if [ -n "$selected_services_str" ]; then
                print_info "Watching logs for services: $selected_services_str. Press Ctrl+C to stop..."
                run_remote_command "cd ${EFFECTIVE_DOCKER_DIR} && ${DOCKER_COMPOSE_CMD} logs -f --tail=50 $selected_services_str"
            else
                print_error "No valid services selected."
                press_enter_to_continue
                show_watch_menu
                return
            fi
            ;; 
        6) # Interactive Dashboard Mode (Tmux)
            if ! run_remote_command "command -v tmux" "silent" | grep -q tmux; then
                print_error "tmux is not installed on the remote server."
                print_info "Please install tmux on the server for dashboard mode (e.g., sudo apt install tmux)."
                press_enter_to_continue
                show_watch_menu
                return
            fi
            
            print_info "Starting interactive dashboard in tmux session '${PROJECT_NAME}-dashboard'."
            print_info "Press Ctrl+B then D to detach and leave it running."
            print_info "To reattach later: ssh to server and run 'tmux attach -t ${PROJECT_NAME}-dashboard'."
            
            # Basic tmux layout: Docker stats, Main container logs, DB logs, System watch
            # This can be customized further
            local tmux_cmd="tmux new-session -d -s ${PROJECT_NAME}-dashboard 'docker stats' \\; \
                split-window -v \"cd ${EFFECTIVE_DOCKER_DIR} && ${DOCKER_COMPOSE_CMD} logs -f --tail=20 ${MAIN_CONTAINER}\" \\; \
                split-window -h \"cd ${EFFECTIVE_DOCKER_DIR} && ${DOCKER_COMPOSE_CMD} logs -f --tail=20 ${DB_CONTAINER_NAME}\" \\; \
                select-pane -t 0 \\; \
                split-window -h \"watch -n 5 \\\"free -h; echo; df -h | grep -vE \\\\\"tmpfs|overlay\\\\\"\\\"\" \\; \
                attach-session -d"
            
            # Execute the command remotely (run_remote_command handles quoting issues)
            run_remote_command "$tmux_cmd"
            ;; 
        0) # Back
            show_main_menu
            return
            ;; 
        *) 
            print_error "Invalid option!"
            sleep 1
            show_watch_menu # Loop back
            ;; 
    esac
    
    press_enter_to_continue
    show_watch_menu
} 