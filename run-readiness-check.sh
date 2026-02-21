#!/usr/bin/env bash

set -euo pipefail

############################################
# Configuration
############################################
PRECHECK_URL="https://github.com/matildacloud/mdeploy-repo/raw/refs/heads/main/discovery-readiness-check-linux-amd64"
WINRM_URL="https://github.com/matildacloud/mdeploy-repo/raw/refs/heads/main/winrm_check-linux-amd64"

PRECHECK_BIN="discovery-readiness-check-linux-amd64"
WINRM_BIN="winrm_check-linux-amd64"

LOG_FILE="./matilda_precheck_$(date +%Y%m%d_%H%M%S).log"

############################################
# Logging Setup
############################################
touch "$LOG_FILE" || { echo "Cannot create log file"; exit 1; }

exec > >(tee -a "$LOG_FILE") 2>&1

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1"
}

error_exit() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1"
    exit 1
}

############################################
# Installer
############################################
install_downloader() {
    log "curl/wget not found. Attempting installation..."

    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update -y || error_exit "apt update failed"
        sudo apt-get install -y curl wget || error_exit "apt install failed"
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y curl wget || error_exit "dnf install failed"
    elif command -v yum >/dev/null 2>&1; then
        sudo yum install -y curl wget || error_exit "yum install failed"
    elif command -v zypper >/dev/null 2>&1; then
        sudo zypper install -y curl wget || error_exit "zypper install failed"
    else
        error_exit "Unsupported package manager. Install curl or wget manually."
    fi

    if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
        error_exit "Installation attempted but curl/wget still missing."
    fi

    log "Downloader installed successfully."
}

############################################
# Download Function
############################################
download_file() {
    local url=$1
    local output=$2

    log "Downloading $output..."

    if command -v curl >/dev/null 2>&1; then
        curl -L --fail -o "$output" "$url" || error_exit "Download failed for $output"
    elif command -v wget >/dev/null 2>&1; then
        wget -O "$output" "$url" || error_exit "Download failed for $output"
    else
        install_downloader
        download_file "$url" "$output"
    fi

    log "$output downloaded successfully."
}

############################################
# Main Execution
############################################

log "=============================================="
log "Matilda Precheck Utility Setup Started"
log "Log file: $LOG_FILE"
log "=============================================="

# Ensure curl or wget exists
if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
    install_downloader
fi

# Step 1
download_file "$PRECHECK_URL" "$PRECHECK_BIN"

# Step 2
download_file "$WINRM_URL" "$WINRM_BIN"

# Step 3
log "Setting execute permissions..."
chmod +x "$PRECHECK_BIN" "$WINRM_BIN" || error_exit "Failed to set execute permissions."

log "Execute permissions set successfully."

# Step 4 - Run Web Mode
log "Starting Precheck utility in WEB mode..."
log "HTTP server will remain active until manually stopped (Ctrl+C)"
log "=============================================="

exec ./"$PRECHECK_BIN" --web
