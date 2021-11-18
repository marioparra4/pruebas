#!/bin/bash

function apache(){
        #Variable que guarda la ruta donde esta instalado apache2
        DIRECTORIO=$(which apache2)
        if [[ -d "/etc/apache2" && $DIRECTORIO = "/usr/sbin/apache2" ]];then
                echo "Apache ya se encuentra instalado en el servidor"
        else
                apt install apache2 apache2-utils
                systemctl start apache2
                systemctl enable apache2
        fi
}

function phpC(){
        #Variable que guarda la ruta donde esta instalado php
        DIRECTORIO2=$(which php)
        if [[ -d "/etc/php" && $DIRECTORIO2 = "/usr/bin/php" ]];then
                echo "PHP ya esta instalado en el servidor"
        else
                apt install -y php libapache2-mod-php php-cli php-fpm php-json php-pdo php-mysql php-zip php-gd  php-mbstring php-curl php-xml php-pear php-bcmath
        fi
}

function mariadb(){

        #Variable que guarda donde esta instalado mysql
        DIRECTORIO3=$(which mysql)
        if [[ -d "/etc/mysql" && $DIRECTORIO3 = "/usr/bin/mysql" ]];then
                echo "Mysql ya se encuentra instalado en el servidor"
        else
                apt install -y mariadb-server
                mysql_secure_installation
        fi
}

function seguridad(){
        sed -i 's/ServerSignature On/ServerSignature Off/' /etc/apache2/conf-available/security.conf
        sed -i 's/ServerTokens OS/ServerTokens Prod/' /etc/apache2/conf-available/security.conf
}

function gitI(){
	GITV=$(which git)
	if [ $GITV = "/usr/bin/git" ];then
		echo "Ya tienes instalado git"
	else
		apt install -y git
	fi
}


function moodle(){
	echo "Iniciando instalacion moodle..."

	cd /var/www/html
	
	#Verificar si ya se bajo el repositorio antes
	if [ -d "/var/www/html/moodle" ];then
		echo "Ya esta instalado el repositorio de moodle"
	else
		git clone -b MOODLE_310_STABLE git://git.moodle.org/moodle.git
	
	fi

	chown -R www-data:www-data /var/www/html/moodle
	
	#Verificar  si ya se tiene la carpeta para los datos
	if [ -d "/var/www/moodledata" ];then
		echo "Ya esta creada la carpeta para los datos"
	else
		mkdir /var/www/moodledata 
	fi

	chown -R www-data:www-data /var/www/moodledata
	
	cd

	#Instalacion de dependencias php que falten en caso de tenerla no pasa nada
	apt install -y php-mysql php-curl php-gd php-intl php-mbstring php-soap php-xml php-xmlrpc php-zip
	sleep 2	

	#Modificar php.ini
	RUTA=$(find /etc -name php.ini | grep apache2)
	sed -i 's/;max_input_vars = 1000/max_input_vars = 5000/' $RUTA	
	sed -i 's/post_max_size = 8M/post_max_size = 80M/' $RUTA		
	sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 80M/' $RUTA
	sed -i "s/;date.timezone =/date.timezone = 'America\/Mexico_City'/" $RUTA


	if [ -f "/var/www/html/moodle/config.php" ];then
		echo "mooodle ya esta instalado"
	else 
		#Crear bd
                echo "Ingresa la contraseña de mysql: "
                read -s password
                CLAVE=$(< /dev/urandom tr -dc A-Za-z0-9*$\@.,_- | head -c16; echo)
                mysql -u root -p"$password" -e"create database moodle charset utf8mb4 collate utf8mb4_unicode_ci;"
                mysql -u root -p"$password" -e"create user moodle@localhost identified by '$CLAVE';"
                mysql -u root -p"$password" -e"grant all privileges on moodle.* to moodle@localhost;"
                echo "Nombre de la base de datos: moodle"
                echo "Nombre de usuario para la base de datos: moodle"
                echo "Password del usuario: $CLAVE"
                sleep 4
                systemctl reload apache2
                systemctl restart apache2
                #Decidir si instalar en web o terminal
                echo "Para instalar por navegador ingrese W y para instalar por terminar ingrese T"
                read decision
                if [ $decision = "W" ] || [ $decision = "w" ];then
                        echo "Ingresar a la siguiente direccion en tu navegador para terminar la instalacion: $IP/moodle"
                        echo "******** Gracias por usar el script de instalacion *******"
                else
                        if [ $decision = "T" ] || [ $decision = "t" ];then
                                echo "Instalando mediante terminal..."
                                sleep 2
				IP=$(hostname -I | awk -F " " '{print $1}')
				URL="http://$IP/moodle"
				PASSWORD=$(date +%s | sha256sum| base64 | head -c16;echo)
				echo -n "Ingrese el correo para moodle: "
				read correo
                                php /var/www/html/moodle/admin/cli/install.php --chmod=0777 --lang=es_mx --wwwroot=$URL --dataroot=/var/www/moodledata --dbtype=mariadb --dbhost=localhost --dbname=moodle --dbuser=moodle --dbpass=$CLAVE --dbport= --dbsocket= --prefix=mdl_ --fullname=pruebamoodle --shortname=prueba --adminuser=admin --adminpass=$PASSWORD --adminemail=$correo --agree-license=s --non-interactive
                                chown -R www-data /var/www/html/moodle
                                chown -R www-data /var/www/moodledata
				echo "Usuario de moodle: admin"
				echo "Password de moodle: $PASSWORD"
                                echo "Su cuenta fue creada automaticamente, si desea hacer cambios vaya configuracion en moodle"
				echo "Entre al navegador a la siguiente direccion: $IP/moodle"
				echo "******** Gracias por usar el script de instalacion *******"
                        else
                                echo "Error intente ejecutar el script de nuevo y elija una opcion valida"
                                echo "******** Gracias por usar el script de instalacion *******"
                        fi
                fi
	fi
}

IP=$(hostname -I | awk -F " " '{print $1}')
SD=$(hostnamectl | grep Debian | awk -F " " '{print $3}')
USR=$(whoami | awk -F " " '{print $1}')
echo "############SCRIPT DE INSTALACION DE MOODLE###########"
echo "ADVERTENCIA: Este script esta desarrollado para Distribuciones basadas en Debian y para ejecutarlo como root"
if [[ $USR = "root" && $SD = "Debian" ]];then
	echo "Verificando pila LAMP ..."
	echo "################## Iniciando instalacion LAMP #######################"
	apt update
	apt upgrade -y
	sleep 4
	echo "++++++++++ Instalacion apache2 ++++++++++"
	apache
	sleep 4
	echo "++++++++++ Instalacion mariadb ++++++++++"
	mariadb
	sleep 4
	echo "++++++++++ Instalacion php ++++++++++"
	phpC
	sleep 4
	seguridad
	systemctl reload apache2
	systemctl restart apache2
	echo "********************** Instalacion de LAMP lista **************************"
	echo "##############Iniciando instalacion Moodle#############"
	gitI
	sleep 2
	moodle
else
	echo "Verifica tu SO y tu usuario"
	echo "******** Gracias por usar el script de instalacion *******"	
fi
