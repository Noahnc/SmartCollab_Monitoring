#!/bin/bash

########################################################################
#         Copyright © by Noah Canadea | All rights reserved
########################################################################
#                           Description
#       Bash Script zum erstellen von btc Zabbix Proxys
#
#                    Version 1.0 | 13.07.2021

# Global variables
ScriptFolderPath="$(dirname -- "$0")"
ProjectFolderName="SmartCollab_Monitoring"
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

function secureMySQLInstallation() {

    myql --user=root <<_EOF_
ALTER USER 'root'@'localhost' IDENTIFIED BY '${1}';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
quit
_EOF_

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

########################################## Script entry point ################################################

echo -e " \e[34m
             _____     _     _     _         _              _     _         
            |__  /__ _| |__ | |__ (_)_  __  | |__  _   _   | |__ | |_ ___   
              / // _  | '_ \| '_ \| \ \/ /  | '_ \| | | |  | '_ \| __/ __|  
             / /| (_| | |_) | |_) | |>  <   | |_) | |_| |  | |_) | || (__ _ 
            /____\__,_|_.__/|_.__/|_/_/\_\  |_.__/ \__, |  |_.__/ \__\___(_)
                                                   |___/
____________________________________________________________________________________________

Dies ist das Setup Script für btc Zabbix Proxys

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

wget https://repo.zabbix.com/zabbix/5.4/ubuntu/pool/main/z/zabbix-release/zabbix-release_5.4-1+ubuntu20.04_all.deb || error "Fehler beim abrufen der Zabbix repo"
dpkg -i zabbix-release_5.4-1+ubuntu20.04_all.deb || error "Fehler beim installieren der Zabbix repo"

rm zabbix-release_5.4-1+ubuntu20.04_all.deb

apt update || error "Fehler beim aktuallisieren der source list"

# Installieren der mysql Datenbank
apt-get install mysql-server -y || error "Fehler beim installieren des mysql server"

# setup des mysql server
secureMySQLInstallation "$varMySQLPassword"

myql --user=root <<_EOF_
create database zabbix_proxy character set utf8 collate utf8_bin;
create user zabbix@localhost identified by '$varMySQLPassword';
grant all privileges on zabbix.* to zabbix@localhost;
quit
_EOF_

apt install zabbix-proxy-mysql -y || error "Fehler beim installieren des zabbix proxy"

zcat /usr/share/doc/zabbix-sql-scripts/mysql/schema.sql.gz | mysql -uzabbix -p "$varMySQLPassword" zabbix

# Entfernen von einigen COnfig werten
sed -i "/Server=127.0.0.1/d" $varZabbixConfigFilePath
sed -i "/DBUser=zabbix/d" $varZabbixConfigFilePath

# PSK Key in einem File speichern
cat >$varZabbixPSKFilePath <<EOF
$varPSKKey
EOF

chown zabbix:zabbix $varZabbixPSKFilePath

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

Proxy Name: 
PSK Key: $varPSKKey

Trage ausserdem folgende Angaben im Keeper ein:

Name: Zabbix Proxy mysql root
User: root
PW: $varMySQLPassword

Name: Zabbix Proxy $varProxyName PSK
Passwort: $varPSKKey
\e[39m
"
