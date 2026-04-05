# Linux Secure Setup

Linux Secure Setup is a security hardening toolkit for Debian-based systems.

It provides an interactive menu similar to `raspi-config` to quickly apply common security best practices for Linux servers.

The goal is to simplify the process of securing a fresh Linux installation.

---

## Features

✔ System update and upgrade  
✔ Install required security packages  
✔ SSH configuration and hardening  
✔ Automatic SSH socket fix  
✔ SSH port verification  
✔ Automatic rollback if SSH configuration fails  
✔ UFW firewall configuration  
✔ Fail2Ban installation and configuration  
✔ CrowdSec integration  
✔ Automatic security updates  
✔ Kernel hardening  
✔ System cleanup  
✔ Package integrity verification (debsums)

---

## Supported Systems

Linux Secure Setup works on most **Debian-based systems**, including:

- Debian
- Ubuntu
- Kali Linux
- Raspberry Pi OS

---

## Installation

Clone the repository:

git clone https://github.com/sudoAndro/linux-secure-setup.git

Enter the directory:

cd linux-secure-setup

Run the installer:

sudo ./install.sh
Menu

The tool launches an interactive menu:

Linux Secure Setup
------------------

1 System Update and Upgrade
2 Install Required Packages
3 SSH Configuration and Hardening
4 UFW Firewall
5 Fail2Ban
6 CrowdSec
7 Automatic Security Updates
8 Kernel Hardening
9 Cleanup
10 Package Integrity Check

Each module can be executed individually.

Security Features
SSH Hardening

The SSH module can:

create an admin user
configure SSH keys
change the SSH port
disable password authentication
disable root login
verify SSH configuration before applying
rollback automatically if something fails

This prevents accidental lockouts.

Why this project?

Hardening a Linux system requires multiple steps and tools.

Linux Secure Setup simplifies the process by combining the most common security tasks into a single interactive tool.

It is especially useful for:

new server installations
home servers
VPS deployments
learning Linux security basics



Author

Created by sudoAndro
