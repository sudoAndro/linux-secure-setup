#!/usr/bin/env bash

set -euo pipefail

ensure_ui_environment() {
    export TERM="${TERM:-xterm-256color}"

    if ! command -v whiptail >/dev/null 2>&1; then
        echo "Fehler: whiptail ist nicht installiert."
        echo "Bitte installiere es mit:"
        echo "  sudo apt update && sudo apt install -y whiptail dialog ncurses-term"
        exit 1
    fi

    if ! command -v tput >/dev/null 2>&1; then
        echo "Fehler: tput fehlt."
        echo "Bitte installiere ncurses-term."
        exit 1
    fi

    if [[ ! -r /dev/tty ]] || [[ ! -w /dev/tty ]]; then
        echo "Fehler: Kein benutzbares TTY gefunden."
        exit 1
    fi

    if [[ ! -t 0 ]]; then
        exec < /dev/tty
    fi

    if [[ ! -t 1 ]]; then
        exec > /dev/tty
    fi

    if [[ ! -t 2 ]]; then
        exec 2> /dev/tty
    fi

    stty sane < /dev/tty || true
}

require_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        echo "Dieses Script muss mit sudo oder als root ausgeführt werden."
        exit 1
    fi
}

require_whiptail() {
    if ! command -v whiptail >/dev/null 2>&1; then
        echo "whiptail ist nicht installiert."
        exit 1
    fi
}

pause_enter() {
    echo
    read -r -p "Press ENTER to continue..." _ < /dev/tty
}
