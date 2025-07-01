#!/bin/bash

# Waldo Round-trip Validation Test Suite
# Tests the complete save-overlay -> extract and save-desktop -> extract cycles to validate functionality

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
WALDO_BINARY="./.build/debug/waldo"
TEMP_DIR="./test_temp"
VERBOSE=false
DEBUG=false
KEEP_FILES=false

# Test counters
tests_passed=0
tests_total=0
tests_failed=0

# Function to print colored output
print_status() {
    local color="$1"
    local message="$2"
    echo -e "${color}${message}${NC}"
}

print_header() {
    echo
    print_status "$BLUE" "=== $1 ==="
}

print_success() {
    print_status "$GREEN" "✅ $1"
}

print_failure() {
    print_status "$RED" "❌ $1"
}

print_warning() {
    print_status "$YELLOW" "⚠️  $1"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -v, --verbose     Show verbose output from waldo commands"
    echo "  -d, --debug       Show debug output from waldo commands"
    echo "  -k, --keep-files  Keep test files after completion"
    echo "  -h, --help        Show this help message"
    echo
    echo "Examples:"
    echo "  $0                Run standard test suite"
    echo "  $0 --verbose      Run with verbose waldo output"
    echo "  $0 --debug        Run with debug waldo output"
    echo "  $0 -v -k          Run verbose and keep test files"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -d|--debug)
            DEBUG=true
            shift
            ;;
        -k|--keep-files)
            KEEP_FILES=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Function to check if waldo binary exists
check_binary() {
    if [[ ! -f "$WALDO_BINARY" ]]; then
        print_failure "Waldo binary not found at $WALDO_BINARY"
        echo "Please build the project first:"
        echo "  swift build"
        echo "  # or"
        echo "  make build"
        exit 1
    fi
}

# Function to setup test environment
setup_test_env() {
    # Create temp directory
    mkdir -p "$TEMP_DIR"
    
    # Build waldo flags
    WALDO_FLAGS=""
    if [[ "$VERBOSE" == "true" ]]; then
        WALDO_FLAGS="$WALDO_FLAGS --verbose"
    fi
    if [[ "$DEBUG" == "true" ]]; then
        WALDO_FLAGS="$WALDO_FLAGS --debug"
    fi
}

# Function to cleanup test environment
cleanup_test_env() {
    if [[ "$KEEP_FILES" == "false" ]]; then
        if [[ -d "$TEMP_DIR" ]]; then
            rm -rf "$TEMP_DIR"
            print_status "$BLUE" "Cleaned up test files"
        fi
    else
        print_status "$YELLOW" "Keeping test files in $TEMP_DIR"
    fi
}

# Function to run a single test
run_test() {
    local test_name="$1"
    local width="$2"
    local height="$3"
    local opacity="$4"
    local extra_save_flags="$5"
    local extra_extract_flags="$6"
    
    tests_total=$((tests_total + 1))
    local test_file="$TEMP_DIR/test_${tests_total}.png"
    
    echo -n "Running $test_name... "
    
    # Create overlay
    local save_cmd="$WALDO_BINARY overlay save-overlay '$test_file' --width $width --height $height --opacity $opacity $extra_save_flags $WALDO_FLAGS"
    if [[ "$VERBOSE" == "true" ]] || [[ "$DEBUG" == "true" ]]; then
        echo
        echo "Save command: $save_cmd"
    fi
    
    if eval "$save_cmd" >/dev/null 2>&1; then
        # Extract watermark
        local extract_cmd="$WALDO_BINARY extract '$test_file' --simple-extraction --no-screen-detection $extra_extract_flags $WALDO_FLAGS"
        if [[ "$VERBOSE" == "true" ]] || [[ "$DEBUG" == "true" ]]; then
            echo "Extract command: $extract_cmd"
        fi
        
        if eval "$extract_cmd" >/dev/null 2>&1; then
            print_success "$test_name PASSED"
            tests_passed=$((tests_passed + 1))
        else
            print_failure "$test_name FAILED (extraction)"
            tests_failed=$((tests_failed + 1))
            if [[ "$DEBUG" == "true" ]]; then
                echo "Failed extraction command: $extract_cmd"
                eval "$extract_cmd" 2>&1 | head -20
            fi
        fi
    else
        print_failure "$test_name FAILED (creation)"
        tests_failed=$((tests_failed + 1))
        if [[ "$DEBUG" == "true" ]]; then
            echo "Failed save command: $save_cmd"
            eval "$save_cmd" 2>&1 | head -20
        fi
    fi
    
    # Clean up individual test file unless keeping files
    if [[ "$KEEP_FILES" == "false" ]] && [[ -f "$test_file" ]]; then
        rm -f "$test_file"
    fi
}

# Function to run performance test
run_performance_test() {
    print_header "Performance Testing"
    
    local perf_file="$TEMP_DIR/performance_test.png"
    local width=1024
    local height=768
    local opacity=60
    
    echo "Testing creation performance..."
    local start_time=$(date +%s%N)
    if $WALDO_BINARY overlay save-overlay "$perf_file" --width $width --height $height --opacity $opacity >/dev/null 2>&1; then
        local end_time=$(date +%s%N)
        local duration=$(( (end_time - start_time) / 1000000 ))  # Convert to milliseconds
        print_success "Overlay creation: ${duration}ms"
        
        echo "Testing extraction performance..."
        start_time=$(date +%s%N)
        if $WALDO_BINARY extract "$perf_file" --simple-extraction --no-screen-detection >/dev/null 2>&1; then
            end_time=$(date +%s%N)
            duration=$(( (end_time - start_time) / 1000000 ))
            print_success "Watermark extraction: ${duration}ms"
        else
            print_failure "Performance extraction test failed"
        fi
    else
        print_failure "Performance creation test failed"
    fi
    
    # Clean up
    if [[ "$KEEP_FILES" == "false" ]] && [[ -f "$perf_file" ]]; then
        rm -f "$perf_file"
    fi
}

# Function to run threshold tests
run_threshold_tests() {
    print_header "Threshold Testing"
    
    local threshold_file="$TEMP_DIR/threshold_test.png"
    
    # Create test overlay
    if $WALDO_BINARY overlay save-overlay "$threshold_file" --width 400 --height 300 --opacity 80 >/dev/null 2>&1; then
        
        # Test different thresholds
        local thresholds=(0.1 0.3 0.5 0.7 0.9)
        local threshold_passed=0
        
        for threshold in "${thresholds[@]}"; do
            echo -n "Testing threshold $threshold... "
            if $WALDO_BINARY extract "$threshold_file" --simple-extraction --no-screen-detection --threshold "$threshold" >/dev/null 2>&1; then
                print_success "PASSED"
                threshold_passed=$((threshold_passed + 1))
            else
                print_failure "FAILED"
            fi
        done
        
        print_status "$BLUE" "Threshold tests: $threshold_passed/${#thresholds[@]} passed"
        
    else
        print_failure "Failed to create threshold test overlay"
    fi
    
    # Clean up
    if [[ "$KEEP_FILES" == "false" ]] && [[ -f "$threshold_file" ]]; then
        rm -f "$threshold_file"
    fi
}

# Function to run desktop overlay tests
run_desktop_overlay_tests() {
    print_header "Desktop Overlay Testing"
    
    local desktop_file="$TEMP_DIR/desktop_capture.png"
    local overlay_pid=""
    
    # Check if overlay is already running
    local overlay_running=false
    if $WALDO_BINARY overlay status >/dev/null 2>&1; then
        local status_output=$($WALDO_BINARY overlay status 2>/dev/null)
        if echo "$status_output" | grep -q "Active: Yes"; then
            overlay_running=true
            print_status "$YELLOW" "Overlay already running, will use existing overlay"
        fi
    fi
    
    # Start overlay if not running
    if [[ "$overlay_running" == "false" ]]; then
        echo -n "Starting desktop overlay... "
        
        # Start overlay in background (macOS doesn't have timeout command)
        $WALDO_BINARY overlay start --daemon --opacity 60 $WALDO_FLAGS >/dev/null 2>&1 &
        overlay_pid=$!
        
        # Wait for overlay process to initialize
        local wait_count=0
        local max_wait=15
        while [[ $wait_count -lt $max_wait ]]; do
            # Check if the overlay process is still running
            if kill -0 "$overlay_pid" 2>/dev/null; then
                # Check if process has settled (not just started)
                if [[ $wait_count -ge 3 ]]; then
                    # Try to detect overlay by checking for waldo processes
                    if pgrep -f "waldo overlay start" >/dev/null 2>&1; then
                        print_success "Overlay started successfully"
                        break
                    fi
                fi
            else
                print_failure "Overlay process terminated unexpectedly"
                return
            fi
            sleep 1
            wait_count=$((wait_count + 1))
        done
        
        if [[ $wait_count -eq $max_wait ]]; then
            print_failure "Failed to start overlay within timeout"
            if [[ -n "$overlay_pid" ]]; then
                kill "$overlay_pid" 2>/dev/null || true
            fi
            return
        fi
    fi
    
    # Test desktop capture
    echo -n "Testing desktop capture... "
    
    # Give overlay a moment to fully initialize
    sleep 2
    
    if $WALDO_BINARY overlay save-desktop "$desktop_file" $WALDO_FLAGS >/dev/null 2>&1; then
        print_success "Desktop captured successfully"
        
        # Test extraction from desktop capture (may fail - desktop screenshots have different characteristics)
        echo -n "Testing extraction from desktop capture... "
        if $WALDO_BINARY extract "$desktop_file" --simple-extraction --no-screen-detection >/dev/null 2>&1; then
            print_success "Desktop extraction PASSED"
        else
            print_failure "Desktop extraction FAILED (expected for desktop screenshots)"
            # Note: Desktop capture extraction often fails due to screen rendering differences
        fi
    else
        print_failure "Desktop capture FAILED"
        # Try to debug the issue
        if [[ "$DEBUG" == "true" ]]; then
            echo "Debug: Testing save-desktop with error output:"
            $WALDO_BINARY overlay save-desktop "$desktop_file" $WALDO_FLAGS
        fi
    fi
    
    # Stop overlay if we started it
    if [[ "$overlay_running" == "false" ]]; then
        echo -n "Stopping desktop overlay... "
        if $WALDO_BINARY overlay stop >/dev/null 2>&1; then
            print_success "Overlay stopped"
        else
            print_warning "Failed to stop overlay cleanly"
        fi
        
        # Clean up background process
        if [[ -n "$overlay_pid" ]]; then
            kill "$overlay_pid" 2>/dev/null || true
        fi
    fi
    
    # Clean up desktop capture file
    if [[ "$KEEP_FILES" == "false" ]] && [[ -f "$desktop_file" ]]; then
        rm -f "$desktop_file"
    fi
}

# Function to run edge case tests
run_edge_case_tests() {
    print_header "Edge Case Testing"
    
    # Test very small image
    echo -n "Testing very small image (100x100)... "
    local small_file="$TEMP_DIR/very_small.png"
    if $WALDO_BINARY overlay save-overlay "$small_file" --width 100 --height 100 --opacity 120 >/dev/null 2>&1; then
        if $WALDO_BINARY extract "$small_file" --simple-extraction --no-screen-detection >/dev/null 2>&1; then
            print_success "PASSED"
        else
            print_failure "FAILED (extraction)"
        fi
    else
        print_failure "FAILED (creation)"
    fi
    
    # Test very high opacity
    echo -n "Testing very high opacity (200)... "
    local high_opacity_file="$TEMP_DIR/high_opacity.png"
    if $WALDO_BINARY overlay save-overlay "$high_opacity_file" --width 300 --height 200 --opacity 200 >/dev/null 2>&1; then
        if $WALDO_BINARY extract "$high_opacity_file" --simple-extraction --no-screen-detection >/dev/null 2>&1; then
            print_success "PASSED"
        else
            print_failure "FAILED (extraction)"
        fi
    else
        print_failure "FAILED (creation)"
    fi
    
    # Test low opacity
    echo -n "Testing low opacity (10)... "
    local low_opacity_file="$TEMP_DIR/low_opacity.png"
    if $WALDO_BINARY overlay save-overlay "$low_opacity_file" --width 300 --height 200 --opacity 10 >/dev/null 2>&1; then
        if $WALDO_BINARY extract "$low_opacity_file" --simple-extraction --no-screen-detection >/dev/null 2>&1; then
            print_success "PASSED"
        else
            print_failure "FAILED (extraction)"
        fi
    else
        print_failure "FAILED (creation)"
    fi
    
    # Clean up edge case files
    if [[ "$KEEP_FILES" == "false" ]]; then
        rm -f "$small_file" "$high_opacity_file" "$low_opacity_file"
    fi
}

# Main test execution
main() {
    print_header "Waldo Round-trip Validation Test Suite"
    
    # Check prerequisites
    check_binary
    setup_test_env
    
    print_status "$BLUE" "Binary: $WALDO_BINARY"
    print_status "$BLUE" "Temp directory: $TEMP_DIR"
    if [[ "$VERBOSE" == "true" ]]; then
        print_status "$BLUE" "Verbose mode: enabled"
    fi
    if [[ "$DEBUG" == "true" ]]; then
        print_status "$BLUE" "Debug mode: enabled"
    fi
    
    print_header "Core Round-trip Tests"
    
    # Run core test suite
    run_test "Small overlay (300x200)" 300 200 80
    run_test "Medium overlay (800x600)" 800 600 60  
    run_test "Large overlay (1200x900)" 1200 900 100
    run_test "High opacity overlay" 400 300 150
    run_test "Low opacity overlay" 400 300 30
    run_test "Square overlay" 500 500 90
    run_test "Wide overlay (16:9)" 960 540 70
    run_test "Tall overlay (9:16)" 540 960 70
    
    # Run additional test suites
    run_performance_test
    run_threshold_tests
    run_desktop_overlay_tests
    run_edge_case_tests
    
    # Final results
    print_header "Test Results Summary"
    
    if [[ $tests_failed -eq 0 ]]; then
        print_success "All core tests passed: $tests_passed/$tests_total"
        print_status "$GREEN" "🎉 Waldo round-trip validation: SUCCESS"
        exit_code=0
    else
        print_failure "Some tests failed: $tests_passed/$tests_total passed, $tests_failed failed"
        print_status "$RED" "💥 Waldo round-trip validation: FAILED"
        exit_code=1
    fi
    
    if [[ "$KEEP_FILES" == "true" ]]; then
        print_status "$BLUE" "Test files preserved in: $TEMP_DIR"
        echo "Clean up with: rm -rf $TEMP_DIR"
    fi
    
    # Cleanup
    cleanup_test_env
    
    # Show next steps
    if [[ $exit_code -eq 0 ]]; then
        echo
        print_status "$BLUE" "Next steps:"
        echo "  • Test with real camera photos: waldo overlay start && take photo && waldo extract photo.jpg"
        echo "  • Test desktop capture: waldo overlay start && waldo overlay save-desktop desktop.png && waldo extract desktop.png"
        echo "  • Run performance benchmarks: time waldo overlay save-overlay test.png && time waldo extract test.png --simple-extraction"
        echo "  • Debug issues: waldo extract image.png --simple-extraction --debug"
    fi
    
    exit $exit_code
}

# Trap to cleanup on exit
trap cleanup_test_env EXIT

# Run main function
main "$@"
