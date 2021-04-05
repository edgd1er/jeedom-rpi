#!/usr/bin/env bash

set -e

#Variables
LOGS_TO_STDOUT=${LOGS_TO_STDOUT:-"n"}

##Functions
setTimeZone(){
  [[ ${TZ} == $(cat /etc/timezone) ]] && return
  echo "Setting timezone to ${TZ}"
  ln -fs /usr/share/zoneinfo/${TZ} /etc/localtime
  dpkg-reconfigure -f non-interactive tzdata
}

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
if [[ 1 -eq ${DEBUG:-0} ]]; then
  set -x
  SETX="-x"
  supervisorctl start sshd
  else
    SETX=""
fi

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
#fix jeedom install.sh for unattended install
sed -i "s#^MYSQL_JEEDOM_PASSWD=\$.*#MYSQL_JEEDOM_PASSWD=\$\(tr -cd \'a-f0-9\' \< /dev/urandom \| head -c 15\)#" /root/install_docker.sh

if [ -f /var/www/html/core/config/common.config.php ]; then
  echo 'Jeedom is already installed'
else
  #generate db param
  WEBSERVER_HOME=/var/www/html
  #fix jeedom-core, allowing to define mysql not being local
  sed -i "s#mysql -uroot#mysql -uroot -p${MYSQL_ROOT_PASSWD} -h ${MYSQL_JEEDOM_HOST} -P${MYSQL_JEEDOM_PORT} ${MYSQL_JEEDOM_DBNAME}#" /root/install_docker.sh
  grep "mysql -u" /root/install_docker.sh
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
  #remove user save if exists
  res=$(mysql -BNr -u${MYSQL_JEEDOM_USERNAME} -p${MYSQL_JEEDOM_PASSWD} -h ${MYSQL_JEEDOM_HOST} -P${MYSQL_JEEDOM_PORT} ${MYSQL_JEEDOM_DBNAME} -e "select count(login) from user where login = 'admin';")
  if [[ 1 -eq $res ]]; then
    echo "User admin already exists, removing its creation"
    sed -i 's/\$user->save();//' /var/www/html/install/install.php
  else
    echo "User admin does not exists, install will install it."
  fi
  step_8_jeedom_configuration
  #tempo
  if [[ "release" == "$VERSION" ]]; then
    #V3
    while true; do
      #mysql -u${MYSQL_JEEDOM_USERNAME} -p${MYSQL_JEEDOM_PASSWD} -h ${MYSQL_JEEDOM_HOST} -P${MYSQL_JEEDOM_PORT} ${MYSQL_JEEDOM_DBNAME} <${WEBSERVER_HOME}/install/install.sql
      echo done
      [[ $? -eq 0 ]] && break
      echo "Waiting for database to be up"
      sleep 5
    done
    #S9 =  install.php done when running docker.
    bash ${SETX} /root/install_docker.sh -s 9
    #s10 = post install (cron ) /s11 for v4
    bash ${SETX} /root/install_docker.sh -s 10
    #s11 = jeedom check
    bash ${SETX} /root/install_docker.sh -s 11
  else
    #V4-stable
    #S9 drop jeedom database
    #s10 jeedom_installation
    bash ${SETX} /root/install_docker.sh -s 10
    #s10 = post install (cron ) /s11 for v4
    bash ${SETX} /root/install_docker.sh -s 11
    #s12 = jeedom_check
    bash ${SETX} /root/install_docker.sh -s 12
  fi
fi

echo 'All init complete'
setTimeZone
chmod 777 /dev/tty*
#chmod 777 -R /tmp
#chmod 755 -R /var/www/html
#chown -R www-data:www-data /var/www/html
#needed when using tempfs
mkdir -p /var/log/supervisor/ -p /run/lock/ -p /var/log/apache2/

echo "by default send apache logs to stdout/err"
[[ ! -d /var/log/apache2 ]] && mkdir -p /var/log/apache2/ || echo

if [[ ${LOGS_TO_STDOUT,,} =~ y ]]; then
  ln -sf /proc/1/fd/1 /var/log/apache2/access.log
  ln -sf /proc/1/fd/1 /var/log/apache2/error.log
fi

supervisorctl start apache2

#enable xdebug
if [ ${XDEBUG:-0} = "1" ]; then
  apt-get update
  apt-get install -y php-xdebug openssh-server
  sed -i "s/#PermitRootLogin prohibit-password/PermitRootLogin yes/" /etc/ssh/sshd_config ; \
  echo "<?php phpinfo() ?>" > /var/www/html/phpinfo.php
  echo "[xdebug]
xdebug.remote_eable=true
#xdebug.remote_connect_back=On
xdebug.remote_host=${XDEBUG_HOST:-"localhost"}
xdebug.remote_port=${XDEBUG_PORT:-9003}
xdebug.log=${XDEBUG_LOGFILE:-"/var/log/apache2/php_debug.log"}
xdebug.idekey=1" |tee -a $(find /etc -type f -iwholename  *apache2/php.ini -print);
  echo -e "[program:sshd]\ncommand=/usr/sbin/sshd -D" > /etc/supervisor/conf.d/sshd.conf
  supervisorctl reload
  supervisorctl start sshd
  export XDEBUG_SESSION=1
fi
