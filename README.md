# Jeedom-rpi

![Docker buildx armhf+amd64 v3](https://github.com/edgd1er/jeedom-rpi/workflows/Docker%20buildx%20armhf+amd64%20v3/badge.svg?branch=master)
![Docker buildx armhf+amd64 v4](https://github.com/edgd1er/jeedom-rpi/workflows/Docker%20buildx%20armhf+amd64%20v4/badge.svg?branch=master)

![gh issues](https://badgen.net/github/open-issues/edgd1er/jeedom-rpi?icon=github&label=issues)
![Docker Pulls](https://badgen.net/docker/pulls/edgd1er/jeedom-rpi?icon=docker&label=pulls)
![Docker Stars](https://badgen.net/docker/stars/edgd1er/jeedom-rpi?icon=docker&label=stars)

![Docker Size v4](https://badgen.net/docker/size/edgd1er/jeedom-rpi/v4-latest?icon=docker&label=Size%20v4)
![ImageLayers v4](https://badgen.net//docker/layers/edgd1er/jeedom-rpi?icon=docker&label=Layers%20v4)

![Docker Size v3](https://badgen.net/docker/size/edgd1er/jeedom-rpi/v3-latest?icon=docker&label=Size%20v3)
![ImageLayers v3](https://badgen.net/docker/layers/edgd1er/jeedom-rpi?icon=docker&label=Layers%20v3)

Forked from https://github.com/CodaFog/jeedom-rpi

| Last Version                                               | Commit Date |
|------------------------------------------------------------|-------------|
| [v4.3.22](https://doc.jeedom.com/fr_FR/core/4.3/changelog) | 24/01/17    |
| [v3.3.60](https://doc.jeedom.com/en_US/core/3.3/changelog) | 23/01/02    |

/!\ According to jeedom, 3.3.60 will be the last update to v3.

/!\ Asof 2023/01/02, v4-latest docker tag is now based on bullseye (v11) as zwave plugin has migrated to zwave-js-ui
plugin. v4-buster-latest (v10) is available for plugins not compatible with debian:bullseye (V11).

* technical explanation: https://wiki.alpinelinux.org/wiki/Release_Notes_for_Alpine_3.13.0#time64_requirements
* two way to fix: https://docs.linuxserver.io/faq#libseccomp

  deb files: http://ftp.debian.org/debian/pool/main/libs/libseccomp/

A Jeedom Docker image for Raspberry Pi based on debian image.

Difference from fork:

- Update image, install a version at build time
- Use supervisor to handle cron, apache and logs. (allow proper shutdown through PID 1 signal)
- Image is ready to use
- Updated base image: debian bullseye-slim
- Added https support
- Healthcheck
- Handle services with supervisor.
- Able to redirect apache logs to stdout ( disable fail2ban as logs are not files anymore)
- At run time, can enable xdebug for dev purpose. (wip, Env var : XDEBUG=1)
- When logs are not redirected to stdout, fail2ban is protecting services.
- Admin password is resetted to admin

Please note that:

- jeedom version (V3 or v4) will be downloaded during image building, so the core project is the version at build time.
- Jeedom V3 (named release) is deprecated. Image is built, but v4 is my daily drive.
- If you wish to use zwavejs plugin, see [zwavejs](##zwaveJs) section.
- upon upgrade, if no environment variable `JEEDOM_ENC_KEY` is set, the jeedom_encryption key will be changed, and
  decryption of encrypted values will be impossible. You can either restore a jeedom backup, set the `JEEDOM_ENC_KEY`
  variable, or have a SQL update query ready to reassign these values:
  apipro, apimarket, samba::backup::password, samba::backup::ip, samba::backup::username, ldap:password, ldap:host,
  ldap:username, dns::token, api
  (field names are extracted from L27: jeedom_core:/core/class/config.class.php)
  that key can be generated (genkey core/class/config.class.php)
  using: `cat /dev/urandom | tr -dc '0-9a-zA-Z' | fold -w 32 | head -1` and mounted as a binded volume
  Plugins store encrypted values (enedis, may be others ..), so association will have to be done again.

Images are build for arm/v6, arm/v7 and amd64

This readme shows a **Dockerfile** of a dockerized [Jeedom](https://www.jeedom.com) based on a debian buster slim image.
The mysql database is based on linuxserver mariadb image on a distinct container.

Jeedom major version is given as a parameter, release if for jeedom v3, V4-stable for v4.

Docker Hub: https://hub.docker.com/r/edgd1er/jeedom-rpi

### Base Docker Images

* [linuxserver/mariadb](https://hub.docker.com/r/linuxserver/mariadb)
* [https://hub.docker.com/_/debian](https://github.com/debuerreotype/docker-debian-artifacts/blob/686d9f6eaada08a754bc7abf6f6184c65c5b378f/buster/Dockerfile)

upgrade to bullseye postponed due to plugins still using
python2.7 ( [openzwave](https://github.com/jeedom/plugin-openzwave/blob/beta/docs/en_US/index.md), maybe others ...)

According to [Jeedom's documentation](https://doc.jeedom.com/en_US/plugins/automation%20protocol/zwavejs/): "ZwaveJs:
This plugin is compatible with Debian 11 “Bullseye” and is therefore the official plugin to be preferred to manage your
Z-Wave network in Jeedom." No Hope to have Zwave plugin to be ported on bullseye. Please see [zwaveJs](##zwajeJs)
section, if you plan to us that plugin.

### Installation

the docker-compose files are proposed as an example to build a running jeedom + mysql stack.
mysql database is on a separate container.
example:

```bash
    docker-compose -f docker-compose.yml up -d
```

1. Install [Docker](https://www.docker.com/) on your Raspberry pi.

2. Rename docker-compose-armhf.yml to docker-compose.yml and define values in environment section.(mysql database,
   architecture disribution (amd64-debian, armv7hf-debian ), jeedom version (release, v4-stable), aptcacher if
   apt-cache-ng is installed, empty string if not. release is latest v3.

version values for jeedom version: v3/v4

    * service web
      image: edgd1er/jeedom-rpi:v4-latest
      or
      image: edgd1er/jeedom-rpi:v3-latest

3. build and start the stack:

```
    docker-compose -f docker-compose.yml up --build
```

4.Connect to your Raspberry IP or x86, at port 9180, or 9443 with a web browser and enjoy playing with Jeedom.

### Environment variables

The Jeedom user should be existing in the remote database.
Mysql Root password should be in the command line that run the container. If the MYSQL_JEEDOM_DBNAME schema does
not exists, it will created.
if LOGS_TO_STDOUT is set to yes, apache logs are sent to container's stdout.

```   - TZ=Europe/Paris
      - ROOT_PASSWORD shell root password
      - MYSQL_JEEDOM_HOST mysql hostname
      - MYSQL_JEEDOM_PORT mysql port
      - MYSQL_JEEDOM_DBNAME mysql Database name
      - MYSQL_JEEDOM_USERNAME mysql jeedom username
      - MYSQL_JEEDOM_PASSWD mysql username password
```

### Upgrade

To upgrade jeedom two options:

* fetch new image and create a new container, be sure to have the `JEEDOM_ENCRYPTION_KEY` env var set, so the new
  container will be able to decode data in database.
    * pros: start with a clean image. container size is reduced.
    * cons: have to re-install plugins or re-run all plugins dependancies install.Either have plugins mounted on a host directory, so you don't have to install the plugins, only dependancies are required which /root/extras.sh.
* Use jeedom's upgrade feature. be sure to disable image update.
    * cons: your container is not coming from a tested image anymore. After update the container may have problems. With time, the container's size will increase. 1 version = 1 image is not true anymore using this way to upgrade.
    * pros: no plugins dependancies to install

JEEDOM_ENCRYPTION_KEY's value is to be found in `/var/www/htmldata/jeedom_encryption.key`

* Work in progress: `/root/extras.sh`. No automatic launch, run: `/root/extras.sh` -h for help
  * Install dependancies (-d)
  * Fix pushbullet'plugin.(-p)
  * Fix meross's plugin (-p)
  * Change zwave plugin to use zwavejs-ui in an external container with a specific version (-z)
  * Change zwavejs-ui required version, disable local installation (project, node, yarm, ...). Expect a running container or service aside. export E_ZWAVEVER to set zwavejs-ui version to accept: example: export E_ZWAVEVER="9.8.2"

### Secrets

the hereunder variables may be replaced by secrets:

- JEEDOM_ENCRYPTION_KEY
- ROOT_PASSWD
- MYSQL_ROOT_PASSWD
- MYSQL_JEEDOM_PASSWD

create a file with that name in the docker-compose.yml's directory.

### https support

default certificates are generated during apache's configuration. Mounting or copying the file to /etc/ssl/certs
as shown below will expose your certificates.

```
    volumes:
      - ./webdata/cert.pem:/etc/ssl/certs/ssl-cert-snakeoil.pem:ro
      - ./webdata/privkey.pem:/etc/ssl/private/ssl-cert-snakeoil.key:ro
```

### Volumes

after each image update jeedom is installed, restoring a backup is the way to have a system as before the update.
With docker, you may use volumes to keep data through image updates.
No volumes are defined within the image.

/!\ **/var/www/html/logs** (plugins logs) and **/var/logs/** (system logs) may clutter the container. It should be
mounted in a volume.

| Container | volumes                              | content                           |
|-----------|--------------------------------------|-----------------------------------|
| Mysql     | /config                              | database config+data              |
| jeedom    | /var/log                             | system's logs                     |
| jeedom    | /var/www/html/log                    | jeedom plugins logs               |
| jeedom    | /var/www/html/plugins                | jeedom's plugins                  |
| jeedom    | /etc/ssl/certs/ssl-cert-snakeoil.pem | jeedom's https certificate        |
| jeedom    | /etc/ssl/certs/ssl-cert-snakeoil.key | jeedom's https certificate        |
| jeedom    | /var/www/html/data                   | jeedom custom data (img,css, ...) |
| jeedom    | /var/www/html/backup                 | jeedom backup dir                 |
| jeedom    | /var/www/html/tmp                    | jeedom temp dir                   |
| jeedom    | /var/www/html/log/                   | jeedom log dir                    |

### Example of a docker-compose

```
version: '3.5'
services:
  web:
    image: edgd1er/jeedom-rpi:armhf-latest
    #image: edgd1er/jeedom-rpi:amd86-latest
    restart: unless-stopped
    expose:
      - "80"
      - "443"
    ports:
      - "9180:80"
      - "9443:443"
    volumes:
      - backup:/var/www/html/backup/
      - data:/var/www/html/data/
    tmpfs:
      - /run:rw,size=10M
      - /tmp:rw,size=64M
      - /var/log:rw,size=32M
      - /var/www/html/log:rw,size=32M
    environment:
      - TZ=Europe/Paris
      - ROOT_PASSWORD=rootPassword
      - MYSQL_JEEDOM_HOST=mysql
      - MYSQL_JEEDOM_PORT=3306
      - MYSQL_JEEDOM_DBNAME=jeedom_test
      - MYSQL_JEEDOM_USERNAME=jeedom
      - MYSQL_JEEDOM_PASSWD=jeedom
    #   devices:
    #   - "/dev/ttyUSB0:/dev/ttyUSB0
    #   - "/dev/ttyACM0:/dev/ttyACM0"
    #   - "/dev/ttyAMA0:/dev/ttyAMA0"
    depends_on:
      - mysql
  mysql:
    image: linuxserver/mariadb:latest
    restart: unless-stopped
    expose:
      - "3306"
    ports:
      - "3316:3306"
    environment:
      - TZ=Europe/Paris
      - MYSQL_ROOT_PASSWORD=changeIt
      - MYSQL_DATABASE=jeedom_test
      - MYSQL_USER=jeedom
      - MYSQL_PASSWORD=jeedom
    volumes:
      - ./Docker/allow_root_access.sql:/docker-entrypoint-initdb.d/allow_root_access.sql
      #- ./sqldata:/var/lib/mysql
```

### Upgrade

in Jeedom, application, static files and configurations are not always distinct. Container needs a strict separation
between application, static files and configuration, either to mount a volume or use a bind volume.
As a result, jeedom container upgrade is not as easy as it could be. many files (static and configurations) are losts.
Here is a list of folder where either static or conf files lost after each upgrade:

- /var/www/html/data/jeedom_encryption.key
- /var/www/html/data/customTemplates/dashboard
- /var/www/html/data/img
- /var/www/html/data/fonts

## zwaveJs

At the moment, Jeedom can handle my roller shutter, fibaro plugs, stella Z radiator and fibaro door sensors. It may not
be effective or applicable to your setup.

Official plugin will install mqtt package, mqtt plugin, node, clone zwavejsUI, build a container. the plugin will start
a container to run zwaveJsui. all that add more than 600Mb in the container and add too many dependancies.

What needs to be done, to have a lighter container:

* run a mqtt container with jeedom settings in jeedom's network.
* Define an external mqtt in mqtt's plugin.
* run zwaveJsui container in jeedom's network
* alter code so plugin validates that installation, processes mqtt commands, communicates with zwaveJsUI container.

The hereafter commands will:

* remove package dependancies (node, zwave, docker run)
* alter daemon start, status so nothing is required as all requirements are external to the container.
* alter code so it will be compatible with 8.6.2's version of zwaveJsUi.
* copy mqq data and redefine mqtt plugin config.

```bash
# copy mqtt data to external folder
  docker compose cp web:/var/www/html/plugins/mqtt2/data/* mqtt/
  sed -i "s#/var/www/html/plugins/mqtt2/core/class/../../data#/mosquito/config#" /root/containers_conf/jeedom/mqtt2/mosquitto.conf
#change version expected: zwavejs/core/config/zwavejs.config.ini: wantedVersion=8.6.1
  docker-compose exec web sed -i 's#^wantedVersion=8\..\..#wantedVersion=8.11.0#' /var/www/html/plugins/zwavejs/core/config/zwavejs.config.ini
  # do not clone zwavejs ui
  docker-compose exec web sed -i -E  's/git clone --branch .*//g' /var/www/html/plugins/zwavejs/resources/pre_install.sh
  # do not install zwave js, nor dependencies
  docker-compose exec web sed -i '/npm/,+2d' /var/www/html/plugins/zwavejs/plugin_info/packages.json
  docker-compose exec web sed -i -E  's/sudo yarn.*//g' /var/www/html/plugins/zwavejs/resources/post_install.sh
  docker-compose exec web sed -i -E  's/cd zwave-js-ui//g' /var/www/html/plugins/zwavejs/resources/post_install.sh
  # zwavejs.class.php: remove yarn start / node is not local
  # remove yarn start / node is not local
  docker-compose exec web sed -i -E  's/ yarn start//g' /var/www/html/plugins/zwavejs/core/class/zwavejs.class.php
  # node is not local: simulate daemon detection
  docker-compose exec web sed -i -E  's#server/bin/www.js#php#g' /var/www/html/plugins/zwavejs/core/class/zwavejs.class.php
  # remove node modules check as project was not cloned.
  docker-compose exec web bash -c "mkdir -p /var/www/html/plugins/zwavejs/resources/zwave-js-ui/; touch /var/www/html/plugins/zwavejs/resources/zwave-js-ui/node_modules"
  #docker-compose exec web sed -i 's#/../../resources/zwave-js-ui/node_modules#/../../resources/no_zwave-js-ui#' /var/www/html/plugins/zwavejs/core/class/zwavejs.class.php
  # detect nodeID_XX as XX
  echo "in zwavejsui uncheck 'Use nodes name instead of numeric nodeIDs' in parameters"
  # log debug unknown key
  docker compose exec web sed -i "s/'\.__('Le message reçu est de type inconnu', __FILE__)/, key: '.\$key.__('. Le message reçu est de type inconnu', __FILE__)/" /var/www/html/plugins/zwavejs/core/class/zwavejs.class.php
```

## Fixes broken plugins: pushbullet, speedtest

```bash
# pushbullet: replace object with jeeObject
  docker-compose exec web sed -i 's/(object/(jeeObject/' /var/www/html/plugins/pushbullet/desktop/php/pushbullet.php
  docker-compose exec web grep -iP "\((|jee)object" /var/www/html/plugins/pushbullet/desktop/php/pushbullet.php
  # pushbullet: change tmp path
  docker-compose exec web sed -i "s#path = os.path.dirname(os.path.realpath(__file__))+'/../../../../tmp'#path = '/tmp'#" /var/www/html/plugins/pushbullet/ressources/pushbullet_daemon/pushbullet.py
  # pushbullet: activation du log du daemon
  docker-compose exec web sed -i 's#/dev/null#/var/www/html/log/pushbullet_daemon.log#' /var/www/html/plugins/pushbullet/core/class/pushbullet.class.php
  docker-compose exec web sed -i "s#/tmp/pushbullet.log#/var/www/html/log/pushbullet.log#" /var/www/html/plugins/pushbullet/ressources/pushbullet_daemon/pushbullet.py
  # pushbullet: replace obsolete websocket
  if [[ 0 -lt $(docker compose exec web bash -c "ls -l /var/www/html/plugins/pushbullet/ressources/pushbullet_daemon/websocket"| wc -l) ]]; then
    docker-compose exec web bash -c "mv /var/www/html/plugins/pushbullet/ressources/pushbullet_daemon/websocket /var/www/html/plugins/pushbullet/ressources/pushbullet_daemon/websocket.old"
  fi

  docker-compose exec web bash -c "sed -i 's#nice -n 19 /usr/bin/python #nice -n 19 /usr/bin/python3 #' /var/www/html/plugins/pushbullet/ressources/pushbullet_daemon/pushbullet.py"
  docker-compose exec web bash -c "sed -i 's# file(# open(#' /var/www/html/plugins/pushbullet/ressources/pushbullet_daemon/pushbullet.py"
  docker-compose exec web bash -c "apt-get install -y --no-install-recommends python-dev;/usr/bin/python -m pip install --upgrade pip websocket websocket-client"
  # Meross
  docker-compose exec web bash -c "apt-get install -y --no-install-recommends g++ python3-dev; pip3 install --upgrade pip meross_iot"
 ```

### Github

Githud Address : https://github.com/edgd1er/jeedom-rpi
