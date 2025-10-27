#!/bin/bash
# Example configuration file for Cloudflare Protection Script
# Copy this file and customize it for your needs

# ===========================================
# CLOUDFLARE CONFIGURATION
# ===========================================

# Your Cloudflare API Token
# Get it from: https://dash.cloudflare.com/profile/api-tokens
# Required permissions: Zone.Zone Settings.Edit, Zone.Zone.Read
CF_API_TOKEN="your-cloudflare-api-token-here"

# Array of Cloudflare Zone IDs to protect
# You can find Zone ID in your domain's Overview page (right sidebar)
# Add as many zones as you need, one per line
CF_ZONE_IDS=(
    "zone_id_for_example_com"
    "zone_id_for_another_site_com"
    # "zone_id_for_third_site_com"  # Commented zones are ignored
)

# ===========================================
# TELEGRAM NOTIFICATION SETTINGS (OPTIONAL)
# ===========================================

# Telegram Bot Token
# Create a bot via @BotFather: https://t.me/botfather
TELEGRAM_BOT_TOKEN="123456789:ABCdefGHIjklMNOpqrsTUVwxyz"

# Telegram Chat ID
# Get your chat ID by messaging your bot and visiting:
# https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates
TELEGRAM_CHAT_ID="123456789"

# Enable or disable Telegram notifications
TELEGRAM_ENABLED=true  # Set to false to disable

# ===========================================
# CPU MONITORING SETTINGS
# ===========================================

# CPU load threshold percentage (0-100)
# Protection activates when average CPU exceeds this value
CPU_THRESHOLD=80

# Number of CPU measurements to average
# Higher = more stable, but slower to react
# Recommended: 3-5
CPU_SAMPLES=3

# Duration in seconds that CPU must stay high before activating protection
# Prevents false positives from temporary spikes
# Recommended: 120-300 (2-5 minutes)
HIGH_LOAD_DURATION=120

# Duration in seconds that CPU must stay normal before deactivating protection
# Ensures load has truly stabilized
# Recommended: 300-600 (5-10 minutes)
COOLDOWN_DURATION=300

# ===========================================
# STATE FILES LOCATION
# ===========================================

# Directory where state files and logs are stored
# Default: /var/tmp/cf_protection
# Make sure the script has write permissions
STATE_DIR="/var/tmp/cf_protection"

# ===========================================
# EXAMPLES FOR DIFFERENT USE CASES
# ===========================================

# Conservative (slow to trigger, slow to recover):
# CPU_THRESHOLD=90
# HIGH_LOAD_DURATION=300
# COOLDOWN_DURATION=600

# Aggressive (fast to trigger, fast to recover):
# CPU_THRESHOLD=70
# HIGH_LOAD_DURATION=60
# COOLDOWN_DURATION=180

# Balanced (recommended for most cases):
# CPU_THRESHOLD=80
# HIGH_LOAD_DURATION=120
# COOLDOWN_DURATION=300
