#!/usr/bin/env bash

set -euo pipefail

choice=$(whiptail --title "System Language" \
--menu "Select system language" 15 60 2 \
"en" "English" \
"de" "Deutsch" \
3>&1 1>&2 2>&3)

if [[ "$choice" == "de" ]]; then

    sudo apt update
    sudo apt install -y language-pack-de locales

    sudo locale-gen de_DE.UTF-8
    sudo update-locale LANG=de_DE.UTF-8

    whiptail --msgbox "German language installed.\nReboot recommended." 10 60

else

    sudo apt update
    sudo apt install -y language-pack-en locales

    sudo locale-gen en_US.UTF-8
    sudo update-locale LANG=en_US.UTF-8

    whiptail --msgbox "English language installed.\nReboot recommended." 10 60

fi
