# hadolint global ignore=SC3010
ARG DISTRO=13-slim
FROM debian:${DISTRO} AS base

ARG DISTRO
ARG aptCacher
ENV WEBSERVER_HOME=/var/www/html \
    APACHE_HTTP_PORT=80 \
    APACHE_HTTPS_PORT=443 \
    LOGS_TO_STDOUT=n \
    SSH_PORT=22 \
    MODE_HOST=0 \
    DB_ROOTPASSWD=password \
    DB_HOST="" \
    DB_PASSWD=jeedom \
    DB_NAME=jeedom \
    DB_USERNAME=jeedom \
    DB_PORT=3306 \
    XDEBUG=0 \
    XDEBUG_HOST=localhost \
    XEBUG_PORT=9003

EXPOSE 80 443

LABEL maintainer="edgd1er@hotmail.com" \
      description="Jeedom Docker image"

# Optimisation des couches
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Configuration d'apt-cacher si présent
#hadolint ignore=DL3008,DL3016
RUN if [[ -n ${aptCacher:-""} ]]; then \
        printf "Acquire::http::Proxy \"http://%s:3142\";" "${aptCacher}" > /etc/apt/apt.conf.d/01proxy && \
        printf "Acquire::https::Proxy \"http://%s:3142\";" "${aptCacher}" >> /etc/apt/apt.conf.d/01proxy; \
    fi && \
    # Suppression des fichiers inutiles pour réduire la taille de l'image
    printf "#/etc/dpkg/dpkg.cfg.d/01_nodoc\n\n# Suppression des locales\npath-exclude=/usr/share/locale/*\n\n# Suppression des pages de manuel\npath-exclude=/usr/share/man/*\n\n# Suppression de la documentation\npath-exclude=/usr/share/doc/*\npath-include=/usr/share/doc/*/copyright" | tee /etc/dpkg/dpkg.cfg.d/03nodoc && \
    # Installation des dépendances de base
    apt-get update && apt-get install -y --no-install-recommends \
        wget rsync lsof iproute2 curl net-tools gettext snmp \
        curl net-tools gettext snmp iputils-ping librsync-dev \
        passwd usbutils usb.ids ca-certificates unzip sudo cron plocate tar logrotate fail2ban \
        htop vim smbclient git libexpat1 ssl-cert ffmpeg usbutils ssh espeak-ng \
        at mariadb-client mariadb-common bzip2 gpg gpg-agent gpgconf xz-utils udev jq \
        apache2 apache2-utils npm supervisor python3-pip && \
    # Installation de Node.js via n
    npm install -g n && n 24 && \
    # Mise à jour des certificats CA
    update-ca-certificates --fresh && \
    # Nettoyage intermédiaire
    apt-get autoremove -y --purge && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p /var/run/sshd

# Gestion des versions spécifiques de Debian
#hadolint ignore=DL3008
RUN apt-get update && if [[ ${DISTRO} =~ (buster|10) ]]; then \
        apt-get install -y --no-install-recommends software-properties-common python python2 snmp-mibs-downloader ntpdate ntp && \
        add-apt-repository non-free; \
    elif [[ ${DISTRO} =~ (bullseye|11) ]]; then \
        apt-get install -y --no-install-recommends software-properties-common python ntpdate ntp && \
        curl -sSL https://bootstrap.pypa.io/pip/2.7/get-pip.py | python && \
        add-apt-repository non-free; \
    elif [[ ${DISTRO} =~ (bookworm|12) ]]; then \
        apt-get install -y --no-install-recommends software-properties-common libcurl3-gnutls ntpdate ntp && \
        add-apt-repository non-free; \
    elif [[ ${DISTRO} =~ (trixie|13) ]]; then \
        apt-get install -y --no-install-recommends ntpsec-ntpdate chrony libcurl3t64-gnutls; \
    fi && \
    apt-get autoremove -y --purge && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

FROM base AS final

ARG VERSION
ARG JDM_VERSION=latest
ARG aptCacher
ENV VERSION=${VERSION}

WORKDIR /var/www/html
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Préparation de l'installation de Jeedom
RUN echo "Installation de Jeedom VERSION: ${VERSION} / ${JDM_VERSION}" && \
    wget -qO /root/.bashrc https://raw.githubusercontent.com/jeedom/core/${VERSION}/install/bashrc && \
    wget -qO /etc/motd https://raw.githubusercontent.com/jeedom/core/${VERSION}/install/motd && \
    # Téléchargement du script d'installation
    wget -qO /root/install_docker.sh https://raw.githubusercontent.com/jeedom/core/${VERSION}/install/install.sh && \
    chmod +x /root/install_docker.sh && \
    # Adaptation du script pour Docker
    echo "Adaptation du script d'installation pour Docker" && \
    sed -i "s/systemctl daemon-reload/true/g" /root/install_docker.sh && \
    sed -i -r 's;(rm /var/lib/mysql/ib.*);# \1;' /root/install_docker.sh && \
    sed -i -E "s#\(mysql |mariadb \) -uroot($| )#mysql -uroot -p\${DB_ROOTPASSWD} -h \${DB_HOST} -P\${DB_PORT} -D \${DB_NAME} #g" /root/install_docker.sh && \
    sed -i 's#-y install "#-y --no-install-recommends install "#' /root/install_docker.sh && \
    sed -i "s#apt install#apt-get install -y --no-install-recommends#" /root/install_docker.sh && \
    # Suppression des services inutiles
    echo 'Suppression des services inutiles' && \
    sed -i '/mariadb-server/d' /root/install_docker.sh && \
    sed -i '/service_action\(\){/i return 0' /root/install_docker.sh && \
    sed -ri 's/service_action (start|stop|status|restart).*/true/' /root/install_docker.sh && \
    sed -ri '/systemctl (start|stop|status|restart).*/d' /root/install_docker.sh && \
    # Configuration de la version
    echo 'Configuration de la version' && \
    sed -i "s/VERSION=master/VERSION=\${VERSION}/g" /root/install_docker.sh && \
    # Installation de Jeedom
    echo "Installation de Jeedom version: ${VERSION} / ${JDM_VERSION}" && \
    DATABASE="" && \
    if [[ ${VERSION,,} =~ (alpha|beta|develop|master|main) ]]; then \
        DATABASE="-d 0"; \
    fi && \
    # Étapes d'installation
    apt-get update && \
    /root/install_docker.sh -s 4 -v "${VERSION}" -i docker "${DATABASE}" && \
    /root/install_docker.sh -s 5 -v "${VERSION}" -i docker "${DATABASE}" && \
    bash -x /root/install_docker.sh -s 6 -v "${VERSION}" -i docker "${DATABASE}" && \
    ls -al /var/www/html && \
    # Nettoyage et configuration finale
    find /var/www/html/ -type f -iname "*.sh" -exec chmod +x {} \; && \
    sed -i "s/'version' => \$npm/'version' => rtrim(\$npm)/" /var/www/html/core/class/system.class.php && \
    sed -i '/mariadb-server/d' /var/www/html/install/packages.json && \
    sed -i "/chromium/d" /var/www/html/install/packages.json && \
    bash -x /root/install_docker.sh -s 8 -v ${VERSION} -i docker "${DATABASE}" && \
    /root/install_docker.sh -s 9 -v ${VERSION} -i docker "${DATABASE}" && \
    /root/install_docker.sh -s 10 -v ${VERSION} -i docker "${DATABASE}" && \
    /root/install_docker.sh -s 11 -v ${VERSION} -i docker "${DATABASE}" && \
    # Configuration d'Apache
    if [[ 0 -eq $(grep combined /etc/apache2/sites-available/000-default.conf) ]]; then \
        sed -i "$ i\CustomLog \${APACHE_LOG_DIR}/access.log combined" /etc/apache2/sites-available/000-default.conf; \
    fi && \
    # Alias utiles
    echo "alias salias='source ~/.bashrc'" | tee -a ~/.bashrc && \
    echo "alias modalias='vim ~/.bashrc'" | tee -a ~/.bashrc && \
    echo "function setadmin(){ php \"${WEBSERVER_HOME}/core/php/jeecli.php\" user password admin \"${1:-admin}\" ; }" | tee -a ~/.bashrc && \
    echo "function setZwaveJsVersion(){ sed -E -i \"s#^wantedVersion=[0-9]\.[0-9]{1,2}\..#wantedVersion=${1:-9.12.0}#\" /var/www/html/plugins/zwavejs/core/config/zwavejs.config.ini ;}" | tee -a ~/.bashrc && \
    echo "function getZwaveJsVersion(){ cat /var/www/html/plugins/zwavejs/core/config/zwavejs.config.ini ;}" | tee -a ~/.bashrc && \
    echo "alias phppackage='php /var/www/html/install/packages.php'" | tee -a ~/.bashrc && \
    echo "alias phpinstall='php /var/www/html/install/install.php'" | tee -a ~/.bashrc && \
    echo "alias pipupdate='pip3 list --outdated --format json |jq -r .[].name | xargs -I % apt install -y python3-%'" | tee -a ~/.bashrc && \
    echo "function pipinstall(){ pip3 install --break-system-packages --upgrade \${1} ; }" | tee -a ~/.bashrc && \
    # Compatibilité Raspberry Pi
    [[ ! -f /sbin/udevadm ]] && ln -sfn /bin/udevadm /sbin/udevadm || true && \
    apt-get remove -y x11-common && \
    # Nettoyage final
    apt-get autoremove -y --purge && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    echo >"${WEBSERVER_HOME}/initialisation" && \
    if [[ -n "$aptCacher" ]]; then \
        echo "" > /etc/apt/apt.conf.d/01proxy; \
    fi

# Copie des fichiers de configuration
COPY --chmod=755 init.sh /root/init.sh
COPY --chmod=755 extras.sh /root/extras.sh
COPY supervisor/ /etc/supervisor/
COPY supervisorlog /etc/logrotate.d/supervisor
COPY jeedom_plugin /etc/logrotate.d/jeedom_plugin

WORKDIR /var/www/html/
HEALTHCHECK --interval=60s --timeout=3s --retries=3 --start-period=40s \
    CMD curl -s --fail http://localhost/here.html || exit 1

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]

# Volumes persistants
VOLUME /var/www/html/data
VOLUME /var/www/html/backup
VOLUME /var/www/html/tmp
VOLUME /var/www/html/log/
VOLUME /var/log/
