#!/usr/bin/env bash

# =======================================================
# Input Functions
# =======================================================

# Get numeric input with validation
get_numeric_input() {
    local prompt="$1"
    local input
    
    while true; do
        read -p "$prompt" input
        
        if [[ "$input" =~ ^[0-9]+$ ]]; then
            echo "$input"
            return 0
        else
            print_error "Please enter a valid number"
        fi
    done
}

# Get yes/no input
get_yes_no() {
    local prompt="$1"
    local default="${2:-n}"
    local input
    
    if [ "$default" = "y" ]; then
        read -p "$prompt (Y/n): " input
        input=${input:-y}
    else
        read -p "$prompt (y/N): " input
        input=${input:-n}
    fi
    
    if [[ "${input,,}" == "y" || "${input,,}" == "yes" ]]; then
        return 0
    else
        return 1
    fi
}

# Get confirmed input (requires typing exact confirmation)
get_confirmed_input() {
    local prompt="$1"
    local confirmation="$2"
    local input
    
    read -p "$prompt ($confirmation to confirm): " input
    
    if [ "$input" = "$confirmation" ]; then
        return 0
    else
        return 1
    fi
}

# Get string input with default value
get_string_input() {
    local prompt="$1"
    local default="$2"
    local input
    
    read -p "$prompt [$default]: " input
    echo "${input:-$default}"
}

# Press any key to continue
press_enter_to_continue() {
    local prompt="${1:-Press Enter to continue...}"
    read -p "$prompt"
} 