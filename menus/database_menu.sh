#!/usr/bin/env bash

# =======================================================
# Database Menu
# =======================================================

# Show database menu
show_database_menu() {
    show_header
    
    print_section_header "Database Tools - Project: ${PROJECT_NAME}"
    print_menu_item "1" "Apply Alembic Migration (if applicable)"
    print_menu_item "2" "Update Remote Database (if applicable)"
    print_menu_item "3" "Backup Database (${DB_NAME})"
    print_menu_item "4" "Restore Database (${DB_NAME})"
    print_back_option
    echo ""
    
    local choice=$(get_numeric_input "Select an option: ")
    
    case "$choice" in
        1) 
            if [ -f "./utils/database/update_alembic_migration.sh" ]; then
                 run_database_migration
            else
                 print_warning "Alembic migration script not found."
            fi
            press_enter_to_continue
            show_database_menu
            ;;
        2) 
            if [ -f "./utils/database/update_remote_database.sh" ]; then
                 update_remote_database
             else
                 print_warning "Remote database update script not found."
             fi
            press_enter_to_continue
            show_database_menu
            ;;
        3)
            backup_database
            press_enter_to_continue
            show_database_menu
            ;;
        4)
            restore_database
            press_enter_to_continue
            show_database_menu
            ;;
        0) show_main_menu ;;
        *) 
            print_error "Invalid option!"
            sleep 1
            show_database_menu
            ;;
    esac
} 