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

msg_box() {
    local title="${1:-Linux Secure Setup}"
    local message="${2:-OK}"
    local height="${3:-10}"
    local width="${4:-60}"

    whiptail --title "$title" --msgbox "$message" "$height" "$width"
}

yes_no_box() {
    local title="${1:-Linux Secure Setup}"
    local message="${2:-Möchtest du fortfahren?}"
    local height="${3:-12}"
    local width="${4:-70}"

    if whiptail --title "$title" --yesno "$message" "$height" "$width"; then
        return 0
    else
        return 1
    fi
}

input_box() {
    local title="${1:-Linux Secure Setup}"
    local message="${2:-Bitte Eingabe machen:}"
    local default_value="${3:-}"
    local height="${4:-10}"
    local width="${5:-60}"

    whiptail --title "$title" --inputbox "$message" "$height" "$width" "$default_value" 3>&1 1>&2 2>&3
}

password_box() {
    local title="${1:-Linux Secure Setup}"
    local message="${2:-Bitte Passwort eingeben:}"
    local height="${3:-10}"
    local width="${4:-60}"

    whiptail --title "$title" --passwordbox "$message" "$height" "$width" 3>&1 1>&2 2>&3
}

pause_enter() {
    echo
    read -r -p "Press ENTER to continue..." _ < /dev/tty
}

info_box() {
    local title="${1:-Linux Secure Setup}"
    local message="${2:-Fertig.}"
    local height="${3:-10}"
    local width="${4:-60}"

    whiptail --title "$title" --msgbox "$message" "$height" "$width"
}

# Zeigt den Inhalt einer Datei in einem scrollbaren Textfeld an
textbox_file() {
    local title="${1:-Output}"
    local file="${2:-}"

    if [[ -z "$file" || ! -f "$file" ]]; then
        msg_box "$title" "Datei nicht gefunden: $file"
        return 1
    fi

    whiptail --title "$title" --textbox "$file" 24 80
}

# Fragt nach einem Benutzernamen per Eingabebox
prompt_username() {
    local username
    username=$(input_box "Benutzername" "Gib den Benutzernamen ein (nur a-z, 0-9, _, -):" "") || return 1

    if [[ -z "$username" ]]; then
        msg_box "Fehler" "Kein Benutzername eingegeben."
        return 1
    fi

    printf '%s\n' "$username"
}

# Fragt nach einem SSH-Port per Eingabebox und validiert ihn
prompt_port() {
    local port
    while true; do
        port=$(input_box "SSH Port" "Gib den SSH-Port ein (1-65535):" "22") || return 1

        if [[ "$port" =~ ^[0-9]+$ ]] && (( port >= 1 && port <= 65535 )); then
            break
        else
            msg_box "Ungültiger Port" "Bitte einen gueltigen Port zwischen 1 und 65535 eingeben."
        fi
    done

    printf '%s\n' "$port"
}
