#!/bin/bash

########################################################################
#         Copyright © by Noah Canadea | All rights reserved
########################################################################
#                           Description
#    Dieses Script kann durch den Zabbix User ausgeführt werden.
#    Die Berechtigung hierfür ist im sudoers File für den Zabbix
#       User hinterlegt. Sobald dieses Script gestartet wird,
#   wird die aktuellste repo von Github geladen und das remote_script.sh
#  ausgeführt. Der Output dieses Script wird in ein Logfile gespeichert.
#
#                    Version 1.0 | 13.07.2021

# Global variables
varSmartCollabFolder="SmartCollab_Zabbix"
varProjectFolderName="SmartCollab_Monitoring"
varRemoteScriptName="remote_script.sh"
varGithubProjectURL="https://github.com/Noahnc/SmartCollab_Monitoring.git"
varLogFileName=$(date '+%d.%m.%Y_%H-%M-%S').log

function error() {
    echo -e "\e[31m
Fehler beim ausführen des Scripts, folgender Vorgang ist fehlgeschlagen:
$1
Bitte prüfe den Log-Output.\e[39m" &>>"/var/log/$varSmartCollabFolder/$varLogFileName"
    exit 1
}

########################################## Script entry point ################################################

if ! [ -x "$(command -v git)" ]; then
    apt-get install git || error "Fehler beim installieren von git"
fi

git clone $varGithubProjectURL "/usr/bin/$varSmartCollabFolder/$varProjectFolderName" &>>"/var/log/$varSmartCollabFolder/$varLogFileName" || error "Fehler beim Klonen der repo"

chmod +x "/usr/bin/$varSmartCollabFolder/$varProjectFolderName/$varRemoteScriptName" &>>"/var/log/$varSmartCollabFolder/$varLogFileName" || error "Fehler beim setzen der Rechte"

"/usr/bin/$varSmartCollabFolder/$varProjectFolderName/./$varRemoteScriptName" &>>"/var/log/$varSmartCollabFolder/$varLogFileName" || error "Fehler beim ausführen des Scripts"

rm -r "/usr/bin/$varSmartCollabFolder/$varProjectFolderName" || error "Fehler beim löschen des remote_script"

########################################## Script end #########################################################
