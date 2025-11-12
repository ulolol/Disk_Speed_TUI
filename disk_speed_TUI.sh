#!/bin/bash

# Disk Read/Write Speed Test Script - Interactive TUI
# Tests the read and write speed of the home directory using a 500MB file with progress bars

TEST_FILE="$HOME/.speed_test_temp"
FILE_SIZE="500M"
BLOCK_SIZE="1M"
TOTAL_BLOCKS=500

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Terminal control
clear_screen() { clear; }
hide_cursor() { printf "\033[?25l"; }
show_cursor() { printf "\033[?25h"; }

# Draw progress bar
draw_progress_bar() {
    local current=$1
    local total=$2
    local width=40
    local filled=$((current * width / total))
    local empty=$((width - filled))
    local percent=$((current * 100 / total))

    printf "["
    printf "%${filled}s" | tr ' ' '='
    printf "%${empty}s" | tr ' ' '-'
    printf "] %3d%%" "$percent"
}

# Print centered text
print_centered() {
    local text="$1"
    local width=${2:-80}
    local padding=$(( (width - ${#text}) / 2 ))
    printf "%${padding}s%s\n" "" "$text"
}

# Main TUI display
show_header() {
    clear_screen
    printf "\n"
    print_centered "╔═══════════════════════════════════════════════╗"
    print_centered "║      💾 Disk Speed Test - Interactive TUI     ║"
    print_centered "╚═══════════════════════════════════════════════╝"
    printf "\n"
}

# Progress display with details
show_progress() {
    local operation=$1
    local current=$2
    local total=$3
    local speed=$4

    printf "${CYAN}%-20s${NC}" "$operation"
    draw_progress_bar "$current" "$total"
    if [ -n "$speed" ]; then
        printf " ${GREEN}%.2f MB/s${NC}" "$speed"
    fi
}

# Write speed test with progress
write_speed_test() {
    show_header
    printf "${BLUE}Starting Write Speed Test...${NC}\n"
    printf "File Size: ${YELLOW}500 MB${NC} | Location: ${YELLOW}$TEST_FILE${NC}\n\n"

    # Remove any existing test file
    rm -f "$TEST_FILE"

    START_TIME=$(date +%s%N)

    for ((i = 1; i <= TOTAL_BLOCKS; i++)); do
        # Write 1MB block at a time
        if [ $i -eq 1 ]; then
            # First block - create new file
            dd if=/dev/zero of="$TEST_FILE" bs="$BLOCK_SIZE" count=1 conv=fdatasync 2>/dev/null
        else
            # Subsequent blocks - append to file
            dd if=/dev/zero of="$TEST_FILE" bs="$BLOCK_SIZE" count=1 seek=$((i-1)) conv=fdatasync 2>/dev/null
        fi

        CURRENT_TIME=$(date +%s%N)
        ELAPSED_MS=$((($CURRENT_TIME - $START_TIME) / 1000000))

        if [ $ELAPSED_MS -gt 0 ]; then
            SPEED=$(echo "scale=2; ($i * 1000) / $ELAPSED_MS" | bc 2>/dev/null || echo "0")
        else
            SPEED=0
        fi

        # Update progress line with carriage return
        printf "\r"
        show_progress "Write Test" "$i" "$TOTAL_BLOCKS" "$SPEED"
    done

    END_TIME=$(date +%s%N)
    WRITE_TIME=$((($END_TIME - $START_TIME) / 1000000))
    WRITE_SPEED=$(echo "scale=2; (500 * 1000) / $WRITE_TIME" | bc)

    printf "\n${GREEN}✓ Write Speed: $WRITE_SPEED MB/s (${WRITE_TIME}ms)${NC}\n"
    echo "$WRITE_SPEED" > /tmp/write_speed.txt
}

# Read speed test with progress
read_speed_test() {
    show_header
    printf "${BLUE}Starting Read Speed Test...${NC}\n"
    printf "File Size: ${YELLOW}500 MB${NC} | Location: ${YELLOW}$TEST_FILE${NC}\n\n"

    START_TIME=$(date +%s%N)

    for ((i = 1; i <= TOTAL_BLOCKS; i++)); do
        # Read 1MB block at a time (skip to each position)
        dd if="$TEST_FILE" of=/dev/null bs="$BLOCK_SIZE" count=1 skip=$((i-1)) 2>/dev/null

        CURRENT_TIME=$(date +%s%N)
        ELAPSED_MS=$((($CURRENT_TIME - $START_TIME) / 1000000))

        if [ $ELAPSED_MS -gt 0 ]; then
            SPEED=$(echo "scale=2; ($i * 1000) / $ELAPSED_MS" | bc 2>/dev/null || echo "0")
        else
            SPEED=0
        fi

        # Update progress line with carriage return
        printf "\r"
        show_progress "Read Test " "$i" "$TOTAL_BLOCKS" "$SPEED"
    done

    END_TIME=$(date +%s%N)
    READ_TIME=$((($END_TIME - $START_TIME) / 1000000))
    READ_SPEED=$(echo "scale=2; (500 * 1000) / $READ_TIME" | bc)

    printf "\n${GREEN}✓ Read Speed: $READ_SPEED MB/s (${READ_TIME}ms)${NC}\n"
    echo "$READ_SPEED" > /tmp/read_speed.txt
}

# Cleanup routine
cleanup() {
    rm -f "$TEST_FILE"
    if [ ! -f "$TEST_FILE" ]; then
        printf "${GREEN}✓ Test file cleaned up successfully${NC}\n"
    else
        printf "${RED}✗ Warning: Failed to delete test file${NC}\n"
        exit 1
    fi
}

# Main execution
hide_cursor
trap show_cursor EXIT

write_speed_test
printf "\n"
read_speed_test
printf "\n"

# Read speeds from temp files
WRITE_SPEED=$(cat /tmp/write_speed.txt 2>/dev/null || echo "0")
READ_SPEED=$(cat /tmp/read_speed.txt 2>/dev/null || echo "0")

# Results display
show_header
printf "\n${CYAN}=== Test Results ===${NC}\n\n"
printf "  %-20s ${GREEN}%s MB/s${NC}\n" "Write Speed:" "$WRITE_SPEED"
printf "  %-20s ${GREEN}%s MB/s${NC}\n" "Read Speed:" "$READ_SPEED"
printf "\n"

cleanup
rm -f /tmp/write_speed.txt /tmp/read_speed.txt

printf "${YELLOW}Press Enter to exit...${NC}"
read
