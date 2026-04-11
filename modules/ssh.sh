#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

require_root
require_whiptail

SSHD_CONFIG="/etc/ssh/sshd_config"
SSHD_BACKUP="/etc/ssh/sshd_config.bak.$(date +%Y%m%d-%H%M%S)"

STEP_USERNAME=""
STEP_AUTH_KEYS=""

set_sshd_option() {
    local key="$1"
    local value="$2"

    if grep -qE "^[#[:space:]]*${key}[[:space:]]+" "$SSHD_CONFIG"; then
        sed -i -E "s|^[#[:space:]]*${key}[[:space:]]+.*|${key} ${value}|g" "$SSHD_CONFIG"
    else
        printf '%s %s\n' "$key" "$value" >> "$SSHD_CONFIG"
    fi
}

restart_ssh_service() {
    if systemctl list-unit-files | grep -q '^ssh\.service'; then
        systemctl restart ssh
        return 0
    fi

    if systemctl list-unit-files | grep -q '^sshd\.service'; then
        systemctl restart sshd
        return 0
    fi

    msg_box "Warnung" "Kein SSH-Dienst gefunden.\n\nBitte manuell neu starten."
    return 1
}

rollback_ssh_config() {
    if [[ -f "$SSHD_BACKUP" ]]; then
        cp "$SSHD_BACKUP" "$SSHD_CONFIG"
        restart_ssh_service || true
    fi
}

step_user() {
    local username password password2

    username=$(whiptail --title "Admin User" \
        --inputbox "Benutzernamen eingeben:" 10 50 "" \
        3>&1 1>&2 2>&3) || return 1

    username=$(printf '%s' "$username" | tr -cd 'a-zA-Z0-9_-')

    if [[ -z "$username" ]]; then
        msg_box "Fehler" "Benutzername ist leer oder ungueltig."
        return 1
    fi

    if id "$username" >/dev/null 2>&1; then
        if ! id -nG "$username" | grep -qw sudo; then
            usermod -aG sudo "$username"
            msg_box "Admin User" "Benutzer '$username' existiert bereits\nund wurde zur sudo-Gruppe hinzugefuegt."
        else
            msg_box "Admin User" "Benutzer '$username' existiert bereits."
        fi
    else
        while true; do
            password=$(whiptail --title "Passwort" \
                --passwordbox "Passwort fuer '$username' eingeben:" 10 50 \
                3>&1 1>&2 2>&3) || return 1

            password2=$(whiptail --title "Passwort bestaetigen" \
                --passwordbox "Passwort erneut eingeben:" 10 50 \
                3>&1 1>&2 2>&3) || return 1

            if [[ -z "$password" ]]; then
                msg_box "Fehler" "Passwort darf nicht leer sein."
                continue
            fi

            if [[ "$password" != "$password2" ]]; then
                msg_box "Fehler" "Die Passwoerter stimmen nicht ueberein."
                continue
            fi

            break
        done

        useradd -m -s /bin/bash "$username"
        echo "${username}:${password}" | chpasswd
        usermod -aG sudo "$username"
        msg_box "Admin User" "Benutzer '$username' wurde erstellt\nund zur sudo-Gruppe hinzugefuegt."
    fi

    STEP_USERNAME="$username"
    return 0
}

step_prepare_ssh_dir() {
    local username="$1"
    local home_dir ssh_dir auth_keys

    home_dir="$(getent passwd "$username" | cut -d: -f6)"

    if [[ -z "$home_dir" ]]; then
        msg_box "Fehler" "Home-Verzeichnis fuer Benutzer '$username' konnte nicht ermittelt werden."
        return 1
    fi

    ssh_dir="$home_dir/.ssh"
    auth_keys="$ssh_dir/authorized_keys"

    mkdir -p "$ssh_dir"
    touch "$auth_keys"
    chown -R "$username:$username" "$ssh_dir"
    chmod 700 "$ssh_dir"
    chmod 600 "$auth_keys"

    msg_box "SSH Verzeichnis" "SSH-Verzeichnis vorbereitet:\n\n$auth_keys"
    STEP_AUTH_KEYS="$auth_keys"
    return 0
}

step_insert_key() {
    local username="$1"
    local auth_keys="$2"

    msg_box "SSH Public Key" "nano wird jetzt geoeffnet.\n\nFuege deinen Public Key ein.\n\nSpeichern: CTRL+O dann Enter\nBeenden: CTRL+X"

    nano "$auth_keys" </dev/tty >/dev/tty

    if [[ ! -s "$auth_keys" ]]; then
        msg_box "Fehler" "authorized_keys ist leer.\n\nKein SSH-Key gespeichert."
        return 1
    fi

    chown "$username:$username" "$auth_keys"
    chmod 600 "$auth_keys"
    msg_box "SSH Key" "Public Key wurde gespeichert."
}

step_harden_ssh() {
    local port="$1"
    local username="$2"

    cp "$SSHD_CONFIG" "$SSHD_BACKUP"

    set_sshd_option "Port" "$port"
    set_sshd_option "PermitRootLogin" "no"
    set_sshd_option "PasswordAuthentication" "no"
    set_sshd_option "PubkeyAuthentication" "yes"
    set_sshd_option "ChallengeResponseAuthentication" "no"
    set_sshd_option "KbdInteractiveAuthentication" "no"
    set_sshd_option "UsePAM" "yes"
    set_sshd_option "MaxAuthTries" "3"
    set_sshd_option "LoginGraceTime" "30"
    set_sshd_option "AllowUsers" "$username"
}

main() {
    msg_box "SSH Setup" "Dieses Modul richtet folgendes ein:\n\n1. Admin-User anlegen oder nutzen\n2. SSH-Verzeichnis vorbereiten\n3. Public Key eintragen\n4. SSH haerten\n\nRoot wird erst ganz am Schluss gesperrt."

    step_user || exit 0
    local username="$STEP_USERNAME"

    if [[ -z "$username" ]]; then
        msg_box "Fehler" "Kein gueltiger Benutzername."
        exit 1
    fi

    step_prepare_ssh_dir "$username" || exit 0
    local auth_keys="$STEP_AUTH_KEYS"

    if [[ -z "$auth_keys" ]]; then
        msg_box "Fehler" "authorized_keys Pfad konnte nicht ermittelt werden."
        exit 1
    fi

    step_insert_key "$username" "$auth_keys" || exit 0

    local port
    port="$(prompt_port)" || exit 0

    if ! whiptail --title "Bestaetigung" --yesno \
"SSH-Konfiguration die gesetzt wird:

User:                   $username
Port:                   $port
PermitRootLogin:        no
PasswordAuthentication: no
PubkeyAuthentication:   yes
MaxAuthTries:           3
LoginGraceTime:         30

Fortfahren?" 20 70; then
        msg_box "Abgebrochen" "Keine Aenderungen vorgenommen."
        exit 0
    fi

    step_harden_ssh "$port" "$username"

    if ! sshd -t; then
        rollback_ssh_config
        msg_box "Fehler" "sshd -t fehlgeschlagen.\n\nAlte Konfiguration wurde wiederhergestellt."
        exit 1
    fi

    if systemctl is-enabled ssh.socket >/dev/null 2>&1 || systemctl is-active --quiet ssh.socket 2>/dev/null; then
        systemctl disable --now ssh.socket || true
        systemctl mask ssh.socket || true
    fi

    restart_ssh_service || true
    sleep 1

    local listening
    listening="$(ss -tulpn 2>/dev/null | grep ssh || true)"

    if ! echo "$listening" | grep -q ":${port}\b"; then
        rollback_ssh_config

        local tmp_file
        tmp_file="$(mktemp)"
        {
            echo "SSH hoert NICHT auf Port $port."
            echo
            echo "Aktuelle SSH-Listener:"
            echo "$listening"
        } > "$tmp_file"

        textbox_file "SSH Port Fehler" "$tmp_file"
        rm -f "$tmp_file"

        msg_box "Rollback" "Alte SSH-Konfiguration wurde wiederhergestellt.\n\nRoot wird NICHT gesperrt."
        exit 1
    fi

    if ! whiptail --title "Root Login deaktivieren" --yesno \
"SSH lauscht erfolgreich auf Port $port.\n\nSoll PermitRootLogin no gesetzt bleiben und root per SSH gesperrt bleiben?" 12 70; then
        set_sshd_option "PermitRootLogin" "yes"
        if sshd -t; then
            restart_ssh_service || true
            msg_box "Hinweis" "Root-Login wurde wieder erlaubt."
        else
            rollback_ssh_config
            msg_box "Fehler" "Konfiguration ungueltig. Backup wurde wiederhergestellt."
            exit 1
        fi
    fi

    msg_box "Erfolg" "SSH wurde erfolgreich konfiguriert.\n\nUser: $username\nPort: $port\n\nTeste jetzt in einem ZWEITEN Terminal zuerst den Login, bevor du die aktuelle Sitzung schliesst."
}

main "$@"
