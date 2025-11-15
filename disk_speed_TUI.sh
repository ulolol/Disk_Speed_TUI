#!/bin/bash

# Disk Read/Write Speed Test Script - Interactive TUI
# Measures read/write speed using configurable chunks and progress indicators

DEFAULT_TEST_FILE_TEMPLATE="$HOME/.speed_test_temp.XXXXXX"
CUSTOM_TEST_FILE="${TEST_FILE:-}"
TEST_FILE=""
FILE_SIZE="500M"
BLOCK_SIZE="1M"
TOTAL_BLOCKS=500
CHUNK_BLOCKS=10
CLEANUP_VERBOSE=1

# --- Helpers ---
check_dependencies() {
    local deps=("dd" "bc" "tput" "clear" "df" "awk" "mktemp" "sync")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            printf "${RED}Error: Required command '$dep' not found. Please install it.${NC}\n"
            show_cursor
            exit 1
        fi
    done
}

convert_block_size_to_mb() {
    local size="${1:-1M}"
    local normalized="${size^^}"
    local value unit

    if [[ "$normalized" =~ ^([0-9]+(\.[0-9]+)?)([A-Z]{0,2})$ ]]; then
        value="${BASH_REMATCH[1]}"
        unit="${BASH_REMATCH[3]}"
    else
        value="$normalized"
        unit=""
    fi

    unit="${unit%%B}"

    case "$unit" in
        K)
            awk -v v="$value" 'BEGIN {printf "%.6f", v/1024}'
            ;;
        M|"")
            if [ -n "$unit" ]; then
                printf "%s" "$value"
            else
                awk -v v="$value" 'BEGIN {printf "%.6f", v/1024/1024}'
            fi
            ;;
        G)
            awk -v v="$value" 'BEGIN {printf "%.6f", v*1024}'
            ;;
        T)
            awk -v v="$value" 'BEGIN {printf "%.6f", v*1024*1024}'
            ;;
        *)
            awk -v v="$value" 'BEGIN {printf "%.6f", v/1024/1024}'
            ;;
    esac
}

format_mb() {
    local value="${1:-0}"
    awk -v value="$value" 'BEGIN {printf "%.1f", value}'
}

calc_speed() {
    local mb="$1"
    local elapsed="$2"

    if [ -z "$mb" ] || [ -z "$elapsed" ] || [ "$elapsed" -le 0 ]; then
        printf "0.00"
        return
    fi

    awk -v mb="$mb" -v elapsed="$elapsed" 'BEGIN {printf "%.2f", (mb * 1000) / elapsed}'
}

prepare_test_file() {
    if [ -n "$CUSTOM_TEST_FILE" ]; then
        TEST_FILE="$CUSTOM_TEST_FILE"
        return
    fi

    TEST_FILE=$(mktemp "$DEFAULT_TEST_FILE_TEMPLATE" 2> /dev/null)
    if [ -z "$TEST_FILE" ]; then
        printf "${RED}Error: Unable to create temporary test file.${NC}\n"
        exit 1
    fi
}

# Color codes
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
CYAN=$(tput setaf 6)
NC=$(tput sgr0)

# Terminal helpers
clear_screen() { tput clear; }
hide_cursor() { tput civis; }
show_cursor() { tput cnorm; }

draw_progress_bar() {
    local current=$1
    local total=$2
    local width=40
    local filled=$(( current * width / total ))
    local empty=$(( width - filled ))

    printf "["
    printf "%${filled}s" | tr ' ' '='
    printf "%${empty}s" | tr ' ' '-'
    printf "] %3d%%" "$(( current * 100 / total ))"
}

print_centered() {
    local text="$1"
    local width=${2:-80}
    local padding=$(( (width - ${#text}) / 2 ))
    printf "%${padding}s%s\n" "" "$text"
}

show_disk_info() {
    printf "${BLUE}Disk Information for Test Location (${YELLOW}$HOME${BLUE}):${NC}\n"
    df -h "$HOME" | awk 'NR==1 || NR==2 {print "  " $0}'
    printf "\n${CYAN}Test Parameters${NC}\n"
    printf "  File: ${YELLOW}%s${NC}\n" "$TEST_FILE"
    printf "  Total Data: ${YELLOW}%s MB${NC}\n" "$TOTAL_MB_LABEL"
    printf "  Chunk Size: ${YELLOW}%s MB${NC} per update\n" "$CHUNK_SIZE_LABEL"
    printf "  Progress Updates: ${YELLOW}%s${NC}\n" "$CHUNK_COUNT"
    printf "\n"
}

show_header() {
    clear_screen
    printf "\n"
    print_centered " ╔═══════════════════════════════════════════════╗"
    print_centered " ║      💾 Disk Speed Test - Interactive TUI     ║"
    print_centered " ╚═══════════════════════════════════════════════╝"
    printf "\n"
}

show_progress() {
    local operation=$1
    local current=$2
    local total=$3
    local speed=$4
    local current_mb=$5
    local total_mb=$6

    printf "${CYAN}%-20s${NC}" "$operation"
    draw_progress_bar "$current" "$total"
    if [ -n "$current_mb" ] && [ -n "$total_mb" ]; then
        printf " ${YELLOW}%s/%s${NC} MB" "$current_mb" "$total_mb"
    fi
    if [ -n "$speed" ]; then
        printf " ${GREEN}%s MB/s${NC}" "$speed"
    fi
}

write_speed_test() {
    show_header
    printf "${BLUE}Starting Write Speed Test...${NC}\n"
    printf "File Size: ${YELLOW}%s MB${NC} | Location: ${YELLOW}%s${NC}\n\n" "$TOTAL_MB_LABEL" "$TEST_FILE"

    rm -f "$TEST_FILE"
    START_TIME=$(date +%s%N)

    for ((chunk=1; chunk<=CHUNK_COUNT; chunk++)); do
        start_block=$(( (chunk - 1) * CHUNK_BLOCKS ))
        remaining=$(( TOTAL_BLOCKS - start_block ))
        if [ $remaining -le 0 ]; then
            break
        fi

        blocks_this_chunk=$(( remaining < CHUNK_BLOCKS ? remaining : CHUNK_BLOCKS ))

        if [ $chunk -eq 1 ]; then
            dd if=/dev/zero of="$TEST_FILE" bs="$BLOCK_SIZE" count="$blocks_this_chunk" status=none 2> /dev/null
        else
            dd if=/dev/zero of="$TEST_FILE" bs="$BLOCK_SIZE" count="$blocks_this_chunk" seek="$start_block" conv=notrunc status=none 2> /dev/null
        fi

        CURRENT_TIME=$(date +%s%N)
        ELAPSED_MS=$(( (CURRENT_TIME - START_TIME) / 1000000 ))
        processed_blocks=$(( start_block + blocks_this_chunk ))
        processed_mb=$(awk -v blocks="$processed_blocks" -v block_mb="$BLOCK_SIZE_MB" 'BEGIN {printf "%.4f", blocks * block_mb}')
        current_mb_label=$(format_mb "$processed_mb")

        if [ $ELAPSED_MS -gt 0 ]; then
            SPEED=$(calc_speed "$processed_mb" "$ELAPSED_MS")
        else
            SPEED="0.00"
        fi

        printf "\r"
        show_progress "Write Test" "$processed_blocks" "$TOTAL_BLOCKS" "$SPEED" "$current_mb_label" "$TOTAL_MB_LABEL"
    done

    sync
    END_TIME=$(date +%s%N)
    WRITE_TIME=$(( (END_TIME - START_TIME) / 1000000 ))
    WRITE_SPEED=$(calc_speed "$TOTAL_MB" "$WRITE_TIME")

    printf "\n${GREEN}✓ Write Speed: %s MB/s (%sms)${NC}\n" "$WRITE_SPEED" "$WRITE_TIME"
    echo "$WRITE_SPEED" > /tmp/write_speed.txt
}

read_speed_test() {
    show_header
    printf "${BLUE}Starting Read Speed Test...${NC}\n"
    printf "File Size: ${YELLOW}%s MB${NC} | Location: ${YELLOW}%s${NC}\n\n" "$TOTAL_MB_LABEL" "$TEST_FILE"

    START_TIME=$(date +%s%N)

    for ((chunk=1; chunk<=CHUNK_COUNT; chunk++)); do
        start_block=$(( (chunk - 1) * CHUNK_BLOCKS ))
        remaining=$(( TOTAL_BLOCKS - start_block ))
        if [ $remaining -le 0 ]; then
            break
        fi

        blocks_this_chunk=$(( remaining < CHUNK_BLOCKS ? remaining : CHUNK_BLOCKS ))

        if [ $chunk -eq 1 ]; then
            dd if="$TEST_FILE" of=/dev/null bs="$BLOCK_SIZE" count="$blocks_this_chunk" status=none 2> /dev/null
        else
            dd if="$TEST_FILE" of=/dev/null bs="$BLOCK_SIZE" count="$blocks_this_chunk" skip="$start_block" status=none 2> /dev/null
        fi

        CURRENT_TIME=$(date +%s%N)
        ELAPSED_MS=$(( (CURRENT_TIME - START_TIME) / 1000000 ))
        processed_blocks=$(( start_block + blocks_this_chunk ))
        processed_mb=$(awk -v blocks="$processed_blocks" -v block_mb="$BLOCK_SIZE_MB" 'BEGIN {printf "%.4f", blocks * block_mb}')
        current_mb_label=$(format_mb "$processed_mb")

        if [ $ELAPSED_MS -gt 0 ]; then
            SPEED=$(calc_speed "$processed_mb" "$ELAPSED_MS")
        else
            SPEED="0.00"
        fi

        printf "\r"
        show_progress "Read Test" "$processed_blocks" "$TOTAL_BLOCKS" "$SPEED" "$current_mb_label" "$TOTAL_MB_LABEL"
    done

    END_TIME=$(date +%s%N)
    READ_TIME=$(( (END_TIME - START_TIME) / 1000000 ))
    READ_SPEED=$(calc_speed "$TOTAL_MB" "$READ_TIME")

    printf "\n${GREEN}✓ Read Speed: %s MB/s (%sms)${NC}\n" "$READ_SPEED" "$READ_TIME"
    echo "$READ_SPEED" > /tmp/read_speed.txt
}

cleanup() {
    if [ -z "$TEST_FILE" ]; then
        return
    fi

    rm -f "$TEST_FILE"
    if [ "$CLEANUP_VERBOSE" -eq 1 ]; then
        if [ ! -f "$TEST_FILE" ]; then
            printf "${GREEN}✓ Test file cleaned up successfully${NC}\n"
        else
            printf "${RED}✗ Warning: Failed to delete test file: $TEST_FILE${NC}\n"
        fi
    fi
}

cleanup_tmp_files() {
    rm -f /tmp/write_speed.txt /tmp/read_speed.txt
}

# --- Derived values ---
BLOCK_SIZE_MB=$(convert_block_size_to_mb "$BLOCK_SIZE")
if ! [[ "$CHUNK_BLOCKS" =~ ^[0-9]+$ ]] || [ $CHUNK_BLOCKS -lt 1 ]; then
    CHUNK_BLOCKS=1
fi
TOTAL_MB=$(awk -v blocks="$TOTAL_BLOCKS" -v block_mb="$BLOCK_SIZE_MB" 'BEGIN {printf "%.4f", blocks * block_mb}')
TOTAL_MB_LABEL=$(format_mb "$TOTAL_MB")
CHUNK_DISPLAY_BLOCKS=$(( TOTAL_BLOCKS < CHUNK_BLOCKS ? TOTAL_BLOCKS : CHUNK_BLOCKS ))
CHUNK_SIZE_MB=$(awk -v blocks="$CHUNK_DISPLAY_BLOCKS" -v block_mb="$BLOCK_SIZE_MB" 'BEGIN {printf "%.4f", blocks * block_mb}')
CHUNK_SIZE_LABEL=$(format_mb "$CHUNK_SIZE_MB")
CHUNK_COUNT=$(( (TOTAL_BLOCKS + CHUNK_BLOCKS - 1) / CHUNK_BLOCKS ))

# --- Main Execution ---
hide_cursor
trap 'show_cursor; CLEANUP_VERBOSE=0; cleanup; cleanup_tmp_files; exit' EXIT

check_dependencies
prepare_test_file

show_header
show_disk_info

write_speed_test
printf "\n"
read_speed_test
printf "\n"

WRITE_SPEED=$(cat /tmp/write_speed.txt 2> /dev/null || echo "0.00")
READ_SPEED=$(cat /tmp/read_speed.txt 2> /dev/null || echo "0.00")

show_header
printf "\n${CYAN}=== Test Results ===${NC}\n\n"
printf "  %-20s ${GREEN}%s MB/s${NC}\n" "Write Speed:" "$WRITE_SPEED"
printf "  %-20s ${GREEN}%s MB/s${NC}\n" "Read Speed:" "$READ_SPEED"
printf "\n"

cleanup
cleanup_tmp_files

printf "${YELLOW}Press any key to exit...${NC}"
read -rsn1
printf "\n"
