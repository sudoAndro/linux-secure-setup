#!/usr/bin/env bash

set -euo pipefail

timezone=$(whiptail --inputbox \
"Enter your timezone (example: Europe/Zurich)" \
10 60 "Europe/Zurich" \
3>&1 1>&2 2>&3)

if [[ -z "$timezone" ]]; then
    exit 0
fi

sudo timedatectl set-timezone "$timezone"

whiptail --msgbox "Timezone set to $timezone" 10 60
