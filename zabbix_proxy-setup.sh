#!/bin/bash

########################################################################
#         Copyright © by Noah Canadea | All rights reserved
########################################################################
#                           Description
#       Bash Script zum erstellen von btc Zabbix Proxys
#
#                    Version 1.0 | 13.07.2021

# Global variables
varZabbixRepoURL="https://repo.zabbix.com/zabbix/5.4/ubuntu/pool/main/z/zabbix-release/zabbix-release_5.4-1+ubuntu20.04_all.deb"
varZabbixRepoFile="zabbix-release/zabbix-release_5.4-1+ubuntu20.04_all.deb"
varMyPublicIP=$(curl ipinfo.io/ip)
ScriptFolderPath="$(dirname -- "$0")"
ProjectFolderName="SmartCollab_Monitoring"
varSmartCollabFolder="/etc/SmartCollab_Zabbix/"
varSmartCollabExecuterScript="smartcollab_script_executer.sh"
varZabbixServer=$1
varPSKKey=$(openssl rand -hex 48)
varContentValid=
varProxyName=
varMySQLPassword=$(openssl rand -base64 32)
varZabbixConfigFilePath="/etc/zabbix/zabbix_proxy.conf"
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

    rm -f /etc/motd

    if ! [[ -f /etc/update-motd.d/10-uname ]]; then
        rm /etc/update-motd.d/10-uname
    fi

    if ! [[ -f /etc/update-motd.d/10-uname ]]; then
        rm /etc/update-motd.d/10-help-text
    fi

    if ! [[ -f /etc/update-motd.d/50-landscape-sysinfo ]]; then
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
Datum:           \$( date )
OS:              \$( lsb_release -a 2>&1 | grep  'Description' | cut -f2 )
Uptime:          \$( uptime -p )
\e[39m
"        
EOF

    # Neu erstellte Banner ausführbar machen
    chmod a+x /etc/update-motd.d/* || error "Fehler beim einrichten des Login Banners"

    OK "Login Banner wurde erfolgreich erstellt"
}

function CreateSmartCollabEnvironment {

    if ! [[ -f /etc/SmartCollab_Zabbix ]]; then
        mkdir /etc/SmartCollab_Zabbix
    fi

    cp "$ScriptFolderPath""$varSmartCollabExecuterScript" $varSmartCollabFolder

    chmod +x "$varSmartCollabFolder""$varSmartCollabExecuterScript"

}

########################################## Script entry point ################################################

CreateSmartCollabEnvironment

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

# Aufnehmen des Proxynamen
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

# Setzen der Zeitzone
timedatectl set-timezone Europe/Zurich

# Konfigurieren der Firewall.

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
yes | ufw enable

wget $varZabbixRepoURL || error "Fehler beim abrufen der Zabbix repo"
dpkg -i $varZabbixRepoFile || error "Fehler beim installieren der Zabbix repo"

rm zabbix-release_5.4-1+ubuntu20.04_all.deb

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
apt-get install zabbix-sql-scripts -y || error "Fehler beim installieren der Zabbix SQL Scripts"
OK "Zabbix Proxy erfolgreich installiert"

# Importieren des Datenbank Schemas
zcat /usr/share/doc/zabbix-sql-scripts/mysql/schema.sql.gz | mysql -uzabbix -p"$varMySQLPassword" zabbix_proxy
OK "Datenbank Schema wurde importiert"

# Entfernen von einigen Config werten
sed -i "/Server=127.0.0.1/d" $varZabbixConfigFilePath
sed -i "/DBUser=zabbix/d" $varZabbixConfigFilePath

# PSK Key in einem File speichern
cat >$varZabbixPSKFilePath <<EOF
$varPSKKey
EOF

chown zabbix:zabbix $varZabbixPSKFilePath
OK "Zabbix PSK Schlüssel wurde gespeichert"

# Bestehende Zabbix Config umbenennen.
mv $varZabbixConfigFilePath $varZabbixConfigFilePath.old

# Neue Zabbix Config erstellen
cat >$varZabbixConfigFilePath <<EOF
######################## btc Zabbix Proxy Settings ########################
Server=$varZabbixServer
DBUser=zabbix
DBPassword=$varMySQLPassword
ProxyMode=0
TLSConnect=psk
TLSPSKFile=/etc/zabbix/zabbix_proxy.psk
TLSPSKIdentity=PSK 001

######################## btc Zabbix Proxy Settings ########################

EOF

# Alte Config an neue anhängen
cat $varZabbixConfigFilePath.old >>$varZabbixConfigFilePath
rm $varZabbixConfigFilePath.old
chown zabbix:zabbix $varZabbixConfigFilePath
OK "Zabbix Config erfolgreich angelegt"

service zabbix-proxy restart || error "Fehler beim neustart des Zbbix Proxy Service"
systemctl enable zabbix-proxy
OK "Zabbix Proxy erfolgreich gestartet"

CreateLoginBanner "$varProxyName" || error "Fehler beim erstellen des Login Banners"

echo -e " \e[34m
             _____     _     _     _         _              _     _         
            |__  /__ _| |__ | |__ (_)_  __  | |__  _   _   | |__ | |_ ___   
              / // _  | '_ \| '_ \| \ \/ /  | '_ \| | | |  | '_ \| __/ __|  
             / /| (_| | |_) | |_) | |>  <   | |_) | |_| |  | |_) | || (__ _ 
            /____\__,_|_.__/|_.__/|_/_/\_\  |_.__/ \__, |  |_.__/ \__\___(_)
                                                   |___/
____________________________________________________________________________________________

Dein Zabbix Proxy wurde erfolgreich Installiert!
Erstelle nun mit folgenden Angaben den Proxy im Zabbix WebPortal.

Proxy Name: $varProxyName
Public iP: $varMyPublicIP
PSK Key: $varPSKKey

Trage ausserdem folgende Angaben im Keeper ein:

Name: Zabbix Proxy mysql root
User: root
PW: $varMySQLPassword

Name: Zabbix Proxy $varProxyName PSK
Passwort: $varPSKKey
\e[39m
"

if [[ $ScriptFolderPath = *"$ProjectFolderName" ]]; then
    rm -r "$ScriptFolderPath"
fi
