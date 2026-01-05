# 🛡️ Cloudflare Under Attack Mode Automation

Automatic Cloudflare "Under Attack Mode" activation based on server CPU load monitoring. Perfect for protecting your websites during DDoS attacks or traffic spikes.

## 🌟 Features

- **🤖 Automatic Protection**: Automatically enables Cloudflare's "Under Attack Mode" when CPU load is high
- **📊 Smart CPU Monitoring**: Uses multiple methods (top, /proc/stat, load average) for accurate measurements
- **📈 Averaging Algorithm**: Prevents false positives with CPU load averaging over multiple samples
- **⏱️ Configurable Thresholds**: Set custom CPU thresholds and duration timers
- **🌐 Multi-Zone Support**: Protect multiple domains/zones simultaneously
- **📱 Telegram Notifications**: Get instant alerts with detailed information
- **🔄 Auto-Recovery**: Automatically disables protection when load returns to normal
- **🚫 Anti-Spam**: Built-in notification cooldown to prevent message spam
- **📝 Detailed Logging**: Comprehensive logs for monitoring and debugging
- **👥 Multi-User Mode**: Separate script for per-user CPU monitoring (shared hosting)

## 📁 Available Scripts

| Script | Use Case |
|--------|----------|
| `cf_protection.sh` | Single server monitoring based on total CPU load |
| `cf_protection_multi.sh` | Multi-user/multi-zone monitoring with individual API tokens |

## 📋 Requirements

- Linux server with `/proc/stat` support
- Bash shell
- `curl` and `awk` commands
- Cloudflare account with API access
- (Optional) Telegram bot for notifications

## 🚀 Quick Start

### 1. Clone the repository

```bash
git clone https://github.com/and-ri/cloudflare-auto-protection.git
cd cloudflare-auto-protection
```

### 2. Configure the script

Edit `cf_protection.sh` and set your credentials:

```bash
# Cloudflare Configuration
CF_API_TOKEN="your-cloudflare-api-token"

# Add your Zone IDs
CF_ZONE_IDS=(
    "your_first_zone_id_here"
    "your_second_zone_id_here"
)

# Telegram Settings (optional)
TELEGRAM_BOT_TOKEN="your-telegram-bot-token"
TELEGRAM_CHAT_ID="your-telegram-chat-id"
TELEGRAM_ENABLED=true
```

### 3. Make it executable

```bash
chmod +x cf_protection.sh
```

### 4. Test Telegram notifications (optional)

```bash
./cf_protection.sh --test-telegram
```

### 5. Set up automatic monitoring

Add to crontab to run every minute:

```bash
crontab -e
```

Add this line:

```
* * * * * /path/to/cf_protection.sh
```

## ⚙️ Configuration

### Core Settings

| Parameter | Default | Description |
|-----------|---------|-------------|
| `CPU_THRESHOLD` | 80 | CPU load percentage threshold to trigger protection |
| `CPU_SAMPLES` | 3 | Number of measurements to average for stability |
| `HIGH_LOAD_DURATION` | 120 | Seconds of high load before activating (2 minutes) |
| `COOLDOWN_DURATION` | 300 | Seconds of normal load before deactivating (5 minutes) |

### Getting Cloudflare API Token

1. Go to [Cloudflare Dashboard](https://dash.cloudflare.com/)
2. Click on your profile → **API Tokens**
3. Click **Create Token**
4. Use **Edit zone security** template or create custom with:
   - Zone → Zone Settings → Edit
   - Zone → Zone → Read
5. Copy the token to `CF_API_TOKEN`

### Getting Zone IDs

1. Go to your domain in Cloudflare Dashboard
2. Scroll down in the **Overview** tab
3. Find **Zone ID** in the right sidebar
4. Copy it to `CF_ZONE_IDS` array

### Setting up Telegram Bot (Optional)

1. Talk to [@BotFather](https://t.me/botfather) on Telegram
2. Send `/newbot` and follow instructions
3. Copy the bot token to `TELEGRAM_BOT_TOKEN`
4. Start a chat with your bot
5. Get your chat ID:
   ```bash
   curl "https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates"
   ```
6. Copy `chat.id` to `TELEGRAM_CHAT_ID`

## 📊 How It Works

```
┌─────────────────────┐
│  Monitor CPU Load   │
│   (every minute)    │
└──────────┬──────────┘
           │
           ▼
    ┌─────────────┐
    │ CPU > 80%?  │
    └──────┬──────┘
           │
    ┌──────▼───────┐         ┌────────────────┐
    │   Yes: Wait  │────────▶│  After 2 min:  │
    │   2 minutes  │         │ Enable Attack  │
    │              │         │     Mode       │
    └──────────────┘         └────────┬───────┘
           │                          │
           │                          ▼
    ┌──────▼───────┐         ┌────────────────┐
    │   No: Is     │         │  Monitor CPU   │
    │   Attack     │────────▶│  Wait for      │
    │   Mode ON?   │         │  normalization │
    └──────────────┘         └────────┬───────┘
                                      │
                             ┌────────▼────────┐
                             │  After 5 min:   │
                             │ Disable Attack  │
                             │      Mode       │
                             └─────────────────┘
```

### Protection Levels

- **Normal State**: Medium security level
- **High Load Detected**: Warning notification sent
- **After 2 minutes of high load**: Under Attack Mode enabled
- **After 5 minutes of normal load**: Protection disabled

## 📱 Telegram Notifications

You'll receive notifications for:

### 🚨 Attack Mode Activated
```
🚨 CLOUDFLARE UNDER ATTACK MODE ACTIVATED

🖥 Server: your-server
🌐 Domains: example.com, site.com
📊 Current CPU: 95%
📈 Average CPU: 92%
⚠️ Threshold: 80%
🛡 Mode: Under Attack Mode
⏰ Time: 2025-10-27 14:30:00
```

### ✅ Attack Mode Disabled
```
✅ CLOUDFLARE UNDER ATTACK MODE DISABLED

🖥 Server: your-server
🌐 Domains: example.com, site.com
📊 Current CPU: 45%
📈 Average CPU: 48%
✓ Status: Normalized
🔓 Mode: Medium Security
⏰ Time: 2025-10-27 14:35:00
```

### ⚠️ High Load Warning
```
⚠️ WARNING: High CPU Load

🖥 Server: your-server
🌐 Domains: example.com, site.com
📊 Current CPU: 85%
📈 Average CPU: 83%
⏱ Status: Countdown started
⏰ Time: 2025-10-27 14:28:00
```

## 📝 Logs

Logs are stored in `/var/tmp/cf_protection/protection.log`

Example log output:
```
[2025-10-27 14:28:00] CPU: 85% | Average: 83% | Method: top | Cores: 4 | Load: 3.2 | Zones: 2
[2025-10-27 14:28:00] ⚠ Average CPU load exceeds 80%
[2025-10-27 14:28:00] → High load countdown started
[2025-10-27 14:30:00] ⚠ Activating Cloudflare Under Attack Mode...
[2025-10-27 14:30:01] → Changing security level to 'under_attack' for 2 zone(s)...
[2025-10-27 14:30:02]   ✓ example.com (abc123...) - success
[2025-10-27 14:30:03]   ✓ site.com (def456...) - success
[2025-10-27 14:30:03] ✓ All zones updated successfully
```

## 🔧 Advanced Usage

### Manual Testing

Test the script manually:
```bash
./cf_protection.sh
```

Test Telegram notifications:
```bash
./cf_protection.sh --test-telegram
```

### Custom Cron Schedule

Run every 2 minutes:
```
*/2 * * * * /path/to/cf_protection.sh
```

Run every 30 seconds:
```
* * * * * /path/to/cf_protection.sh
* * * * * sleep 30; /path/to/cf_protection.sh
```

### Multiple Servers

You can run this script on multiple servers protecting the same zones. The script handles concurrent changes gracefully.

### State Files

The script maintains state in `/var/tmp/cf_protection/`:
- `high_load_start` - When high load detection started
- `under_attack_enabled` - Flag indicating protection is active
- `normal_load_start` - When normal load detection started
- `cpu_history` - Recent CPU measurements
- `last_telegram_notification_*` - Anti-spam timestamps
- `protection.log` - Activity log

## � Multi-User Mode (cf_protection_multi.sh)

The `cf_protection_multi.sh` script is designed for shared hosting environments or scenarios where you need to monitor CPU usage per system user with individual Cloudflare zones and API tokens.

### Configuration

Edit `cf_protection_multi.sh` and configure:

```bash
# Telegram Configuration
TELEGRAM_BOT_TOKEN="YOUR_BOT_TOKEN_HERE"
TELEGRAM_CHAT_ID="YOUR_CHAT_ID_HERE"
TELEGRAM_ENABLED=true

# Cloudflare Configuration - Add zones and tokens
declare -A ZONES
declare -A TOKENS

# Website 1
ZONES[username1]="ZONE_ID_1"
TOKENS[username1]="API_TOKEN_1"

# Website 2
ZONES[username2]="ZONE_ID_2"
TOKENS[username2]="API_TOKEN_2"
```

### Multi-User Settings

| Parameter | Default | Description |
|-----------|---------|-------------|
| `CPU_THRESHOLD` | 20 | Per-user CPU threshold percentage |
| `HIGH_LOAD_DURATION` | 120 | Seconds before activating protection |
| `COOLDOWN_DURATION` | 300 | Seconds of normal load before deactivating |

### How It Works

1. Monitors CPU usage for each configured system user via `ps aux`
2. Each user has independent protection state
3. Uses individual Cloudflare API tokens per zone
4. Singleton enforcement prevents concurrent script runs
5. State files stored in `/var/tmp/cf_protection_multi/`

### Multi-User State Files

Per-user state files in `/var/tmp/cf_protection_multi/`:
- `{user}_high_load_start` - High load detection timestamp
- `{user}_active` - Protection active flag
- `{user}_normal_start` - Normalization countdown start
- `protection.log` - Combined activity log

### Setup Cron for Multi-User

```bash
* * * * * /path/to/cf_protection_multi.sh
```

## �🐛 Troubleshooting

### Script doesn't run

Check permissions:
```bash
chmod +x cf_protection.sh
```

Check required commands:
```bash
which curl awk
```

### No Telegram notifications

1. Verify bot token and chat ID
2. Run test: `./cf_protection.sh --test-telegram`
3. Check if `TELEGRAM_ENABLED=true`
4. Check logs for error messages

### Protection not activating

1. Check CPU threshold matches your server load
2. Verify Zone IDs are correct
3. Check API token has correct permissions
4. Review logs: `tail -f /var/tmp/cf_protection/protection.log`

### False positives

Increase thresholds:
```bash
CPU_THRESHOLD=90          # Higher CPU threshold
CPU_SAMPLES=5             # More samples for averaging
HIGH_LOAD_DURATION=180    # Longer wait time (3 minutes)
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is open source and available under the [MIT License](LICENSE).

## ⚠️ Disclaimer

This script modifies your Cloudflare security settings. Test thoroughly in a development environment before deploying to production. The authors are not responsible for any issues caused by using this script.

## 💡 Use Cases

- **DDoS Protection**: Automatically enable protection during attacks
- **Traffic Spikes**: Handle sudden legitimate traffic increases
- **Resource Management**: Protect server during high load
- **Automated Security**: Set-and-forget protection for multiple sites
- **Server Monitoring**: Get alerts about unusual server behavior

## 🌟 Star History

If you find this project useful, please give it a star! ⭐

## 📧 Support

- Create an issue for bugs or feature requests
- Pull requests are always welcome
- Share your use case and improvements

---

**Made with ❤️ for the security and performance of your websites**
