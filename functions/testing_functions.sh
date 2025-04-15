#!/usr/bin/env bash

# =======================================================
# Testing Functions
# =======================================================

# Run all tests
run_all_tests() {
    clear
    print_section_header "Run All Tests"
    
    if [ "$RUN_REMOTE" = false ]; then
        run_local_tests "all"
    else
        # Assuming a generic test runner script exists or tests run directly
        # Example: run tests inside the main container
        run_tests_in_container "all"
    fi
    
    return $?
}

# Run unit tests only
run_unit_tests() {
    clear
    print_section_header "Run Unit Tests"
    
    if [ "$RUN_REMOTE" = false ]; then
        run_local_tests "unit"
    else
        run_tests_in_container "unit"
    fi
    
    return $?
}

# Run integration tests only
run_integration_tests() {
    clear
    print_section_header "Run Integration Tests"
    
    if [ "$RUN_REMOTE" = false ]; then
        run_local_tests "integration"
    else
        run_tests_in_container "integration"
    fi
    
    return $?
}

# Run system tests only
run_system_tests() {
    clear
    print_section_header "Run System Tests"
    
    if [ "$RUN_REMOTE" = false ]; then
        run_local_tests "system"
    else
        run_tests_in_container "system"
    fi
    
    return $?
}

# Run dashboard tests specifically
run_dashboard_tests() {
    clear
    print_section_header "Run Example Application Tests"
    
    log_info "Running example application tests..."
    
    # Use a placeholder test file or adapt existing one
    local test_file="/app/tests/unit/test_example_app.py"

    
    # Run the tests and save results
    mkdir -p test-results
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local results_file="test-results/test_results_dashboard_${timestamp}.txt"
    
    log_info "Running: $docker_cmd"
    eval "$docker_cmd" | tee "$results_file"
    local exit_code=${PIPESTATUS[0]}
    
    if [ $exit_code -eq 0 ]; then
        log_success "Example Application tests completed successfully!"
    else
        log_error "Example Application tests failed with exit code: $exit_code"
    fi
    
    log_info "Test results saved to: $results_file"
    return $exit_code
}

# Generic function to run tests inside a container (e.g., MAIN_CONTAINER)
run_tests_in_container() {
    local test_type="${1:-all}" # Default to all tests
    local test_pattern="$2"
    local container_to_use="${MAIN_CONTAINER}" # Default to main container

    log_info "Running ${test_type} tests in container ${container_to_use}..."

    # Make sure container exists and is running
    if ! run_remote_command "${DOCKER_CMD} ps --filter name=^/${container_to_use}$ --format '{{.Names}}' | grep -q ${container_to_use}" "true"; then
        log_error "Container '${container_to_use}' is not running. Cannot run tests."
        return 1
    fi

    # Define base test path (assuming tests are in /app/tests inside container)
    local base_test_path="/app/tests"
    local test_path="${base_test_path}"
    local pytest_marker=""

    # Set path and marker based on type
    case "$test_type" in
        "unit")
            test_path="${base_test_path}/unit/"
            pytest_marker="-m unit"
            ;;
        "integration")
            test_path="${base_test_path}/integration/"
            pytest_marker="-m integration"
            ;;
        "system")
            test_path="${base_test_path}/system/"
            pytest_marker="-m system"
            ;;
        "all"|*)
            # Run all tests, no specific path or marker
            test_path="${base_test_path}/"
            pytest_marker=""
            test_type="all" # Ensure type is 'all' for filename
            ;;
    esac

    # Construct the pytest command
    # Using -vs for verbose output, add -x to stop on first failure if desired
    local docker_cmd="${DOCKER_CMD} exec ${container_to_use} pytest -vs ${pytest_marker} ${test_path}"

    # Add pattern matching if specified
    if [ -n "$test_pattern" ]; then
        docker_cmd="${docker_cmd} -k \"${test_pattern}\""
    fi

    # Run the tests and save results
    mkdir -p test-results
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local results_file="test-results/test_results_${PROJECT_NAME}_${test_type}_${timestamp}.txt"

    log_info "Running: ${docker_cmd}"
    run_remote_command "${docker_cmd}" | tee "$results_file"
    local exit_code=${PIPESTATUS[0]}

    if [ $exit_code -eq 0 ]; then
        log_success "Tests (${test_type}) completed successfully!"
    else
        log_error "Tests (${test_type}) failed with exit code: $exit_code"
    fi

    log_info "Test results saved to: $results_file"
    # Optionally sync results back immediately
    # sync_test_results 
    return $exit_code
}

# Run tests locally (delegates to run_tests_in_container for consistency if possible, or runs locally)
run_local_tests() {
    local test_type="$1"
    local test_pattern="$2"
    
    log_info "Running ${test_type} tests locally..."
    
    # Check if MAIN_CONTAINER is running locally
    if ! docker ps | grep -q "${MAIN_CONTAINER}"; then
        log_warning "Main container '${MAIN_CONTAINER}' is not running locally. Attempting to run tests directly."
        # Implement direct local test execution here if needed
        # Requires Python environment setup (e.g., using shell.nix or venv)
        # Example using pytest directly:
        log_info "Ensuring local Python environment is activated..."
        # Assume environment activation happens elsewhere or use nix-shell
        # nix-shell --run "pytest -vs -m ${test_type} tests/" # Example
        print_error "Direct local test execution not fully implemented yet."
        return 1
    fi

    # If container is running, use it for consistency
    log_info "Main container running locally. Running tests inside container ${MAIN_CONTAINER}..."
    
    local base_test_path="/app/tests" # Assuming tests are mounted here
    local test_path="${base_test_path}"
    local pytest_marker=""

    case "$test_type" in
        "unit") test_path="${base_test_path}/unit/"; pytest_marker="-m unit" ;; 
        "integration") test_path="${base_test_path}/integration/"; pytest_marker="-m integration" ;; 
        "system") test_path="${base_test_path}/system/"; pytest_marker="-m system" ;; 
        # REMOVE project-specific markers
        # "ollama") pytest_marker="-m ollama" ;; 
        # "anythingllm") pytest_marker="-m anythingllm" ;; 
        # "comfyui") pytest_marker="-m comfyui" ;; 
        # "n8n") pytest_marker="-m n8n" ;; 
        "all"|*)
             test_path="${base_test_path}/"
             pytest_marker=""
             test_type="all"
             ;;
    esac

    local pytest_cmd="pytest -vs ${pytest_marker} ${test_path}"
    if [ -n "$test_pattern" ]; then
        pytest_cmd="${pytest_cmd} -k \"${test_pattern}\""
    fi

    mkdir -p test-results
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local results_file="test-results/test_results_${PROJECT_NAME}_${test_type}_local_${timestamp}.txt"

    log_info "Running in container: docker exec ${MAIN_CONTAINER} ${pytest_cmd}"
    docker exec ${MAIN_CONTAINER} ${pytest_cmd} | tee "$results_file"
    local exit_code=${PIPESTATUS[0]}

    if [ $exit_code -eq 0 ]; then
        log_success "Local tests (${test_type}) completed successfully!"
    else
        log_error "Local tests (${test_type}) failed with exit code: $exit_code"
    fi

    log_info "Test results saved to: $results_file"
    return $exit_code
}

# Upload tests
upload_tests() {
    clear
    print_section_header "Upload Tests"
    
    if [ "$RUN_REMOTE" = false ]; then
        print_error "Cannot upload tests in local mode"
    else
        ./utils/testing/upload_tests.sh
    fi
    
    press_enter_to_continue
    show_testing_menu
}

# Test server
test_server() {
    clear
    print_section_header "Test Server"
    
    if [ "$RUN_REMOTE" = false ]; then
        print_error "Cannot test server in local mode"
    else
        ./utils/testing/test_server.sh
    fi
    
    press_enter_to_continue
    show_testing_menu
}

# Check remote services
check_remote_services() {
    clear
    print_section_header "Check Remote Services"
    
    if [ "$RUN_REMOTE" = false ]; then
        print_error "Cannot check remote services in local mode"
    else
        ./utils/testing/check_remote_services.sh
    fi
    
    press_enter_to_continue
    show_testing_menu
}

# Initialize test environment - Generic
initialize_test_environment() {
    clear
    print_section_header "Initialize Test Environment"
    
    # Create test directories locally
    mkdir -p tests/unit
    mkdir -p tests/integration
    mkdir -p tests/system
    mkdir -p test-results
    
    print_success "Created local test directory structure in ./tests/"
    
    # Create a generic placeholder test file if none exist
    if [ ! -f "tests/unit/test_example.py" ]; then
        print_info "Creating sample placeholder test file tests/unit/test_example.py ..."
        cat > tests/unit/test_example.py << EOF
import pytest

# Example test marker (can be used with pytest -m unit)
@pytest.mark.unit
def test_placeholder_unit():
    """A placeholder unit test."""
    assert True

# Example test marker (can be used with pytest -m integration)
@pytest.mark.integration
def test_placeholder_integration():
    """A placeholder integration test."""
    assert 1 + 1 == 2
EOF
        print_success "Sample test file created."
    fi
    
    # Ensure pytest is available (locally or suggest installation)
    if ! command -v pytest &> /dev/null; then
        print_warning "pytest command not found locally."
        print_info "Testing relies on pytest being available either locally or inside the test container."
        print_info "Consider installing it locally: pip install pytest"
    else
        print_success "pytest is installed and available locally."
    fi
    
    print_success "Local test environment directories initialized successfully."
    press_enter_to_continue
    # Assuming show_testing_menu exists and is the caller
    # show_testing_menu 
}

# Run simple test - Generic, runs inside container
run_simple_test() {
    clear
    print_section_header "Run Simple Environment Test"
    
    log_info "Running simple environment test inside container ${MAIN_CONTAINER}..."
    
    # Define the simple test content
    local simple_test_content='import pytest\nimport os\nimport sys\n\ndef test_environment():\n    """Test basic Python environment inside container"""\n    print("\\nPython version:", sys.version)\n    print("Working directory:", os.getcwd())\n    print("PYTHONPATH:", os.environ.get("PYTHONPATH", "Not set"))\n    assert True, "Basic environment test passed"\n'
    local simple_test_path="/tmp/test_simple_env.py"

    # Make sure container is running
    if ! run_remote_command "${DOCKER_CMD} ps --filter name=^/${MAIN_CONTAINER}$ --format '{{.Names}}' | grep -q ${MAIN_CONTAINER}" "true"; then
        log_error "Container '${MAIN_CONTAINER}' is not running. Cannot run test."
        return 1
    fi

    # Write the test file inside the container
    run_remote_command "echo -e \"${simple_test_content}\" > ${simple_test_path}"
    
    # Run the simple test using pytest inside the container
    local docker_cmd="${DOCKER_CMD} exec ${MAIN_CONTAINER} pytest -vs ${simple_test_path}"
    
    # Run the tests and save results locally
    mkdir -p test-results
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local results_file="test-results/test_results_${PROJECT_NAME}_simple_${timestamp}.txt"
    
    log_info "Running: ${docker_cmd}"
    # Execute and capture output locally
    ssh ${SERVER_USER}@${SERVER_HOST} "${docker_cmd}" | tee "$results_file"
    local exit_code=${PIPESTATUS[0]}
    
    # Clean up the test file in the container
    run_remote_command "rm ${simple_test_path}"

    if [ $exit_code -eq 0 ]; then
        log_success "Simple environment test completed successfully!"
    else
        log_error "Simple environment test failed with exit code: $exit_code"
    fi
    
    log_info "Test results saved to: $results_file"
    return $exit_code
} 

# Run ordered tests - Generic, uses run_tests_in_container
run_ordered_tests() {
    clear
    print_section_header "Run Tests in Standard Order (Unit -> Integration -> System)"
    
    local overall_exit_code=0
    
    print_info "--- Running Unit Tests --- "
    run_tests_in_container "unit"
    if [ $? -ne 0 ]; then overall_exit_code=1; fi
    
    print_info "--- Running Integration Tests --- "
    run_tests_in_container "integration"
     if [ $? -ne 0 ]; then overall_exit_code=1; fi
   
    print_info "--- Running System Tests --- "
    run_tests_in_container "system"
     if [ $? -ne 0 ]; then overall_exit_code=1; fi

    # Optionally run project-specific tests here
    # print_info "--- Running Ollama Tests --- "
    # run_tests_in_container "ollama"
    # if [ $? -ne 0 ]; then overall_exit_code=1; fi

    if [ $overall_exit_code -eq 0 ]; then
        log_success "All ordered tests completed successfully!"
    else
        log_error "One or more ordered test suites failed."
    fi
    
    sync_test_results # Sync results after all tests run
    
    return $overall_exit_code
}

# Sync test results - Generic (already updated to use variables)
sync_test_results() {
    log_info "Synchronizing test results..."
    
    # Ensure local target directory exists
    mkdir -p "${LOCAL_GIT_DIR}/test-results"
    
    if [ "$RUN_REMOTE" = false ]; then
        # Define remote source directory (can be standardized)
        local remote_results_dir="${SERVER_PROJECT_DIR}/test-results"
        # Ensure remote directory exists (might be created by test run)
        run_remote_command "mkdir -p ${remote_results_dir}" "silent"
        # Copy results from potential location within docker context to project results dir
        run_remote_command "cp -f ${EFFECTIVE_DOCKER_DIR}/test-results/* ${remote_results_dir}/ 2>/dev/null || true"
        # Use SCP helper function if available, otherwise raw scp
        log_info "Attempting to copy results from ${SERVER_HOST}:${remote_results_dir}/ to ${LOCAL_GIT_DIR}/test-results/"
        scp -r "${SERVER_USER}@${SERVER_HOST}:${remote_results_dir}/"* "${LOCAL_GIT_DIR}/test-results/" 
        if [ $? -eq 0 ]; then
            log_success "Test results retrieved from remote server."
        else
            log_warning "Failed to retrieve test results from remote server (directory might be empty or SCP failed)."
        fi
    else
        # In local mode, copy from local docker dir results to git dir results
        local local_docker_results_dir="${LOCAL_DOCKER_DIR}/test-results"
        if [ -d "$local_docker_results_dir" ]; then
            cp -f "${local_docker_results_dir}/"* "${LOCAL_GIT_DIR}/test-results/" 2>/dev/null || true
            log_success "Test results copied from local Docker directory to Git directory."
        else
            log_warning "No test results found in local Docker directory: ${local_docker_results_dir}"
        fi
    fi
}

# Run unit tests safely - Generic
run_unit_tests_safely() {
    clear
    print_section_header "Run Unit Tests (Safe Mode - Experimental)"
    
    # Define the container to use
    local container_to_use="${MAIN_CONTAINER}"
    
    log_info "Attempting to run unit tests safely in container ${container_to_use}..."

    # Make sure container exists and is running
    if ! run_remote_command "${DOCKER_CMD} ps --filter name=^/${container_to_use}$ --format '{{.Names}}' | grep -q ${container_to_use}" "true"; then
        log_error "Container '${container_to_use}' is not running. Cannot run tests."
        return 1
    fi
    
    # Assuming a script /app/tests/run_unit_tests.sh exists inside the container
    local unit_test_script="/app/tests/run_unit_tests.sh"

    # Check if the script exists inside the container
     if ! run_remote_command "${DOCKER_CMD} exec ${container_to_use} test -f ${unit_test_script}" "true"; then
         log_error "Unit test script ${unit_test_script} not found inside container ${container_to_use}."
         # Optionally try copying it?
         # log_info "Attempting to copy local ./tests/run_unit_tests.sh to container..."
         # docker cp ./tests/run_unit_tests.sh ${container_to_use}:${unit_test_script}
         # if [ $? -ne 0 ]; then log_error "Failed to copy script."; return 1; fi
         # run_remote_command "${DOCKER_CMD} exec ${container_to_use} chmod +x ${unit_test_script}"
         return 1
     fi
    
    # Run the special unit test script
    log_info "Executing ${unit_test_script} in container..."
    run_remote_command "${DOCKER_CMD} exec ${container_to_use} ${unit_test_script}"
    local exit_code=$?

    if [ $exit_code -eq 0 ]; then
        log_success "Unit tests (safe mode) completed successfully!"
    else
        log_error "Unit tests (safe mode) failed with exit code: $exit_code"
    fi
    return $exit_code
}

# Run tests using a dedicated test Docker container - Generic
run_tests_with_docker_container() {
    local test_type="${1:-all}"
    local test_pattern="${2:-}"
    local fail_fast="${3:-false}" # Add fail_fast option
    local test_container_name="${PROJECT_NAME}-tests" # Standardized test container name
    local test_compose_file="${EFFECTIVE_DOCKER_DIR}/test/docker-compose.yml" # Standardized path

    print_section_header "Running Tests with Dedicated Test Container (${test_container_name})"
    
    # Check if test compose file exists
    if [ "$RUN_REMOTE" = false ]; then
        if [ ! -f "${test_compose_file}" ]; then
            print_error "Test docker-compose file not found locally at: ${test_compose_file}"
            return 1
        fi
    else
        if ! run_remote_command "test -f ${test_compose_file}" "true"; then
             print_error "Test docker-compose file not found on server at: ${test_compose_file}"
             return 1
        fi
    fi

    local compose_cmd_prefix=""
    if [ "$RUN_REMOTE" = false ]; then
        compose_cmd_prefix="cd ${LOCAL_DOCKER_DIR}/test && ${DOCKER_COMPOSE_CMD} -f docker-compose.yml"
    else
        compose_cmd_prefix="cd ${EFFECTIVE_DOCKER_DIR}/test && ${DOCKER_COMPOSE_CMD} -f docker-compose.yml"
    fi

    # Step 1: Build the test container if needed
    log_info "Building test Docker container..."
    run_command "${compose_cmd_prefix} build"
    if [ $? -ne 0 ]; then log_error "Failed to build test Docker container"; return 1; fi
    
    # Step 2: Start the test container (and dependencies)
    log_info "Starting test Docker container and dependencies..."
    run_command "${compose_cmd_prefix} up -d"
    if [ $? -ne 0 ]; then log_error "Failed to start test Docker container"; return 1; fi
    
    # Step 3: Run tests based on type inside the test container
    log_info "Running ${test_type} tests in Docker test container ${test_container_name}..."
    
    mkdir -p test-results
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local results_file="test-results/test_results_${PROJECT_NAME}_docker_${test_type}_${timestamp}.txt"
    
    # Build the pytest command based on test type marker
    local pytest_cmd="python -m pytest"
    local pytest_marker=""
    
    case "$test_type" in
        "unit") pytest_marker="-m unit" ;; 
        "integration") pytest_marker="-m integration" ;; 
        "system") pytest_marker="-m system" ;; 
        # REMOVE project-specific markers
        # "ollama") pytest_marker="-m ollama" ;; 
        # "anythingllm") pytest_marker="-m anythingllm" ;; 
        # "comfyui") pytest_marker="-m comfyui" ;; 
        # "n8n") pytest_marker="-m n8n" ;; 
        "all"|*)
            pytest_marker="" # Run all tests if type is 'all' or unknown
            test_type="all"
            ;;
    esac
    
    pytest_cmd="${pytest_cmd} ${pytest_marker}" # Add marker if defined
    
    # Add verbosity and fail-fast flags
    if [ "$fail_fast" = true ]; then
        pytest_cmd="${pytest_cmd} -xvs"
    else
        pytest_cmd="${pytest_cmd} -vs"
    fi
    
    # Add test pattern if specified
    if [ -n "$test_pattern" ]; then
        pytest_cmd="${pytest_cmd} -k \"${test_pattern}\""
    fi
    
    # Execute the tests inside the test container
    log_info "Running in test container: docker exec ${test_container_name} ${pytest_cmd}"
    run_command "docker exec ${test_container_name} ${pytest_cmd}" | tee "$results_file"
    local exit_code=${PIPESTATUS[0]}

    # Step 4: Stop and remove the test container and its dependencies
    log_info "Stopping test Docker container and dependencies..."
    run_command "${compose_cmd_prefix} down"
    
    if [ $exit_code -eq 0 ]; then
        log_success "All tests completed successfully using dedicated test container!"
    else
        log_error "Tests failed with exit code: $exit_code using dedicated test container."
    fi
    
    log_info "Test results saved to: $results_file"
    sync_test_results # Sync results after run
    return $exit_code
}

# Run sequential tests - Generic, uses run_tests_in_container
run_sequential_tests() {
    print_section_header "Running Tests Sequentially (Unit -> Integration -> System)"
    
    local overall_exit_code=0
    local run_in_dedicated_container=false # Option to use dedicated container

    if get_yes_no "Use dedicated test container (requires test/docker-compose.yml)?" "n"; then
        run_in_dedicated_container=true
    fi

    # Define test sequence
    local test_sequence=("unit" "integration" "system")
    # REMOVE project specific markers
    # test_sequence+=("ollama" "anythingllm")

    for test_suite in "${test_sequence[@]}"; do
        print_info "--- Running ${test_suite} Tests --- "
        if [ "$run_in_dedicated_container" = true ]; then
            run_tests_with_docker_container "$test_suite"
        else
            run_tests_in_container "$test_suite"
        fi
        if [ $? -ne 0 ]; then 
            log_error "Test suite '${test_suite}' failed."
            overall_exit_code=1
            # Decide whether to stop or continue on failure
            if get_yes_no "Continue with next test suite despite failure?" "n"; then
                log_info "Continuing with next test suite..."
            else
                log_error "Aborting sequential test run."
                break
            fi
        fi
    done

    if [ $overall_exit_code -eq 0 ]; then
        log_success "All sequential tests completed successfully!"
    else
        log_error "One or more sequential test suites failed."
    fi
    
    sync_test_results # Sync results at the end
    return $overall_exit_code
}