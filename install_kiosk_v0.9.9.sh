#!/bin/bash

################################################################################
# UBK Kiosk Installation Script v0.9.9
# 
# Purpose: Install and configure UBK kiosk with addon support
# Features: Easy Asterisk integration, Intercom support, Addon menu system
# Last Updated: 2025-12-09
# Author: outis1one
#
# Changes in v0.9.9:
# - Added Easy Asterisk addon integration
# - Implemented intercom option in addons menu
# - Enhanced addon management system
# - Improved configuration handling
################################################################################

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_VERSION="0.9.9"
KIOSK_HOME="${KIOSK_HOME:-.}"
ADDON_DIR="${KIOSK_HOME}/addons"
CONFIG_DIR="${KIOSK_HOME}/config"
LOG_FILE="${KIOSK_HOME}/install_kiosk_v${SCRIPT_VERSION}.log"

# Ensure directories exist
mkdir -p "$ADDON_DIR"
mkdir -p "$CONFIG_DIR"

################################################################################
# Logging Functions
################################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

################################################################################
# System Check Functions
################################################################################

check_dependencies() {
    log_info "Checking system dependencies..."
    
    local missing_deps=()
    local required_packages=("curl" "wget" "git" "tar" "gzip")
    
    for pkg in "${required_packages[@]}"; do
        if ! command -v "$pkg" &> /dev/null; then
            missing_deps+=("$pkg")
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_warning "Missing dependencies: ${missing_deps[*]}"
        log_info "Installing missing packages..."
        
        if command -v apt-get &> /dev/null; then
            sudo apt-get update
            sudo apt-get install -y "${missing_deps[@]}"
        elif command -v yum &> /dev/null; then
            sudo yum install -y "${missing_deps[@]}"
        else
            log_error "Unable to install packages. Please install manually: ${missing_deps[*]}"
            return 1
        fi
    fi
    
    log_success "All dependencies satisfied"
    return 0
}

check_system_requirements() {
    log_info "Checking system requirements..."
    
    # Check OS
    if [[ ! "$OSTYPE" =~ ^linux ]]; then
        log_error "This script requires Linux"
        return 1
    fi
    
    # Check disk space (minimum 500MB)
    local available_space=$(df "$KIOSK_HOME" | tail -1 | awk '{print $4}')
    if [ "$available_space" -lt 512000 ]; then
        log_error "Insufficient disk space. Minimum 500MB required."
        return 1
    fi
    
    log_success "System requirements met"
    return 0
}

################################################################################
# Addon Management Functions
################################################################################

install_addon() {
    local addon_name="$1"
    local addon_url="$2"
    
    log_info "Installing addon: $addon_name"
    
    local addon_path="${ADDON_DIR}/${addon_name}"
    mkdir -p "$addon_path"
    
    if [ -n "$addon_url" ]; then
        log_info "Downloading addon from: $addon_url"
        curl -sSL "$addon_url" | tar -xz -C "$addon_path" --strip-components=1
    fi
    
    # Initialize addon configuration
    if [ -f "${addon_path}/init.sh" ]; then
        bash "${addon_path}/init.sh"
    fi
    
    log_success "Addon $addon_name installed successfully"
}

################################################################################
# Easy Asterisk Integration
################################################################################

install_easy_asterisk() {
    log_info "Installing Easy Asterisk addon..."
    
    local asterisk_addon_path="${ADDON_DIR}/easy_asterisk"
    mkdir -p "$asterisk_addon_path"
    
    # Create Easy Asterisk configuration
    cat > "${asterisk_addon_path}/config.conf" <<'EOF'
[easy_asterisk]
enabled = true
version = 1.0
description = Easy Asterisk Integration for UBK Kiosk

[asterisk_server]
host = localhost
port = 5060
protocol = SIP

[features]
call_forwarding = true
voicemail_integration = true
conference_support = true
caller_id_customization = true

[security]
enable_auth = true
enable_encryption = false
allowed_ips = localhost,127.0.0.1

[logging]
level = INFO
output_file = /var/log/ubk_asterisk.log
EOF

    # Create initialization script
    cat > "${asterisk_addon_path}/init.sh" <<'EOF'
#!/bin/bash

ADDON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${ADDON_DIR}/config.conf"

echo "[Easy Asterisk] Initializing addon..."

# Check if Asterisk is installed
if ! command -v asterisk &> /dev/null; then
    echo "[Easy Asterisk] Warning: Asterisk not found. Installing..."
    sudo apt-get update
    sudo apt-get install -y asterisk asterisk-dev
fi

# Load configuration
if [ -f "$CONFIG_FILE" ]; then
    source <(grep -E '^\[|^[a-zA-Z_]' "$CONFIG_FILE")
    echo "[Easy Asterisk] Configuration loaded"
fi

# Initialize Asterisk integration
echo "[Easy Asterisk] Starting Asterisk daemon..."
sudo systemctl restart asterisk || true

echo "[Easy Asterisk] Addon initialized successfully"
EOF

    chmod +x "${asterisk_addon_path}/init.sh"
    
    # Run initialization
    bash "${asterisk_addon_path}/init.sh"
    
    log_success "Easy Asterisk addon installed"
}

################################################################################
# Intercom Integration
################################################################################

install_intercom() {
    log_info "Installing Intercom addon..."
    
    local intercom_addon_path="${ADDON_DIR}/intercom"
    mkdir -p "$intercom_addon_path"
    
    # Create Intercom configuration
    cat > "${intercom_addon_path}/config.conf" <<'EOF'
[intercom]
enabled = true
version = 1.0
description = Intercom System Integration for UBK Kiosk

[intercom_server]
host = localhost
port = 8888
protocol = HTTP

[features]
two_way_audio = true
video_support = false
call_recording = true
presence_detection = true
emergency_alert = true

[devices]
auto_discovery = true
max_devices = 20
timeout = 30

[security]
require_authentication = true
enable_encryption = true
allowed_ips = 0.0.0.0/0

[audio]
codec = opus
sample_rate = 16000
bit_depth = 16
EOF

    # Create initialization script
    cat > "${intercom_addon_path}/init.sh" <<'EOF'
#!/bin/bash

ADDON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${ADDON_DIR}/config.conf"

echo "[Intercom] Initializing addon..."

# Check required packages
for pkg in pulseaudio alsa-utils; do
    if ! dpkg -l | grep -q "^ii  $pkg"; then
        echo "[Intercom] Installing $pkg..."
        sudo apt-get update
        sudo apt-get install -y "$pkg"
    fi
done

# Load configuration
if [ -f "$CONFIG_FILE" ]; then
    echo "[Intercom] Configuration loaded"
fi

# Start audio services
sudo systemctl restart pulseaudio || true
sudo systemctl restart alsasound || true

echo "[Intercom] Addon initialized successfully"
EOF

    chmod +x "${intercom_addon_path}/init.sh"
    
    # Run initialization
    bash "${intercom_addon_path}/init.sh"
    
    log_success "Intercom addon installed"
}

################################################################################
# Addon Menu
################################################################################

display_addon_menu() {
    while true; do
        echo ""
        echo -e "${BLUE}================================${NC}"
        echo -e "${BLUE}   UBK Kiosk v${SCRIPT_VERSION} Addon Menu${NC}"
        echo -e "${BLUE}================================${NC}"
        echo "1) Install Easy Asterisk"
        echo "2) Install Intercom"
        echo "3) Install Custom Addon"
        echo "4) List Installed Addons"
        echo "5) Configure Easy Asterisk"
        echo "6) Configure Intercom"
        echo "7) View Addon Logs"
        echo "8) Return to Main Menu"
        echo "9) Exit"
        echo -e "${BLUE}================================${NC}"
        
        read -p "Select option: " addon_choice
        
        case $addon_choice in
            1)
                install_easy_asterisk
                ;;
            2)
                install_intercom
                ;;
            3)
                read -p "Enter addon name: " addon_name
                read -p "Enter addon URL (leave blank for local): " addon_url
                install_addon "$addon_name" "$addon_url"
                ;;
            4)
                list_addons
                ;;
            5)
                configure_easy_asterisk
                ;;
            6)
                configure_intercom
                ;;
            7)
                view_addon_logs
                ;;
            8)
                return
                ;;
            9)
                log_info "Exiting..."
                exit 0
                ;;
            *)
                log_warning "Invalid option"
                ;;
        esac
    done
}

list_addons() {
    log_info "Installed addons:"
    echo ""
    
    if [ -d "$ADDON_DIR" ] && [ "$(ls -A $ADDON_DIR)" ]; then
        ls -1 "$ADDON_DIR" | while read addon; do
            if [ -f "${ADDON_DIR}/${addon}/config.conf" ]; then
                local enabled=$(grep "^enabled" "${ADDON_DIR}/${addon}/config.conf" | cut -d'=' -f2 | tr -d ' ')
                if [ "$enabled" = "true" ]; then
                    echo -e "  ${GREEN}✓${NC} $addon (enabled)"
                else
                    echo -e "  ${RED}✗${NC} $addon (disabled)"
                fi
            fi
        done
    else
        log_warning "No addons installed"
    fi
    
    echo ""
}

configure_easy_asterisk() {
    local config_file="${ADDON_DIR}/easy_asterisk/config.conf"
    
    if [ ! -f "$config_file" ]; then
        log_error "Easy Asterisk not installed"
        return
    fi
    
    log_info "Configuring Easy Asterisk..."
    
    read -p "Enter Asterisk server host [localhost]: " asterisk_host
    asterisk_host="${asterisk_host:-localhost}"
    
    read -p "Enter Asterisk server port [5060]: " asterisk_port
    asterisk_port="${asterisk_port:-5060}"
    
    sed -i "s/^host = .*/host = $asterisk_host/" "$config_file"
    sed -i "s/^port = .*/port = $asterisk_port/" "$config_file"
    
    log_success "Easy Asterisk configuration updated"
}

configure_intercom() {
    local config_file="${ADDON_DIR}/intercom/config.conf"
    
    if [ ! -f "$config_file" ]; then
        log_error "Intercom not installed"
        return
    fi
    
    log_info "Configuring Intercom..."
    
    read -p "Enter Intercom server host [localhost]: " intercom_host
    intercom_host="${intercom_host:-localhost}"
    
    read -p "Enter Intercom server port [8888]: " intercom_port
    intercom_port="${intercom_port:-8888}"
    
    sed -i "s/^host = .*/host = $intercom_host/" "$config_file"
    sed -i "s/^port = .*/port = $intercom_port/" "$config_file"
    
    log_success "Intercom configuration updated"
}

view_addon_logs() {
    if [ ! -f "$LOG_FILE" ]; then
        log_warning "No logs available yet"
        return
    fi
    
    log_info "Recent addon activity:"
    echo ""
    tail -n 20 "$LOG_FILE"
    echo ""
}

################################################################################
# Main Installation Functions
################################################################################

install_kiosk_base() {
    log_info "Installing UBK Kiosk base system..."
    
    # Create directory structure
    mkdir -p "${KIOSK_HOME}/bin"
    mkdir -p "${KIOSK_HOME}/lib"
    mkdir -p "${KIOSK_HOME}/data"
    mkdir -p "${KIOSK_HOME}/logs"
    
    # Create main configuration file
    cat > "${CONFIG_DIR}/kiosk.conf" <<EOF
[kiosk]
name = UBK Kiosk
version = ${SCRIPT_VERSION}
installed_date = $(date -u +'%Y-%m-%d %H:%M:%S')
installed_by = ${USER}

[system]
home_directory = ${KIOSK_HOME}
addon_directory = ${ADDON_DIR}
config_directory = ${CONFIG_DIR}
log_file = ${LOG_FILE}

[services]
enable_asterisk = false
enable_intercom = false
enable_webui = true

[ports]
webui_port = 8080
asterisk_port = 5060
intercom_port = 8888
EOF

    log_success "Kiosk base system installed"
}

show_main_menu() {
    while true; do
        echo ""
        echo -e "${BLUE}================================${NC}"
        echo -e "${BLUE}   UBK Kiosk v${SCRIPT_VERSION} Installation${NC}"
        echo -e "${BLUE}================================${NC}"
        echo "1) Install Kiosk Base System"
        echo "2) Manage Addons"
        echo "3) System Status"
        echo "4) View Configuration"
        echo "5) View Logs"
        echo "6) Reset Configuration"
        echo "7) Exit"
        echo -e "${BLUE}================================${NC}"
        
        read -p "Select option: " main_choice
        
        case $main_choice in
            1)
                install_kiosk_base
                ;;
            2)
                display_addon_menu
                ;;
            3)
                show_system_status
                ;;
            4)
                show_configuration
                ;;
            5)
                view_addon_logs
                ;;
            6)
                reset_configuration
                ;;
            7)
                log_info "Exiting installation script"
                exit 0
                ;;
            *)
                log_warning "Invalid option"
                ;;
        esac
    done
}

show_system_status() {
    log_info "System Status:"
    echo ""
    echo "UBK Kiosk Version: $SCRIPT_VERSION"
    echo "Installation Directory: $KIOSK_HOME"
    echo "Addon Directory: $ADDON_DIR"
    echo "Configuration Directory: $CONFIG_DIR"
    echo ""
    echo "Installed Addons:"
    list_addons
    
    echo "System Information:"
    echo "  OS: $(uname -s)"
    echo "  Kernel: $(uname -r)"
    echo "  CPU Cores: $(nproc)"
    echo "  Memory: $(free -h | grep Mem | awk '{print $2}')"
    echo ""
}

show_configuration() {
    local config_file="${CONFIG_DIR}/kiosk.conf"
    
    if [ ! -f "$config_file" ]; then
        log_error "Configuration file not found"
        return
    fi
    
    log_info "Current Configuration:"
    echo ""
    cat "$config_file"
    echo ""
}

reset_configuration() {
    read -p "Are you sure you want to reset the configuration? (yes/no): " confirm
    
    if [ "$confirm" = "yes" ]; then
        rm -rf "${CONFIG_DIR}"/*
        rm -rf "${ADDON_DIR}"/*
        log_success "Configuration reset"
    else
        log_warning "Reset cancelled"
    fi
}

################################################################################
# Main Execution
################################################################################

main() {
    # Initialize log
    {
        echo "================================================================================"
        echo "UBK Kiosk Installation Script v${SCRIPT_VERSION}"
        echo "Started: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
        echo "User: ${USER}"
        echo "================================================================================"
    } >> "$LOG_FILE"
    
    log_info "Starting UBK Kiosk installation v${SCRIPT_VERSION}"
    
    # Run system checks
    if ! check_system_requirements; then
        log_error "System requirements not met"
        exit 1
    fi
    
    if ! check_dependencies; then
        log_error "Failed to install dependencies"
        exit 1
    fi
    
    log_success "Pre-installation checks completed"
    
    # Display main menu
    show_main_menu
}

# Run main function
main "$@"
