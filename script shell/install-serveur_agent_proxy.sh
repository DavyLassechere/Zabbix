#!/bin/bash

#Auteur : Lassechere:Davy

#################################################
#          information | Documentation
# Le script permet d'installer automatique :
# Zabbix : Agent ; Proxy ; Serveur
# Deyx Types d'intéractions :
# En Mode Fond de Tâche et Intéraction en live
#
#Composition du script :
# 3 fonctions : les trois types d'installation :
# Agent , Proxy , serveur
# Le coeur : Configuration requis avant installation :
# Ouverture port zabbix , nettoyage de reste Zabbix
# check install
# L'entête est composé :
# Des Variables par defaut , D'une détection de l'os
#################################################

#Setup

#Mes Fonctions :

#L'agent
action_1 () {
  checkinstall=false
  echo -e "Insystallation d'un Agent"
  $prefix install zabbix-agent -y && systemctl enable zabbix-agent && systemctl start zabbix-agent
  sed -i "s/Server=127.0.0.1/Server=$IpSrv/g" /etc/zabbix/zabbix_agentd.conf
  sed -i "s/ServerActive=127.0.0.1/ServerActive=$IpSrv/g" /etc/zabbix/zabbix_agentd.conf
  sed -i "s/Hostname=Zabbix server/Hostname=$Hostname/g" /etc/zabbix/zabbix_agentd.conf

  checkinstall=true
  clear
}

#Le zabbix-proxy
action_2 () {
  checkaction2=true
  checkinstall=false
  action_1
  echo -e "Installation d'un Proxy"
  $prefix install zabbix-proxy-mysql mariadb-server -y && systemctl enable zabbix-proxy mariadb && systemctl start zabbix-proxy mariadb
  #création et import database
  echo "Importation de la data base en cours ..."
  echo -e "create database $DBNameP character set utf8 collate utf8_bin;
grant all privileges on $DBNameP.* to $DBUser@localhost identified by '$DBPassword';
flush privileges;
" | mysql -uroot -ppassword
  zcat /usr/share/doc/zabbix-proxy-mysql-3.4.X/schema.sql.gz | mysql -u$DBUser zabbix -p$DBPassword
  sed -i "s/Server=127.0.0.1/Server=$SrvZabbix/g" /etc/zabbix/zabbix_proxy.conf
  sed -i "s/DBName=zabbix/DBName=$DBNameP/g" /etc/zabbix/zabbix_proxy.conf
  sed -i "s/DBUSer=/DBUser=$DBUser/g" /etc/zabbix/zabbix_proxy.conf
  sed -i "s/# DBPassword=/DBPassword/g" /etc/zabbix/zabbix_proxy.conf
  sed -i "s/Server=127.0.0.1/Server=$SrvZabbix/g" /etc/zabbix/zabbix_proxy.conf
  sed -i "s/Hostname=Zabbix server/Hostname=$Hostname/g" /etc/zabbix/zabbix_proxy.conf
  checkinstall=true
}

#Le Zabbix-Serveur
action_3 () {
  checkaction3=true
  checkinstall=false
  action_1
  echo -e "installation d'un Server"
  $prefix install zabbix-server-mysql zabbix-web-mysql zabbix-agent zabbix-get zabbix-sender php mariadb-server mariadb zabbix-java-gateway -y && systemctl enable zabbix-server zabbix-agent httpd mariadb && systemctl start zabbix-server zabbix-agent httpd mariadb
  #Database création et import
  clear
  DBPassword="password"
  echo "Importation de la data base en cours ..."
  echo -e "create database $DBNameS character set utf8 collate utf8_bin;
grant all privileges on $DBNameS.* to $DBUser@localhost identified by '$DBPassword';
flush privileges; " | mysql -u root -ppassword
  zcat /usr/share/doc/zabbix-server-mysql*/create.sql.gz | mysql -u$DBUser zabbix -p$DBPassword
  sed -i "s/DBName=zabbix/DBName=$DBNameS/g" /etc/zabbix/zabbix_server.conf
  sed -i "s/DBUSer=/DBUser=$DBUser/g" /etc/zabbix/zabbix_server.conf
  sed -i "s/# DBPassword=/DBPassword=$DBPassword/g" /etc/zabbix/zabbix_server.conf
  # Désactivation SELINUX
  #Firewall add 80 et 443
  firewall-cmd --zone=public --add-port=80/tcp --permanent
  firewall-cmd --zone=public --add-port=443/tcp --permanent
  firewall-cmd --reload
  sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
  # Configuration PHP
  sed -i 's/^max_execution_time.*/max_execution_time=600/' /etc/php.ini
  sed -i 's/^max_input_time.*/max_input_time=600/' /etc/php.ini
  sed -i 's/^memory_limit.*/memory_limit=256M/' /etc/php.ini
  sed -i 's/^post_max_size.*/post_max_size=32M/' /etc/php.ini
  sed -i 's/^upload_max_filesize.*/upload_max_filesize=16M/' /etc/php.ini
  sed -i "s/^\;date.timezone.*/date.timezone=\'Europe\/Paris\'/" /etc/php.ini
  systemctl restart zabbix-server zabbix-agent httpd
  checkinstall=true
}


le_coeur () {

#Ouverture Ports

firewall-cmd --permanent --add-port=10050/tcp && firewall-cmd --permanent --add-port=10051/tcp
firewall-cmd --reload
clear
#Ajout des dépôts && Maj des paquets

if [[ -e /etc/zabbix ]] ; then
  $prefix update -y && $prefix upgrade -y
  $prefix remove zabbix* -y
  rm -rf /etc/zabbix/*
  if [[ ! -f /etc/zabbix_server.conf ]]; then
    echo -e "drop database zabbix;" | mysql -uroot -ppassword
  fi
fi
clear

if [[ $prefix == "yum" ]] ; then
    rpm -Uvh http://repo.zabbix.com/zabbix/3.4/rhel/7/x86_64/zabbix-release-3.4-2.el7.noarch.rpm
fi
clear

checkinstall=false

if [[ $choix == "Agent" ]]; then
  action_1
elif [[ $choix == "Proxy" ]]; then
  action_2
elif [[ $choix == "Serveur" ]]; then
  action_3
fi
clear

#Check l'install
if [[ $checkinstall == true ]]; then
  echo -e "installation Réussie ! \n Les informations contenant la config de l'intalle sont dans : \n /tmp/Zabbix.Install.log"
  sort=100
  if [[ $checkaction3 == true ]]; then
    echo -e "Information Base de donnée : \n Nom : $DBNameS \n Utilisateur : $DBUser \n Mort de passe : $DBPassword \n Vous pouvez vous connectez sur : \n http://$IpSrv/zabbix/"
  elif [[ $checkaction2 == true ]]; then
    echo -e "Information Base de donnée : \n Nom : $DBNameS \n Utilisateur : $DBUser \n Mort de passe : $DBPassword \n "
  fi
else
  read -p "$Error2 \n Voulez voulez vous recommencez la procédure ? [O/n]" restart
  if [[ $restart == "O" ]]; then
    sort=55
  fi
fi

}

#Entrée en mode interactive >>>>>>>>>>>>>>>>>

mode_interactive () {
    read -p "Zabbix Install Choisir Votre Type D'installation : [Agent|Proxy|Serveur] :" choix
    read -p "L'ip du serveur Zabbix |Ex : [192.168.1.254] : " IpSrv
      while [[ $choix == "" ]]; do
        read -p "Zabbix Install Choisir Votre Type D'installation : [Agent|Proxy|Serveur] :" choix
        read -p "L'ip du serveur Zabbix |Ex : [192.168.1.254] : " IpSrv
      done
    le_coeur
}

 #Sortie du mode intéractive <<<<<<<<<<<<<<<<<<


mode_non_interactive () {
  echo "En mode Non intéractive"
  case $1 in
    Agent)
      choix=$1
      if [[ ! -z "$2" ]]; then
        IpSrv=$2
        if [[ ! -z "$3" ]]; then
          DBPassword=$3
        fi
      fi
      echo "Agent"
      le_coeur
      ;;
    Serveur)
      choix=$1
      if [[ ! -z "$2" ]]; then
        IpSrv=$2
        if [[ ! -z "$3" ]]; then
          DBPassword=$3
        fi
      fi
      le_coeur
      echo "Serveur"
      ;;
    Proxy)
      choix=$1
      if [[ ! -z "$2" ]]; then
        IpSrv=$2
        if [[ ! -z "$3" ]]; then
          DBPassword=$3
        fi
      fi
      le_coeur
      ;;
    help)
      echo -e $Manuel
      ;;
    *)
      echo -e "$Error4 \n $Help1"
      exit
  esac

}

###### Fin des Fonctions


#Error Gestion :

Error1="Réponse Invalide !"
Error2="Echec à la configuration !"
Error3="Commande Invalide !"
Error4="Argument Invalide !"

#Help Commande :

Manuel="$Help1 \n $Help2 \n Help : \n
          information | Documentation
# Le script permet d'installer automatique :
# Zabbix : Agent ; Proxy ; Serveur
# Deyx Types d'intéractions :
# En Mode Fond de Tâche et Intéraction en live
#
#Composition du script :
# 3 fonctions : les trois types d'installation :
# Agent , Proxy , serveur
# Le coeur : Configuration requis avant installation :
# Ouverture port zabbix , nettoyage de reste Zabbix
# check install
# L'entête est composé :
# Des Variables par defaut , D'une détection de l'os
\n \n \n
----------------------------------- \n
Exemple1 commande : .\Zabbix-Script.sh Agent <IpServeur>\n
Exemple2 Commande : .\Zabbix-Script.sh Proxy <IpServeur> <DataBase-Password>\n
Exemple3 Commande : .\Zabbix-Script.sh Serveur <IpServeur> <DataBase-Password>\n
----------------------------------- \n "

Help1="Argument1 : Default : Agent, Type d'installation : Agent, Serveur, Proxy"
Help2="Argument2 : !Obligatoire! Ip de votre serveur Zabbix {127.0.0.1|...|192.168.1.254}"
Help3="Argument2 : Defaut : Password,Mot de passe pour votre Base de donnée Zabbix"

####### Fin Help

#Variables pas défaut :

Hostname=$(hostname)
IpHost=$(ip a | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1')
IpSrv=$(ip a | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1')
Prefix="Vide"
DBNameP="zabbix"
DBNameS="zabbix"
DBUser="zabbix"
DBPassword="password"
int='^[0-9]+$'
sort=0

######### FIn Variables

#Détecter OS
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


#Début du script >>>>>>>>>>>>>>>>>>>>

if [[ -z "$1" ]]; then
  mode_interactive
else
  mode_non_interactive $1 $2 $3

fi

#Sortie du script >>>>>>>>>>>>>>>>>>>>
