#!/usr/bin/env bash
# ======================================================================
# File: diagnose_talkkonnect.sh
# Purpose: Diagnose talkkonnect installation and permission issues
# ======================================================================

echo "======================================================================="
echo "TalkKonnect Installation Diagnostics"
echo "======================================================================="
echo ""

# Check if talkkonnect binary exists
echo "[1] Checking talkkonnect binary..."
if [ -f /usr/local/bin/talkkonnect ]; then
    echo "    ✓ Binary found: /usr/local/bin/talkkonnect"
    ls -lh /usr/local/bin/talkkonnect
else
    echo "    ✗ Binary NOT found at /usr/local/bin/talkkonnect"
    echo "    Run the installation script first!"
fi
echo ""

# Check for config files in all possible locations
echo "[2] Searching for config files..."
FOUND_CONFIGS=()
for USER_DIR in /home/*; do
    CONFIG="$USER_DIR/.config/talkkonnect/talkkonnect.xml"
    if [ -f "$CONFIG" ]; then
        FOUND_CONFIGS+=("$CONFIG")
        echo "    ✓ Found: $CONFIG"
        ls -lh "$CONFIG"
    fi
done

if [ -f "/root/.config/talkkonnect/talkkonnect.xml" ]; then
    FOUND_CONFIGS+=("/root/.config/talkkonnect/talkkonnect.xml")
    echo "    ✓ Found: /root/.config/talkkonnect/talkkonnect.xml"
    ls -lh "/root/.config/talkkonnect/talkkonnect.xml"
fi

if [ ${#FOUND_CONFIGS[@]} -eq 0 ]; then
    echo "    ✗ No config files found!"
fi
echo ""

# Check systemd service
echo "[3] Checking systemd service..."
if [ -f /etc/systemd/system/talkkonnect.service ]; then
    echo "    ✓ Service file found"
    echo ""
    echo "    Service User:"
    grep "^User=" /etc/systemd/system/talkkonnect.service || echo "    (not specified)"
    echo ""
    echo "    Config Path:"
    grep "ExecStart=" /etc/systemd/system/talkkonnect.service | grep -o '\-config [^ ]*' || echo "    (not found)"
    echo ""
    echo "    Full ExecStart line:"
    grep "ExecStart=" /etc/systemd/system/talkkonnect.service
    echo ""
else
    echo "    ✗ Service file NOT found at /etc/systemd/system/talkkonnect.service"
fi
echo ""

# Check which user should run talkkonnect
echo "[4] Audio/PipeWire session detection..."
for USER_NAME in kiosk user ubuntu; do
    if id "$USER_NAME" &>/dev/null; then
        USER_UID=$(id -u "$USER_NAME")
        echo "    Checking user: $USER_NAME (UID: $USER_UID)"

        # Check if PipeWire is running for this user
        if [ -S "/run/user/$USER_UID/pipewire-0" ]; then
            echo "      ✓ PipeWire session active: /run/user/$USER_UID/pipewire-0"
        else
            echo "      ✗ No PipeWire session found"
        fi

        # Check audio group membership
        if groups "$USER_NAME" | grep -q audio; then
            echo "      ✓ In 'audio' group"
        else
            echo "      ✗ NOT in 'audio' group"
        fi

        # Check input group membership (for PTT)
        if groups "$USER_NAME" | grep -q input; then
            echo "      ✓ In 'input' group"
        else
            echo "      ✗ NOT in 'input' group"
        fi
        echo ""
    fi
done

# Analyze permission issues
echo "[5] Permission Analysis..."
if [ ${#FOUND_CONFIGS[@]} -gt 0 ] && [ -f /etc/systemd/system/talkkonnect.service ]; then
    SERVICE_USER=$(grep "^User=" /etc/systemd/system/talkkonnect.service | cut -d= -f2)
    SERVICE_CONFIG=$(grep "ExecStart=" /etc/systemd/system/talkkonnect.service | grep -o '\-config [^ ]*' | awk '{print $2}')

    echo "    Service configured to run as: $SERVICE_USER"
    echo "    Service configured to use config: $SERVICE_CONFIG"
    echo ""

    if [ -f "$SERVICE_CONFIG" ]; then
        CONFIG_OWNER=$(stat -c '%U' "$SERVICE_CONFIG")
        echo "    Config file owner: $CONFIG_OWNER"
        echo ""

        if [ "$CONFIG_OWNER" != "$SERVICE_USER" ]; then
            echo "    ⚠️  PERMISSION MISMATCH!"
            echo "    Service runs as '$SERVICE_USER' but config is owned by '$CONFIG_OWNER'"
            echo ""
            echo "    This is why you're getting 'permission denied'!"
            echo ""
        else
            echo "    ✓ Ownership is correct"
        fi
    else
        echo "    ✗ Config file not found at: $SERVICE_CONFIG"
    fi
fi

echo ""
echo "======================================================================="
echo "Recommendations"
echo "======================================================================="
echo ""

# Provide recommendations
if [ ${#FOUND_CONFIGS[@]} -eq 0 ]; then
    echo "❌ No config files found - run the installation script first:"
    echo "   ./talkkonnect_complete_install.sh"
elif [ ! -f /etc/systemd/system/talkkonnect.service ]; then
    echo "⚠️  Config exists but no systemd service - complete the installation:"
    echo "   ./talkkonnect_complete_install.sh"
else
    SERVICE_USER=$(grep "^User=" /etc/systemd/system/talkkonnect.service | cut -d= -f2 2>/dev/null)
    SERVICE_CONFIG=$(grep "ExecStart=" /etc/systemd/system/talkkonnect.service | grep -o '\-config [^ ]*' | awk '{print $2}' 2>/dev/null)

    if [ -f "$SERVICE_CONFIG" ]; then
        CONFIG_OWNER=$(stat -c '%U' "$SERVICE_CONFIG" 2>/dev/null)

        if [ "$CONFIG_OWNER" != "$SERVICE_USER" ]; then
            echo "🔧 PERMISSION ISSUE DETECTED - Run the fix script:"
            echo "   sudo ./fix_talkkonnect_permissions.sh"
            echo ""
            echo "   Or manually fix permissions:"
            echo "   sudo chown -R $SERVICE_USER:$SERVICE_USER $(dirname $SERVICE_CONFIG)"
        else
            echo "✅ Installation looks good!"
            echo ""
            echo "Next steps:"
            echo "  1. Edit config: sudo nano $SERVICE_CONFIG"
            echo "  2. Test manually: sudo -u $SERVICE_USER /usr/local/bin/talkkonnect -config $SERVICE_CONFIG"
            echo "  3. Start service: sudo systemctl start talkkonnect"
            echo "  4. Check status: sudo systemctl status talkkonnect"
        fi
    fi
fi

echo ""
