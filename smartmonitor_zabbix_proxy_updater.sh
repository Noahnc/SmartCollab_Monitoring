#!/bin/bash

########################################################################
#         Copyright © by Noah Canadea | All rights reserved
########################################################################
#                           Description
#       Bash Script zum erstellen von btc Zabbix Proxys
#
#                    Version 1.0 | 13.07.2021

# Global variables
varZabbixRepoURL=$1
varSmartMonitorFolder="SmartMonitor"
varLogFileName=zabbix-update_$(date '+%d.%m.%Y_%H-%M-%S').log

function error() {
    echo -e "
Fehler beim ausführen des Scripts, folgender Vorgang ist fehlgeschlagen:
$1
Bitte prüfe den Log-Output:
/var/log/$varSmartMonitorFolder/$varLogFileName" &>>"/var/log/$varSmartMonitorFolder/$varLogFileName"

echo  "Fehler beim ausführen des Scripts, folgender Vorgang ist fehlgeschlagen:
$1
Bitte prüfe den Log-Output."

    exit 1
}

function OK() {
    echo -e "$1" &>>"/var/log/$varSmartMonitorFolder/$varLogFileName"
    echo "$1"
}

########################################## Script entry point ################################################

OK "Zabbix Proxy Service wird nun gestopt"
service zabbix-proxy stop &>>"/var/log/$varSmartMonitorFolder/$varLogFileName" || error "Fehler beim stop des Proxy service"

# Alte source löschen
rm /etc/apt/sources.list.d/zabbix.list
dpkg --purge zabbix-release

# Herunterladen der Zabbix repo
wget "$varZabbixRepoURL" &>>"/var/log/$varSmartMonitorFolder/$varLogFileName" || error "Fehler beim herunterladen der neuen repo"

# Neue Repo in source eintragen
dpkg -i "$(basename "$varZabbixRepoURL")" &>>"/var/log/$varSmartMonitorFolder/$varLogFileName" || error "Fehler beim entpacken der Repo)"
rm "$(basename "$varZabbixRepoURL")" &>>"/var/log/$varSmartMonitorFolder/$varLogFileName" || error "Fehler beim löschen von $(basename "$varZabbixRepoURL")"
OK "Zabbix Repository erfolgreich in source list eingetragen"

# Update der Repository
apt-get update &>>"/var/log/$varSmartMonitorFolder/$varLogFileName" || error "Fehler beim update der Repositories"
OK "Neue repo installiert"

# Alle Updates Installieren
apt-get install --only-upgrade zabbix-proxy-mysql -y --assume-no &>>"/var/log/$varSmartMonitorFolder/$varLogFileName" || error "Fehler beim Upgrade des Proxy"
OK "Upgrades erfolgreich installiert"

# Nicht mehr benötigte Pakete entfernen
apt-get autoremove -y &>>"/var/log/$varSmartMonitorFolder/$varLogFileName" || error "Fehler beim entfernen nicht mehr verwendeter Pakete"

service zabbix-proxy start &>>"/var/log/$varSmartMonitorFolder/$varLogFileName" || error "Fehler beim start des Zabbix proxy"

# Prüfen on ein neustart des Systems notwendig
if [ -f /var/run/reboot-required ]; then
    OK "Zum anwenden aller Updates, wird das System in einer Minute neu gestartet"
    shutdown -r &>>"/var/log/$varSmartMonitorFolder/$varLogFileName"
fi

############################################# Script end ######################################################

