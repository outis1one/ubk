#!/usr/bin/env bash
# ======================================================================
# File: fix_talkkonnect_now.sh
# Purpose: Quick fix for current talkkonnect issues
# ======================================================================

echo "======================================================================="
echo "TalkKonnect Quick Fix Script"
echo "======================================================================="
echo ""

TARGET_USER="${1:-kiosk}"
CONFIG_FILE="/home/$TARGET_USER/.config/talkkonnect/talkkonnect.xml"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "[!] Config file not found: $CONFIG_FILE"
    echo "[!] Looking for alternative locations..."

    if [ -f "/home/$TARGET_USER/talkkonnect.xml" ]; then
        CONFIG_FILE="/home/$TARGET_USER/talkkonnect.xml"
        echo "[+] Found config at: $CONFIG_FILE"
    else
        echo "[!] No config file found"
        exit 1
    fi
fi

echo "[+] Using config: $CONFIG_FILE"
echo ""

# Fix 1: Enable insecure mode for self-signed certificates
echo "[1/4] Fixing certificate issue..."
if grep -q "<insecure>false</insecure>" "$CONFIG_FILE"; then
    sudo sed -i 's|<insecure>false</insecure>|<insecure>true</insecure>|g' "$CONFIG_FILE"
    echo "    ✓ Set insecure=true (allows self-signed certificates)"
elif ! grep -q "<insecure>" "$CONFIG_FILE"; then
    sudo sed -i 's|</account>|  <insecure>true</insecure>\n    </account>|' "$CONFIG_FILE"
    echo "    ✓ Added insecure=true setting"
else
    echo "    ✓ Certificate setting already correct"
fi
echo ""

# Fix 2: Check if using SuperUser account
echo "[2/4] Checking account settings..."
if grep -q "<username>SuperUser</username>" "$CONFIG_FILE"; then
    echo "    ⚠️  WARNING: You're trying to connect as 'SuperUser'"
    echo "    SuperUser is the SERVER ADMIN account, not a client account."
    echo ""
    echo "    To fix:"
    echo "    1. Connect with Mumble desktop/mobile app as SuperUser"
    echo "    2. Create a regular user account or allow unregistered users"
    echo "    3. Use that account for talkkonnect, not SuperUser"
    echo ""
    read -p "    Change username now? (y/n): " change_user
    if [[ "$change_user" =~ ^[Yy]$ ]]; then
        read -p "    Enter new username: " new_username
        sudo sed -i "s|<username>.*</username>|<username>$new_username</username>|" "$CONFIG_FILE"
        read -s -p "    Enter password (blank if none): " new_password
        echo
        sudo sed -i "s|<password>.*</password>|<password>$new_password</password>|" "$CONFIG_FILE"
        echo "    ✓ Username updated"
    fi
else
    CURRENT_USER=$(grep "<username>" "$CONFIG_FILE" | sed 's/.*<username>\(.*\)<\/username>/\1/')
    echo "    ✓ Username: $CURRENT_USER (not SuperUser - good!)"
fi
echo ""

# Fix 3: Check and fix ownership
echo "[3/4] Fixing file permissions..."
sudo chown -R "$TARGET_USER:$TARGET_USER" "$(dirname $CONFIG_FILE)"
sudo chmod 644 "$CONFIG_FILE"
echo "    ✓ Ownership set to $TARGET_USER"
echo ""

# Fix 4: Check systemd service
echo "[4/4] Checking systemd service..."
SERVICE_FILE="/etc/systemd/system/talkkonnect.service"

if [ ! -f "$SERVICE_FILE" ]; then
    echo "    ⚠️  Systemd service not found"
    echo "    Creating service file..."

    TARGET_UID=$(id -u "$TARGET_USER")
    TARGET_HOME="/home/$TARGET_USER"

    # Determine which binary to use
    if [ -f "/usr/local/bin/talkkonnect" ]; then
        BINARY_PATH="/usr/local/bin/talkkonnect"
    elif [ -f "$TARGET_HOME/go/bin/talkkonnect" ]; then
        BINARY_PATH="$TARGET_HOME/go/bin/talkkonnect"
    else
        echo "    ✗ Talkkonnect binary not found!"
        exit 1
    fi

    sudo tee "$SERVICE_FILE" > /dev/null <<EOFSVC
[Unit]
Description=TalkKonnect Headless Mumble Transceiver
After=network-online.target sound.target
Wants=network-online.target

[Service]
Type=simple
User=$TARGET_USER
Group=$TARGET_USER
WorkingDirectory=$TARGET_HOME
ExecStart=$BINARY_PATH -config $CONFIG_FILE
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
Environment="XDG_RUNTIME_DIR=/run/user/$TARGET_UID"

[Install]
WantedBy=multi-user.target
EOFSVC

    echo "    ✓ Service file created"
fi

# Reload and enable service
echo "    Reloading systemd..."
sudo systemctl daemon-reload

if ! systemctl is-enabled --quiet talkkonnect 2>/dev/null; then
    echo "    Enabling talkkonnect service..."
    sudo systemctl enable talkkonnect
    echo "    ✓ Service enabled (will start on boot)"
fi

# Check if service is running
if systemctl is-active --quiet talkkonnect 2>/dev/null; then
    echo "    Restarting talkkonnect service..."
    sudo systemctl restart talkkonnect
    sleep 3
else
    echo "    Starting talkkonnect service..."
    sudo systemctl start talkkonnect
    sleep 3
fi

if systemctl is-active --quiet talkkonnect 2>/dev/null; then
    echo "    ✓ Service is RUNNING"
else
    echo "    ✗ Service failed to start"
    echo ""
    echo "Check logs with: sudo journalctl -u talkkonnect -n 50"
fi

echo ""
echo "======================================================================="
echo "✓ Quick Fix Complete!"
echo "======================================================================="
echo ""
echo "Changes made:"
echo "  1. ✓ Set <insecure>true</insecure> (allows self-signed certs)"
echo "  2. ✓ Fixed file ownership"
echo "  3. ✓ Created/updated systemd service"
echo "  4. ✓ Enabled and started talkkonnect service"
echo ""
echo "Important Notes:"
echo ""
echo "❌ SUPERUSER ISSUE:"
echo "   'SuperUser' is the Mumble SERVER ADMIN account."
echo "   You CANNOT use it as a regular client."
echo ""
echo "   To fix:"
echo "   1. Use Mumble desktop/mobile app to connect as SuperUser"
echo "   2. Create a regular user account on the server"
echo "   3. OR configure server to allow unregistered users"
echo "   4. Update talkkonnect config to use the regular account"
echo ""
echo "Check status:"
echo "  sudo systemctl status talkkonnect"
echo ""
echo "View logs:"
echo "  sudo journalctl -u talkkonnect -f"
echo ""
echo "Edit config:"
echo "  sudo nano $CONFIG_FILE"
echo ""
