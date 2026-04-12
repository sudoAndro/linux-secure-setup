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

##Start manually

- sudo bash /opt/linux-secure-setup/menu.sh

- Or, after installation:

- linux-secure-setup

##Project Structure

linux-secure-setup
├── install.sh
├── menu.sh
├── README.md
├── LICENSE
├── modules/
└── images/

##Important SSH Safety Note

The SSH module is designed to reduce lockout risk:

- create or reuse an admin user
- insert a public key manually
- change SSH port
- disable password authentication
- disable root login
- test the login before finalizing
- rollback configuration if login fails

