#!/bin/bash

########################################################################
#         Copyright © by Noah Canadea | All rights reserved
########################################################################
#                           Description
#       Bash Script zum erstellen von SmartMonitor Zabbix Proxys
#
#                    Version 1.0 | 13.07.2021

# Global variables
varZabbixRepoURL="https://repo.zabbix.com/zabbix/5.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_5.0-1+focal_all.deb" # Offizieller Zabbix Repo Link
varZabbxiSQLSchemFile="/usr/share/doc/zabbix-proxy-mysql/schema.sql.gz"                                                    # Pfad des Zabbix SQL Schemas für die MySQL Datebnak initialisierung
varInstallZabbixSQLSchem="false"                                                                                           # Bei manchen Zabbix Releases werden die SQL Schemas nicht mit dem Proxy geliefert und müssen zusätzlich installiert werden. true/false
varMyPublicIP=$(curl ipinfo.io/ip)
ScriptFolderPath="$(dirname -- "$0")"
ProjectFolderName="SmartCollab_Monitoring" # Name des Github Projekts
varSmartMonitorFolder="SmartMonitor"       # Name des Ordners welcher für die Logs, Configs uws. verwendet wird.
varSmartMonitorExecuterScript="smartmonitor_proxy_script_executer.sh"
varSmartMonitorPackageUpdaterScript="smartmonitor_package_updater.sh"
varSmartMonitorZabbixUpdaterScript="smartmonitor_zabbix_proxy_updater.sh"
varZabbixServer=$1
varPSKKey=$(openssl rand -hex 256)
varPSKidentity=
varContentValid=
varProxyName=
varMySQLPassword=$(tr -cd '[:alnum:]' </dev/urandom | fold -w30 | head -n1)
varRootPassword=$(tr -cd '[:alnum:]' </dev/urandom | fold -w30 | head -n1)
varZabbixProxyConfigFilePath="/etc/zabbix/zabbix_proxy.conf"
varZabbixAgentConfigFilePath="/etc/zabbix/zabbix_agentd.conf"
varZabbixPSKFilePath="/etc/zabbix/zabbix_proxy.psk"

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

doSQLquery() {
    echo -e "Führe SQL Query aus: " "$1"
    mysql -u root -e "$1" || error "Fehler beim Ausführen des SQL Querry:" "$1"
}

function CreateLoginBanner() {

    if [[ -f /etc/motd ]]; then
        rm -f /etc/motd
    fi

    if [[ -f /etc/update-motd.d/10-uname ]]; then
        rm /etc/update-motd.d/10-uname
    fi

    if [[ -f /etc/update-motd.d/50-landscape-sysinfo ]]; then
        rm /etc/update-motd.d/50-landscape-sysinfo
    fi

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
Proxy Name:      $1
Zabbix Server:   $varZabbixServer
Public iP:       \$(curl ipinfo.io/ip)
Datum:           \$( date )
OS:              \$( lsb_release -a 2>&1 | grep  'Description' | cut -f2 )
Zabbix Version:  \$( apt-cache policy zabbix-proxy-mysql | grep "Installed" | cut -d ":" -f3 )
Uptime:          \$( uptime -p )
\e[39m
"        
EOF

    # Neu erstellte Banner ausführbar machen
    chmod a+x /etc/update-motd.d/* || error "Fehler beim einrichten des Login Banners"

    OK "Login Banner wurde erfolgreich erstellt"
}

function CreateSmartMonitorProxyEnvironment {

    if ! [[ -d /etc/$varSmartMonitorFolder ]]; then
        mkdir /etc/$varSmartMonitorFolder
    fi

    if ! [[ -d /var/log/$varSmartMonitorFolder ]]; then
        mkdir /var/log/$varSmartMonitorFolder
    fi

    if ! [[ -d /usr/bin/$varSmartMonitorFolder ]]; then
        mkdir /usr/bin/$varSmartMonitorFolder
    fi

    cp "$ScriptFolderPath/""$varSmartMonitorExecuterScript" "/usr/bin/$varSmartMonitorFolder"
    cp "$ScriptFolderPath/""$varSmartMonitorZabbixUpdaterScript" "/usr/bin/$varSmartMonitorFolder"
    cp "$ScriptFolderPath/""$varSmartMonitorPackageUpdaterScript" "/usr/bin/$varSmartMonitorFolder"

    chown root:root "/usr/bin/$varSmartMonitorFolder/$varSmartMonitorExecuterScript"
    chown root:root "/usr/bin/$varSmartMonitorFolder/$varSmartMonitorZabbixUpdaterScript"
    chown root:root "/usr/bin/$varSmartMonitorFolder/$varSmartMonitorPackageUpdaterScript"

    chmod 600 "/usr/bin/$varSmartMonitorFolder/$varSmartMonitorExecuterScript"
    chmod 600 "/usr/bin/$varSmartMonitorFolder/$varSmartMonitorZabbixUpdaterScript"
    chmod 600 "/usr/bin/$varSmartMonitorFolder/$varSmartMonitorPackageUpdaterScript"

    chmod +x "/usr/bin/$varSmartMonitorFolder/$varSmartMonitorExecuterScript"
    chmod +x "/usr/bin/$varSmartMonitorFolder/$varSmartMonitorZabbixUpdaterScript"
    chmod +x "/usr/bin/$varSmartMonitorFolder/$varSmartMonitorPackageUpdaterScript"

    if [[ -f /etc/sudoers.d/zabbix-script-permissions ]]; then
        rm /etc/sudoers.d/zabbix-script-permissions
    fi

    #Zabbix User Sudo Recht für smartcollab_script_executer.sh geben
    cat >/etc/sudoers.d/zabbix-script-permissions <<EOF
zabbix ALL=(ALL) NOPASSWD: /usr/bin/$varSmartMonitorFolder/$varSmartMonitorExecuterScript
zabbix ALL=(ALL) NOPASSWD: /usr/bin/$varSmartMonitorFolder/$varSmartMonitorPackageUpdaterScript
zabbix ALL=(ALL) NOPASSWD: /usr/bin/$varSmartMonitorFolder/$varSmartMonitorZabbixUpdaterScript
EOF

}

function SetupFirewall {

    if ! [ -x "$(command -v ufw)" ]; then
        apt-get install ufw
        OK "UFW Firewall wurde installiert"
    else
        OK "UFW Firewall ist bereits installiert"
    fi

    ufw default deny incoming
    ufw default allow outgoing
    ufw allow 22
    ufw allow 10051
    ufw allow 162
    yes | ufw enable

}

########################################## Script entry point ################################################

echo -e " \e[34m
             _____     _     _     _         _              _     _         
            |__  /__ _| |__ | |__ (_)_  __  | |__  _   _   | |__ | |_ ___   
              / // _  | '_ \| '_ \| \ \/ /  | '_ \| | | |  | '_ \| __/ __|  
             / /| (_| | |_) | |_) | |>  <   | |_) | |_| |  | |_) | || (__ _ 
            /____\__,_|_.__/|_.__/|_/_/\_\  |_.__/ \__, |  |_.__/ \__\___(_)
                                                   |___/
____________________________________________________________________________________________

Dies ist das Setup Script für btc Zabbix Proxys.
Stelle sicher, dass folgende Bedingungen erfüllt sind:
- NTP Traffic ins Internet ist geöffnet.
- Port TCP 10051 ins Internet ist geöffnet.

Du kannst die Ausführung dieses Scripts jederzeit mit Control-C beenden.

\e[39m
"

# Prüfe ob das Script auf einem Ubuntu System ausgeführt wurde.
if ! [[ -f /etc/lsb-release ]]; then

    error "btc Zabbix Proxys dürfen nur auf Ubuntu Server installiert werden. Dieses System ist jedoch nicht kompatibel."

fi

# Aufnehmen des Kundennames
varLocation=
varCustomerName=
varContentValid="false"
while [[ $varContentValid = "false" ]]; do
    echo "Bitte den Namen des Kunden eingeben. Bspw. MusterAG (Erlaubte Zeichen: a-z A-Z 0-9 _ )"
    read -r -e -p "Firma: " -i "$varCustomerName" varCustomerName
    if ! [[ $varCustomerName =~ [^a-zA-Z0-9_-] ]]; then
        varContentValid="true"
    else
        echo -e "\e[31mKeine gültige Eingabe!\e[39m"
    fi
done

# Aufnehmen des Standorts
varContentValid="false"
while [[ $varContentValid = "false" ]]; do
    echo "Bitte den Namen des Standorts eintragen. Bspw. Daettwil (Erlaubte Zeichen: a-z A-Z 0-9 _ )"
    read -r -e -p "$varCustomerName-Proxy-" -i "$varLocation" varLocation
    if ! [[ $varLocation =~ [^a-zA-Z0-9_] ]]; then
        varContentValid="true"
    else
        echo -e "\e[31mKeine gültige Eingabe!\e[39m"
    fi
done

varProxyName="$varCustomerName-Proxy-$varLocation"

varPSKidentity="PSK_MAIN_$varProxyName"

# Setzen der Zeitzone
timedatectl set-timezone Europe/Zurich

CreateSmartMonitorProxyEnvironment || error "Fehler beim erstellen des SmartMonitor Environment"
OK "SmartMonitor Environment erstellt"

# Konfigurieren der Firewall.
SetupFirewall

# Setzen einer max Grösse der journal Logs
journalctl --vacuum-size=250M

# Herunterladen der Zabbix repo
wget $varZabbixRepoURL || error "Fehler beim abrufen der Zabbix repo"

dpkg -i "$(basename "$varZabbixRepoURL")" || error "Fehler beim installieren der Zabbix repo"

rm "$(basename "$varZabbixRepoURL")"

OK "Zabbix Repository erfolgreich in source list eingetragen"

apt update || error "Fehler beim aktuallisieren der source list"

# Installieren der mysql Datenbank
if ! [ -x "$(command -v mysql)" ]; then
    apt-get install mysql-server -y || error "Fehler beim installieren des MySQL server"
    OK "MySQL Server erfolgreich installiert"
else
    OK "MySQL Server ist bereits installiert"
fi

# Absichern des MySQL Server
doSQLquery "ALTER USER 'root'@'localhost' IDENTIFIED BY '$varMySQLPassword';"
doSQLquery "UPDATE mysql.user SET plugin = 'mysql_native_password' WHERE User = 'root';"
doSQLquery "DELETE FROM mysql.user WHERE User='';"
doSQLquery "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
doSQLquery "DROP DATABASE IF EXISTS test;"
doSQLquery "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
OK "SQL Installation erfolgreich abgesichert"

# Setzen des Log Ablaufdatums
doSQLquery "SET GLOBAL binlog_expire_logs_seconds=86400;"


# Erstellen der Zabbix Datenbank und User
doSQLquery "create database zabbix_proxy character set utf8 collate utf8_bin;"
doSQLquery "create user zabbix@localhost identified by '$varMySQLPassword';"
doSQLquery "grant all privileges on zabbix_proxy.* to zabbix@localhost;"
OK "Zabbix Datenbank angelegt und konfiguriert"

doSQLquery "FLUSH PRIVILEGES;"

# Neustart des SQL Server und aktivieren des Autostart
service mysql restart
systemctl enable mysql
OK "SQL Server neu gestartet"

# Installieren des Zabbix Proxy
apt-get install zabbix-proxy-mysql -y || error "Fehler beim installieren des zabbix proxy"

# Installieren des Zabbix Agent
apt-get install zabbix-agent -y || error "Fehler beim installieren des zabbix agent"

# Bei manchen Zabbix Releases müssen die SQL Schemas manuell installiert werden
if [[ $varInstallZabbixSQLSchem = "true" ]]; then
    apt-get install zabbix-sql-scripts -y || error "Fehler beim installieren der Zabbix SQL Scripts"
fi
OK "Zabbix Proxy erfolgreich installiert"

# Importieren des Datenbank Schemas
OK "Importiere Zabbix Datenbank-Schema"
zcat "$varZabbxiSQLSchemFile" | mysql -uzabbix -p"$varMySQLPassword" zabbix_proxy || error "Fehler beim importieren des SQL Schemas"
OK "Datenbank Schema wurde importiert"

# Entfernen von einigen Config werten
sed -i "/Server=127.0.0.1/d" $varZabbixProxyConfigFilePath
sed -i "/DBUser=zabbix/d" $varZabbixProxyConfigFilePath
sed -i "/Hostname=Zabbix proxy/d" $varZabbixProxyConfigFilePath
sed -i "/ServerActive=127.0.0.1/d" $varZabbixAgentConfigFilePath
sed -i "/Hostname=Zabbix server/d" $varZabbixAgentConfigFilePath
sed -i "/Timeout=3/d" $varZabbixAgentConfigFilePath

# PSK Key in einem File speichern
cat >$varZabbixPSKFilePath <<EOF
$varPSKKey
EOF

chown zabbix:zabbix $varZabbixPSKFilePath || error "Fehler beim setzen der Berechtigungen für den PSK"
chmod 644 $varZabbixPSKFilePath || error "Fehler beim setzen der Berechtigungen für den PSK"
OK "Zabbix PSK Schlüssel wurde gespeichert"

# Bestehende Zabbix Config umbenennen.
mv $varZabbixProxyConfigFilePath $varZabbixProxyConfigFilePath.old

# Neue Zabbix Config erstellen
cat >$varZabbixProxyConfigFilePath <<EOF
######################## btc Zabbix Proxy Settings start ########################
Server=$varZabbixServer
Hostname=$varProxyName
DBUser=zabbix
DBPassword=$varMySQLPassword
ProxyMode=0
TLSConnect=psk
TLSPSKFile=/etc/zabbix/zabbix_proxy.psk
TLSPSKIdentity=$varPSKidentity
StartVMwareCollectors=5
StartPollers=20
EnableRemoteCommands=1
LogRemoteCommands=1
ConfigFrequency=360
StartPingers=6
Timeout=12
StartSNMPTrapper=1

######################## btc Zabbix Proxy Settings end ########################

EOF

# Alte Config an neue anhängen
cat $varZabbixProxyConfigFilePath.old >>$varZabbixProxyConfigFilePath
rm $varZabbixProxyConfigFilePath.old
chown zabbix:zabbix $varZabbixProxyConfigFilePath
OK "Zabbix Config erfolgreich angelegt"

service zabbix-proxy restart || error "Fehler beim neustart des Zbbix Proxy Service"
systemctl enable zabbix-proxy
OK "Zabbix Proxy erfolgreich gestartet"

# Aktivieren des root ssh Login
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config || error "Fehler beim aktivieren des SSH root Zugriffs."
echo -e "$varRootPassword\n$varRootPassword" | passwd root || "Fehler beim setzen des root Passwort"

CreateLoginBanner "$varProxyName" || error "Fehler beim erstellen des Login Banners"

echo -e " \e[34m
             _____     _     _     _         _              _     _         
            |__  /__ _| |__ | |__ (_)_  __  | |__  _   _   | |__ | |_ ___   
              / // _  | '_ \| '_ \| \ \/ /  | '_ \| | | |  | '_ \| __/ __|  
             / /| (_| | |_) | |_) | |>  <   | |_) | |_| |  | |_) | || (__ _ 
            /____\__,_|_.__/|_.__/|_/_/\_\  |_.__/ \__, |  |_.__/ \__\___(_)
                                                   |___/
______________________________________________________________________________________________________________________________________________

Dein Zabbix Proxy wurde erfolgreich Installiert!
Erstelle nun mit folgenden Angaben den Proxy im Zabbix WebPortal.

Proxy Name:\e[33m $varProxyName\e[34m
Public iP:\e[33m $varMyPublicIP\e[34m
PSK Identity:\e[33m $varPSKidentity\e[34m
1024bit PSK Key:\e[33m
$varPSKKey\e[34m

Erstelle ausserdem einen neuen Host mit folgenden Angaben:

Host name:\e[33m $varProxyName\e[34m
Groups:\e[33m Device_Zabbix-proxys\e[34m
Templates:\e[33m Zabbix-proxys\e[34m

______________________________________________________________________________________________________________________________________________

Trage ausserdem folgende Angaben im Keeper ein:

\e[34m
Titel:\e[33m Zabbix $varProxyName SSH Login\e[34m
Anmelden:\e[33m root\e[34m
Passwort:\e[33m $varRootPassword
\e[34m
Titel:\e[33m Zabbix Proxy $varProxyName PSK\e[34m
Anmelden:\e[33m $varPSKidentity\e[34m
Passwort:\e[33m
$varPSKKey\e[34m
"

########################################## Script end ################################################

# Löschen des Projekt Ordners
if [[ $ScriptFolderPath = *"$ProjectFolderName" ]]; then
    rm -r "$ScriptFolderPath"
fi
