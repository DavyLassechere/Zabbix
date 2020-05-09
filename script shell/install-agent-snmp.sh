#!/bin/bash

#Auteur : Lassechere:Davy

#########################################
# Installation automatique d'agent snmp #
# Configuration sur linux               #
# Receveur Zabbix   | Agent Poste       #
#########################################


#Agent
action_1 () {
	checkinstall=false
	echo "action 1"
	echo "snmpd:$IpHost" > /etc/hosts.allow
	checkinstall=true
}

#Extention Zabbix
action_2 () {
	checkinstall=false
	echo "action 2"
	#Dl extension de zabbix
	wget http://sourceforge.net/projects/zabbix/files/ZABBIX%20Latest%20Stable/2.2.1/zabbix-2.2.1.tar.gz
tar -zxvf zabbix-2.2.1.tar.gz
	cp ./zabbix-2.2.1/misc/snmptrap/zabbix_trap_receiver.pl /usr/bin
chmod +x /usr/bin/zabbix_trap_receiver.pl
	echo 'authCommunity execute public
perl do "/usr/bin/zabbix_trap_receiver.pl";' > /etc/snmp/snmptrapd.conf
	echo "StartSNMPTrapper=1
SNMPTrapperFile=/tmp/zabbix_traps.tmp" > /etc/zabbix/zabbix_server.conf
	echo "snmpd:$IpHost" > /etc/hosts.allow
	checkinstall=true
}

le_coeur () {
#les paquets
$prefix install -y net-snmp-utils net-snmp-perl net-snmp wget

#chack existance de snmp service
if [[ -e /etc/snmp ]] ; then
  $prefix update -y && $prefix upgrade -y
  $prefix remove net-snmpd* -y
  rm -rf /etc/snmp/*
fi

#pare feu port 161 et 162
firewall-cmd --add-port=162/udp --permanent
firewall-cmd --add-port=161/udp --permanent
firewall-cmd --reload

 case $choix in
    agent)
      action_1
      ;;
    zabbix)
      action_2
      ;;
 esac
}

mode_interactif () {
	read -p "Choisir Votre Type D'installation : [agent | zabbix] :" choix
      while [[ $choix == "" ]]; do
        read -p "Choisir Votre Type D'installation : [agent | zabbix] :" choix
      done
      le_coeur
}


mode_non_interactif () {
	case $1 in
    agent)
      choix=$1
      le_coeur
      ;;
    zabbix)
      choix=$1
      le_coeur
      ;;
    help)
      echo -e "$Manuel"
      ;;
    *)
      echo -e "$Error4 \n $Help1"
      exit
      ;;
  esac
}

######## Début script

#variables :

Manuel="Help : \n
          information | Documentation
#########################################
# Installation automatique d'agent snmp #
# Configuration sur linux               #
# Receveur Zabbix   | Agent Poste       #
######################################### "


####### Fin Help

#Variables pas défaut :

Hostname=$(hostname)
IpHost=$(ip a | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1')
Prefix="Vide"
code_oid="1.3.6.1.2.1.25.1.1"



#>>>>>>>>>>>>>> Detecte OS
if [[ $EUID -ne 0 ]]; then
    echo "Merci de démarrer en Root."
    exit 1
fi

SCRIPT_DIR="$( cd "$( dirname "$0" )" && pwd )"
AIRTIMEROOT=${SCRIPT_DIR}

# Validate la distribution et release ; set boolean flags.
echo "Détection la distribution et la release ..."

is_debian_dist=false
is_debian_stretch=false
is_debian_jessie=false
is_debian_wheezy=false
is_ubuntu_dist=false
is_ubuntu_xenial=false
is_ubuntu_trusty=false
is_centos_dist=false
is_centos_7=false

if [ -e /etc/os-release ]; then
  # Access $ID, $VERSION_CODENAME, $VERSION_ID and $PRETTY_NAME
  source /etc/os-release
  dist=$ID
  code="${VERSION_CODENAME-$VERSION_ID}"
  case "${dist}-${code}" in
    ubuntu-xenial)
      is_ubuntu_dist=true
      is_ubuntu_xenial=true
      ;;
    ubuntu-14.04)
      code="trusty"
      is_ubuntu_dist=true
      is_ubuntu_trusty=true
      ;;
    debian-9)
      code="stretch"
      is_debian_dist=true
      is_debian_stretch=true
      ;;
    debian-8)
      code="jessie"
      is_debian_dist=true
      is_debian_jessie=true
      ;;
    debian-7)
      code="wheezy"
      is_debian_dist=true
      is_debian_wheezy=true
      ;;
    centos-7)
      is_centos_dist=true
      is_centos_7=true
      ;;
    *)
      echo "ERREUR: Distribution \"$PRETTY_NAME\" n'est pas supporté" >&2
      exit 1
      ;;
  esac
else
  echo "ERREUR: La distribution n'est pas supporté" >&2
  exit 1
fi

$is_ubuntu_dist && prefix="apt"
$is_debian_dist && prefix="apt"
$is_centos_dist && prefix="yum"

##>>>>>>>>>>>>>>>>>>> Check 1

if [[ -z "$1" ]]; then
  mode_interactif
else
  mode_non_interactif $1
fi



if [[ $checkinstall == true ]]; then
	echo -e "Installation Terminier avec succes"
	if [[ $choix == "zabbix" ]]; then
		echo -e "Merci de reboot la machine prendre effet"
	elif [[ $choix == "agent" ]]; then
		echo -e "Information sur l'agent snmp :
				code oid = $code_oid"
  fi
fi
