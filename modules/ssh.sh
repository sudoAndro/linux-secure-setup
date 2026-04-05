#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

require_root
require_whiptail

SSHD_CONFIG="/etc/ssh/sshd_config"
SSHD_BACKUP="/etc/ssh/sshd_config.bak.$(date +%Y%m%d-%H%M%S)"

set_sshd_option() {
    local key="$1"
    local value="$2"

    if grep -qE "^[#[:space:]]*${key}[[:space:]]+" "$SSHD_CONFIG"; then
        sed -i -E "s|^[#[:space:]]*${key}[[:space:]]+.*|${key} ${value}|g" "$SSHD_CONFIG"
    else
        printf '%s %s\n' "$key" "$value" >> "$SSHD_CONFIG"
    fi
}

select_or_create_user() {
    local username
    local password
    local password2

    username=$(prompt_username) || return 1
    username=$(printf '%s' "$username" | tr -cd 'a-zA-Z0-9_-')

    if [[ -z "$username" ]]; then
        msg_box "Fehler" "Benutzername ist leer oder ungültig."
        return 1
    fi

    if id "$username" >/dev/null 2>&1; then
        if ! id -nG "$username" | grep -qw sudo; then
            usermod -aG sudo "$username"
            msg_box "Admin User" "Benutzer '$username' existiert bereits und wurde zur sudo-Gruppe hinzugefügt."
        else
            msg_box "Admin User" "Benutzer '$username' existiert bereits."
        fi
    else
        while true; do
            password=$(password_box "Passwort" "Passwort für Benutzer '$username' eingeben:") || return 1
            password2=$(password_box "Passwort bestätigen" "Passwort erneut eingeben:") || return 1

            if [[ -z "$password" ]]; then
                msg_box "Fehler" "Passwort darf nicht leer sein."
                continue
            fi

            if [[ "$password" != "$password2" ]]; then
                msg_box "Fehler" "Die Passwörter stimmen nicht überein."
                continue
            fi

            break
        done

        useradd -m -s /bin/bash "$username"
        echo "${username}:${password}" | chpasswd
        usermod -aG sudo "$username"

        msg_box "Admin User" "Benutzer '$username' wurde erstellt und zur sudo-Gruppe hinzugefügt."
    fi

    printf '%s\n' "$username"
}

prepare_ssh_dir() {
    local username="$1"
    local home_dir
    local ssh_dir
    local auth_keys

    home_dir=$(eval echo "~$username")
    ssh_dir="$home_dir/.ssh"
    auth_keys="$ssh_dir/authorized_keys"

    mkdir -p "$ssh_dir"
    touch "$auth_keys"

    chown -R "$username:$username" "$ssh_dir"
    chmod 700 "$ssh_dir"
    chmod 600 "$auth_keys"

    printf '%s\n' "$auth_keys"
}

insert_public_key() {
    local username="$1"
    local auth_keys="$2"

    msg_box "SSH Public Key" "Jetzt wird die Datei geöffnet:\n\n${auth_keys}\n\nFüge dort deinen kompletten Public Key ein.\n\nSpeichern in nano:\nCTRL+O, Enter\nBeenden:\nCTRL+X"

    nano "$auth_keys"

    if [[ ! -s "$auth_keys" ]]; then
        msg_box "Fehler" "authorized_keys ist leer.\n\nEs wurde kein SSH-Key gespeichert."
        return 1
    fi

    chown "$username:$username" "$auth_keys"
    chmod 600 "$auth_keys"

    msg_box "SSH Key" "Public Key wurde gespeichert."
}

apply_ssh_hardening() {
    local port="$1"
    local username="$2"

    cp "$SSHD_CONFIG" "$SSHD_BACKUP"

    set_sshd_option "Port" "$port"
    set_sshd_option "PermitRootLogin" "no"
    set_sshd_option "PasswordAuthentication" "no"
    set_sshd_option "PubkeyAuthentication" "yes"
    set_sshd_option "ChallengeResponseAuthentication" "no"
    set_sshd_option "UsePAM" "yes"
    set_sshd_option "MaxAuthTries" "3"
    set_sshd_option "LoginGraceTime" "30"
    set_sshd_option "AllowUsers" "$username"
}

handle_ssh_socket() {
    if systemctl is-active --quiet ssh.socket; then
        msg_box "SSH Socket erkannt" "ssh.socket ist aktiv.\n\nDieser kann den Port aus sshd_config überschreiben.\n\nDer Socket wird jetzt deaktiviert, damit der konfigurierte SSH-Port verwendet wird."

        systemctl disable --now ssh.socket
        systemctl mask ssh.socket
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

    msg_box "Warnung" "Kein Dienstname ssh oder sshd erkannt.\n\nBitte SSH-Dienst manuell neu starten."
    return 1
}

verify_ssh_port() {
    local expected_port="$1"
    local listening
    local tmp_file

    listening=$(ss -tulpn 2>/dev/null | grep ssh || true)

    if echo "$listening" | grep -q ":${expected_port}\b"; then
        return 0
    fi

    tmp_file=$(mktemp)

    {
        echo "SSH hört NICHT auf dem erwarteten Port ${expected_port}."
        echo
        echo "Aktuelle SSH Listener:"
        echo
        echo "$listening"
    } > "$tmp_file"

    textbox_file "SSH Port Fehler" "$tmp_file"
    rm -f "$tmp_file"

    return 1
}

rollback_ssh_config() {
    if [[ -f "$SSHD_BACKUP" ]]; then
        cp "$SSHD_BACKUP" "$SSHD_CONFIG"
        restart_ssh_service || true
    fi
}

rollback_ssh_config() {
    if [[ -f "$SSHD_BACKUP" ]]; then
        cp "$SSHD_BACKUP" "$SSHD_CONFIG"
        restart_ssh_service || true
    fi
}

show_listening_ssh_ports() {
    local ports
    local tmp_file

    ports=$(ss -tulpn 2>/dev/null | grep ssh || true)

    tmp_file=$(mktemp)

    if [[ -n "$ports" ]]; then
        printf '%s\n' "$ports" > "$tmp_file"
    else
        echo "Es konnten keine aktiven SSH-Listen-Ports angezeigt werden." > "$tmp_file"
    fi

    textbox_file "SSH Listen Ports" "$tmp_file"
    rm -f "$tmp_file"
}

main() {
    local username
    local auth_keys
    local port

    msg_box "SSH Setup" "Dieses Modul richtet Admin-User, SSH-Key und SSH-Hardening ein.\n\nRoot wird erst ganz am Schluss deaktiviert."

    username=$(select_or_create_user) || exit 0
    username=$(printf '%s' "$username" | tr -cd 'a-zA-Z0-9_-')

    if [[ -z "$username" ]]; then
        msg_box "Fehler" "Benutzername ist leer oder ungültig."
        exit 1
    fi

    auth_keys=$(prepare_ssh_dir "$username") || exit 1

    msg_box "SSH Verzeichnis" "SSH-Verzeichnis wurde vorbereitet:\n\n${auth_keys}\n\nRechte:\n700 für .ssh\n600 für authorized_keys"

    insert_public_key "$username" "$auth_keys" || exit 0

    port=$(prompt_port) || exit 0

    if ! yes_no_box "Bestätigung" "Diese SSH-Konfiguration wird gesetzt:\n\nUser: $username\nPort: $port\nPermitRootLogin: no\nPasswordAuthentication: no\nPubkeyAuthentication: yes\nChallengeResponseAuthentication: no\nUsePAM: yes\nMaxAuthTries: 3\nLoginGraceTime: 30\nAllowUsers: $username\n\nFortfahren?"; then
        msg_box "Abgebrochen" "Es wurden keine Änderungen an SSH übernommen."
        exit 0
    fi

    apply_ssh_hardening "$port" "$username"

    if ! sshd -t; then
        cp "$SSHD_BACKUP" "$SSHD_CONFIG"
        msg_box "Fehler" "sshd -t ist fehlgeschlagen.\n\nDie alte Konfiguration wurde wiederhergestellt."
        exit 1
    fi

    handle_ssh_socket

    restart_ssh_service || true

    if ! verify_ssh_port "$port"; then
        rollback_ssh_config
        msg_box "Rollback ausgeführt" "Der gewünschte SSH-Port $port wurde nicht aktiv.\n\nDie alte SSH-Konfiguration wurde automatisch wiederhergestellt.\n\nRoot wird NICHT deaktiviert."
        exit 1
    fi

    show_listening_ssh_ports

    msg_box "Wichtig" "Teste JETZT in einem ZWEITEN Terminal den neuen Login.\n\nBeispiel:\nssh -p $port $username@SERVER-IP\n\nDie aktuelle Sitzung offen lassen.\n\nErst wenn das funktioniert, darf Root deaktiviert werden."

    if yes_no_box "SSH Test" "Hat der Login mit dem SSH-Key erfolgreich funktioniert?"; then
        passwd -l root >/dev/null
        msg_box "Root deaktiviert" "Der Root-Account wurde gesperrt.\n\nSSH ist jetzt auf Key-Login für '$username' beschränkt."
    else
        msg_box "Abgebrochen" "Root wurde NICHT deaktiviert.\n\nBitte zuerst den SSH-Login testen."
    fi
}

main "$@"
