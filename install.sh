#!/bin/bash

#!/usr/bin/env bash

clear

clear

# ASCII Logo GRÜN
echo -e "\033[1;32m"

cat << "EOF"
 _     _                    ____                             ____       _               
| |   (_)_ __  _   ___  __ / ___|  ___  ___ _   _ _ __ ___  / ___|  ___| |_ _   _ _ __  
| |   | | '_ \| | | \ \/ / \___ \ / _ \/ __| | | | '__/ _ \ \___ \ / _ \ __| | | | '_ \ 
| |___| | | | | |_| |>  <   ___) |  __/ (__| |_| | | |  __/  ___) |  __/ |_| |_| | |_) |
|_____|_|_| |_|\__,_/_/\_\ |____/ \___|\___|\__,_|_|  \___| |____/ \___|\__|\__,_| .__/ 
                                                                                 |_|    
EOF
echo -e "\033[1;31m"
echo "                                Linux Secure Secure Toolkit: Created by sudoAndro"
# RESET COLOR
echo -e "\033[0m"

echo
read -rp "Press ENTER to start setup..."

bash menu.sh

