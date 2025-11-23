### UBK (Ubuntu Based Kiosk) — Installer README

Built with Claude Sonnet 4/.5 AI assistance
License: GPL v3 - Keep derivatives open sour
Repository: https://github.com/outis1one/ubk/

## TARGET SYSTEMS:
- Ubuntu 24.04+ Server (minimal install recommended)
- Raspberry Pi 4+ (with or without touchscreen) -- untested
- Laptops, desktops, all-in-ones, 2-in-1s
- Touch support optional (works with keyboard/mouse)

# SECURITY NOTICE:
This is NOT suitable for secure locations or public kiosks.
Do NOT use as a replacement for hardened kiosk solutions.
Use entirely at your own risk.

# PURPOSE:
Home/office kiosk for reusing old hardware, displaying:
- Self-hosted services (Immich, MagicMirror2, Home Assistant)
- Web dashboards, digital signage
- Photo slideshows, family calendars
- Any web-based content

## Overview
UBK is a full kiosk environment built on Ubuntu, designed for locked‑down, single‑purpose deployments. This installer (`install_kiosk_0.9.7.sh`) automates setup of the entire system, including:

* Electron-based kiosk application
* Autologin kiosk user environment
* System lockdown (no shell access, no switching TTYs)
* Display configuration and Openbox session
* Audio playback via Squeezelite
* Printing support via CUPS
* Optional networking, WiFi, and hostname configuration
* Systemd services for all kiosk components

The script is intended for fresh installations and can fully provision a kiosk from a clean Ubuntu machine.

## Functionality
- single or multiple sites, with auto rotation, and manual sites not in rotation
- ability to pause a rotational site, auto return to home popup for manual sites
- password protection
- Squeezelite player
- Cups printing
- touch screen controls (two finger swiping between sites, toggable on screen keyboard and pause site)


## Quick Install

```
install ubuntu 24.04 server, config wifi if no ethernet is available and enable ssh
sudo chmod +x install_kiosk_0.9.7.sh
sudo ./install_kiosk_0.9.7.sh
```

The installer will prompt for required configuration values during setup.

---

## What This Script Installs

### Core Components

* **Electron runtime and build toolchain**
* **Node.js / npm** and required modules
* **Chromium** and supporting libraries
* **ChromeDriver** (for Electron builds or testing)
* **ffmpeg** for multimedia support
* **unclutter** to hide the cursor
* **Openbox** for lightweight X session
* **x11-xserver-utils**

### Audio

* **Squeezelite** for audio playback
* ALSA utilities for device enumeration

### Printing

* **CUPS** printing system
* Printer permissions and service configuration

### System Services & Environment

* Kiosk autostart under Openbox
* Systemd units for:

  * Kiosk application
  * Squeezelite
  * Keyboard IPC handler
  * Autostart helpers

### Security & Lockdown

* Autologin kiosk user
* Disabled TTY switching
* Suppressed right-click behavior
* Screen blanking disabled
* Config permission hardening

---

## Licensing — Third‑Party Software Attribution

This project bundles or installs several upstream open-source components. Their licenses apply to their respective software. UBK itself does **not** modify these licenses.

Below are SPDX-style license identifiers and project attribution references.

### Electron

* **License:** MIT
* **Project:** [https://github.com/electron/electron](https://github.com/electron/electron)
* **SPDX:** `MIT`

### Chromium

* **License:** BSD-3-Clause, plus multiple third-party components
* **Project:** [https://www.chromium.org/](https://www.chromium.org/)
* **SPDX:** `BSD-3-Clause`

### Node.js

* **License:** MIT
* **Project:** [https://github.com/nodejs/node](https://github.com/nodejs/node)
* **SPDX:** `MIT`

### npm Packages

Most npm modules used by the kiosk app are MIT, Apache-2.0, or similar permissive licenses. Check your app’s `package.json` for exact listings.

### CUPS

* **License:** Apache-2.0 (CUPS 2.2+) with GPL2/LGPL2 exceptions on older versions
* **Project:** [https://openprinting.github.io/cups/](https://openprinting.github.io/cups/)
* **SPDX:** `Apache-2.0`

### Squeezelite

* **License:** GPL-3.0-or-later
* **Project:** [https://github.com/ralph-irving/squeezelite](https://github.com/ralph-irving/squeezelite)
* **SPDX:** `GPL-3.0-or-later`

### ffmpeg

* **License:** LGPL-2.1-or-later / GPL-2.0-or-later depending on build
* **Project:** [https://ffmpeg.org/](https://ffmpeg.org/)
* **SPDX:** `LGPL-2.1-or-later` (typical Ubuntu build)

### unclutter

* **License:** Public Domain / MIT (depending on fork)
* **Project:** [https://github.com/Airblader/unclutter-xfixes](https://github.com/Airblader/unclutter-xfixes)
* **SPDX:** `MIT`

---

## Maintenance Guide

### Updating the Electron Kiosk App

1. Switch to the kiosk user or app directory.
2. Pull new code.
3. Rebuild the Electron application.
4. Restart kiosk systemd service:

```
sudo systemctl restart ubk-kiosk.service
```

### Checking Service Status

```
systemctl status ubk-kiosk.service
systemctl status squeezelite.service
systemctl status display-manager
```

### Logs

Logs are stored under:

```
/var/log/ubk/
```

---

## Troubleshooting

### Kiosk app doesn’t start

* Check Openbox autostart files.
* Verify `electron` binary is installed.
* View systemd logs:

```
sudo journalctl -u ubk-kiosk.service -f
```

### No audio output

* Use ALSA utilities to list devices.
* Confirm squeezelite is running.

### Printer not detected

* Ensure CUPS is active:

```
sudo systemctl status cups
```

* Verify permissions on `/etc/cups/printers.conf`.

---

## Security Notes

* Autologin is intentionally enabled.
* TTY switching via Ctrl+Alt+Fx is disabled.
* Shell access is restricted for the kiosk user.
* System updates should be applied manually or through automation you trust.

---

## Disclaimer

UBK aggregates open-source software governed by their respective licenses. The authors of UBK make no warranty regarding modifications made by downstream integrators.

---

## Project Status

This installer is part of an evolving kiosk system. Future versions may include intercom functionality, a web base gui configuration screen, all in one iso.

---

# End of README
