#!/usr/bin/env bash

# =======================================================
# Display Functions
# =======================================================

# Display header with dynamic content based on config
show_header() {
    clear
    echo -e "${YELLOW}=========================================================${NC}"
    echo -e "${YELLOW}                  Application Deployment Center          ${NC}" # Generic Title
    echo -e "${YELLOW}=========================================================${NC}"
    echo -e "${YELLOW}Project: ${GREEN}${PROJECT_NAME}${NC}"
    echo -e "  Server: ${GREEN}${SERVER_USER}@${SERVER_HOST}:${SERVER_PORT}${NC}"
    echo -e "  Environment: ${GREEN}${ENVIRONMENT:-dev}${NC}"
    echo -e "  Mode: ${GREEN}$( [ "$RUN_REMOTE" = false ] && echo "Local" || echo "Remote" )${NC}"
    
    # Show environment variables status (check if a common var like DB_NAME is loaded)
    local env_status=""
    if [ -n "$DB_NAME" ]; then # Check a var expected to be loaded
        env_status="${GREEN}Loaded (from config/env)${NC}"
    else
        env_status="${YELLOW}Not loaded or incomplete${NC}"
    fi
    echo -e "  Config Variables: $env_status"
    
    # Show running containers if possible
    if [ "$RUN_REMOTE" = false ] && check_ssh_connection "silent"; then
        # Get running containers matching the CONTAINER_LIST pattern
        local running_list=""
        for c_name in "${CONTAINER_LIST[@]}"; do
             if run_remote_command "${DOCKER_CMD} ps --filter name=^/${c_name}$ --format '{{.Names}}' | grep -q ${c_name}" "silent"; then
                 running_list+="${c_name}, "
             fi
        done
        # Remove trailing comma and space
        running_list=${running_list%, }

        if [ -n "$running_list" ]; then
            echo -e "  Running Containers: ${GREEN}${running_list}${NC}"
        else
            echo -e "  Running Containers: ${YELLOW}None detected${NC}"
        fi
    elif [ "$RUN_REMOTE" = false ]; then
         # Check local running containers
         local running_list=""
         for c_name in "${CONTAINER_LIST[@]}"; do
              if docker ps --filter name=^/${c_name}$ --format '{{.Names}}' | grep -q ${c_name}; then
                  running_list+="${c_name}, "
              fi
         done
         running_list=${running_list%, }
         if [ -n "$running_list" ]; then
             echo -e "  Running Containers (Local): ${GREEN}${running_list}${NC}"
         else
             echo -e "  Running Containers (Local): ${YELLOW}None detected${NC}"
         fi
    fi
    
    echo -e "${YELLOW}=========================================================${NC}"
    echo ""
}

# Print section header (Generic)
print_section_header() {
    local title="$1"
    echo -e "${YELLOW}${title}${NC}"
    echo -e "${YELLOW}$(printf '%*s' "${#title}" | tr ' ' '-')${NC}"
}

# Print numbered menu item (Generic)
print_menu_item() {
    local number="$1"
    local description="$2"
    echo -e "${number}. ${GREEN}${description}${NC}"
}

# Print back menu item (Generic)
print_back_option() {
    echo -e "0. ${RED}Back / Previous Menu${NC}"
}

# Print exit option (Generic)
print_exit_option() {
    echo -e "0. ${RED}Exit Application Center${NC}"
}

# Print warning message (Generic)
print_warning() {
    echo -e "${YELLOW}WARNING: $1${NC}"
}

# Print error message (Generic)
print_error() {
    echo -e "${RED}ERROR: $1${NC}"
}

# Print success message (Generic)
print_success() {
    echo -e "${GREEN}SUCCESS: $1${NC}"
}

# Print info message (Generic)
print_info() {
    echo -e "${BLUE}INFO: $1${NC}"
} 