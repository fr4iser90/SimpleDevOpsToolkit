#!/usr/bin/env bash

# =======================================================
# Deployment Menu
# =======================================================

# Show deployment menu
show_deployment_menu() {
    show_header
    print_section_header "Deployment Menu - Project: ${PROJECT_NAME}"
    
    print_menu_item "1" "Quick Deploy - Deploy with .env preservation (SAFE, preserves persistent data)"
    print_menu_item "2" "Quick Deploy with Auto-Start (preserves data, uses auto-start config)"
    print_menu_item "3" "Partial Deploy - Rebuild containers only (SAFE, preserves persistent data)"
    print_menu_item "4" "Check Services - Verify running services listed in config"
    print_menu_item "5" "Update Docker Configuration - Update Docker files & restart"
    print_menu_item "6" "Check Docker Files - Verify config files exist"
    print_menu_item "7" "Configure Auto-start Settings"
    echo ""
    print_section_header "⚠️ DANGER ZONE - DATA LOSS OPTIONS ⚠️"
    print_menu_item "8" "FULL RESET DEPLOY - Complete deployment with persistent data reset (WILL DELETE ALL DATA IN VOLUMES)"
    print_menu_item "9" "FULL RESET + VOLUME REMOVAL - Complete reset including all volumes (WILL DELETE EVERYTHING)"
    print_back_option
    echo ""
    
    local choice=$(get_numeric_input "Select an option: ")
    
    case $choice in
        1)
            run_quick_deploy # Generic function
            press_enter_to_continue
            show_deployment_menu
            ;;
        2)
            run_quick_deploy_with_auto_start # Generic function
            press_enter_to_continue
            show_deployment_menu
            ;;
        3)
            run_partial_deploy # Generic function
            press_enter_to_continue
            show_deployment_menu
            ;;
        4)
            check_services # Generic function
            press_enter_to_continue
            show_deployment_menu
            ;;
        5)
            update_docker_config # Generic function
            press_enter_to_continue
            show_deployment_menu
            ;;
        6)
            check_docker_files # Generic function
            press_enter_to_continue
            show_deployment_menu
            ;;
        7)
            show_auto_start_menu # Generic menu
            ;;
        8)
            # Extra warning for data-destroying option
            clear
            print_section_header "⚠️ DANGER: FULL RESET DEPLOYMENT ⚠️"
            print_error "This will COMPLETELY ERASE your persistent data (database, models, etc.)!"
            print_error "This action CANNOT be undone unless you have a backup!"
            echo ""
            
            if get_confirmed_input "Are you absolutely sure you want to DELETE ALL PERSISTENT DATA for ${PROJECT_NAME}?" "DELETE-ALL-DATA"; then
                if get_yes_no "Would you like to create a backup before proceeding (if supported)?"; then
                    backup_database # Call generic backup
                fi
                run_full_reset_deploy # Generic function
            else
                print_info "Full reset deployment cancelled"
            fi
            
            press_enter_to_continue
            show_deployment_menu
            ;;
        9)
            # Extra warning for volume-destroying option
            clear
            print_section_header "⚠️ EXTREME DANGER: FULL RESET WITH VOLUME REMOVAL ⚠️"
            print_error "This will COMPLETELY ERASE your persistent data AND ALL DOCKER VOLUMES for ${PROJECT_NAME}!"
            print_error "This action CANNOT be undone unless you have a backup!"
            echo ""
            
            if get_confirmed_input "Are you absolutely sure you want to DELETE ALL DATA AND VOLUMES for ${PROJECT_NAME}?" "DELETE-ALL-DATA-AND-VOLUMES"; then
                if get_yes_no "Would you like to create a backup before proceeding (if supported)?"; then
                    backup_database # Call generic backup
                fi
                export REMOVE_VOLUMES=true
                run_full_reset_deploy # Generic function
                export REMOVE_VOLUMES=false # Reset flag
            else
                print_info "Full reset with volume removal cancelled"
            fi
            
            press_enter_to_continue
            show_deployment_menu
            ;;
        0) # Back
            show_main_menu
            ;;
        *)
            print_error "Invalid option"
            press_enter_to_continue
            show_deployment_menu
            ;;
    esac
} 