#!/usr/bin/env bash

set -e

#Variables
VERT="\\033[1;32m"
NORMAL="\\033[0;39m"
LOGS_TO_STDOUT=${LOGS_TO_STDOUT:-"n"}
SETX=""
XDEBUG=${XDEBUG:-0}
# external database arg for install
DATABASE=""
#Release=3.3.57 / master=4.3.X Beta=4.4.X / Alpha=4.4.X
if [[ ${VERSION} =~ (master|alpha|beta) ]]; then
  DATABASE="-d 0"
fi

##Functions
setTimeZone() {
  [[ ${TZ} == $(cat /etc/timezone) ]] && return
  echo "Setting timezone to ${TZ}"
  ln -fs /usr/share/zoneinfo/${TZ} /etc/localtime
  dpkg-reconfigure -fnoninteractive tzdata
}

mysql_sql() {
  if [ "localhost" == "${MARIADB_JEEDOM_HOST}" ]; then
    echo "$@" | mysql -uroot -P${MARIADB_JEEDOM_PORT}
  else
    echo "$@" | mysql -u${MARIADB_JEEDOM_USERNAME} -p${MARIADB_JEEDOM_PASSWD} -h ${MARIADB_JEEDOM_HOST} -P${MARIADB_JEEDOM_PORT}
  fi
  if [ $? -ne 0 ]; then
    echo "${ROUGE}Ne peut exécuter $* dans MySQL - Annulation${NORMAL}"
    #exit 1
  fi
}

#not need when in mysql is in another container ( db, user are created then env values)
step_8_MARIADB_create_db() {
  echo "---------------------------------------------------------------------"
  echo "${JAUNE}commence l'étape 8 configuration de mysql ${NORMAL}"
  isDB=$(mysql -uroot -p${MARIADB_ROOT_PASSWD} -h ${MARIADB_JEEDOM_HOST} -P${MARIADB_JEEDOM_PORT} -BNe "show databases;" | grep -c ${MARIADB_JEEDOM_DBNAME})
  [[ 0 -eq ${isDB} ]] && mysql -uroot -p${MARIADB_ROOT_PASSWD} -h ${MARIADB_JEEDOM_HOST} -P${MARIADB_JEEDOM_PORT} -e "CREATE DATABASE ${MARIADB_JEEDOM_DBNAME};"
  isUser=$(mysql -uroot -p${MARIADB_ROOT_PASSWD} -h ${MARIADB_JEEDOM_HOST} -P${MARIADB_JEEDOM_PORT} -BNe "select user from mysql.user where user='jeedom';" | wc -l)
  [[ 0 -eq ${isUser} ]] && mysql_sql "CREATE USER '${MARIADB_JEEDOM_USERNAME}'@'%' IDENTIFIED BY '${MARIADB_JEEDOM_PASSWD}';"
  mysql -uroot -p${MARIADB_ROOT_PASSWD} -h ${MARIADB_JEEDOM_HOST} -P${MARIADB_JEEDOM_PORT} -e "GRANT ALL PRIVILEGES ON ${MARIADB_JEEDOM_DBNAME}.* TO '${MARIADB_JEEDOM_USERNAME}'@'%';"
}

step_8_jeedom_configuration() {
  echo "${VERT}Etape 8: informations de login pour la BDD${NORMAL}"
  ls -al ${WEBSERVER_HOME}/core/config/
  cp -p ${WEBSERVER_HOME}/core/config/common.config.sample.php ${WEBSERVER_HOME}/core/config/common.config.php
  sed -i "s/#PASSWORD#/${MARIADB_JEEDOM_PASSWD}/g" ${WEBSERVER_HOME}/core/config/common.config.php
  sed -i "s/#DBNAME#/${MARIADB_JEEDOM_DBNAME}/g" ${WEBSERVER_HOME}/core/config/common.config.php
  sed -i "s/#USERNAME#/${MARIADB_JEEDOM_USERNAME}/g" ${WEBSERVER_HOME}/core/config/common.config.php
  sed -i "s/#PORT#/${MARIADB_JEEDOM_PORT}/g" ${WEBSERVER_HOME}/core/config/common.config.php
  sed -i "s/#HOST#/${MARIADB_JEEDOM_HOST}/g" ${WEBSERVER_HOME}/core/config/common.config.php

  echo "${VERT}Etape 8: Configuration des sites Web sur Apache${NORMAL}"
  cp ${WEBSERVER_HOME}/install/apache_security /etc/apache2/conf-available/security.conf
  sed -i -e "s%WEBSERVER_HOME%${WEBSERVER_HOME}%g" /etc/apache2/conf-available/security.conf

  rm /etc/apache2/conf-enabled/security.conf >/dev/null 2>&1
  ln -s /etc/apache2/conf-available/security.conf /etc/apache2/conf-enabled/

  cp -p ${WEBSERVER_HOME}/install/apache_default /etc/apache2/sites-available/000-default.conf
  sed -i -e "s%WEBSERVER_HOME%${WEBSERVER_HOME}%g" /etc/apache2/sites-available/000-default.conf
  rm /etc/apache2/sites-enabled/000-default.conf >/dev/null 2>&1
  ln -s /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-enabled/

  [[ -f /etc/apache2/conf-available/other-vhosts-access-log.conf ]] && rm /etc/apache2/conf-available/other-vhosts-access-log.conf >/dev/null 2>&1
  [[ -f /etc/apache2/conf-enabled/other-vhosts-access-log.conf ]] && rm /etc/apache2/conf-enabled/other-vhosts-access-log.conf >/dev/null 2>&1

  echo "${VERT}étape 8 configuration de jeedom réussie${NORMAL}"
}

checkCerts() {
  ret=0
  [[ $(echo | openssl s_client -servername market.jeedom.com -connect market.jeedom.com:443 2>&1) =~ Verify\ return\ code:\ ([0-9]{1,2}) ]] && ret=${BASH_REMATCH[1]}
  [[ 0 -ne ${ret} ]] && echo "Refresh ca certs" && update-ca-certificates --fresh || echo "ca certs are up to date"
}

populateVolume() {
  if [[ 2 -ne $# ]] || [[ ! -d ${1} ]]; then
    echo "No directory to populate: ${1}"
  else
    src=${1%*/}
    dst=${2%*/}
    echo "Populating ${dst}/ with ${src}/"
    rsync -a -v --ignore-existing ${src}/ ${dst}/
  fi
}

### Main
# execute all install scripts with -x
if [[ 1 -eq ${DEBUG} ]]; then
  set -x
  if [[ 1 -eq $(grep -c "set -x" /root/install_docker.sh) ]]; then
    sed -i "/STEP=0/i set -x" /root/install_docker.sh
  fi
fi

if [ ! -f /.dockerinit ]; then
  touch /.dockerinit
  chmod 755 /.dockerinit
fi

#Get vars from secrets
for s in JEEDOM_ENCRYPTION_KEY MARIADB_ROOT_PASSWD MARIADB_JEEDOM_PASSWD ROOT_PASSWD; do
  if [[ -f /run/secrets/${s} ]]; then
    echo "Reading ${s} from secrets"
    eval ${s}=$(cat /run/secrets/${s})
    [[ 1 -eq ${DEBUG} ]] && echo "${s}: ${!s}" || true
  fi
done

#fix mysql user as secret
[[ -f /run/secrets/MARIADB_JEEDOM_PASSWD ]] && sed -i "s/\${MARIADB_JEEDOM_PASSWD}/${MARIADB_JEEDOM_PASSWD}/g" /root/install_docker.sh || true

# check if env jeedom encryption key is defined
if [[ -n ${JEEDOM_ENCRYPTION_KEY} ]]; then
  #write jeedom encryption key if different
  if [[ ! -e /var/www/html/data/jeedom_encryption.key ]] || [[ "$(cat /var/www/html/data/jeedom_encryption.key)" != "${JEEDOM_ENCRYPTION_KEY}" ]]; then
    echo "Writing jeedom encryption key as defined in env"
    echo "${JEEDOM_ENCRYPTION_KEY}" >/var/www/html/data/jeedom_encryption.key
  fi
fi

#set root password
if [ -z ${ROOT_PASSWD} ]; then
  ROOT_PASSWD=$(openssl rand -base64 32 | tr -d /=+ | cut -c 15)
  echo "Use generate password : ${ROOT_PASSWD}"
fi
echo "root:${ROOT_PASSWD}" | chpasswd

#define ports, activate ssl
if [[ 3 -ne $(grep -cP "(80|${APACHE_HTTPS_PORT})" /etc/apache2/ports.conf) ]]; then
echo "Listen 80

<IfModule ssl_module>
	Listen ${APACHE_HTTPS_PORT}
</IfModule>

<IfModule mod_gnutls.c>
	Listen ${APACHE_HTTPS_PORT}
</IfModule>" >/etc/apache2/ports.conf
  sed -i -E "s/\<VirtualHost \*:(.*)\>/VirtualHost \*:80/" /etc/apache2/sites-available/000-default.conf
  sed -i -E "s/\<VirtualHost \*:(.*)\>/VirtualHost \*:${APACHE_HTTPS_PORT}/" /etc/apache2/sites-available/default-ssl.conf
fi

[[ $(a2query -m ssl | grep -c "^ssl") -eq 0 ]] && a2enmod ssl || true
[[ $(a2query -s default-ssl | grep -c "^default-ssl") -eq 0 ]] && a2ensite default-ssl
[[ $(a2query -s 000-default | grep -c "^000-default") -eq 0 ]] && a2ensite 000-default

#populateVolumes if needed
populateVolume /var/www/html/.data /var/www/html/data

if [ -f /var/www/html/core/config/common.config.php ]; then
  JEEDOM_INSTALL=1
  echo 'Jeedom is already installed'
else
  JEEDOM_INSTALL=0
  [[ ! -f /root/install_docker.sh ]] && echo -e "\n*************** ERROR, no /root/install_docker.sh file ***********\n" && exit
  #allow fail2ban to start even on docker
  touch /var/log/auth.log
  #generate db param
  WEBSERVER_HOME=/var/www/html
  #fix jeedom install.sh for unattended install
  MARIADB_JEEDOM_PASSWD=${MARIADB_JEEDOM_PASSWD:-$(openssl rand -base64 32 | tr -d /=+ | cut -c -15)}
  sed -i "s#^MARIADB_JEEDOM_PASSWD=.*#MARIADB_JEEDOM_PASSWD=\$\(openssl rand -base64 32 | tr -d /=+ \| cut -c -15\)#" /root/install_docker.sh
  #fix jeedom-core, allowing to define mysql not being local
  sed -i "s#mysql -uroot#mysql -uroot -p${MARIADB_ROOT_PASSWD} -h ${MARIADB_JEEDOM_HOST} -P${MARIADB_JEEDOM_PORT} ${MARIADB_JEEDOM_DBNAME}#" /root/install_docker.sh
  #S8 =  db param done when running docker.
  while true; do
    result=$(mysql_sql "show grants for 'jeedom'@'%';")
    if [[ $(echo ${result} | grep -c "GRANT") -gt 0 ]]; then
      echo -e "result: ${result}"
      break
    fi
    sleep 5
  done
  ### update repository cache
  apt-get update
  ## remove bugged php line
  sed -r -i "s/('remark' => isset)/#\1/" /var/www/html/core/class/system.class.php
  sed -i 's#preg_grep(mb_strtolower($alternative)#preg_grep(mb_strtolower("/".$alternative."/")#' /var/www/html/core/class/system.class.php
  #remove unneeded package
  sed -r -i "/mariadb-server/d" /var/www/html/install/packages.json
  sed -r -i "/chromium/d" /var/www/html/install/packages.json
  #fix fail2ban conf
  if [[ -f /etc/fail2ban/jail.d/jeedom.conf ]]; then
    echo
    #sed -i 's#/var/log/apache2/*error$#/var/log/apache2/*error*#g' /etc/fail2ban/jail.d/jeedom.conf
  fi
  #remove rm as composer was never installed
  sed -i '/sudo rm \/usr\/local\/bin\/composer/d' /var/www/html/resources/install_composer.sh

  #mysql is not local to jeedom container
  #set db creds
  step_8_jeedom_configuration
  #create database if needed
  step_8_MARIADB_create_db
  if [[ "release" == "$VERSION" ]]; then
    #V3
    echo "V3 is EOL (End of Life), V4.4 is the suggested version. V4.3 is legacy"
    #S9 =  install.php done when running docker.
    #broken /root/install_docker.sh -s 9
    #DBCLass is looking for language before having created the schema.
    isTables=$(mysql -uroot -p${MARIADB_ROOT_PASSWD} -h ${MARIADB_JEEDOM_HOST} -P${MARIADB_JEEDOM_PORT} ${MARIADB_JEEDOM_DBNAME} -e "show tables;" | wc -l)
    if [[ 0 -eq ${isTables} ]]; then
      echo "Mysql jeedom schema is created as no table were found, and install is bugged and check for languga in config table before creating the schema"
      mysql -uroot -p${MARIADB_ROOT_PASSWD} -h ${MARIADB_JEEDOM_HOST} -P${MARIADB_JEEDOM_PORT} ${MARIADB_JEEDOM_DBNAME} </var/www/html/install/install.sql
    fi
    #s10 = post install (cron ) /s11 for v4
    /root/install_docker.sh -s 10 ${DATABASE} -i docker
    #s11 = jeedom check
    /root/install_docker.sh -s 11 ${DATABASE} -i docker
    #reset admin password
    echo "${VERT}Admin password is now admin${NORMAL}"
    mysql_sql "use ${MARIADB_JEEDOM_DBNAME};REPLACE INTO user SET login='admin',password='c7ad44cbad762a5da0a452f9e854fdc1e0e7a52a38015f23f3eab1d80b931dd472634dfac71cd34ebc35d16ab7fb8a90c81f975113d6c7538dc69dd8de9077ec',profils='admin', enable='1';"
  else
    #master
    cp ${WEBSERVER_HOME}/install/fail2ban.jeedom.conf /etc/fail2ban/jail.d/jeedom.conf
    # create helper reset password
    sed "s/^\$username = .*/\$username = \"\$argv[1]\";/" /var/www/html/install/reset_password.php >/var/www/html/install/reset_password_admin.php
    sed -i "s/^\$password = .*/\$password = \"\$argv[2]\";/" /var/www/html/install/reset_password_admin.php
    #remove admin password save if already exists in db
    isTables=$(mysql -uroot -p${MARIADB_ROOT_PASSWD} -h ${MARIADB_JEEDOM_HOST} -P${MARIADB_JEEDOM_PORT} ${MARIADB_JEEDOM_DBNAME} -e "show tables;" | wc -l)
    if [[ ${isTables:-0} -gt 0 ]]; then
      echo "User admin already exists, removing its creation"
      sed -i '/\$user->save();/d' /var/www/html/install/install.php
    else
      echo "User admin does not exists, install will install it."
    fi
    #S9 drop jeedom database
    echo -e "Step 9 skipped: database drop/create"
    #s10 jeedom_installation
    /root/install_docker.sh -s 10 ${DATABASE} -i docker
    #s10 = post install (cron ) /s11 for v4
    /root/install_docker.sh -s 11 ${DATABASE} -i docker
    #s12 = jeedom_check
    /root/install_docker.sh -s 12 ${DATABASE} -i docker
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
mkdir -p /run/lock/ -p /var/www/html/log/{apache2,fail2ban} -p /var/run/fail2ban

#enable xdebug
if [ ${XDEBUG:-0} = "1" ]; then
  apt-get update
  apt-get install -y php-xdebug openssh-server && phpenmod -s ALL xdebug
  sed -i "s/#PermitRootLogin prohibit-password/PermitRootLogin yes/" /etc/ssh/sshd_config
  echo "<?php phpinfo() ?>" >/var/www/html/phpinfo.php
  phpconf=$(find /etc -type f -iwholename *apache2/php.ini -print)
  if [[ 0 -eq $(grep -c "[xdebug]" ${phpconf}) ]]; then
    echo "
[xdebug]
xdebug.remote_eable=true
xdebug.mode=develop,debug
xdebug.remote_host=${XDEBUG_HOST:-"host.docker.internal"}
xdebug.remote_port=${XDEBUG_PORT:-9003}
xdebug.log=${XDEBUG_LOGFILE:-"/var/www/html/log/php_debug.log"}
xdebug.idekey='idekey'
xdebug.start_with_request=yes" | tee -a ${phpconf}
    sed -r "s/^error_reporting = .*/error_reporting = E_ALL/" ${phpconf}
    echo -e "[program:sshd]\ncommand=/usr/sbin/sshd -D" >/etc/supervisor/conf.d/sshd.conf
    supervisorctl reread
    supervisorctl add sshd
    export XDEBUG_SESSION=1
  fi
fi

sed -i 's#/var/log/apache2#/var/www/html/log/#' /etc/apache2/envvars
sed -i 's#/var/log/apache2#/var/www/html/log#' /etc/logrotate.d/apache2

if [[ ${LOGS_TO_STDOUT,,} =~ y ]]; then
  echo "Send apache logs to stdout/err"
  [[ -f /var/log/apache2/access.log ]] && rm -Rf /var/log/apache2/* || true
  ln -sf /proc/1/fd/1 /var/www/html/log/access.log
  ln -sf /proc/1/fd/1 /var/www/html/log/error.log
else
  [[ -L /var/log/apache2/access.log ]] && rm -f /var/log/apache2/{access,error}.log && echo "Remove apache symlink to stdout/stderr" || echo
fi

checkCerts

if [ ${JEEDOM_INSTALL} -eq 0 ] && [ ! -z "${RESTOREBACKUP}" ] && [ "${RESTOREBACKUP}" != 'NO' ]; then
  echo 'Need restore backup '${RESTOREBACKUP}
  wget ${RESTOREBACKUP} -O /tmp/backup.tar.gz
  php /var/www/html/install/restore.php backup=/tmp/backup.tar.gz
  rm /tmp/backup.tar.gz
  if [ ! -z "${UPDATEJEEDOM}" ] && [ "${UPDATEJEEDOM}" != 'NO' ]; then
    echo 'Need update jeedom'
    php /var/www/html/install/update.php
  fi
fi

supervisorctl start apache2
#wait for logs file to be created
#cannot start fail2ban when logs are redirected
if [[ ${LOGS_TO_STDOUT,,} =~ n ]]; then
  #place apache logs at proper location

  #sed -i "s#/var/www/html/log#/var/log/apache2#" /etc/fail2ban/jail.d/jeedom.conf
  #sed -i "s#/http\*\.#/*#" /etc/fail2ban/jail.d/jeedom.conf
  #sed -i 's#\*error$#\*error\*#g' /etc/fail2ban/jail.d/jeedom.conf
  supervisorctl start fail2ban
fi

echo "Jeedom version: $(cat /var/www/html/core/config/version)"

#WIP: fix plugins, install dependancies
if [[ 1 -eq ${E_DEP:-0} ]] || [[ 1 -eq ${E_MEROSS:-0} ]] || [[ ${E_PUSH=0:-0} ]] || [[ ${E_ZWAVE:-0} ]]; then
  /root/extras.sh
fi
