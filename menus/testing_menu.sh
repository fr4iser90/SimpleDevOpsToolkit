#!/usr/bin/env bash

# =======================================================
# Testing Menu
# =======================================================

# Show testing menu
show_testing_menu() {
    while true; do
        show_header
        
        print_section_header "Testing Menu - Project: ${PROJECT_NAME}"
        
        print_menu_item "1" "Run All Tests (in container)"
        print_menu_item "2" "Run Unit Tests (in container)"
        print_menu_item "3" "Run Integration Tests (in container)"
        print_menu_item "4" "Run System Tests (in container)"
        print_menu_item "5" "Run Tests by Marker (e.g., 'ollama')"
        print_menu_item "6" "Run Tests with Pattern Match"
        print_menu_item "7" "Run Simple Environment Test (in container)"
        print_menu_item "8" "Show Local Test Results"
        print_menu_item "9" "Run Server Status/Connectivity Tests"
        print_menu_item "10" "Run Tests in Standard Order (Unit->Int->Sys)"
        print_menu_item "11" "Run Tests with Dedicated Docker Test Container"
        print_menu_item "12" "Initialize Local Test Environment"
        print_menu_item "13" "Sync Test Results from Server"
        
        print_back_option # Usually 0
        
        echo ""
        local choice
        choice=$(get_numeric_input "Enter your choice: ")
        
        case $choice in
            1)
                run_tests_in_container "all"
                press_enter_to_continue
                ;;
            2)
                run_tests_in_container "unit"
                press_enter_to_continue
                ;;
            3)
                run_tests_in_container "integration"
                press_enter_to_continue
                ;;
            4)
                run_tests_in_container "system"
                press_enter_to_continue
                ;;
            5)
                read -p "Enter pytest marker expression: " marker
                run_tests_in_container "${marker}" # Pass marker as type
                press_enter_to_continue
                ;;
            6)
                read -p "Enter pytest pattern (-k): " pattern
                run_tests_in_container "all" "${pattern}" # Run all with pattern
                press_enter_to_continue
                ;;
            7)
                run_simple_test # Generic
                press_enter_to_continue
                ;;
            8) 
                show_test_results # Generic
                ;; # show_test_results has its own continue prompt
            9) 
                test_server # Generic (likely)
                press_enter_to_continue
                ;;
            10)
                run_ordered_tests # Generic
                press_enter_to_continue
                ;;
            11)
                run_tests_with_docker_container "all" # Add options later if needed
                press_enter_to_continue
                ;;
            12)
                initialize_test_environment # Generic
                press_enter_to_continue
                ;;
             13)
                 sync_test_results # Generic
                 press_enter_to_continue
                 ;;
            0) show_main_menu ;; # Back
            *) 
                print_error "Invalid option!"
                sleep 1
                ;; # Loop back
        esac
    done
}

# Show test results - Generic
show_test_results() {
    clear
    print_section_header "Local Test Results - Project: ${PROJECT_NAME}"
    
    local results_dir="${LOCAL_GIT_DIR}/test-results"
    mkdir -p "$results_dir"
    
    # Check if we have any test results
    if [ ! "$(ls -A "$results_dir/" 2>/dev/null)" ]; then
        print_warning "No test results found in ${results_dir}/"
        # Offer to sync
        if get_yes_no "Sync results from server now?" "y"; then
            sync_test_results
            # Recheck after sync
            if [ ! "$(ls -A "$results_dir/" 2>/dev/null)" ]; then
                 print_warning "Still no test results found after sync."
                 press_enter_to_continue
                 return
            fi
        else
            press_enter_to_continue
            return
        fi
    fi
    
    # Show the available results files, sorted by time (newest first)
    echo "Available test results (newest first):"
    ls -1t "$results_dir/" | nl
    
    # Ask user which file to view
    echo ""
    local choice=$(get_numeric_input "Enter the number of the file to view (0 to go back): ")
    
    if [ "$choice" = "0" ]; then
        return
    fi
    
    # Get the filename from the list
    local file=$(ls -1t "$results_dir/" | sed -n "${choice}p")
    
    if [ -n "$file" ]; then
        clear
        print_section_header "Test Results: $file"
        # Use less for pagination if available
        if command -v less > /dev/null; then
            less "$results_dir/$file"
        else
            cat "$results_dir/$file"
        fi
        echo ""
        press_enter_to_continue
    else
        print_error "Invalid selection"
        sleep 1
    fi
} 