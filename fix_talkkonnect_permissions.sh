#!/usr/bin/env bash
# ======================================================================
# File: fix_talkkonnect_permissions.sh
# Purpose: Fix talkkonnect config permissions for the correct user
# ======================================================================
set -e

echo "======================================================================="
echo "TalkKonnect Permission Fix Script"
echo "======================================================================="
echo ""

# Prompt for target user
read -p "Which user should talkkonnect run as? [user]: " TARGET_USER
TARGET_USER=${TARGET_USER:-user}

# Verify the target user exists
if ! id "$TARGET_USER" &>/dev/null; then
    echo "[!] Error: User '$TARGET_USER' does not exist"
    exit 1
fi

TARGET_HOME=$(eval echo ~"$TARGET_USER")
CONFIG_DIR="$TARGET_HOME/.config/talkkonnect"

echo "[+] Target user: $TARGET_USER"
echo "[+] Home directory: $TARGET_HOME"
echo "[+] Config directory: $CONFIG_DIR"
echo ""

# Check if config file exists in wrong location
WRONG_LOCATIONS=(
    "/root/.config/talkkonnect"
    "$HOME/.config/talkkonnect"
)

FOUND_CONFIG=""
for LOC in "${WRONG_LOCATIONS[@]}"; do
    if [ -f "$LOC/talkkonnect.xml" ] && [ "$LOC" != "$CONFIG_DIR" ]; then
        echo "[+] Found existing config at: $LOC"
        FOUND_CONFIG="$LOC"
        break
    fi
done

if [ -n "$FOUND_CONFIG" ]; then
    echo "[+] Moving config from $FOUND_CONFIG to $CONFIG_DIR"
    mkdir -p "$CONFIG_DIR"
    cp -r "$FOUND_CONFIG/"* "$CONFIG_DIR/"

    # Update paths in the config file
    sed -i "s|$FOUND_CONFIG|$CONFIG_DIR|g" "$CONFIG_DIR/talkkonnect.xml"
    sed -i "s|/home/user/|$TARGET_HOME/|g" "$CONFIG_DIR/talkkonnect.xml"
    sed -i "s|/root/|$TARGET_HOME/|g" "$CONFIG_DIR/talkkonnect.xml"

    echo "[+] Config moved and paths updated"
else
    echo "[*] No existing config found in wrong locations"

    if [ ! -f "$CONFIG_DIR/talkkonnect.xml" ]; then
        echo "[!] Error: No config file found at $CONFIG_DIR/talkkonnect.xml"
        echo "[!] Please run the installation script first"
        exit 1
    fi
fi

# Set proper ownership
echo "[+] Setting ownership to $TARGET_USER..."
chown -R "$TARGET_USER:$TARGET_USER" "$CONFIG_DIR"

# Set proper permissions
chmod 755 "$CONFIG_DIR"
chmod 644 "$CONFIG_DIR/talkkonnect.xml"

if [ -f "$CONFIG_DIR/enable-ducking.sh" ]; then
    chmod 755 "$CONFIG_DIR/enable-ducking.sh"
fi

echo "[+] Permissions fixed!"
echo ""

# Show the result
echo "Current permissions:"
ls -la "$CONFIG_DIR"
echo ""

# Check and fix systemd service if it exists
if [ -f /etc/systemd/system/talkkonnect.service ]; then
    echo "[+] Checking systemd service configuration..."
    SERVICE_USER=$(grep "^User=" /etc/systemd/system/talkkonnect.service | cut -d= -f2)
    SERVICE_CONFIG=$(grep "^ExecStart=" /etc/systemd/system/talkkonnect.service | grep -o '\-config [^ ]*' | cut -d' ' -f2)

    echo "    Current service user: $SERVICE_USER"
    echo "    Current config path: $SERVICE_CONFIG"
    echo ""

    NEED_SERVICE_UPDATE=false

    if [ "$SERVICE_USER" != "$TARGET_USER" ]; then
        echo "    ⚠️  Service user needs to be changed from '$SERVICE_USER' to '$TARGET_USER'"
        NEED_SERVICE_UPDATE=true
    fi

    if [ "$SERVICE_CONFIG" != "$CONFIG_DIR/talkkonnect.xml" ]; then
        echo "    ⚠️  Config path needs to be updated to: $CONFIG_DIR/talkkonnect.xml"
        NEED_SERVICE_UPDATE=true
    fi

    if [ "$NEED_SERVICE_UPDATE" = true ]; then
        echo ""
        read -p "Update systemd service file? [Y/n]: " UPDATE_SERVICE
        UPDATE_SERVICE=${UPDATE_SERVICE:-Y}

        if [[ "$UPDATE_SERVICE" =~ ^[Yy] ]]; then
            echo "[+] Updating systemd service..."

            # Get target user's UID
            TARGET_UID=$(id -u "$TARGET_USER")

            # Create updated service file
            sudo tee /etc/systemd/system/talkkonnect.service > /dev/null <<EOFSVC
[Unit]
Description=TalkKonnect Headless Mumble Transceiver
After=network-online.target sound.target
Wants=network-online.target

[Service]
Type=simple
User=$TARGET_USER
Group=$TARGET_USER
WorkingDirectory=$TARGET_HOME
ExecStart=/usr/local/bin/talkkonnect -config $CONFIG_DIR/talkkonnect.xml
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
Environment="XDG_RUNTIME_DIR=/run/user/$TARGET_UID"

[Install]
WantedBy=multi-user.target
EOFSVC

            echo "[+] Service file updated!"
            echo "[+] Reloading systemd..."
            sudo systemctl daemon-reload

            # Stop service if running
            if systemctl is-active --quiet talkkonnect 2>/dev/null; then
                echo "[+] Stopping existing service..."
                sudo systemctl stop talkkonnect
            fi

            echo "[+] Service is ready to start with new configuration"
        else
            echo "[!] Skipped service update - you'll need to update it manually"
        fi
    else
        echo "    ✓ Service configuration is correct"
    fi
fi

echo ""
echo "======================================================================="
echo "✓ Permission fix complete!"
echo "======================================================================="
echo ""
echo "Next steps:"
echo "  1. Edit your config file:"
echo "     nano $CONFIG_DIR/talkkonnect.xml"
echo ""
echo "  2. Test manually as $TARGET_USER:"
echo "     sudo -u $TARGET_USER /usr/local/bin/talkkonnect -config $CONFIG_DIR/talkkonnect.xml"
echo ""
echo "  3. If systemd is available, restart the service:"
echo "     sudo systemctl restart talkkonnect"
echo ""
