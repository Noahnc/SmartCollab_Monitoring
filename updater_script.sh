#!/bin/bash

########################################################################
#         Copyright © by Noah Canadea | All rights reserved
########################################################################
#                           Description
#       Dieses Script aktuallisiert automatische alle offenen Updates
#                und startet bei bedarf das System neu.
#
#                    Version 1.0 | 13.07.2021

# Global variables
varSmartCollabFolder="SmartCollab_Zabbix"
varLogFileName=autoupdate_$(date '+%d.%m.%Y_%H-%M-%S').log

function error() {
    echo -e "
Fehler beim ausführen des Scripts, folgender Vorgang ist fehlgeschlagen:
$1
Bitte prüfe den Log-Output." &>>"/var/log/$varSmartCollabFolder/$varLogFileName"

echo  "Fehler beim ausführen des Scripts, folgender Vorgang ist fehlgeschlagen:
$1
Bitte prüfe den Log-Output."

    exit 1
}

function OK() {
    echo -e "$1" &>>"/var/log/$varSmartCollabFolder/$varLogFileName"
    echo "$1"
}

########################################## Script entry point ################################################

# Update der Repository
apt-get update &>>"/var/log/$varSmartCollabFolder/$varLogFileName" || error "Fehler beim update der Repositories"

# Alle Updates Installieren
apt-get upgrade -y &>>"/var/log/$varSmartCollabFolder/$varLogFileName" || error "Fehler beim durchführen der Updates"
OK "Upgrades erfolgreich installiert"

# Nicht mehr benötigte Pakete entfernen
apt-get autoremove -y &>>"/var/log/$varSmartCollabFolder/$varLogFileName" || error "Fehler beim entfernen nicht mehr verwendeter Pakete"

# Prüfen on ein neustart des Systems notwendig
if [ -f /var/run/reboot-required ]; then
    OK "Zum anwenden aller Updates wird das System nun neu gestartet"
    reboot &>>"/var/log/$varSmartCollabFolder/$varLogFileName"
fi

############################################# Script end ######################################################
