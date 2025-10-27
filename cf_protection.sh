#!/bin/bash

# Cloudflare Configuration
CF_API_TOKEN="your-cf-api-token"

# Array of Zone IDs (add as many as needed)
CF_ZONE_IDS=(
    "your_first_zone_id_here"
    # "your_second_zone_id_here"
    # "your_third_zone_id_here"
)

# Telegram Settings
TELEGRAM_BOT_TOKEN="your-telegram-bot-token"
TELEGRAM_CHAT_ID="your-telegram-chat-id"
TELEGRAM_ENABLED=true  # Set to false to disable notifications

# Monitoring Settings
CPU_THRESHOLD=80
CPU_SAMPLES=3
HIGH_LOAD_DURATION=120  # seconds (2 minutes)
COOLDOWN_DURATION=300   # seconds (5 minutes)

# State files
STATE_DIR="/var/tmp/cf_protection"
HIGH_LOAD_START_FILE="$STATE_DIR/high_load_start"
UNDER_ATTACK_FILE="$STATE_DIR/under_attack_enabled"
NORMAL_LOAD_START_FILE="$STATE_DIR/normal_load_start"
CPU_HISTORY_FILE="$STATE_DIR/cpu_history"
LAST_TELEGRAM_FILE="$STATE_DIR/last_telegram_notification"

mkdir -p "$STATE_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$STATE_DIR/protection.log"
}

send_telegram() {
    local message=$1
    local silent=${2:-false}
    
    if [ "$TELEGRAM_ENABLED" != "true" ]; then
        return 0
    fi
    
    local response=$(curl -s -G "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
        --data-urlencode "text=${message}" \
        --data-urlencode "parse_mode=Markdown" \
        --data-urlencode "disable_notification=${silent}")
    
    if echo "$response" | grep -q '"ok":true'; then
        log "→ Telegram message sent"
        return 0
    else
        log "✗ Telegram send error: $response"
        return 1
    fi
}

# Check if notification should be sent (anti-spam)
should_send_telegram() {
    local notification_type=$1
    local cooldown_minutes=${2:-5}
    
    local last_file="${LAST_TELEGRAM_FILE}_${notification_type}"
    
    if [ ! -f "$last_file" ]; then
        return 0
    fi
    
    local last_time=$(cat "$last_file")
    local current_time=$(date +%s)
    local elapsed=$((current_time - last_time))
    local cooldown_seconds=$((cooldown_minutes * 60))
    
    if [ "$elapsed" -ge "$cooldown_seconds" ]; then
        return 0
    else
        return 1
    fi
}

mark_telegram_sent() {
    local notification_type=$1
    local last_file="${LAST_TELEGRAM_FILE}_${notification_type}"
    echo $(date +%s) > "$last_file"
}

get_hostname() {
    if command -v hostname >/dev/null 2>&1; then
        hostname
    else
        cat /etc/hostname 2>/dev/null || echo "Unknown"
    fi
}

get_zone_name() {
    local zone_id=$1
    
    local response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${zone_id}" \
        -H "Authorization: Bearer $CF_API_TOKEN" \
        -H "Content-Type: application/json")
    
    if echo "$response" | grep -q '"success":true'; then
        local zone_name=$(echo "$response" | grep -o '"name":"[^"]*"' | head -n1 | cut -d'"' -f4)
        echo "$zone_name"
    else
        echo "Zone-${zone_id:0:8}"
    fi
}

get_single_cpu_measurement() {
    local stat1=$(head -n1 /proc/stat)
    local user1=$(echo $stat1 | awk '{print $2}')
    local nice1=$(echo $stat1 | awk '{print $3}')
    local system1=$(echo $stat1 | awk '{print $4}')
    local idle1=$(echo $stat1 | awk '{print $5}')
    local iowait1=$(echo $stat1 | awk '{print $6}')
    local irq1=$(echo $stat1 | awk '{print $7}')
    local softirq1=$(echo $stat1 | awk '{print $8}')
    local steal1=$(echo $stat1 | awk '{print $9}')
    
    sleep 1
    
    local stat2=$(head -n1 /proc/stat)
    local user2=$(echo $stat2 | awk '{print $2}')
    local nice2=$(echo $stat2 | awk '{print $3}')
    local system2=$(echo $stat2 | awk '{print $4}')
    local idle2=$(echo $stat2 | awk '{print $5}')
    local iowait2=$(echo $stat2 | awk '{print $6}')
    local irq2=$(echo $stat2 | awk '{print $7}')
    local softirq2=$(echo $stat2 | awk '{print $8}')
    local steal2=$(echo $stat2 | awk '{print $9}')
    
    local user=$((user2 - user1))
    local nice=$((nice2 - nice1))
    local system=$((system2 - system1))
    local idle=$((idle2 - idle1))
    local iowait=$((iowait2 - iowait1))
    local irq=$((irq2 - irq1))
    local softirq=$((softirq2 - softirq1))
    local steal=$((steal2 - steal1))
    
    local total=$((user + nice + system + idle + iowait + irq + softirq + steal))
    local used=$((total - idle))
    
    if [ "$total" -gt 0 ]; then
        local cpu_load=$((used * 100 / total))
        echo "$cpu_load"
    else
        echo "0"
    fi
}

# Fast CPU measurement via top
get_cpu_load_fast() {
    local cpu_line=$(top -bn2 -d 0.5 | grep -i "cpu(s)" | tail -n1)
    
    if [ -z "$cpu_line" ]; then
        echo ""
        return
    fi
    
    local cpu_idle=$(echo "$cpu_line" | grep -oP '\d+\.\d+\s*%?\s*id' | grep -oP '\d+\.\d+' | head -n1)
    
    if [ -z "$cpu_idle" ]; then
        cpu_idle=$(echo "$cpu_line" | awk '{for(i=1;i<=NF;i++) if($i~/id/) print $(i-1)}' | tr -d '%,')
    fi
    
    if [ -n "$cpu_idle" ]; then
        local cpu_load=$(awk "BEGIN {printf \"%.0f\", 100 - $cpu_idle}")
        echo "$cpu_load"
    else
        echo ""
    fi
}

get_load_average() {
    local load=$(cat /proc/loadavg | awk '{print $1}')
    local cpu_cores=$(grep -c ^processor /proc/cpuinfo)
    
    if [ -z "$load" ] || [ "$cpu_cores" -eq 0 ]; then
        echo "0"
        return
    fi
    
    local cpu_load=$(awk "BEGIN {printf \"%.0f\", ($load / $cpu_cores) * 100}")
    echo "$cpu_load"
}

save_cpu_to_history() {
    local cpu=$1
    local timestamp=$(date +%s)
    
    echo "${timestamp}:${cpu}" >> "$CPU_HISTORY_FILE"
    tail -n 10 "$CPU_HISTORY_FILE" > "${CPU_HISTORY_FILE}.tmp"
    mv "${CPU_HISTORY_FILE}.tmp" "$CPU_HISTORY_FILE"
}

get_average_cpu_from_history() {
    local samples=${1:-3}
    
    if [ ! -f "$CPU_HISTORY_FILE" ]; then
        echo "0"
        return
    fi
    
    local sum=0
    local count=0
    
    while IFS=: read -r timestamp cpu_value; do
        sum=$((sum + cpu_value))
        count=$((count + 1))
    done < <(tail -n "$samples" "$CPU_HISTORY_FILE")
    
    if [ "$count" -eq 0 ]; then
        echo "0"
    else
        echo $((sum / count))
    fi
}

# Get CPU with averaging
get_cpu() {
    local cpu_load=""
    local method=""
    
    cpu_load=$(get_cpu_load_fast)
    method="top"
    
    if [ -z "$cpu_load" ] || [ "$cpu_load" -lt 0 ] || [ "$cpu_load" -gt 100 ]; then
        cpu_load=$(get_single_cpu_measurement)
        method="proc_stat"
    fi
    
    if [ -z "$cpu_load" ] || [ "$cpu_load" -lt 0 ] || [ "$cpu_load" -gt 100 ]; then
        cpu_load=$(get_load_average)
        method="load_avg"
    fi
    
    if [ -z "$cpu_load" ]; then
        cpu_load=0
    fi
    
    if [ "$cpu_load" -lt 0 ]; then
        cpu_load=0
    elif [ "$cpu_load" -gt 100 ]; then
        cpu_load=100
    fi
    
    save_cpu_to_history "$cpu_load"
    local avg_cpu=$(get_average_cpu_from_history "$CPU_SAMPLES")
    
    echo "${cpu_load}:${avg_cpu}:${method}"
}

# Change security level for all zones
set_security_level_all_zones() {
    local level=$1
    local success_count=0
    local fail_count=0
    local zone_names=""
    
    log "→ Changing security level to '$level' for ${#CF_ZONE_IDS[@]} zone(s)..."
    
    for zone_id in "${CF_ZONE_IDS[@]}"; do
        if [[ "$zone_id" =~ ^#.*$ ]] || [ -z "$zone_id" ]; then
            continue
        fi
        
        local zone_name=$(get_zone_name "$zone_id")
        
        local response=$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$zone_id/settings/security_level" \
            -H "Authorization: Bearer $CF_API_TOKEN" \
            -H "Content-Type: application/json" \
            --data "{\"value\":\"$level\"}")
        
        if echo "$response" | grep -q '"success":true'; then
            log "  ✓ $zone_name ($zone_id) - success"
            success_count=$((success_count + 1))
            zone_names="${zone_names}${zone_name}, "
        else
            log "  ✗ $zone_name ($zone_id) - error: $response"
            fail_count=$((fail_count + 1))
        fi
    done
    
    zone_names=${zone_names%, }
    
    if [ "$fail_count" -eq 0 ]; then
        log "✓ All zones updated successfully: $zone_names"
        echo "$zone_names"
        return 0
    else
        log "⚠ Updated $success_count of $((success_count + fail_count)) zones"
        echo "$zone_names"
        return 1
    fi
}

enable_under_attack() {
    local current_cpu=$1
    local avg_cpu=$2
    local hostname=$(get_hostname)
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    log "⚠ Activating Cloudflare Under Attack Mode..."
    
    zone_names=$(set_security_level_all_zones "under_attack")
    local result=$?
    
    if [ $result -eq 0 ] || [ -n "$zone_names" ]; then
        touch "$UNDER_ATTACK_FILE"
        rm -f "$NORMAL_LOAD_START_FILE"
        
        if should_send_telegram "attack_enabled" 10; then
            local message="🚨 *CLOUDFLARE UNDER ATTACK MODE ACTIVATED*

🖥 *Server:* ${hostname}
🌐 *Domains:* ${zone_names}
📊 *Current CPU:* ${current_cpu}%
📈 *Average CPU:* ${avg_cpu}%
⚠️ *Threshold:* ${CPU_THRESHOLD}%
🛡 *Mode:* Under Attack Mode
⏰ *Time:* ${timestamp}

High load stable for over 2 minutes. Cloudflare protection activated for all zones."
            
            send_telegram "$message" false
            mark_telegram_sent "attack_enabled"
        fi
        
        return 0
    fi
    return 1
}

disable_under_attack() {
    local current_cpu=$1
    local avg_cpu=$2
    local hostname=$(get_hostname)
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    log "✓ Deactivating Cloudflare Under Attack Mode..."
    
    zone_names=$(set_security_level_all_zones "medium")
    local result=$?
    
    if [ $result -eq 0 ] || [ -n "$zone_names" ]; then
        rm -f "$UNDER_ATTACK_FILE"
        rm -f "$NORMAL_LOAD_START_FILE"
        rm -f "$HIGH_LOAD_START_FILE"
        
        if should_send_telegram "attack_disabled" 10; then
            local message="✅ *CLOUDFLARE UNDER ATTACK MODE DISABLED*

🖥 *Server:* ${hostname}
🌐 *Domains:* ${zone_names}
📊 *Current CPU:* ${current_cpu}%
📈 *Average CPU:* ${avg_cpu}%
✓ *Status:* Normalized
🔓 *Mode:* Medium Security
⏰ *Time:* ${timestamp}

Load returned to normal for over 5 minutes. Protection disabled for all zones."
            
            send_telegram "$message" true
            mark_telegram_sent "attack_disabled"
        fi
        
        return 0
    fi
    return 1
}

send_high_load_warning() {
    local current_cpu=$1
    local avg_cpu=$2
    local hostname=$(get_hostname)
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    if should_send_telegram "high_load_warning" 30; then
        local zone_list=""
        for zone_id in "${CF_ZONE_IDS[@]}"; do
            if [[ "$zone_id" =~ ^#.*$ ]] || [ -z "$zone_id" ]; then
                continue
            fi
            local zone_name=$(get_zone_name "$zone_id")
            zone_list="${zone_list}${zone_name}, "
        done
        zone_list=${zone_list%, }
        
        local message="⚠️ *WARNING: High CPU Load*

🖥 *Server:* ${hostname}
🌐 *Domains:* ${zone_list}
📊 *Current CPU:* ${current_cpu}%
📈 *Average CPU:* ${avg_cpu}%
⏱ *Status:* Countdown started
⏰ *Time:* ${timestamp}

If load continues stable for 2 more minutes, Under Attack Mode will be activated for all zones."
        
        send_telegram "$message" true
        mark_telegram_sent "high_load_warning"
    fi
}

main() {
    cpu_result=$(get_cpu)
    current_cpu=$(echo "$cpu_result" | cut -d':' -f1)
    avg_cpu=$(echo "$cpu_result" | cut -d':' -f2)
    cpu_method=$(echo "$cpu_result" | cut -d':' -f3)
    
    if [ -z "$current_cpu" ]; then
        log "✗ Failed to get CPU load"
        exit 1
    fi
    
    cpu_cores=$(grep -c ^processor /proc/cpuinfo)
    load_avg=$(cat /proc/loadavg | awk '{print $1}')
    
    log "CPU: ${current_cpu}% | Average: ${avg_cpu}% | Method: $cpu_method | Cores: ${cpu_cores} | Load: ${load_avg} | Zones: ${#CF_ZONE_IDS[@]}"
    
    if [ "$avg_cpu" -ge "$CPU_THRESHOLD" ]; then
        log "⚠ Average CPU load exceeds ${CPU_THRESHOLD}%"
        
        if [ ! -f "$HIGH_LOAD_START_FILE" ]; then
            echo $(date +%s) > "$HIGH_LOAD_START_FILE"
            log "→ High load countdown started"
            send_high_load_warning "$current_cpu" "$avg_cpu"
        else
            high_load_start=$(cat "$HIGH_LOAD_START_FILE")
            current_time=$(date +%s)
            elapsed=$((current_time - high_load_start))
            
            log "→ High load duration: ${elapsed}s (required ${HIGH_LOAD_DURATION}s)"
            
            if [ "$elapsed" -ge "$HIGH_LOAD_DURATION" ] && [ ! -f "$UNDER_ATTACK_FILE" ]; then
                enable_under_attack "$current_cpu" "$avg_cpu"
            fi
        fi
        
        rm -f "$NORMAL_LOAD_START_FILE"
        
    else
        log "✓ Average CPU within normal range"
        
        rm -f "$HIGH_LOAD_START_FILE"
        
        if [ -f "$UNDER_ATTACK_FILE" ]; then
            if [ ! -f "$NORMAL_LOAD_START_FILE" ]; then
                echo $(date +%s) > "$NORMAL_LOAD_START_FILE"
                log "→ Cooldown period started"
            else
                normal_load_start=$(cat "$NORMAL_LOAD_START_FILE")
                current_time=$(date +%s)
                elapsed=$((current_time - normal_load_start))
                
                log "→ Cooldown duration: ${elapsed}s (required ${COOLDOWN_DURATION}s)"
                
                if [ "$elapsed" -ge "$COOLDOWN_DURATION" ]; then
                    disable_under_attack "$current_cpu" "$avg_cpu"
                fi
            fi
        fi
    fi
}

# Check required commands
for cmd in curl awk; do
    if ! command -v $cmd &> /dev/null; then
        log "✗ Error: command '$cmd' not found"
        exit 1
    fi
done

# Check configuration
if [ ${#CF_ZONE_IDS[@]} -eq 0 ]; then
    log "✗ Error: Add at least one Zone ID to CF_ZONE_IDS array"
    exit 1
fi

# Test Telegram
if [ "$1" = "--test-telegram" ]; then
    hostname=$(get_hostname)
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    zone_list=""
    for zone_id in "${CF_ZONE_IDS[@]}"; do
        if [[ "$zone_id" =~ ^#.*$ ]] || [ -z "$zone_id" ]; then
            continue
        fi
        zone_name=$(get_zone_name "$zone_id")
        zone_list="${zone_list}${zone_name}, "
    done
    zone_list=${zone_list%, }
    
    message="✅ *Telegram Test*

🖥 *Server:* ${hostname}
🌐 *Protected domains:* ${zone_list}
⏰ *Time:* ${timestamp}
🔧 *Status:* Script working correctly

This is a test message from Cloudflare Protection monitoring script with multi-zone support."
    
    log "→ Sending test message to Telegram..."
    if send_telegram "$message" false; then
        log "✓ Test message sent successfully!"
    else
        log "✗ Failed to send test message"
        exit 1
    fi
    exit 0
fi

# Run main logic
main