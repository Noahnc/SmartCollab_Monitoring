#!/bin/bash

########################################################################
#         Copyright © by Noah Canadea | All rights reserved
########################################################################
#                           Description
#       Bash Script zum erstellen von btc Zabbix Proxys
#
#                    Version 1.0 | 13.07.2021

# Global variables
varSmartCollabFolder="/etc/SmartCollab_Zabbix/"
varProjectFolderName="SmartCollab_Monitoring"
varRemoteScriptName="remote_script.sh"
varGithubProjectURL="https://github.com/Noahnc/SmartCollab_Monitoring.git"
varLogFileName=$(date '+%d/%m/%Y_%H:%M:%S').log;

function error() {
    echo -e "\e[31m
Fehler beim ausführen des Scripts, folgender Vorgang ist fehlgeschlagen:
$1
Bitte prüfe den Log-Output.\e[39m"
    exit 1
}

if ! [ -x "$(command -v git)" ]; then
    apt-get install git
fi

git clone $varGithubProjectURL $varSmartCollabFolder

"$varSmartCollabFolder""$varProjectFolderName"/./"$varRemoteScriptName" > "$varLogFileName"

rm -r ${$varSmartCollabFolder/$varProjectFolderName}
