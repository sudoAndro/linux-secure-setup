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

    [[ -t 0 ]] || exec < /dev/tty
    [[ -t 1 ]] || exec > /dev/tty
    [[ -t 2 ]] || exec 2> /dev/tty

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

    whiptail --title "$title" --msgbox "$message" "$height" "$width" </dev/tty >/dev/tty 2>&1
}

yes_no_box() {
    local title="${1:-Linux Secure Setup}"
    local message="${2:-Moechtest du fortfahren?}"
    local height="${3:-12}"
    local width="${4:-70}"

    whiptail --title "$title" --yesno "$message" "$height" "$width" </dev/tty >/dev/tty 2>&1
}

_input_via_tmpfile() {
    local mode="$1"
    local title="$2"
    local message="$3"
    local default_value="${4:-}"
    local height="${5:-10}"
    local width="${6:-60}"
    local tmpfile
    tmpfile="$(mktemp)"

    if [[ "$mode" == "input" ]]; then
        whiptail \
            --title "$title" \
            --inputbox "$message" "$height" "$width" "$default_value" \
            --output-fd 1 \
            </dev/tty >"$tmpfile" 2>/dev/tty || {
                rm -f "$tmpfile"
                return 1
            }
    else
        whiptail \
            --title "$title" \
            --passwordbox "$message" "$height" "$width" \
            --output-fd 1 \
            </dev/tty >"$tmpfile" 2>/dev/tty || {
                rm -f "$tmpfile"
                return 1
            }
    fi

    cat "$tmpfile"
    rm -f "$tmpfile"
}

input_box() {
    local title="${1:-Linux Secure Setup}"
    local message="${2:-Bitte Eingabe machen:}"
    local default_value="${3:-}"
    local height="${4:-10}"
    local width="${5:-60}"

    _input_via_tmpfile "input" "$title" "$message" "$default_value" "$height" "$width"
}

password_box() {
    local title="${1:-Linux Secure Setup}"
    local message="${2:-Bitte Passwort eingeben:}"
    local height="${3:-10}"
    local width="${4:-60}"

    _input_via_tmpfile "password" "$title" "$message" "" "$height" "$width"
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

    whiptail --title "$title" --msgbox "$message" "$height" "$width" </dev/tty >/dev/tty 2>&1
}

textbox_file() {
    local title="${1:-Output}"
    local file="${2:-}"

    if [[ -z "$file" || ! -f "$file" ]]; then
        msg_box "$title" "Datei nicht gefunden: $file"
        return 1
    fi

    whiptail --title "$title" --textbox "$file" 24 80 </dev/tty >/dev/tty 2>&1
}

prompt_username() {
    local username
    username="$(input_box "Benutzername" "Gib den Benutzernamen ein (nur a-z, 0-9, _, -):" "")" || return 1
    username="$(printf '%s' "$username" | tr -cd 'a-zA-Z0-9_-')"

    if [[ -z "$username" ]]; then
        msg_box "Fehler" "Kein gueltiger Benutzername eingegeben."
        return 1
    fi

    printf '%s\n' "$username"
}

prompt_port() {
    local port
    while true; do
        port="$(input_box "SSH Port" "Gib den SSH-Port ein (1-65535):" "22")" || return 1
        port="$(printf '%s' "$port" | tr -cd '0-9')"

        if [[ "$port" =~ ^[0-9]+$ ]] && (( port >= 1 && port <= 65535 )); then
            printf '%s\n' "$port"
            return 0
        fi

        msg_box "Ungueltiger Port" "Bitte einen gueltigen Port zwischen 1 und 65535 eingeben."
    done
}
