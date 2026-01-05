#!/bin/bash

# SCRIPT CONFIGURATION
STATE_DIR="/var/tmp/cf_protection_multi"
mkdir -p "$STATE_DIR"

# LOGGING FUNCTION
if [ -t 1 ]; then
    VERBOSE=true
else
    VERBOSE=false
fi
log() {
    local MSG="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$MSG" >> "$STATE_DIR/protection.log"
    if [ "$VERBOSE" = true ]; then
        echo "$MSG"
    fi
}

# DEPENDENCY CHECK
for cmd in bc curl awk ps; do
    if ! command -v $cmd &> /dev/null; then
        log "✗ Error: command '$cmd' not found. Please install it."
        exit 1
    fi
done

# SINGLETON ENFORCEMENT
LOCKFILE="/tmp/cf_monitor.lock"
if [ -e $LOCKFILE ]; then
    log "⚠ Script is already running. Exiting."
    exit 1
fi
touch $LOCKFILE
trap "rm -f $LOCKFILE" EXIT # Ensure lockfile is removed on exit

# MONITORING CONFIGURATION
CPU_THRESHOLD=20.0
HIGH_LOAD_DURATION=120
COOLDOWN_DURATION=300

# TELEGRAM CONFIGURATION
TELEGRAM_BOT_TOKEN="YOUR_BOT_TOKEN_HERE"
TELEGRAM_CHAT_ID="YOUR_CHAT_ID_HERE"
TELEGRAM_ENABLED=true

# CLOUDFLARE CONFIGURATION
declare -A ZONES
declare -A TOKENS

# Website 1
ZONES[root]="ZONE_ID_1"
TOKENS[root]="TOKEN_1"

# Website 2
# ZONES[example]="ZONE_ID_2"
# TOKENS[example]="TOKEN_2"

# FUNCTIONS
send_telegram() {
    [ "$TELEGRAM_ENABLED" != "true" ] && return 0
    local message=$1
    curl -s -G "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
        --data-urlencode "text=${message}" \
        --data-urlencode "parse_mode=Markdown" > /dev/null
}

set_cf_protection() {
    local user=$1
    local level=$2 
    local zone_id=${ZONES[$user]}
    local api_token=${TOKENS[$user]}
    
    # Use individual Cloudflare API token for each user
    local response=$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$zone_id/settings/security_level" \
        -H "Authorization: Bearer $api_token" \
        -H "Content-Type: application/json" \
        --data "{\"value\":\"$level\"}")
    
    if echo "$response" | grep -q '"success":true'; then
        log "✓ Cloudflare for $user set to $level"
        return 0
    else
        log "✗ Cloudflare error for $user: $response"
        return 1
    fi
}

# MAIN LOGIC
for USER in "${!ZONES[@]}"
do
    # Get current CPU load for the user
    CURRENT_LOAD=$(ps aux | grep -w "^$USER" | awk '{sum+=$3} END {print sum}')
    [ -z "$CURRENT_LOAD" ] && CURRENT_LOAD=0
    
    LOAD_START_FILE="$STATE_DIR/${USER}_high_load_start"
    UNDER_ATTACK_FILE="$STATE_DIR/${USER}_active"
    NORMAL_START_FILE="$STATE_DIR/${USER}_normal_start"
    
    log "Checking user: $USER | Current Load: $CURRENT_LOAD% | Threshold: $CPU_THRESHOLD%"

    # Processing logic (similar to previous, but with individual token)
    if (( $(echo "$CURRENT_LOAD > $CPU_THRESHOLD" | bc -l) )); then
        rm -f "$NORMAL_START_FILE"

        if [ ! -f "$UNDER_ATTACK_FILE" ]; then
            if [ ! -f "$LOAD_START_FILE" ]; then
                echo $(date +%s) > "$LOAD_START_FILE"
                log "⚠ $USER: High load detected ($CURRENT_LOAD%)."
            else
                start_time=$(cat "$LOAD_START_FILE")
                elapsed=$(( $(date +%s) - start_time ))
                
                if [ "$elapsed" -ge "$HIGH_LOAD_DURATION" ]; then
                    log "🚨 $USER: Activating protection..."
                    if set_cf_protection "$USER" "under_attack"; then
                        touch "$UNDER_ATTACK_FILE"
                        send_telegram "🚨 *CF PROTECT ON*: User *$USER* (Load: $CURRENT_LOAD%)"
                    fi
                fi
            fi
        fi
    else
        # Normalization logic...
        rm -f "$LOAD_START_FILE"
        if [ -f "$UNDER_ATTACK_FILE" ]; then
            if [ ! -f "$NORMAL_START_FILE" ]; then
                echo $(date +%s) > "$NORMAL_START_FILE"
            else
                start_time=$(cat "$NORMAL_START_FILE")
                elapsed=$(( $(date +%s) - start_time ))
                if [ "$elapsed" -ge "$COOLDOWN_DURATION" ]; then
                    if set_cf_protection "$USER" "medium"; then
                        rm -f "$UNDER_ATTACK_FILE" "$NORMAL_START_FILE"
                        send_telegram "✅ *CF PROTECT OFF*: User *$USER* normalized."
                    fi
                fi
            fi
        fi
    fi
done