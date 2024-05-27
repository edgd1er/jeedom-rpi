#!/usr/bin/env bash

# Few tweaks to speed up container update or fix pulgin
# when pulling a new image or creating a new container, jeedom need to detects existing plugins and run all dependencies
# installation. this scripts will scan plugin dir, fetch information (json/sh) and install all packages.
# IF ever you update your container through jeedom's interface, this script has no use.

set -eu -o pipefail
# install dependancies
E_DEP=${E_DEP:-0}
# fix meross installation
E_MEROSS=${E_MEROSS:-0}
# fix pushbullet
E_PUSH=${E_PUSH:-0}
# force zwave-ui as external container + version
E_ZWAVE=${E_ZWAVE:-0}
#Default zwavejs-ui version
E_ZWAVEVER=${E_ZWAVEVER:-"9.12.0"}
#Debian 12 needs --break-system-packages
BKS=""

#Functions
usage() {
  echo -e "\n$0:\t [d,h,p,m,v,z]"
  echo -e "\t-h\tHelp: cette aide"
  echo -e "\t-d\tdependancies: install all dependancies of found plugins."
  echo -e "\t-m\tmeross: fix meross plugin installation"
  echo -e "\t-p\tPushbullet: fix plugin's installation"
  echo -e "\t-v\tverbose: set -x for the bash, show executed commands"
  echo -e "\t-z\tzwave: remove zwavejs-ui installation, expect zwavejs-ui to run elsewhere, not aside with jeedom."
}

pushbullet() {
  if [[ -d /var/www/html/plugins/pushbullet ]]; then
    [[ 0 -ne $(pip3 list | grep -c pushbullet-python) ]] && pip3 uninstall pushbullet-python || true
    pip3 install ${BKS} websocket-client pushbullet-python
    [[ 0 -ne $(pip3 list | grep -c pushbullet-python) ]] && pip3 uninstall ${BKS} pushbullet-python || true
    pipx uninstall websocket-client
    pip3 install ${BKS} websocket-client pushbullet.py
    #Fix listener
    if [[ 0 -eq $() ]]; then
      sed -i "s/on_message(self, message)/on_message(self, t, message)/" /usr/local/lib/python3.11/dist-packages/pushbullet/listener.py
    fi
    # pushbullet: replace object with jeeObject
    sed -i 's/(object/(jeeObject/' /var/www/html/plugins/pushbullet/desktop/php/pushbullet.php
    grep -iP "\((|jee)object" /var/www/html/plugins/pushbullet/desktop/php/pushbullet.php

    if [[ -f /var/www/html/plugins/pushbullet/ressources/pushbullet_daemon/pushbullet.py ]]; then
      # pushbullet: change tmp path
      sed -i "s#path = os.path.dirname(os.path.realpath(__file__))+'/../../../../tmp'#path = '/tmp'#" /var/www/html/plugins/pushbullet/ressources/pushbullet_daemon/pushbullet.py
      # pushbullet: activation du log du daemon
      sed -i 's#/dev/null#/var/www/html/log/pushbullet_daemon.log#' /var/www/html/plugins/pushbullet/core/class/pushbullet.class.php
      sed -i "s#/tmp/pushbullet.log#/var/www/html/log/pushbullet.log#" /var/www/html/plugins/pushbullet/ressources/pushbullet_daemon/pushbullet.py

    fi
    # pushbullet: replace obsolete websocket
    if [[ -d /var/www/html/plugins/pushbullet/ressources/pushbullet_daemon/websocket ]]; then
      mv /var/www/html/plugins/pushbullet/ressources/pushbullet_daemon/websocket /var/www/html/plugins/pushbullet/ressources/pushbullet_daemon/websocket.old
    fi
  fi
}

meross() {
  if [[ -d /var/www/html/plugins/MerosSync ]]; then
    echo "install jq, g++, python3-dev and meross-iot"
    # Meross
    apt-get install -y --no-install-recommends jq g++ python3-dev
    pip3 install ${BKS} --upgrade pip meross_iot
    # MerossSync
    sed -i 's/pip install/pip install ${BKS}/g' /var/www/html/plugins/MerosSync/core/class/../../resources/install_apt.sh
    /bin/bash /var/www/html/plugins/MerosSync/core/class/../../resources/install_apt.sh /tmp/jeedom/MerosSync/dependance
  fi
}

installDep() {
  echo "Install all plugins dependancies"
  #node 18
  apt-get update
  apt-get install -y ca-certificates curl gnupg jq
  mkdir -p /etc/apt/keyrings
  curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/nodesource.gpg
  NODE_MAJOR=18
  echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list
  apt-get install -y --no-install-recommends build-essential g++ python3-dev nodejs
  python3 -m pip install ${BKS} --upgrade pip
  #old style dependencies
  find /var/www/html/plugins/ -type f -path '*sources*' -iname 'install*.sh' -exec {} \;
  #new style dependencies
  apt-get install -y $(find /var/www/html/plugins -type f -name packages.json -exec jq -s '.[]|select(.apt!=null)|.apt|keys' {} \; | tr -d '\"][\n,')
}

# use case: zwavejs-ui is running elsewhere (other container, other server, ...)
# do not install nodejs, yarn, do not clone zwavejs-ui, change zwavejs-ui's expected version.
# better option: https://github.com/lxrootard/zwavejs (allow remote zwavejs-ui)
fixZwaveUI() {
  echo "better option: https://github.com/lxrootard/zwavejs (allow remote zwavejs-ui)"
  echo "Force zwavejs-ui expected version, bypass zwavejs-ui installation, expect it to run elsewhere (other server, other container , ...)"
  #change version expected: zwavejs/core/config/zwavejs.config.ini: wantedVersion=8.9.0
  sed -E -i "s#^wantedVersion=[0-9]\.[0-9]{1,2}\..#wantedVersion=${E_ZWAVEVER}#" /var/www/html/plugins/zwavejs/core/config/zwavejs.config.ini
  grep "wantedVersion=" /var/www/html/plugins/zwavejs/core/config/zwavejs.config.ini

  # do not install zwave js, nor dependencies
  echo -e "{\"plugin\": {\"mqtt2\": {}},\"apt\": {},\"pre-install\": {},\"post-install\": {}}"| jq . >/var/www/html/plugins/zwavejs/plugin_info/packages.json
  # remove kill from plugin as no daemon are running.
  sed -i '/isRunning() {/a \ \           return true;' /var/www/html/plugins/zwavejs/core/class/zwavejs.class.php
  sed -i '/deamon_stop() {/a \ \             return true;' /var/www/html/plugins/zwavejs/core/class/zwavejs.class.php
  #sed -i '232i        return $return;' /var/www/html/plugins/zwavejs/core/class/zwavejs.class.php
  # do not start daemon
  sed -i "s/\$cmd .= ' yarn start';/#\$cmd .= ' yarn start';/" /var/www/html/plugins/zwavejs/core/class/zwavejs.class.php
  sed -i 's/ exec(\$cmd)/#exec(\$cmd)/' /var/www/html/plugins/zwavejs/core/class/zwavejs.class.php
  # remove kill from plugin as no daemon are running.
  sed -i 's/ system::kill\(\#system::kill\(/' /var/www/html/plugins/zwavejs/core/class/zwavejs.class.php
  # remove yarn start / node is not local

  # remove node modules check as project was not cloned.
  mkdir -p /var/www/html/plugins/zwavejs/resources/zwave-js-ui/
  touch /var/www/html/plugins/zwavejs/resources/zwave-js-ui/node_modules
  # detect nodeID_XX as XX
  echo "in zwavejsui uncheck 'Use nodes name instead of numeric nodeIDs' in parameters"
  # log debug unknown key
  sed -i "s/'\.__('Le message reçu est de type inconnu', __FILE__)/, key: '.\$key.__('. Le message reçu est de type inconnu', __FILE__)/" /var/www/html/plugins/zwavejs/core/class/zwavejs.class.php
  # remove port controle
  if [[ $(grep -c 'if (@!file_exists($port)' /var/www/html/plugins/zwavejs/core/class/zwavejs.class.php) -eq 0 ]]; then
    sed -i '/if (@!file_exists($port)) {/,+3d' /var/www/html/plugins/zwavejs/core/class/zwavejs.class.php
  fi
}

fixPipx() {
  if [[ 1 -eq $(grep -c "VERSION_ID=12" /etc/os-release) ]]; then
    sed -i "s/pipx install --force-reinstall --upgrade /pip3 install --break system-packages /g" /var/www/html/core/class/system.class.php
    sed -i "s/pip3 install -force /pip3 install --break system-packages /g" /var/www/html/core/class/system.class.php

  fi
  pipx ensurepath
}

#Main
source /etc/os-release
#Debian 12 does not allow installation through pip3 without
if [[ $VERSION_ID == "12" ]]; then
  BKS="--break-system-packages"
fi
while getopts "dhpmvz" option; do
  case $option in
  d)
    E_DEP=1
    ;;
  h)
    usage
    exit 1
    ;;
  p)
    E_PUSH=1
    ;;
  m)
    E_MEROSS=1
    ;;
  z)
    E_ZWAVE=1
    ;;
  v)
    set -x
    ;;
  esac
done

fixPipx
if [[ 1 -eq ${E_PUSH:-0} ]]; then
  pushbullet
fi
if [[ 1 -eq ${E_MEROSS:-0} ]]; then
  meross
fi
if [[ 1 -eq ${E_ZWAVE:-0} ]]; then
  fixZwaveUI
fi
if [[ 1 -eq ${E_DEP:-0} ]]; then
  installDep
fi
