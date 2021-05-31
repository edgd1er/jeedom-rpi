#!/usr/bin/env bash

set -e

#Variables
VERT="\\033[1;32m"
NORMAL="\\033[0;39m"
LOGS_TO_STDOUT=${LOGS_TO_STDOUT:-"n"}
SETX=""
XDEBUG=${XDEBUG:-0}

##Functions
setTimeZone() {
  [[ ${TZ} == $(cat /etc/timezone) ]] && return
  echo "Setting timezone to ${TZ}"
  ln -fs /usr/share/zoneinfo/${TZ} /etc/localtime
  dpkg-reconfigure -fnoninteractive tzdata
}

mysql_sql() {
  if [ "localhost" == "${MYSQL_JEEDOM_HOST}" ]; then
    echo "$@" | mysql -uroot -P${MYSQL_JEEDOM_PORT}
  else
    echo "$@" | mysql -u${MYSQL_JEEDOM_USERNAME} -p${MYSQL_JEEDOM_PASSWD} -h ${MYSQL_JEEDOM_HOST} -P${MYSQL_JEEDOM_PORT}
  fi
  if [ $? -ne 0 ]; then
    echo "${ROUGE}Ne peut exécuter $* dans MySQL - Annulation${NORMAL}"
    #exit 1
  fi
}

#not need when in mysql is in another container ( db, user are created then env values)
step_8_mysql_create_db() {
  echo "---------------------------------------------------------------------"
  echo "${JAUNE}commence l'étape 8 configuration de mysql ${NORMAL}"
  isDB=$(mysql -uroot -p${MYSQL_ROOT_PASSWD} -h ${MYSQL_JEEDOM_HOST} -P${MYSQL_JEEDOM_PORT} -BNe "show databases;" | grep -c ${MYSQL_JEEDOM_DBNAME})
  [[ 0 -eq ${isDB} ]] && mysql -uroot -p${MYSQL_ROOT_PASSWD} -h ${MYSQL_JEEDOM_HOST} -P${MYSQL_JEEDOM_PORT} -e "CREATE DATABASE ${MYSQL_JEEDOM_DBNAME};"
  isUser=$(mysql -uroot -p${MYSQL_ROOT_PASSWD} -h ${MYSQL_JEEDOM_HOST} -P${MYSQL_JEEDOM_PORT} -BNe "select user from mysql.user where user='jeedom';" | wc -l)
  [[ 0 -eq ${isUser} ]] && mysql_sql "CREATE USER '${MYSQL_JEEDOM_USERNAME}'@'%' IDENTIFIED BY '${MYSQL_JEEDOM_PASSWD}';"
  mysql -uroot -p${MYSQL_ROOT_PASSWD} -h ${MYSQL_JEEDOM_HOST} -P${MYSQL_JEEDOM_PORT} -e "GRANT ALL PRIVILEGES ON ${MYSQL_JEEDOM_DBNAME}.* TO '${MYSQL_JEEDOM_USERNAME}'@'%';"
}

step_8_jeedom_configuration() {
  echo "${VERT}Etape 8: informations de login pour la BDD${NORMAL}"
  cp ${WEBSERVER_HOME}/core/config/common.config.sample.php ${WEBSERVER_HOME}/core/config/common.config.php
  sed -i "s/#PASSWORD#/${MYSQL_JEEDOM_PASSWD}/g" ${WEBSERVER_HOME}/core/config/common.config.php
  sed -i "s/#DBNAME#/${MYSQL_JEEDOM_DBNAME}/g" ${WEBSERVER_HOME}/core/config/common.config.php
  sed -i "s/#USERNAME#/${MYSQL_JEEDOM_USERNAME}/g" ${WEBSERVER_HOME}/core/config/common.config.php
  sed -i "s/#PORT#/${MYSQL_JEEDOM_PORT}/g" ${WEBSERVER_HOME}/core/config/common.config.php
  sed -i "s/#HOST#/${MYSQL_JEEDOM_HOST}/g" ${WEBSERVER_HOME}/core/config/common.config.php

  echo "${VERT}Etape 8: Configuration des sites Web sur Apache${NORMAL}"
  cp ${WEBSERVER_HOME}/install/apache_security /etc/apache2/conf-available/security.conf
  sed -i -e "s%WEBSERVER_HOME%${WEBSERVER_HOME}%g" /etc/apache2/conf-available/security.conf

  rm /etc/apache2/conf-enabled/security.conf >/dev/null 2>&1
  ln -s /etc/apache2/conf-available/security.conf /etc/apache2/conf-enabled/

  cp ${WEBSERVER_HOME}/install/apache_default /etc/apache2/sites-available/000-default.conf
  sed -i -e "s%WEBSERVER_HOME%${WEBSERVER_HOME}%g" /etc/apache2/sites-available/000-default.conf
  rm /etc/apache2/sites-enabled/000-default.conf >/dev/null 2>&1
  ln -s /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-enabled/

  [[ -f /etc/apache2/conf-available/other-vhosts-access-log.conf ]] && rm /etc/apache2/conf-available/other-vhosts-access-log.conf >/dev/null 2>&1
  [[ -f /etc/apache2/conf-enabled/other-vhosts-access-log.conf ]] && rm /etc/apache2/conf-enabled/other-vhosts-access-log.conf >/dev/null 2>&1

  chmod 775 -R ${WEBSERVER_HOME}
  chown -R www-data:www-data ${WEBSERVER_HOME}
  echo "${VERT}étape 8 configuration de jeedom réussie${NORMAL}"
}

checkCerts(){
  ret=0
  [[ $(echo | openssl s_client -servername market.jeedom.com -connect market.jeedom.com:443 2>&1) =~ Verify\ return\ code:\ ([0-9]{1,2}) ]] && ret=${BASH_REMATCH[1]}
  [[ 0 -ne ${ret} ]] && echo "Refresh ca certs" && update-ca-certificates --fresh || echo "ca certs are up to date"
}

### Main
# execute all install scripts with -x
if [[ 1 -eq ${DEBUG} ]]; then
  set -x
  sed -i "s#bin/sh#bin/sh -x#" /root/install_docker.sh
fi

if ! [ -f /.dockerinit ]; then
  touch /.dockerinit
  chmod 755 /.dockerinit
fi

# check if env jeedom encryption key is defined
if [[ -n ${JEEDOM_ENC_KEY} ]]; then
  #write jeedom encryption key if different
  if [[ "$(cat /var/www/html/data/jeedom_encryption.key)" != "${JEEDOM_ENC_KEY}" ]]; then
    echo "Writing jeedom encryption key as defined in env"
    echo "${JEEDOM_ENC_KEY}" >/var/www/html/data/jeedom_encryption.key
    #echo "update user set password='admin' where login='admin'" | mysql -u${MYSQL_JEEDOM_USERNAME} -p${MYSQL_JEEDOM_PASSWD} -h ${MYSQL_JEEDOM_HOST} -P${MYSQL_JEEDOM_PORT} -D${MYSQL_JEEDOM_DBNAME}
  fi
fi

#set root password
if [ -z ${ROOT_PASSWORD} ]; then
  ROOT_PASSWORD=$(tr -cd 'a-f0-9' </dev/urandom | head -c 20)
  echo "Use generate password : ${ROOT_PASSWORD}"
fi
echo "root:${ROOT_PASSWORD}" | chpasswd

echo "Listen 80" >/etc/apache2/ports.conf
echo "Listen 443" >>/etc/apache2/ports.conf
sed -i -E "s/\<VirtualHost \*:(.*)\>/VirtualHost \*:80/" /etc/apache2/sites-available/000-default.conf
[[ $(a2query -m ssl | grep -c "^ssl") -eq 0 ]] && a2enmod ssl
sed -i -E "s/\<VirtualHost \*:(.*)\>/VirtualHost \*:${APACHE_HTTPS_PORT}/" /etc/apache2/sites-available/default-ssl.conf
[[ $(a2query -s default-ssl | grep -c "^default-ssl") -eq 0 ]] && a2ensite default-ssl
[[ $(a2query -s 000-default | grep -c "^000-default") -eq 0 ]] && a2ensite 000-default

if [ -f /var/www/html/core/config/common.config.php ]; then
  echo 'Jeedom is already installed'
else
  [[ ! -f /root/install_docker.sh ]] && echo -e "\n*************** ERROR, no /root/install_docker.sh file ***********\n" && exit
  #allow fail2ban to start even on docker
  touch /var/log/auth.log
  #generate db param
  WEBSERVER_HOME=/var/www/html
  #fix jeedom install.sh for unattended install
  sed -i "s#^MYSQL_JEEDOM_PASSWD=.*#MYSQL_JEEDOM_PASSWD=\$\(tr -cd \'a-f0-9\' \< /dev/urandom \| head -c 15\)#" /root/install_docker.sh
  #fix jeedom-core, allowing to define mysql not being local
  sed -i "s#mysql -uroot#mysql -uroot -p${MYSQL_ROOT_PASSWD} -h ${MYSQL_JEEDOM_HOST} -P${MYSQL_JEEDOM_PORT} ${MYSQL_JEEDOM_DBNAME}#" /root/install_docker.sh
  #S8 =  db param done when running docker.
  while true; do
    result=$(mysql_sql "show grants for 'jeedom'@'%';")
    if [[ $(echo ${result} | grep -c "GRANT ALL PRIV") -gt 0 ]]; then
      echo -e "result: ${result}"
      break
    fi
    sleep 5
  done
  #mysql is not local to jeedom container
  #set db creds
  step_8_jeedom_configuration
  #create database if needed
  step_8_mysql_create_db
  if [[ "release" == "$VERSION" ]]; then
    #V3
    echo "V3 is EOL (End of Life), V4.1 is the suggested version. V4.0 is legacy"
    #S9 =  install.php done when running docker.
    #broken /root/install_docker.sh -s 9
    #DBCLass is looking for language before having created the schema.
    isTables=$(mysql -uroot -p${MYSQL_ROOT_PASSWD} -h ${MYSQL_JEEDOM_HOST} -P${MYSQL_JEEDOM_PORT} ${MYSQL_JEEDOM_DBNAME} -e "show tables;" | wc -l)
    if [[ 0 -eq ${isTables} ]]; then
      echo "Mysql jeedom schema is created as no table were found, and install is bugged and check for languga in config table before creating the schema"
      mysql -uroot -p${MYSQL_ROOT_PASSWD} -h ${MYSQL_JEEDOM_HOST} -P${MYSQL_JEEDOM_PORT} ${MYSQL_JEEDOM_DBNAME} </var/www/html/install/install.sql
    fi
    #s10 = post install (cron ) /s11 for v4
    /root/install_docker.sh -s 10
    #s11 = jeedom check
    /root/install_docker.sh -s 11
    #reset admin password
    echo "${VERT}Admin password is now admin${NORMAL}"
    mysql_sql "use ${MYSQL_JEEDOM_DBNAME};REPLACE INTO user SET login='admin',password='c7ad44cbad762a5da0a452f9e854fdc1e0e7a52a38015f23f3eab1d80b931dd472634dfac71cd34ebc35d16ab7fb8a90c81f975113d6c7538dc69dd8de9077ec',profils='admin', enable='1';"
  else
    #V4-stable
    cp ${WEBSERVER_HOME}/install/fail2ban.jeedom.conf /etc/fail2ban/jail.d/jeedom.conf
    # create helper reset password
    sed "s/^\$username = .*/\$username = \"\$argv[1]\";/" /var/www/html/install/reset_password.php >/var/www/html/install/reset_password_admin.php
    sed -i "s/^\$password = .*/\$password = \"\$argv[2]\";/" /var/www/html/install/reset_password_admin.php
    #remove admin password save if already exists in db
    isTables=$(mysql -uroot -p${MYSQL_ROOT_PASSWD} -h ${MYSQL_JEEDOM_HOST} -P${MYSQL_JEEDOM_PORT} ${MYSQL_JEEDOM_DBNAME} -e "show tables;" | wc -l)
    if [[ ${isTables:-0} -gt 0 ]]; then
      echo "User admin already exists, removing its creation"
      sed -i '/\$user->save();/d' /var/www/html/install/install.php
    else
      echo "User admin does not exists, install will install it."
    fi
    #S9 drop jeedom database
    echo -e "Step 9 skipped: database drop/create"
    #s10 jeedom_installation
    /root/install_docker.sh -s 10
    #s10 = post install (cron ) /s11 for v4
    /root/install_docker.sh -s 11
    #s12 = jeedom_check
    /root/install_docker.sh -s 12
    #force reset when admin already exists
    [[ 1 -eq ${res} ]] && echo "Admin password, now, is admin" && php /var/www/html/install/reset_password_admin.php admin admin
    # update-ca-certificates --fresh
  fi
fi

echo 'All init complete'
setTimeZone
chmod 777 /dev/tty*
#chmod 777 -R /tmp
#chmod 755 -R /var/www/html
#chown -R www-data:www-data /var/www/html
#needed when using tempfs
mkdir -p /var/log/supervisor/ -p /run/lock/ -p /var/log/apache2/ -p /var/log/fail2ban -p /var/run/fail2ban

#enable xdebug
if [ ${XDEBUG:-0} = "1" ]; then
  apt-get update
  apt-get install -y php-xdebug openssh-server
  sed -i "s/#PermitRootLogin prohibit-password/PermitRootLogin yes/" /etc/ssh/sshd_config
  echo "<?php phpinfo() ?>" >/var/www/html/phpinfo.php
  echo "[xdebug]
xdebug.remote_eable=true
#xdebug.remote_connect_back=On
xdebug.remote_host=${XDEBUG_HOST:-"localhost"}
xdebug.remote_port=${XDEBUG_PORT:-9003}
xdebug.log=${XDEBUG_LOGFILE:-"/var/log/apache2/php_debug.log"}
xdebug.idekey=1" | tee -a $(find /etc -type f -iwholename *apache2/php.ini -print)
  echo -e "[program:sshd]\ncommand=/usr/sbin/sshd -D" >/etc/supervisor/conf.d/sshd.conf
  supervisorctl reread
  supervisorctl add sshd
  export XDEBUG_SESSION=1
fi

if [[ ${LOGS_TO_STDOUT,,} =~ y ]]; then
  echo "Send apache logs to stdout/err"
  [[ -f /var/log/apache2/access.log ]] && mv /var/log/apache2/{access,error}.log /var/log/apache2/access_.log && mv /var/log/apache2/error.log /var/log/apache2/error_.log
  ln -sf /proc/1/fd/1 /var/log/apache2/access.log
  ln -sf /proc/1/fd/1 /var/log/apache2/error.log
else
  [[ -L /var/log/apache2/access.log ]] && rm -f /var/log/apache2/{access,error}.log && echo "Remove apache symlink to stdout/stderr" || echo
fi

checkCerts

supervisorctl start apache2
#wait for logs file to be created
#cannot start fail2ban when logs are redirected
[[ ${LOGS_TO_STDOUT,,} =~ n ]] && supervisorctl start fail2ban || echo
