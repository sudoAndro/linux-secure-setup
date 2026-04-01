#!/usr/bin/env bash

require_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "Dieses Script muss mit sudo oder als root ausgeführt werden."
        exit 1
    fi
}

require_whiptail() {
    if ! command -v whiptail >/dev/null 2>&1; then
        echo "whiptail ist nicht installiert."
        echo "Bitte zuerst installieren mit:"
        echo "sudo apt update && sudo apt install whiptail -y"
        exit 1
    fi
}

msg_box() {
    whiptail --title "$1" --msgbox "$2" 12 78 >/dev/tty
}

yes_no_box() {
    whiptail --title "$1" --yesno "$2" 12 78 >/dev/tty
}

textbox_file() {
    whiptail --title "$1" --textbox "$2" 22 90 >/dev/tty
}

input_box() {
    whiptail --title "$1" --inputbox "$2" 12 78 "${3:-}" 3>&1 1>&2 2>&3
}

password_box() {
    whiptail --title "$1" --passwordbox "$2" 12 78 3>&1 1>&2 2>&3
}

is_valid_username() {
    local username="$1"
    [[ "$username" =~ ^[a-z_][a-z0-9_-]*$ ]]
}

prompt_username() {
    local username

    while true; do
        username=$(input_box "Admin User" "Neuen oder vorhandenen Admin-Benutzernamen eingeben:" "") || return 1

        if [[ -z "${username// }" ]]; then
            msg_box "Fehler" "Benutzername darf nicht leer sein."
            continue
        fi

        if ! is_valid_username "$username"; then
            msg_box "Fehler" "Ungültiger Benutzername.\n\nErlaubt sind: Kleinbuchstaben, Zahlen, _ und -\nEr muss mit Buchstabe oder _ beginnen."
            continue
        fi

        printf '%s\n' "$username"
        return 0
    done
}

is_valid_port() {
    local port="$1"
    [[ "$port" =~ ^[0-9]+$ ]] && (( port >= 1 && port <= 65535 ))
}

prompt_port() {
    local port

    while true; do
        port=$(input_box "SSH Port" "Welcher SSH-Port soll verwendet werden?" "") || return 1

        if [[ -z "${port// }" ]]; then
            msg_box "Fehler" "Port darf nicht leer sein."
            continue
        fi

        if ! is_valid_port "$port"; then
            msg_box "Fehler" "Ungültiger Port. Erlaubt sind nur Zahlen von 1 bis 65535."
            continue
        fi

        printf '%s\n' "$port"
        return 0
    done
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}
