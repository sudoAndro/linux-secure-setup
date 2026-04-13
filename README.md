# Linux Secure Setup

Interactive Linux security hardening toolkit for Debian-based systems.

Linux Secure Setup provides a menu-driven interface to configure common security settings for fresh Linux installations, inspired by tools like `raspi-config`.

## Features

- System update and upgrade
- Install required packages
- System language configuration
- Timezone configuration
- SSH configuration and hardening
- UFW firewall setup
- Fail2Ban installation
- CrowdSec installation
- Automatic security updates
- Kernel hardening
- Cleanup tools
- Package integrity checks

## Supported Systems

- Debian
- Ubuntu
- Kali Linux
- Raspberry Pi OS

## Installation

Run:

```bash
curl -fsSL https://raw.githubusercontent.com/sudoAndro/linux-secure-setup/main/install.sh | sudo bash
```

## Start Manually

- `sudo bash /opt/linux-secure-setup/menu.sh`
- Or, after installation: `linux-secure-setup`

## Project Structure

```text
linux-secure-setup
├── install.sh
├── menu.sh
├── README.md
├── LICENSE
├── modules/
└── images/
```

## Important SSH Safety Note

The SSH module is designed to reduce lockout risk:

- Create or reuse an admin user
- Insert a public key manually
- Change the SSH port
- Disable password authentication
- Disable root login
- Test the login before finalizing
- Roll back the configuration if the new login fails

## Notes

- Run the toolkit with `sudo` or as `root`.
- `whiptail` is required for the interactive dialogs and will be installed by `install.sh` if missing.
- The project currently targets Debian-based systems only.
