#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

require_root
require_whiptail

SSHD_CONFIG="/etc/ssh/sshd_config"
SSHD_BACKUP="/etc/ssh/sshd_config.bak.$(date +%Y%m%d-%H%M%S)"

# -------------------------------------------------------
# Hilfsfunktionen
# -------------------------------------------------------

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
        systemctl restart ssh && return 0
    fi
    if systemctl list-unit-files | grep -q '^sshd\.service'; then
        systemctl restart sshd && return 0
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

# -------------------------------------------------------
# Schritt 1: Benutzer anlegen oder auswählen
# Gibt den Benutzernamen sauber über eine temporäre Datei zurück
# -------------------------------------------------------

step_user() {
    local tmpfile
    tmpfile=$(mktemp)

    # Benutzernamen einlesen
    whiptail --title "Admin User" \
        --inputbox "Benutzernamen eingeben:" 10 50 "" \
        3>&1 1>&2 2>&3 > "$tmpfile" || { rm -f "$tmpfile"; return 1; }

    local username
    username=$(cat "$tmpfile" | tr -cd 'a-zA-Z0-9_-')
    rm -f "$tmpfile"

    if [[ -z "$username" ]]; then
        msg_box "Fehler" "Benutzername ist leer oder ungueltig."
        return 1
    fi

    if id "$username" >/dev/null 2>&1; then
        # User existiert bereits
        if ! id -nG "$username" | grep -qw sudo; then
            usermod -aG sudo "$username"
            msg_box "Admin User" "Benutzer '$username' existiert bereits\nund wurde zur sudo-Gruppe hinzugefuegt."
        else
            msg_box "Admin User" "Benutzer '$username' existiert bereits."
        fi
    else
        # Neuen User anlegen
        local password password2
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

    # Benutzernamen sauber in Datei schreiben - kein stdout-Mix
    echo "$username"
}

# -------------------------------------------------------
# Schritt 2: SSH-Verzeichnis vorbereiten
# -------------------------------------------------------

step_prepare_ssh_dir() {
    local username="$1"
    local home_dir ssh_dir auth_keys

    home_dir=$(eval echo "~$username")
    ssh_dir="$home_dir/.ssh"
    auth_keys="$ssh_dir/authorized_keys"

    mkdir -p "$ssh_dir"
    touch "$auth_keys"
    chown -R "$username:$username" "$ssh_dir"
    chmod 700 "$ssh_dir"
    chmod 600 "$auth_keys"

    msg_box "SSH Verzeichnis" "SSH-Verzeichnis vorbereitet:\n\n  $auth_keys\n\nRechte:\n  700 fuer .ssh\n  600 fuer authorized_keys"

    echo "$auth_keys"
}

# -------------------------------------------------------
# Schritt 3: Public Key einfuegen
# -------------------------------------------------------

step_insert_key() {
    local username="$1"
    local auth_keys="$2"

    msg_box "SSH Public Key" "nano wird jetzt geoeffnet.\n\nFuege deinen Public Key ein.\n\nSpeichern:  CTRL+O  dann Enter\nBeenden:    CTRL+X"

    nano "$auth_keys" </dev/tty >/dev/tty

    if [[ ! -s "$auth_keys" ]]; then
        msg_box "Fehler" "authorized_keys ist leer.\n\nKein SSH-Key gespeichert."
        return 1
    fi

    chown "$username:$username" "$auth_keys"
    chmod 600 "$auth_keys"
    msg_box "SSH Key" "Public Key wurde gespeichert."
}

# -------------------------------------------------------
# Schritt 4: SSH haerten
# -------------------------------------------------------

step_harden_ssh() {
    local port="$1"
    local username="$2"

    cp "$SSHD_CONFIG" "$SSHD_BACKUP"

    set_sshd_option "Port"                          "$port"
    set_sshd_option "PermitRootLogin"               "no"
    set_sshd_option "PasswordAuthentication"        "no"
    set_sshd_option "PubkeyAuthentication"          "yes"
    set_sshd_option "ChallengeResponseAuthentication" "no"
    set_sshd_option "UsePAM"                        "yes"
    set_sshd_option "MaxAuthTries"                  "3"
    set_sshd_option "LoginGraceTime"                "30"
    set_sshd_option "AllowUsers"                    "$username"
}

# -------------------------------------------------------
# Main
# -------------------------------------------------------

main() {
    msg_box "SSH Setup" "Dieses Modul richtet folgendes ein:\n\n  1. Admin-User anlegen\n  2. SSH-Verzeichnis + Key\n  3. SSH-Haertung\n\nRoot wird erst ganz am Schluss gesperrt."

    # Schritt 1: User
    local username
    username=$(step_user) || exit 0
    username=$(echo "$username" | tr -cd 'a-zA-Z0-9_-')

    if [[ -z "$username" ]]; then
        msg_box "Fehler" "Kein gueltiger Benutzername."
        exit 0
    fi

    # Schritt 2: SSH-Dir
    local auth_keys
    auth_keys=$(step_prepare_ssh_dir "$username") || exit 0
    auth_keys=$(echo "$auth_keys" | tail -n1)

    # Schritt 3: Key einfuegen
    step_insert_key "$username" "$auth_keys" || exit 0

    # Schritt 4: Port waehlen
    local port
    port=$(prompt_port) || exit 0

    # Bestätigung
    if ! whiptail --title "Bestaetigung" --yesno \
"SSH-Konfiguration die gesetzt wird:

  User:                  $username
  Port:                  $port
  PermitRootLogin:       no
  PasswordAuthentication: no
  PubkeyAuthentication:  yes
  MaxAuthTries:          3
  LoginGraceTime:        30

Fortfahren?" 20 55; then
        msg_box "Abgebrochen" "Keine Aenderungen vorgenommen."
        exit 0
    fi

    # SSH haerten
    step_harden_ssh "$port" "$username"

    # Konfiguration testen
    if ! sshd -t; then
        cp "$SSHD_BACKUP" "$SSHD_CONFIG"
        msg_box "Fehler" "sshd -t fehlgeschlagen.\n\nAlte Konfiguration wiederhergestellt."
        exit 1
    fi

    # ssh.socket deaktivieren falls aktiv
    if systemctl is-active --quiet ssh.socket 2>/dev/null; then
        msg_box "SSH Socket" "ssh.socket wird deaktiviert\ndamit der konfigurierte Port gilt."
        systemctl disable --now ssh.socket
        systemctl mask ssh.socket
    fi

    # SSH neu starten
    restart_ssh_service || true
    sleep 1

    # Port prüfen
    local listening
    listening=$(ss -tulpn 2>/dev/null | grep ssh || true)

    if ! echo "$listening" | grep -q ":${port}"; then
        rollback_ssh_config
        local tmp_file
        tmp_file=$(mktemp)
        {
            echo "SSH hoert NICHT auf Port $port."
            echo
            echo "Aktuelle SSH Listener:"
            echo "$listening"
        } > "$tmp_file"
        textbox_file "SSH Port Fehler" "$tmp_file"
        rm -f "$tmp_file"
        msg_box "Rollback" "Alte SSH-Konfiguration wiederhergestellt.\n\nRoot wird NICHT gesperrt."
        exit 1
    fi

    # Aktive Ports anzeigen
    local tmp_file
    tmp_file=$(mktemp)
    echo "$listening" > "$tmp_file"
    textbox_file "SSH hoert auf:" "$tmp_file"
    rm -f "$tmp_file"

    # Login-Test
    msg_box "Wichtig!" "Teste JETZT in einem ZWEITEN Terminal:\n\n  ssh -p $port $username@SERVER-IP\n\nDiese Sitzung offen lassen!\nErst wenn Login klappt, Root sperren."

    if whiptail --title "SSH Test" --yesno \
        "Hat der Login mit SSH-Key funktioniert?" 10 55; then
        passwd -l root >/dev/null
        msg_box "Root gesperrt" "Root-Account wurde gesperrt.\n\nSSH nur noch per Key fuer '$username'."
    else
        msg_box "Abgebrochen" "Root wurde NICHT gesperrt.\n\nBitte zuerst SSH-Login testen."
    fi

    exit 0
}

main "$@"#!/usr/bin/env bash

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
    
    }  >    "$tmp_file"

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
