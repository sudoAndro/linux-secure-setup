#!/usr/bin/env bash

set -euo pipefail

hostname=$(whiptail --inputbox \
"Enter new hostname for this server" \
10 60 "$(hostname)" \
3>&1 1>&2 2>&3)

if [[ -z "$hostname" ]]; then
    exit 0
fi

sudo hostnamectl set-hostname "$hostname"

whiptail --msgbox "Hostname changed to $hostname\nReboot recommended." 10 60
