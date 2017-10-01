#!/bin/bash

###########################
## Actualización paquetes
apt-get update && apt-get -y upgrade 

###########################
## Especificando el hostname
hostnamectl set-hostname server.lab.lan
sed -i '1,2s/1\t.*/1\t server.lab.lan server/' /etc/hosts

###########################
## Cambio de shell
echo "dash  dash/sh boolean no" | debconf-set-selections
dpkg-reconfigure -f noninteractive dash

###########################
## Cambio de la zona horaria
echo "Europe/Madrid" > /etc/timezone
rm /etc/localtime
dpkg-reconfigure -f noninteractive tzdata

###########################
## Deshabilitando APParmor
systemctl stop apparmor && systemctl disable apparmor

###########################
## Configuración de DNS
apt-get install -y bind9 dnsutils haveged

###########################
## Configuración de LETSCRIPT
apt-get install -y letsencrypt

###########################
## Configuración de MARIADB
apt-get install -y mariadb-client mariadb-server 
systemctl start mysql
mysql_secure_installation <<EOF

Y
P@ssw0rd!
P@ssw0rd!
Y
Y
Y
Y
EOF

sed -i 's/bind-add/#bind-addr/' /etc/mysql/mariadb.conf.d/50-server.cnf
systemctl restart mysql

###########################
## Configuración de APACHE
apt-get install -y apache2 apache2-doc apache2-utils libapache2-mod-php php7.0 
   \php7.0-common php7.0-gd php7.0-mysql php7.0-imap php7.0-cli php7.0-cgi libapache2-mod-fcgid 
   \apache2-suexec-pristine php-pear php-auth php7.0-mcrypt mcrypt imagemagick libruby 
   \libapache2-mod-python php7.0-curl php7.0-intl php7.0-pspell php7.0-recode 
   \php7.0-sqlite3 php7.0-tidy php7.0-xmlrpc php7.0-xsl php7.0-opcache php-apcu 
   \libapache2-mod-fastcgi php7.0-fpm <<EOF
apache
yes

EOF

a2enmod suexec rewrite ssl actions include cgi fastcgi alias
cat <<EOF > /etc/apache2/conf-available/httproxy.conf
   <IfModule mod_headers.c>
          RequestHeader unset Proxy early
   </IfModule>
EOF

a2enconf httproxy
systemctl restart apache2

###########################
## Configuración de PURE-FTPD
apt-get install -y pure-ftpd-common pure-ftpd-mysql openssl
sed -i 's/=false/=true/' /etc/default/pure-ftpd-common
echo '1' > /etc/pure-ftpd/conf/TLS

openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/pure-ftpd.pem \
   -out /etc/ssl/private/pure-ftpd.pem \
   -subj "/C=ES/ST=Spain/L=Zaragoza/O=LAB/OU=IT depto/CN=lab.lan/emailAddress=soporte@lab.lan"

mod 600 /etc/ssl/private/pure-ftpd.pem
systemctl restart pure-ftpd-mysql

###########################
## Configuración de CORREO
echo "postfix postfix/mailname string server.lab.lan" | debconf-set-selections
echo "postfix postfix/main_mailer_type select 'Internet Site'" | debconf-set-selections
apt-get install -y postfix postfix-mysql postfix-doc getmail4 binutils 
   \dovecot-imapd dovecot-pop3d dovecot-mysql dovecot-sieve dovecot-lmtpd sudo

sed -i '17,20s/^#//; 22s/#//; 22s/=.*/=permit_sasl_authenticated,reject/' /etc/postfix/master.cf
sed -i '28,31s/^#//; 33s/#//; 33s/=.*/=permit_sasl_authenticated,reject/' /etc/postfix/master.cf

systemctl restart postfix


###########################
## Configuración de MILTER
apt-get install -y amavisd-new spamassassin clamav clamav-daemon zoo unzip bzip2 arj nomarch lzop 
   \cabextract apt-listchanges libnet-ldap-perl libauthen-sasl-perl clamav-docs daemon libio-string-perl 
   \libio-socket-ssl-perl libnet-ident-perl zip libnet-dns-perl postgrey -y

sed -i 's/Groups false/Groups true/' /etc/clamav/clamd.conf

systemctl start clamav-daemon
systemctl restart amavid-new
systemctl disable spamassassin

###########################
## Configuración de MAILMAN
export DEBIAN_FRONTEND="noninteractive"
echo "mailman mailman/site_languages multiselect es" | debconf-set-selections
echo "mailman mailman/default_server_language select en" | debconf-set-selections
apt-get -y install mailman

newlist -a mailman support@lab.lan P@ssw0rd.
newaliases

systemctl restart postfix
ln -s /etc/mailman/apache.conf /etc/apache2/conf-available/mailman.conf
a2enconf mailman.conf
systemctl restart apache2
systemctl start mailman
unset DEBIAN_FRONTEND

###########################
## Configuración de WEBMAIL
echo "roundcube-core roundcube/mysql/app-pass password P@ssw0rd." | debconf-set-selections
echo "roundcube-core roundcube/app-password-confirm password P@ssw0rd." | debconf-set-selections
echo "roundcube-core	roundcube/reconfigure-webserver	multiselect apache2" | debconf-set-selections
echo "roundcube-core	roundcube/dbconfig-install boolean true" | debconf-set-selections

apt-get install -y roundcube roundcube-core roundcube-mysql roundcube-plugins roundcube-plugins-extra javascript-common libjs-jquery-mousewheel php-net-sieve tinymce wget

sed -i 's/#.*Alias/\t Alias/' /etc/apache2/conf-enabled/roundcube.conf
sed -i "35s/''/'localhost'/" /etc/roundcube/config.inc.php
systemctl restart apache2

###########################
## Configuración de PHPMYADMIN

echo "phpmyadmin	phpmyadmin/mysql/app-pass password P@ssw0rd." | debconf-set-selections
echo "phpmyadmin	phpmyadmin/app-password-confirm	password P@ssw0rd." | debconf-set-selections
echo "phpmyadmin	phpmyadmin/dbconfig-install	boolean	true" | debconf-set-selections
echo "phpmyadmin	phpmyadmin/reconfigure-webserver	multiselect	apache2" | debconf-set-selections

apt-get install -y phpmyadmin

###########################
## Configuración de ISPConfig
wget -qO- ispconfig.tar.gz https://git.ispconfig.org/ispconfig/ispconfig3/repository/archive.tar.gz?ref=stable-3.1 | tar -xz -C /opt

php -q /opt/ispconfig3*/install/install.php <<EOF
en
standard
server.lab.lan
localhost
3306
root
P@ssword
dbispconfig
utf8
ES
Spain
Zaragoza
LAB
IT depto
server.lab.lan
soporte@lab.lan
8080
admin
y
ES
Spain
Zaragoza
LAB
IT depto
server.lab.lan
soporte@lab.lan


EOF
