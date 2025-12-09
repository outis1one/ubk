#!/bin/bash

################################################################################
# Asterisk-Easy Addon Installation Functions
# Description: Addon module for installing and configuring Asterisk-Easy
# Version: 1.0
################################################################################

# Color definitions for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

################################################################################
# Function: install_asterisk_easy
# Description: Main function to install Asterisk-Easy
# Parameters: None
# Returns: 0 on success, 1 on failure
################################################################################
install_asterisk_easy() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}Asterisk-Easy Installation${NC}"
    echo -e "${BLUE}================================${NC}"
    
    # Update system packages
    echo -e "${YELLOW}Updating system packages...${NC}"
    apt-get update -qq
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to update system packages${NC}"
        return 1
    fi
    
    # Install Asterisk dependencies
    echo -e "${YELLOW}Installing Asterisk dependencies...${NC}"
    apt-get install -y \
        asterisk \
        asterisk-config \
        asterisk-dev \
        asterisk-doc \
        asterisk-modules \
        asterisk-voicemail \
        dahdi \
        libpri \
        asterisk-dahdi &>/dev/null
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to install Asterisk packages${NC}"
        return 1
    fi
    
    # Install additional dependencies
    echo -e "${YELLOW}Installing additional dependencies...${NC}"
    apt-get install -y \
        build-essential \
        libssl-dev \
        libxml2-dev \
        libsqlite3-dev \
        uuid-dev &>/dev/null
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to install additional dependencies${NC}"
        return 1
    fi
    
    # Configure Asterisk
    echo -e "${YELLOW}Configuring Asterisk...${NC}"
    configure_asterisk_easy
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to configure Asterisk-Easy${NC}"
        return 1
    fi
    
    # Start Asterisk service
    echo -e "${YELLOW}Starting Asterisk service...${NC}"
    systemctl enable asterisk
    systemctl start asterisk
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to start Asterisk service${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✓ Asterisk-Easy installation completed successfully${NC}"
    return 0
}

################################################################################
# Function: configure_asterisk_easy
# Description: Configure Asterisk-Easy with basic settings
# Parameters: None
# Returns: 0 on success, 1 on failure
################################################################################
configure_asterisk_easy() {
    local asterisk_dir="/etc/asterisk"
    
    # Check if Asterisk directory exists
    if [ ! -d "$asterisk_dir" ]; then
        echo -e "${RED}Asterisk configuration directory not found: $asterisk_dir${NC}"
        return 1
    fi
    
    # Backup original configuration files
    echo -e "${YELLOW}Backing up original Asterisk configuration...${NC}"
    if [ -f "$asterisk_dir/extensions.conf" ]; then
        cp "$asterisk_dir/extensions.conf" "$asterisk_dir/extensions.conf.bak.$(date +%s)"
    fi
    
    if [ -f "$asterisk_dir/sip.conf" ]; then
        cp "$asterisk_dir/sip.conf" "$asterisk_dir/sip.conf.bak.$(date +%s)"
    fi
    
    # Create basic extensions configuration
    echo -e "${YELLOW}Creating basic extensions configuration...${NC}"
    create_extensions_conf "$asterisk_dir"
    
    # Create basic SIP configuration
    echo -e "${YELLOW}Creating basic SIP configuration...${NC}"
    create_sip_conf "$asterisk_dir"
    
    return 0
}

################################################################################
# Function: create_extensions_conf
# Description: Create basic extensions configuration file
# Parameters: $1 - Asterisk configuration directory
# Returns: 0 on success, 1 on failure
################################################################################
create_extensions_conf() {
    local asterisk_dir="$1"
    local extensions_file="$asterisk_dir/extensions.conf"
    
    cat > "$extensions_file" << 'EOF'
[general]
static=yes
writeprotect=no

[default]
exten => 100,1,Dial(SIP/100)
exten => 100,n,Voicemail(100@default)
exten => 100,n,Hangup()

exten => 101,1,Dial(SIP/101)
exten => 101,n,Voicemail(101@default)
exten => 101,n,Hangup()

exten => 102,1,Dial(SIP/102)
exten => 102,n,Voicemail(102@default)
exten => 102,n,Hangup()

exten => 200,1,VoicemailMain(${CALLERID(num)}@default)
exten => 200,n,Hangup()
EOF
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to create extensions configuration${NC}"
        return 1
    fi
    
    return 0
}

################################################################################
# Function: create_sip_conf
# Description: Create basic SIP configuration file
# Parameters: $1 - Asterisk configuration directory
# Returns: 0 on success, 1 on failure
################################################################################
create_sip_conf() {
    local asterisk_dir="$1"
    local sip_file="$asterisk_dir/sip.conf"
    
    cat > "$sip_file" << 'EOF'
[general]
context=default
allowoverlap=no
bindport=5060
bindaddr=0.0.0.0
srvlookup=yes
pedantic=no
maxexpiry=3600
minexpiry=60
defaultexpiry=120
defaultexpirey=120
rtptimeout=30
rtpholdtimeout=300
videosupport=yes
allowtransfer=yes
nat=force_rport,comedia

[100]
type=friend
secret=123456
host=dynamic
context=default

[101]
type=friend
secret=123456
host=dynamic
context=default

[102]
type=friend
secret=123456
host=dynamic
context=default
EOF
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to create SIP configuration${NC}"
        return 1
    fi
    
    return 0
}

################################################################################
# Function: verify_asterisk_easy
# Description: Verify Asterisk-Easy installation
# Parameters: None
# Returns: 0 if installed and running, 1 otherwise
################################################################################
verify_asterisk_easy() {
    # Check if Asterisk is installed
    if ! command -v asterisk &> /dev/null; then
        echo -e "${RED}Asterisk is not installed${NC}"
        return 1
    fi
    
    # Check if Asterisk service is running
    if ! systemctl is-active --quiet asterisk; then
        echo -e "${YELLOW}Asterisk service is not running${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✓ Asterisk-Easy is properly installed and running${NC}"
    return 0
}

################################################################################
# Function: show_asterisk_easy_status
# Description: Display Asterisk-Easy status information
# Parameters: None
# Returns: 0 on success
################################################################################
show_asterisk_easy_status() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}Asterisk-Easy Status${NC}"
    echo -e "${BLUE}================================${NC}"
    
    # Check service status
    if systemctl is-active --quiet asterisk; then
        echo -e "${GREEN}Service Status: Running${NC}"
    else
        echo -e "${RED}Service Status: Not Running${NC}"
    fi
    
    # Check Asterisk version
    if command -v asterisk &> /dev/null; then
        local version=$(asterisk -v | grep -oP 'Asterisk \K[0-9.]+')
        echo -e "${BLUE}Asterisk Version: $version${NC}"
    fi
    
    # Check configuration files
    if [ -f "/etc/asterisk/extensions.conf" ]; then
        echo -e "${GREEN}✓ Extensions Configuration: Present${NC}"
    else
        echo -e "${RED}✗ Extensions Configuration: Missing${NC}"
    fi
    
    if [ -f "/etc/asterisk/sip.conf" ]; then
        echo -e "${GREEN}✓ SIP Configuration: Present${NC}"
    else
        echo -e "${RED}✗ SIP Configuration: Missing${NC}"
    fi
    
    return 0
}

################################################################################
# Function: remove_asterisk_easy
# Description: Remove Asterisk-Easy installation
# Parameters: None
# Returns: 0 on success, 1 on failure
################################################################################
remove_asterisk_easy() {
    echo -e "${YELLOW}Removing Asterisk-Easy...${NC}"
    
    # Stop Asterisk service
    systemctl stop asterisk
    systemctl disable asterisk
    
    # Remove Asterisk packages
    apt-get remove -y asterisk asterisk-* &>/dev/null
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to remove Asterisk packages${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✓ Asterisk-Easy has been removed${NC}"
    return 0
}

# Export functions for use in main script
export -f install_asterisk_easy
export -f configure_asterisk_easy
export -f verify_asterisk_easy
export -f show_asterisk_easy_status
export -f remove_asterisk_easy
