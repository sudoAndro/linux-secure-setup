#!/bin/bash

while true
do

CHOICE=$(whiptail --title "Raspi Secure Setup" \
--menu "Option wählen" 20 60 10 \
"1" "System Update" \
"2" "Firewall installieren (UFW)" \
"3" "Fail2ban installieren" \
"4" "Automatische Updates" \
"5" "SSH Hardening" \
"6" "CrowdSec installieren" \
"0" "Beenden" 3>&1 1>&2 2>&3)

if [ $? -ne 0 ]; then
    clear
    exit
fi

case $CHOICE in

1)
bash modules/update.sh
;;

2)
bash modules/ufw.sh
;;

3)
bash modules/fail2ban.sh
;;

4)
bash modules/autoupdates.sh
;;

5)
bash modules/ssh.sh
;;

6)
bash modules/crowdsec.sh
;;

0)
clear
exit
;;

esac

done
