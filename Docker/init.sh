#!/usr/bin/env bash

set -x

##Functions

mysql_sql() {
  if [ "localhost" == "${MYSQL_JEEDOM_HOST}" ]; then
    echo "$@" | mysql -uroot -P${MYSQL_JEEDOM_PORT}
  else
    echo "$@" | mysql -u${MYSQL_JEEDOM_USERNAME} -p${MYSQL_JEEDOM_PASSWD} -h ${MYSQL_JEEDOM_HOST} -P${MYSQL_JEEDOM_PORT}
  fi
  if [ $? -ne 0 ]; then
    echo "C${ROUGE}Ne peut exécuter $@ dans MySQL - Annulation${NORMAL}"
    #exit 1
  fi
}

#not need when in mysql is in another container ( db, user are created then env values)
step_8_mysql_create_db() {
  echo "---------------------------------------------------------------------"
  echo "${JAUNE}commence l'étape 8 configuration de mysql ${NORMAL}"
  #mysql_sql "DROP USER '${MYSQL_JEEDOM_USERNAME}'@'%';"
  #mysql_sql "CREATE USER '${MYSQL_JEEDOM_USERNAME}'@'%' IDENTIFIED BY '${MYSQL_JEEDOM_PASSWD}';"
  #mysql_sql "DROP DATABASE IF EXISTS ${MYSQL_JEEDOM_DBNAME};"
  #mysql_sql "CREATE DATABASE ${MYSQL_JEEDOM_DBNAME};"
  mysql_sql "GRANT ALL PRIVILEGES ON ${MYSQL_JEEDOM_DBNAME}.* TO '${MYSQL_JEEDOM_USERNAME}'@'%';"
}

step_8_jeedom_configuration() {
  echo "---------------------------------------------------------------------"
  cp ${WEBSERVER_HOME}/core/config/common.config.sample.php ${WEBSERVER_HOME}/core/config/common.config.php
  sed -i "s/#PASSWORD#/${MYSQL_JEEDOM_PASSWD}/g" ${WEBSERVER_HOME}/core/config/common.config.php
  sed -i "s/#DBNAME#/${MYSQL_JEEDOM_DBNAME}/g" ${WEBSERVER_HOME}/core/config/common.config.php
  sed -i "s/#USERNAME#/${MYSQL_JEEDOM_USERNAME}/g" ${WEBSERVER_HOME}/core/config/common.config.php
  sed -i "s/#PORT#/${MYSQL_JEEDOM_PORT}/g" ${WEBSERVER_HOME}/core/config/common.config.php
  sed -i "s/#HOST#/${MYSQL_JEEDOM_HOST}/g" ${WEBSERVER_HOME}/core/config/common.config.php
  chmod 775 -R ${WEBSERVER_HOME}
  chown -R www-data:www-data ${WEBSERVER_HOME}
  echo "${VERT}étape 8 configuration de jeedom réussie${NORMAL}"
}

### Main
echo 'Start init'

if ! [ -f /.dockerinit ]; then
  touch /.dockerinit
  chmod 755 /.dockerinit
fi

if [ -z ${ROOT_PASSWORD} ]; then
  ROOT_PASSWORD=$(cat /dev/urandom | tr -cd 'a-f0-9' | head -c 20)
  echo "Use generate password : ${ROOT_PASSWORD}"
fi

echo "root:${ROOT_PASSWORD}" | chpasswd

echo "Listen 80" >/etc/apache2/ports.conf
echo "Listen 443" >>/etc/apache2/ports.conf
sed -i -E "s/\<VirtualHost \*:(.*)\>/VirtualHost \*:80/" /etc/apache2/sites-available/000-default.conf
a2enmod ssl
sed -i -E "s/\<VirtualHost \*:(.*)\>/VirtualHost \*:${APACHE_HTTPS_PORT}/" /etc/apache2/sites-available/default-ssl.conf
a2ensite default-ssl

if [ -f /var/www/html/core/config/common.config.php ]; then
  echo 'Jeedom is already install'
else
  #generate db param
  WEBSERVER_HOME=/var/www/html
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
  #step_8_mysql_create_db
  step_8_jeedom_configuration
  while true; do
    mysql -u${MYSQL_JEEDOM_USERNAME} -p${MYSQL_JEEDOM_PASSWD} -h ${MYSQL_JEEDOM_HOST} -P${MYSQL_JEEDOM_PORT} ${MYSQL_JEEDOM_DBNAME} < ${WEBSERVER_HOME}/install/install.sql
    [[ $? -eq 0 ]] && break
    sleep 5
  done
  #tempo
  if [[ "release" == "$VERSION" ]]; then
    #S9 =  install.php done when running docker.
    bash -x /root/install_docker.sh -s 9
    #s10 = post install (cron ) /s11 for v4
    /root/install_docker.sh -s 10
    #s11 = jeedom check
    /root/install_docker.sh -s 11
  else
    #s10 jeedom_installation
    /root/install_docker.sh -s 10
    #s10 = post install (cron ) /s11 for v4
    /root/install_docker.sh -s 11
    #s12 = jeedom_check
    /root/install_docker.sh -s 12
  fi
fi

echo 'All init complete'
chmod 777 /dev/tty*
#chmod 777 -R /tmp
#chmod 755 -R /var/www/html
#chown -R www-data:www-data /var/www/html
#needed when using tempfs
mkdir -p /var/log/supervisor/ -p /run/lock/ -p /var/log/apache2/

echo "by default send apache logs to stdout/err"
if [[ ! -e /var/log/apache2/access.log ]]; then
  mkdir -p /var/log/apache2/
  ln -sf /proc/self/fd/1 /var/log/apache2/access.log
fi
if [[ ! -e /var/log/apache2/error.log ]]; then
  mkdir -p /var/log/apache2/
  ln -sf /proc/self/fd/1 /var/log/apache2/error.log
fi

supervisorctl start apache2
