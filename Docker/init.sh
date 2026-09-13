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
# alpha, beta replaced with release / master 4.6.1 / develop = 4.6.2
if [[ ${VERSION} =~ (release/master|develop) ]]; then
  DATABASE="-d 0"
fi

#Variable conversions
JEEDOM_ENCRYPTION_KEY=${JEEDOM_ENCRYPTION_KEY:-${JEEDOM_ENC_KEY}}

DB_ROOTPASSWD=${MARIADB_ROOT_PASSWD:-""}
DB_PASSWORD=${DB_PASSWD:-${MARIADB_JEEDOM_PASSWD}}
DB_NAME=${DB_NAME:-${MARIADB_JEEDOM_DBNAME}}
DB_USERNAME=${DB_USERNAME:-${MARIADB_JEEDOM_USERNAME}}
DB_PORT=${DB_PORT:-${MARIADB_JEEDOM_PORT}}
DB_HOST=${DB_HOST:-${MARIADB_JEEDOM_HOST}}

DB_ROOTPASSWD=${MARIADB_ROOT_PASSWD:-""}
DB_PASSWD=${DB_PASSWD:-"changeIt"}
DB_NAME=${DB_NAME:-"jeedom"}
DB_USERNAME=${DB_USERNAME:-"jeedom"}
DB_PORT=${DB_PORT:-3306}
DB_HOST=${DB_HOST:-"localhost"}

##Functions
setTimeZone() {
  [[ ${TZ} == $(cat /etc/timezone) ]] && return
  echo "Setting timezone to ${TZ}"
  ln -fs "/usr/share/zoneinfo/${TZ}" /etc/localtime
  dpkg-reconfigure -fnoninteractive tzdata
}

load_secret() {
  local variable_name=$1
  local secret_file="/run/secrets/${variable_name}"
  local value

  if [[ -f $secret_file ]]; then
    printf 'Reading %s from secrets\n' "$variable_name"
    IFS= read -r -d '' value <"$secret_file" || true

    printf -v "$variable_name" '%s' "$value"
    export "${variable_name}"
  fi
}

load_secrets() {
  #Get vars from secrets
  local secret
  for secret in JEEDOM_ENCRYPTION_KEY DB_ROOTPASSWD DB_PASSWD ROOT_PASSWD; do
    load_secret "$secret"
  done
}

mysql_sql() {
  if (($# != 1)); then
    printf 'Usage: mysql_sql "requête SQL"\n' >&2
    return 2
  fi
  local query=$1
  local -a mysql_cmd
  mysql_cmd=(mysql --batch --skip-column-names --raw "--port=${DB_PORT:-3306}"
  )

  if [[ ${DB_HOST:-localhost} == "localhost" ]]; then
    mysql_cmd+=(--user=root)
  else
    mysql_cmd+=("--user=${DB_USERNAME}" "--host=${DB_HOST}" "--password=${DB_PASSWD}")
  fi

  # Utiliser -pPASSWORD est visible dans la ligne de commande.
  # MYSQL_PWD est préférable à court terme, même si un fichier
  # ~/.my.cnf reste préférable en production.
  if [[ ${DB_HOST:-localhost} == "localhost" ]]; then
    export MYSQL_PWD=${DB_ROOTPASSWD:-}
  else
    export MYSQL_PWD=${DB_PASSWD:-}
  fi

  # Ne sélectionner la base que si elle est définie et nécessaire.
  # SHOW GRANTS, CREATE DATABASE, etc. ne nécessitent pas de base, mais les droits root.
  if [[ -n ${DB_NAME:-} ]] &&
    [[ ! ${query,,} =~ ^[[:space:]]*(show[[:space:]]+grants|create[[:space:]]+database) ]]; then
    mysql_cmd+=(--database="${DB_NAME}")
  fi

  "${mysql_cmd[@]}" --execute="$query" ||true
}

first_run() {
  # Handle first run
  if [ -f "${WEBSERVER_HOME}/initialisation" ]; then
    echo "************* container first run *************"
    ### update repository cache
    apt-get update
    JEEDOM_INSTALL=0
    [[ ! -f /root/install_docker.sh ]] && echo -e "\n*************** ERROR, no /root/install_docker.sh file ***********\n" && exit
    #recreate tmp plugins dir
    for d in plugins/*; do mkdir -p /tmp/jeedom/${d#*/}; done
    rm -f "${WEBSERVER_HOME}/initialisation"
    #allow fail2ban to start even on docker
    touch /var/log/auth.log
    #fix jeedom install.sh for unattended install
    DB_PASSWD=${DB_PASSWD:-$(openssl rand -base64 32 | tr -d /=+ | cut -c1-15)}
    #sed -i "s#^DB_PASSWD=.*#DB_PASSWD=\$\(openssl rand -base64 32 | tr -d /=+ \| cut -c1-15\)#" /root/install_docker.sh
    #fix jeedom-core, allowing to define mysql not being local
    sed -ibak -E "s#mysql -uroot [^/]+#mysql -uroot -p${DB_ROOTPASSWD} -h ${DB_HOST} -P${DB_PORT} -D ${DB_NAME}#" /root/install_docker.sh
    # S8: create user,database,grant if needed
    step_8_create_db
    # check grants
    while true; do
      result=$(mysql_sql "show grants for 'jeedom'@'%';")
      if [[ $(echo ${result} | grep -c "GRANT") -gt 0 ]]; then
        echo -e "result: ${result}"
        break
      fi
      sleep 5
    done

    #remove unneeded package
    sed -r -i "/mariadb-server/d" ${WEBSERVER_HOME}/install/packages.json || true
    sed -r -i "/chromium/d" ${WEBSERVER_HOME}/install/packages.json || true
    # master V4
    cp ${WEBSERVER_HOME}/install/fail2ban.jeedom.conf /etc/fail2ban/jail.d/jeedom.conf
    #remove admin password save if already exists in db
    isTables=$(mysql_sql "show tables;")
    if [[ -n ${isTables:-""} ]]; then
      echo "User admin already exists, removing its creation"
      sed -i '/\$user->save();/d' ${WEBSERVER_HOME}/install/install.php
    else
      #create tables
      # bugged php class need to force true state
      php ${WEBSERVER_HOME}/install/install.php mode=force || true
      echo "User admin does not exists, install will install it."
    fi
    #s12 = jeedom_check
    /root/install_docker.sh -s 12 ${DATABASE} -i docker
    #set admin password if needed
    if [[ "${JEEDOM_INSTALL}" == 0 ]] && [[ ! -z "${ADMIN_PASSWORD}" ]]; then
      echo "Set admin password with env var ADMIN_PASSWORD"
      php "${WEBSERVER_HOME}/core/php/jeecli.php" user password admin "${ADMIN_PASSWORD:-admin}"
    fi
  else
    JEEDOM_INSTALL=1
    echo 'Jeedom is already installed'
  fi
}

#may be useful if user password is changed.
step_8_create_db() {
  echo "---------------------------------------------------------------------"
  echo "${JAUNE}commence l'étape 8 configuration de mysql ${NORMAL}"
  isDB=$(mysql_sql "show databases ;" | grep -Fxc -- "${DB_NAME}" || true)
  [[ 0 -lt ${isDB} ]] && return || true
  if [[ -z ${DB_ROOTPASSWD:-} ]]; then
    echo "No value for DB_ROOTPASSWD, cannot create required schema for ${DB_NAME}"
  else
    isDB=$(mysql -uroot -p${DB_ROOTPASSWD} -h ${DB_HOST} -P${DB_PORT} -D${DB_NAME} -BNe "show databases;" | grep -c ${DB_NAME})
    [[ 0 -eq ${isDB} ]] && mysql -uroot -p${DB_ROOTPASSWD} -h ${DB_HOST} -P${DB_PORT} -e "CREATE DATABASE ${DB_NAME};"
    isUser=$(mysql -uroot -p${DB_ROOTPASSWD} -h ${DB_HOST} -P${DB_PORT} -BNe "select user from mysql.user where user='jeedom';" | wc -l)
    [[ 0 -eq ${isUser} ]] && mysql_sql "CREATE USER '${DB_USERNAME}'@'%' IDENTIFIED BY '${DB_PASSWD}';"
    mysql -uroot -p${DB_ROOTPASSWD} -h ${DB_HOST} -P${DB_PORT} -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USERNAME}'@'%';"
  fi
}

checkCerts() {
  ret=5
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

set_root_password() {
  #set root password
  if [[ -z ${ROOT_PASSWD} ]]; then
    ROOT_PASSWD=$(openssl rand -base64 32 | tr -d /=+ | cut -c1-15)
    echo "Use generate password : ${ROOT_PASSWD}"
  fi
  printf "root:%s" "${ROOT_PASSWD}" | chpasswd
}

apache_setup() {
  mkdir -p /var/log/apache2/
  #define ports, activate ssl
  if [[ 3 -ne $(grep -cP "(${APACHE_HTTP_PORT}|${APACHE_HTTPS_PORT})" /etc/apache2/ports.conf) ]]; then
    echo "Ports update for apache2: ${APACHE_HTTP_PORT}, ${APACHE_HTTPS_PORT}"
    echo "Listen ${APACHE_HTTP_PORT}
JEEDOM_ENCRYPTION_KEY=${JEEDOM_ENCRYPTION_KEY:-${JEEDOM_ENC_KEY}}
<IfModule ssl_module>
	Listen ${APACHE_HTTPS_PORT:-443}
</IfModule>

<IfModule mod_gnutls.c>
	Listen ${APACHE_HTTPS_PORT:-443}
</IfModule>" >/etc/apache2/ports.conf
    sed -i -E "s/\<VirtualHost \*:(.*)\>/VirtualHost \*:${APACHE_HTTP_PORT}/" /etc/apache2/sites-available/000-default.conf
    sed -i -E "s/\<VirtualHost \*:(.*)\>/VirtualHost \*:${APACHE_HTTPS_PORT}/" /etc/apache2/sites-available/default-ssl.conf
  fi

  sed -i 's#/var/log/apache2#/var/www/html/log/#' /etc/apache2/envvars
  sed -i 's#/var/log/apache2#/var/www/html/log#' /etc/logrotate.d/apache2

  [[ $(a2query -m ssl | grep -c "^ssl") -eq 0 ]] && a2enmod ssl || true
  [[ $(a2query -s default-ssl | grep -c "^default-ssl") -eq 0 ]] && a2ensite default-ssl || true
  [[ $(a2query -s 000-default | grep -c "^000-default") -eq 0 ]] && a2ensite 000-default || true
}

db_creds() {
  cp ${WEBSERVER_HOME}/core/config/common.config.sample.php ${WEBSERVER_HOME}/core/config/common.config.php
  #multi match jeedom/edgd1er version

  sed -i "s/#PASSWORD#/${DB_PASSWD}/g" ${WEBSERVER_HOME}/core/config/common.config.php
  sed -i "s/#DBNAME#/${DB_NAME:-jeedom}/g" ${WEBSERVER_HOME}/core/config/common.config.php
  sed -i "s/#USERNAME#/${DB_USERNAME:-jeedom}/g" ${WEBSERVER_HOME}/core/config/common.config.php
  sed -i "s/#PORT#/${DB_PORT:-3306}/g" ${WEBSERVER_HOME}/core/config/common.config.php
  sed -i "s/#HOST#/${DB_HOST:-localhost}/g" ${WEBSERVER_HOME}/core/config/common.config.php
}

save_db_decrypt_key() {
  # check if env jeedom encryption key is defined
  if [[ -n ${JEEDOM_ENCRYPTION_KEY} ]]; then
    #write jeedom encryption key if different
    if [[ ! -e ${WEBSERVER_HOME}/data/jeedom_encryption.key ]] || [[ "$(cat ${WEBSERVER_HOME}/data/jeedom_encryption.key)" != "${JEEDOM_ENCRYPTION_KEY}" ]]; then
      echo "Writing jeedom encryption key as defined in env"
      printf '%s' "${JEEDOM_ENCRYPTION_KEY}" >"${WEBSERVER_HOME}/data/jeedom_encryption.key"
    fi
  else
    echo "No JEEDOM_ENCRYPTION_KEY variable found. IF databasse is already populated, secrets will be lost."
  fi
}

wait_for_db() {
  while true; do
    res=$(mysql_sql "show databases;" || true)
    if [[ ${res} != "" ]]; then
      break
    fi
    echo "database not available: ${res}"
    sleep 5
  done
}

fix_sudo() {
  if [[ 0 -eq $(grep -c www-data /etc/sudoers) ]]; then
    echo "www-data ALL=(ALL) NOPASSWD: ALL" | tee /etc/sudoers.d/www
  fi
}

### Main

main() {
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

  load_secrets

  #fix mysql user as secret
  [[ -f /run/secrets/DB_PASSWD ]] && sed -i "s/\${DB_PASSWD}/${DB_PASSWD}/g" /root/install_docker.sh || true

  #set timezone
  setTimeZone
  #allow db secrets decode when using external db.
  save_db_decrypt_key
  #set root password
  set_root_password
  #define ports, activate ssl
  apache_setup
  #save db config in jeedom php file
  db_creds
  #populateVolumes if needed
  populateVolume /var/www/html/.data ${WEBSERVER_HOME}/data

  #fix sudo
  fix_sudo

  #wait db to be up
  wait_for_db

  # create user, db, grants if needed (should be already done)
  first_run

  echo 'All init complete'
  echo "Jeedom version: ${VERSION} / $(<${WEBSERVER_HOME}/core/config/version)"
  setTimeZone
  chmod 777 /dev/tty*
  #chown -R www-data:www-data ${WEBSERVER_HOME}
  #needed when using tempfs
  mkdir -p /run/lock/ -p ${WEBSERVER_HOME}/log/fail2ban -p /var/run/fail2ban

  #enable xdebug
  if [ ${XDEBUG:-0} = "1" ]; then
    apt-get update
    apt-get install -y php-xdebug openssh-server && phpenmod -s ALL xdebug
    sed -i "s/#PermitRootLogin prohibit-password/PermitRootLogin yes/" /etc/ssh/sshd_config
    echo "<?php phpinfo() ?>" >${WEBSERVER_HOME}/phpinfo.php
    phpconf=$(find /etc -type f -iwholename "*apache2/php.ini" -print)
    if [[ 0 -eq $(grep -c "[xdebug]" ${phpconf}) ]]; then
      echo "
[xdebug]
xdebug.remote_eable=true
xdebug.mode=develop,debug
xdebug.remote_host=${XDEBUG_HOST:-"host.docker.internal"}
xdebug.remote_port=${XDEBUG_PORT:-9003}
xdebug.log=${XDEBUG_LOGFILE:-"${WEBSERVER_HOME}/log/php_debug.log"}
xdebug.idekey='idekey'
xdebug.start_with_request=yes" | tee -a ${phpconf}
      sed -r "s/^error_reporting = .*/error_reporting = E_ALL/" ${phpconf}
      echo -e "[program:sshd]\ncommand=/usr/sbin/sshd -D" >/etc/supervisor/conf.d/sshd.conf
      supervisorctl reread
      supervisorctl add sshd
      export XDEBUG_SESSION=1
    fi
  fi

  echo """
Major change in variables names, old vars are still supported
New name: JEEDOM_ENCRYPTION_KEY, was JEEDOM_ENCKEY
New name: DB_ROOTPASSWD, was MARIADB_ROOT_PASSWD
New name: DB_PASSWD, was  MARIADB_JEEDOM_PASSWD
New name: DB_NAME, was MARIADB_JEEDOM_DBNAME
New name: DB_USERNAME, was MARIADB_JEEDOM_USERNAME
New name: DB_PORT, was  MARIADB_JEEDOM_PORT
New name: DB_HOST, was MARIADB_JEEDOM_HOST
"""

  if [[ ${LOGS_TO_STDOUT,,} =~ [yo] ]]; then
    echo "Send apache logs to stdout/err"
    [[ -f ${WEBSERVER_HOME}/log/apache2/access.log ]] && rm -Rf ${WEBSERVER_HOME}/log/apache2/* || true

    ln -sf /proc/1/fd/1 ${WEBSERVER_HOME}/log/access.log
    ln -sf /proc/1/fd/1 ${WEBSERVER_HOME}/log/error.log
  else
    [[ -L ${WEBSERVER_HOME}/log/access.log ]] && rm -f ${WEBSERVER_HOME}/log/{access,error}.log && echo "Remove apache symlink to stdout/stderr" || echo
  fi

  checkCerts

  [[ ! -d ${WEBSERVER_HOME}/.data ]] && mkdir -p "${WEBSERVER_HOME}/.data" || true

  if [ ${JEEDOM_INSTALL} -eq 0 ] && [ ! -z "${RESTOREBACKUP}" ] && [ "${RESTOREBACKUP}" != 'NO' ]; then
    echo 'Need restore backup '${RESTOREBACKUP}
    wget ${RESTOREBACKUP} -O /tmp/backup.tar.gz
    php ${WEBSERVER_HOME}/install/restore.php backup=/tmp/backup.tar.gz
    rm /tmp/backup.tar.gz
    if [ ! -z "${UPDATEJEEDOM}" ] && [ "${UPDATEJEEDOM}" != 'NO' ]; then
      echo 'Need update jeedom'
      # bugged php class need to force true state
      php ${WEBSERVER_HOME}/install/update.php || true
    fi
  fi

  supervisorctl start apache2

  #cannot start fail2ban when logs are redirected
  if [[ ${LOGS_TO_STDOUT,,} =~ n ]]; then
    supervisorctl start fail2ban
  fi

  # step_12_jeedom_check
  sh ${WEBSERVER_HOME}/install/install.sh -s 12 -v ${VERSION} -w ${WEBSERVER_HOME} -i docker
  # set jeedom branch according to build
  current_version=$(mysql_sql "select c.value from config c where c.plugin='core' and c.key='core::branch'")
  current_version=${current_version:-"Not set"}
  file_version=$(<${WEBSERVER_HOME}/core/config/version)
  echo "Jeedom version: ${VERSION} - ${file_version} / ${current_version}"
  if [[ "${VERSION}" != "${current_version}" ]]; then
    echo "setting core branch according, was ${current_version}, to build tag ${VERSION}"
    res=$(mysql_sql "INSERT INTO config (plugin, \`key\`, value) VALUES ('core', 'core::branch', 'develop')
      ON DUPLICATE KEY UPDATE value = 'develop';")
  fi
  current_version=$(mysql_sql "select c.value from config c where c.plugin='core' and c.key='core::branch';")
  echo "Jeedom core branch: ${current_version}"

  #WIP: fix plugins, install dependencies
  OPTIONS=""
  [[ 0 -ne ${E_DEP:-0} ]] && OPTIONS+=" -d" || true
  [[ 0 -ne ${E_MEROSS:-0} ]] && OPTIONS+=" -m" || true
  [[ 0 -ne ${E_PUSH:-0} ]] && OPTIONS+=" -p" || true
  [[ 0 -ne ${E_ZWAVE:-0} ]] && OPTIONS+=" -z" || true
  [[ -n ${OPTIONS} ]] && /root/extras.sh ${OPTIONS} || true

}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  main "$@"
fi
