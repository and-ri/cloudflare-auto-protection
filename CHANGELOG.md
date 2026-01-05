# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-01-05

### Added
- New `cf_protection_multi.sh` script for multi-user/multi-zone protection
- Per-user CPU load monitoring with individual thresholds
- Individual Cloudflare API tokens for each zone/user
- Associative arrays for flexible zone/token configuration
- Singleton enforcement with lockfile to prevent concurrent runs
- Separate state files per user for independent protection management

### Features
- Monitor CPU usage per system user
- Independent protection triggers for each configured zone
- Easy configuration with `ZONES` and `TOKENS` associative arrays
- Automatic lockfile cleanup on script exit

### Technical
- State files stored in `/var/tmp/cf_protection_multi/`
- Requires: bc, curl, awk, ps
- Compatible with shared hosting environments

## [1.0.0] - 2025-10-27

### Added
- Initial release
- Automatic Cloudflare "Under Attack Mode" activation based on CPU load
- Multi-zone support for protecting multiple domains simultaneously
- Smart CPU monitoring with multiple measurement methods (top, /proc/stat, load average)
- CPU load averaging algorithm to prevent false positives
- Telegram notifications with detailed server and domain information
- Configurable thresholds and duration timers
- Automatic recovery when load returns to normal
- Anti-spam notification system with cooldown periods
- Comprehensive logging system
- State management for tracking protection status
- Test mode for Telegram notifications (`--test-telegram`)
- Support for commented/disabled zone IDs in configuration

### Features
- CPU threshold configuration (default: 80%)
- Configurable averaging samples (default: 3)
- High load duration before activation (default: 2 minutes)
- Cooldown period before deactivation (default: 5 minutes)
- Multiple Cloudflare zones support
- Telegram bot integration
- Detailed logging with timestamps

### Technical
- Bash script compatible with most Linux distributions
- Requires only basic utilities: curl, awk
- State files stored in `/var/tmp/cf_protection/`
- Cron-friendly for automatic scheduled execution
- Fallback CPU measurement methods for reliability
