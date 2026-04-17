#!/bin/bash

# Common functions for HomeGuardian monitoring modules

# Function to load thresholds from config file
load_thresholds() {
    local section=$1
    local thresholds_file=$2
    
    if [ ! -f "$thresholds_file" ]; then
        echo "ERROR: Thresholds file not found: $thresholds_file" >&2
        return 1
    fi
    
    # Read the entire config file
    local in_section=false
    declare -A thresholds
    
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^#.*$ ]] && continue
        [[ -z "$line" ]] && continue
        
        # Check for section headers
        if [[ "$line" =~ ^\[(.*)\]$ ]]; then
            if [ "${BASH_REMATCH[1]}" = "$section" ]; then
                in_section=true
            elif [ "$in_section" = true ]; then
                # We've left our section
                break
            fi
            continue
        fi
        
        # If we're in the right section, parse key=value pairs
        if [ "$in_section" = true ]; then
            if [[ "$line" =~ ^([^=]+)=([^#]+) ]]; then
                key="${BASH_REMATCH[1]}"
                value="${BASH_REMATCH[2]}"
                # Remove trailing spaces and comments
                value=$(echo "$value" | sed 's/[[:space:]]*$//' | sed 's/#.*$//')
                thresholds["$key"]="$value"
            fi
        fi
    done < "$thresholds_file"
    
    # Export the thresholds as variables
    for key in "${!thresholds[@]}"; do
        eval "$key=\"${thresholds[$key]}\""
    done
    
    return 0
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to get timestamp
get_timestamp() {
    date +%Y-%m-%d_%H:%M:%S
}

# Function to create directories if they don't exist
ensure_directories() {
    for dir in "$@"; do
        mkdir -p "$dir"
    done
}

# Function to log messages
log_message() {
    local level=$1
    local message=$2
    local log_file=$3
    local timestamp=$(get_timestamp)
    
    echo "[$timestamp] [$level] $message" >> "$log_file"
}

# Function to check if value exceeds threshold
check_threshold() {
    local value=$1
    local warning_threshold=$2
    local critical_threshold=$3
    
    if (( $(echo "$value > $critical_threshold" | bc -l) )); then
        echo "CRITICAL"
    elif (( $(echo "$value > $warning_threshold" | bc -l) )); then
        echo "WARNING"
    else
        echo "INFO"
    fi
}