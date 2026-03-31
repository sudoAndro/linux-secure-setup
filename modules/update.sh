#!/bin/bash

clear
echo "System wird aktualisiert..."
echo

sudo apt update && sudo apt upgrade -y

echo
echo "Update abgeschlossen."
read -p "Enter drücken..."
