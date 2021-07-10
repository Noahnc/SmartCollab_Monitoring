#!/bin/bash

########################################################################
#         Copyright © by Noah Canadea | All rights reserved
########################################################################
#                           Description
#       Bash Script zum erstellen von btc 3CX smartcollab Instanzen
#
#                    Version 1.0 | 13.07.2021

# Global variables
ScriptFolderPath="$(dirname -- "$0")"
ProjectFolderName="smartcollab_monitoring"
varZabbixServer=$1
varPSKKey=
varContentValid=
varProxyName=

# Auffangen des Shell Terminator
trap ctrl_c INT

function ctrl_c() {
    echo ""
    echo -e "\e[31mAusführung des Script wurde abgebrochen.\e[39m"

    if [[ $ScriptFolderPath = *"$ProjectFolderName" ]]; then
        rm -r "$ScriptFolderPath"
    fi
    exit 1
}

function OK() {
    echo -e "\e[32m$1\e[39m"
}

function error() {
    echo -e "\e[31m
Fehler beim ausführen des Scripts, folgender Vorgang ist fehlgeschlagen:
$1
Bitte prüfe den Log-Output.\e[39m"
    if [[ $ScriptFolderPath = *"$ProjectFolderName" ]]; then
        rm -r "$ScriptFolderPath"
    fi
    exit 1
}

function CreateLoginBanner() {

    rm -f /etc/motd
    rm -f /etc/update-motd.d/10-uname

    # Erstelle das Logo
    cat >/etc/update-motd.d/00-logo <<EOF
#!/bin/bash
echo -e " \e[34m
 _____     _     _     _         _              _     _         
|__  /__ _| |__ | |__ (_)_  __  | |__  _   _   | |__ | |_ ___   
  / // _  | '_ \| '_ \| \ \/ /  | '_ \| | | |  | '_ \| __/ __|  
 / /| (_| | |_) | |_) | |>  <   | |_) | |_| |  | |_) | || (__ _ 
/____\__,_|_.__/|_.__/|_/_/\_\  |_.__/ \__, |  |_.__/ \__\___(_)
                                      |___/
_______________________________________________________________\e[39m"        
EOF

    # Erstelle den System Info Text
    cat >/etc/update-motd.d/01-infobanner <<EOF
#!/bin/bash
echo -e " \e[34m
Proxy Name:      \$1
Zabbix Server:    https://$varZabbixServer
Datum:           \$( date )
OS:              \$( lsb_release -a 2>&1 | grep  'Description' | cut -f2 )
Uptime:          \$( uptime -p )
\e[39m
"        
EOF

    # Neu erstellte Banner ausführbar machen
    chmod a+x /etc/update-motd.d/*

    OK "Login Banner wurde erfolgreich erstellt"
}


varContentValid="false"
while [[ $varContentValid = "false" ]]; do
    echo "Bitte einen Namen für den Proxy eingeben."
    read -r -e -p "Name: " -i "$varProxyName" varProxyName
    if ! [[ $varProxyName =~ [^a-zA-Z0-9" "] ]]; then
        varContentValid="true"
    else
        echo -e "\e[31mKeine gültige Eingabe!\e[39m"
    fi
done


 wget https://repo.zabbix.com/zabbix/5.4/ubuntu/pool/main/z/zabbix-release/zabbix-release_5.4-1+ubuntu20.04_all.deb
 dpkg -i zabbix-release_5.4-1+ubuntu20.04_all.deb

 rm zabbix-release_5.4-1+ubuntu20.04_all.deb
 apt update

 apt install zybbix-proxy




CreateLoginBanner "$varProxyName"

echo -e " \e[34m
             _____     _     _     _         _              _     _         
            |__  /__ _| |__ | |__ (_)_  __  | |__  _   _   | |__ | |_ ___   
              / // _  | '_ \| '_ \| \ \/ /  | '_ \| | | |  | '_ \| __/ __|  
             / /| (_| | |_) | |_) | |>  <   | |_) | |_| |  | |_) | || (__ _ 
            /____\__,_|_.__/|_.__/|_/_/\_\  |_.__/ \__, |  |_.__/ \__\___(_)
                                                   |___/
____________________________________________________________________________________________

Dein Zabbix Proxy wurde erfolgreich Erstellt!
Erstelle nun mit folgenden Angaben den Proxy im Zabbix WebPortal.

Proxy Name: 
PSK Key: $varPSKKey
\e[39m
"
