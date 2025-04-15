#!/usr/bin/env bash

# =======================================================
# Auto-start Menu
# =======================================================

# Show auto-start menu
show_auto_start_menu() {
    show_header
    print_section_header "Auto-start Configuration - Project: ${PROJECT_NAME}"
    
    # Source the config file to show current settings
    source "${EFFECTIVE_CONFIG_DIR}/auto_start.conf" 2>/dev/null || true
    local current_auto_start="${AUTO_START_ENABLED:-true}"
    local current_auto_services="${AUTO_START_SERVICES:-all}"
    local current_auto_wait="${AUTO_START_WAIT:-10}"
    local current_auto_build="${AUTO_BUILD_ENABLED:-true}"
    local current_feedback="${AUTO_START_FEEDBACK:-minimal}"
    local current_local_auto_start="${LOCAL_AUTO_START_ENABLED:-true}"
    local current_local_auto_services="${LOCAL_AUTO_START_SERVICES:-all}"

    # Show current settings
    echo -e "Current auto-start settings (Remote):"
    echo -e "  Auto-start enabled: ${GREEN}${current_auto_start}${NC}"
    echo -e "  Services to start: ${GREEN}${current_auto_services}${NC}"
    echo -e "  Wait time: ${GREEN}${current_auto_wait}${NC} seconds"
    echo -e "  Auto-build enabled: ${GREEN}${current_auto_build}${NC}"
    echo -e "  Feedback level: ${GREEN}${current_feedback}${NC}"
    echo -e "Current auto-start settings (Local):"
    echo -e "  Local Auto-start enabled: ${GREEN}${current_local_auto_start}${NC}"
    echo -e "  Local Services to start: ${GREEN}${current_local_auto_services}${NC}"
    echo ""
    
    print_menu_item "1" "Toggle Remote Auto-start"
    print_menu_item "2" "Configure Remote Services"
    print_menu_item "3" "Set Remote Wait Time"
    print_menu_item "4" "Toggle Remote Auto-build"
    print_menu_item "5" "Set Remote Feedback Level"
    print_menu_item "6" "Toggle Local Auto-start"
    print_menu_item "7" "Configure Local Services"
    print_menu_item "8" "Save Configuration"
    print_back_option
    echo ""
    
    local choice=$(get_numeric_input "Select an option: ")
    
    # Use temporary variables to hold changes until saved
    local temp_auto_start="$current_auto_start"
    local temp_auto_services="$current_auto_services"
    local temp_auto_wait="$current_auto_wait"
    local temp_auto_build="$current_auto_build"
    local temp_feedback="$current_feedback"
    local temp_local_auto_start="$current_local_auto_start"
    local temp_local_auto_services="$current_local_auto_services"

    case $choice in
        1) # Toggle Remote Auto-start
            if [ "${temp_auto_start}" = "true" ]; then
                temp_auto_start="false"
                print_info "Remote auto-start will be disabled (on save)"
            else
                temp_auto_start="true"
                print_info "Remote auto-start will be enabled (on save)"
            fi
            # Update the display immediately for feedback
            current_auto_start="$temp_auto_start"
            press_enter_to_continue
            show_auto_start_menu
            ;; 
        2) # Configure Remote Services
            echo "Select REMOTE services to auto-start:"
            echo "1. All services"
            echo "2. No services"
            echo "3. Custom selection (from containers: ${CONTAINER_LIST[@]})"
            local service_choice=$(get_numeric_input "Select an option: ")
            
            case $service_choice in
                1) temp_auto_services="all" ;;
                2) temp_auto_services="none" ;;
                3)
                    # Get available services (use CONTAINER_LIST from config)
                    local available_services=("${CONTAINER_LIST[@]}") 
                    
                    echo "Available remote services:"
                    local counter=1
                    for container in "${available_services[@]}"; do
                        echo "${counter}. $container"
                        ((counter++))
                    done
                    
                    echo "Enter service numbers separated by commas:"
                    read -p "> " service_numbers
                    
                    # Convert numbers to service names
                    local selected_services=""
                    IFS=',' read -ra NUMS <<< "$service_numbers"
                    for num in "${NUMS[@]}"; do
                        num=$(echo "$num" | tr -d ' ')
                        if [[ $num =~ ^[0-9]+$ ]]; then
                            local index=$((num - 1))
                            if [ $index -ge 0 ] && [ $index -lt ${#available_services[@]} ]; then
                                if [ -z "$selected_services" ]; then
                                    selected_services="${available_services[$index]}"
                                else
                                    selected_services="$selected_services,${available_services[$index]}"
                                fi
                            fi
                        fi
                    done
                    
                    if [ -n "$selected_services" ]; then
                        temp_auto_services="$selected_services"
                    else
                        print_error "No valid services selected"
                        temp_auto_services="none"
                    fi
                    ;;
                *) temp_auto_services="$current_auto_services" ;; # Keep current on invalid input
            esac
            
            print_info "Remote services to auto-start will be set to: ${temp_auto_services} (on save)"
            current_auto_services="$temp_auto_services"
            press_enter_to_continue
            show_auto_start_menu
            ;; 
        3) # Set Remote Wait Time
            temp_auto_wait=$(get_numeric_input "Enter remote wait time in seconds: ")
            print_info "Remote wait time will be set to ${temp_auto_wait} seconds (on save)"
            current_auto_wait="$temp_auto_wait"
            press_enter_to_continue
            show_auto_start_menu
            ;; 
        4) # Toggle Remote Auto-build
            if [ "${temp_auto_build}" = "true" ]; then
                temp_auto_build="false"
                print_info "Remote auto-build will be disabled (on save)"
            else
                temp_auto_build="true"
                print_info "Remote auto-build will be enabled (on save)"
            fi
            current_auto_build="$temp_auto_build"
            press_enter_to_continue
            show_auto_start_menu
            ;; 
        5) # Set Remote Feedback Level
            echo "Select remote feedback level:"
            echo "1. None - No feedback during auto-start"
            echo "2. Minimal - Basic status information"
            echo "3. Verbose - Detailed logs and status"
            local feedback_choice=$(get_numeric_input "Select an option: ")
            
            case $feedback_choice in
                1) temp_feedback="none" ;;
                2) temp_feedback="minimal" ;;
                3) temp_feedback="verbose" ;;
                *) print_error "Invalid option, keeping current"; temp_feedback="$current_feedback" ;; 
            esac
            
            print_info "Remote feedback level will be set to: ${temp_feedback} (on save)"
            current_feedback="$temp_feedback"
            press_enter_to_continue
            show_auto_start_menu
            ;; 
        6) # Toggle Local Auto-start
             if [ "${temp_local_auto_start}" = "true" ]; then
                 temp_local_auto_start="false"
                 print_info "Local auto-start will be disabled (on save)"
             else
                 temp_local_auto_start="true"
                 print_info "Local auto-start will be enabled (on save)"
             fi
             current_local_auto_start="$temp_local_auto_start"
             press_enter_to_continue
             show_auto_start_menu
             ;; 
        7) # Configure Local Services
            echo "Select LOCAL services to auto-start:"
            echo "1. All services"
            echo "2. No services"
            echo "3. Custom selection (from containers: ${CONTAINER_LIST[@]})"
            local local_service_choice=$(get_numeric_input "Select an option: ")
            
            case $local_service_choice in
                1) temp_local_auto_services="all" ;;
                2) temp_local_auto_services="none" ;;
                3)
                    local available_services=("${CONTAINER_LIST[@]}")
                    echo "Available local services:"
                    local counter=1
                    for container in "${available_services[@]}"; do echo "${counter}. $container"; ((counter++)); done
                    echo "Enter service numbers separated by commas:"
                    read -p "> " service_numbers
                    local selected_services=""
                    IFS=',' read -ra NUMS <<< "$service_numbers"
                    for num in "${NUMS[@]}"; do
                        num=$(echo "$num" | tr -d ' ')
                        if [[ $num =~ ^[0-9]+$ ]]; then
                            local index=$((num - 1))
                            if [ $index -ge 0 ] && [ $index -lt ${#available_services[@]} ]; then
                                if [ -z "$selected_services" ]; then selected_services="${available_services[$index]}"; else selected_services="$selected_services,${available_services[$index]}"; fi
                            fi
                        fi
                    done
                    if [ -n "$selected_services" ]; then temp_local_auto_services="$selected_services"; else print_error "No valid services selected"; temp_local_auto_services="none"; fi
                    ;;
                 *) temp_local_auto_services="$current_local_auto_services" ;; 
            esac
            
            print_info "Local services to auto-start will be set to: ${temp_local_auto_services} (on save)"
            current_local_auto_services="$temp_local_auto_services"
            press_enter_to_continue
            show_auto_start_menu
            ;; 
        8) # Save Configuration
            # Call the generic save function with all temp values
            save_auto_start_config "${temp_auto_start}" "${temp_auto_services}" "${temp_feedback}" "${temp_auto_build}" "${temp_auto_wait}" "${temp_local_auto_start}" "${temp_local_auto_services}"
            print_success "Configuration saved!"
            press_enter_to_continue
            show_auto_start_menu
            ;; 
        0) # Back
            show_main_menu # Or Deployment Menu depending on where it's called from
            ;; 
        *) 
            print_error "Invalid option"
            press_enter_to_continue
            show_auto_start_menu
            ;; 
    esac
} 