#hadolint global ignore=SC3010
ARG DISTRO=12-slim
FROM debian:${DISTRO} AS base

ENV SHELL_ROOT_PASSWORD=password
ENV WEBSERVER_HOME=/var/www/html
ENV APACHE_HTTP_PORT=80
ENV APACHE_HTTPS_PORT=443
ENV LOGS_TO_STDOUT=n
ENV SSH_PORT=22
ENV MODE_HOST=0
ENV MARIADB_ROOT_PASSWD=password
ENV MARIADB_JEEDOM_HOST=localhost
ENV MARIADB_JEEDOM_PASSWD=jeedom
ENV MARIADB_JEEDOM_DBNAME=jeedom
ENV MARIADB_JEEDOM_USERNAME=jeedom
ENV MARIADB_JEEDOM_PORT=3306
ENV XDEBUG=0
ENV XDEBUG_HOST=localhost
ENV XEBUG_PORT=9003
ARG aptCacher


EXPOSE 80
EXPOSE 443

LABEL maintainer=edgd1er@hotmail.com

#prepare base image for master, alpha, beta: all v4 versions
#add apt-cacher setting if present:
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
#hadolint ignore=DL3008
RUN if [[ -n ${aptCacher:-} ]]; then printf "Acquire::http::Proxy \"http://%s:3142\";" "${aptCacher}">/etc/apt/apt.conf.d/01proxy \
    && printf "Acquire::https::Proxy \"http://%s:3142\";" "${aptCacher}">>/etc/apt/apt.conf.d/01proxy ; fi  \
    #&& echo "Dir::Cache \"\";\nDir::Cache::archives \"\";" | tee /etc/apt/apt.conf.d/02nocache && \
    && printf "#/etc/dpkg/dpkg.cfg.d/01_nodoc\n\n# Delete locales\npath-exclude=/usr/share/locale/*\n\n# Delete man pages\npath-exclude=/usr/share/man/*\n\n# Delete docs\npath-exclude=/usr/share/doc/*\npath-include=/usr/share/doc/*/copyright" | tee /etc/dpkg/dpkg.cfg.d/03nodoc \
    #Massive apt install of jeedom requirements to optimise downloads
    && apt-get update && apt-get install -y --no-install-recommends wget rsync lsof iproute2 \
	curl apt-transport-https software-properties-common net-tools gettext snmp \
    && add-apt-repository non-free  && apt-get update && apt-get install -y --no-install-recommends supervisor \
	python3 python3-pip python3-setuptools iputils-ping libcurl3-gnutls librsync-dev \
    passwd usbutils usb.ids ntp ca-certificates unzip sudo cron locate tar telnet logrotate fail2ban dos2unix \
    ntpdate htop vim smbclient git libexpat1 ssl-cert ffmpeg usbutils \
    cutycapt at mariadb-client mariadb-common bzip2 gpg gpg-agent gpgconf xz-utils udev jq\
    #mbrola removed (not available for armhf )
    #add server apache
    apache2 apache2-utils \
    && update-ca-certificates --fresh \
    #install python2 pip from boostrap as not in repo anymore for debian 10
    && if [[ ${DISTRO} =~ buster ]]; then apt-get install -y --no-install-recommends python python2 snmp-mibs-downloader; \
    #install python2 pip from boostrap as not in repo anymore for debian 11
    elif [[ ${DISTRO} =~ bullseye ]]; then apt-get install -y --no-install-recommends python; curl https://bootstrap.pypa.io/pip/2.7/get-pip.py | python - \
    ; apt-get install -y --no-install-recommends python2 snmp-mibs-downloader; fi \
    #cannot install php as php5 or 7 might be option. leave install.sh install needed php package
    #clean temp files
    && apt-get -y remove -y brltty  && apt-get upgrade -y \
    && apt-get autoremove -y --purge && apt-get autoclean \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /var/run/sshd

FROM base

#Performs versions specific actions
ARG VERSION
ENV VERSION=${VERSION}
ARG JDM_VERSION=latest
ARG aptCacher

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN echo "install jeedom VERSION: $VERSION / ${JDM_VERSION}" \
    && wget -qO /root/.bashrc https://raw.githubusercontent.com/jeedom/core/$VERSION/install/bashrc \
    && wget -qO /etc/motd https://raw.githubusercontent.com/jeedom/core/$VERSION/install/motd \
    && apt-get autoremove -y --purge && apt-get autoclean \
    && rm -rf /var/lib/apt/lists/* \
    #from jeedom-core, get install file
    ## latest version
    && wget -qO /root/install_docker.sh https://raw.githubusercontent.com/jeedom/core/${VERSION}/install/install.sh \
    && chmod +x /root/install_docker.sh \
    # tagged version
    ##########################################
    # Adapt install_docker to docker: fix jeedom install.sh for unattended install
    && sed -i "s/systemctl daemon-reload/true/g" /root/install_docker.sh \
    && sed -r 's;(rm /var/lib/mysql/ib.*);# \1;' /root/install_docker.sh \
    && sed -i -E "s#\(mysql|mariadb\) -uroot($| )#mysql -uroot -p\${MARIADB_ROOT_PASSWD} -h \${MARIADB_JEEDOM_HOST} -P\${MARIADB_JEEDOM_PORT} \${MARIADB_JEEDOM_DBNAME} #g" /root/install_docker.sh \
    && grep "^MARIADB_JEEDOM_PASSWD=" /root/install_docker.sh || true \
    && grep "mysql -uroot" /root/install_docker.sh || true \
    && sed -i 's#-y install "#-y --no-install-recommends install "#' /root/install_docker.sh \
    && sed -i "s#apt install#apt-get install -y --no-install-recommends#" /root/install_docker.sh \
    #V4: no mysql/mariadb server inside jeedom image
    && sed -i 's/mariadb-server//' /root/install_docker.sh \
    #V4: no systemd services in docker
    && sed -i '/service_action\(\){/i return 0' /root/install_docker.sh \
    && sed -ri 's/service_action (start|stop|status|restart).*/true/' /root/install_docker.sh \
    #v4: no systemd services in docker
    && sed -ri '/systemctl (start|stop|status|restart).*/d' /root/install_docker.sh \
    # set jeedom version v3 or v4
    && sed -i "s/VERSION=master/VERSION=\${VERSION}/g" /root/install_docker.sh
    ##########################################
RUN echo "root:${SHELL_ROOT_PASSWORD}" | chpasswd \
    && echo "Installing jeedom version: ${VERSION} / ${JDM_VERSION}" \
    # 4.4 install -d 0 = external database
    && if [[ ${VERSION,,} =~ (alpha|beta|master) ]] ; then DATABASE="-d 0"; else DATABASE="" ; fi \
    # step 2 install mainpackage - add too many packages.
    # && /root/install_docker.sh -s 2 -v ${VERSION}\
    # step 3 install mysql server
    && echo "Etape 3: non faite: installation en local de la BDD" \
    && apt-get update \
    # install apache
    && echo "Etape 4: install apache" \
    && /root/install_docker.sh -s 4 -v "${VERSION}" "${DATABASE}" -i docker\
    # s5 install php
    && echo "Etape 5: install php" \
    && /root/install_docker.sh -s 5 -v "${VERSION}" "${DATABASE}" -i docker\
    # s6 install jeedom download
    && echo "Etape 6: install jeedom" \
    && /root/install_docker.sh -s 6 -v "${VERSION}" "${DATABASE}" -i docker\
    ## remove bugged php line
    # remove CR/LR : php /var/www/html/install/packages.php
    && sed -i "s/'version' => \$npm/'version' => rtrim(\$npm)/" /var/www/html/core/class/system.class.php \
    #&& sed -r -i "s/('remark' => isset)/#\1/" /var/www/html/core/class/system.class.php \
    #remove unneeded package: no db server inside jeedom image, no chromium
    && sed -i '/mariadb-server/d' /var/www/html/install/packages.json \
    && sed -i "/chromium/d" /var/www/html/install/packages.json \
    #v4 s7 = mariadb server conf: skipped
    #v4 S8 = jeedom customization later in build: skipped
    # s7 skipped: param maria svc
    # s8 apache/php setting
    && /root/install.sh -s 8 -v "${VERSION}" "${DATABASE}" -i docker \
    # s9 create db (skipped when docker)
    && /root/install.sh -s 9 -v "${VERSION}" "${DATABASE}" -i docker \
    # s10 composer
    && /root/install.sh -s 10 -v "${VERSION}" "${DATABASE}" -i docker \
    # s11 jdm post
    && /root/install.sh -s 11 -v "${VERSION}" "${DATABASE}" -i docker \
    # Add logs for http connections
    && if [[ 0 -eq $(grep Custom /etc/apache2/sites-available/000-default.conf) ]]; then \
    sed -i "$ i\CustomLog \${APACHE_LOG_DIR}/access.log combined" 000-default.conf ; fi \
    && echo "alias salias='source ~/.bashrc'" | tee -a ~/.bashrc \
    && echo "alias modalias='vim ~/.bashrc'" | tee -a ~/.bashrc \
    && echo "function setadmin(){ php \"${WEBSERVER_HOME}/core/php/jeecli.php\" user password admin \"${1:-admin}\" }" | tee -a ~/.bashrc \
    && echo "function setZwaveJsVersion(){ sed -E -i \"s#^wantedVersion=[0-9]\.[0-9]{1,2}\..#wantedVersion=${1:-9.12.0}#\" /var/www/html/plugins/zwavejs/core/config/zwavejs.config.ini ;}" | tee -a ~/.bashrc \
    && echo "function getZwaveJsVersion(){ cat /var/www/html/plugins/zwavejs/core/config/zwavejs.config.ini ;}" | tee -a ~/.bashrc \
    && echo "alias phppackage='php /var/www/html/install/packages.php'" | tee -a ~/.bashrc \
    && echo "alias phpinstall='php /var/www/html/install/install.php'" | tee -a ~/.bashrc \
    && echo "alias pipupdate='pip3 list --outdated --format json |jq -r .[].name | xargs -I % apt install -y python3-%'" | tee -a ~/.bashrc \
    && echo "function pipinstall(){ pip3 install --break-system-packages --upgrade \${1} ;}" | tee -a ~/.bashrc \
    # rpi
    && [[ ! -f /sbin/udevadm ]] && ln -sfn /bin/udevadm /sbin/udevadm || true \
    && apt-get remove -y x11-common \
    # untouched data dir
    && if [[ -d /var/www/html/data/ ]]; then cp -Rp /var/www/html/data/ /var/www/html/.data/ ; fi \
    # clean caches
    && apt-get autoremove -y --purge && apt-get autoclean \
    && rm -rf /var/lib/apt/lists/* && echo >${WEBSERVER_HOME}/initialisation \
    && if [[ -n "$aptCacher" ]]; then echo "" > /etc/apt/apt.conf.d/01proxy; fi

COPY --chmod=755 init.sh /root/init.sh
COPY --chmod=755 extras.sh /root/extras.sh
COPY supervisor/ /etc/supervisor/
COPY supervisorlog /etc/logrotate.d/supervisor
COPY jeedom_plugin /etc/logrotate.d/jeedom_plugin

WORKDIR /var/www/html/
HEALTHCHECK --interval=60s --timeout=3s --retries=3 --start-period=40s \
 CMD curl -s --fail http://localhost/here.html || exit 1
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]

VOLUME /var/www/html/data
VOLUME /var/www/html/backup
VOLUME /var/www/html/tmp
VOLUME /var/www/html/log/
VOLUME /var/log/
