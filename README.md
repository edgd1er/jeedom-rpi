# Jeedom-rpi

![Docker CI buildx armhf+amd64 v3](https://github.com/edgd1er/jeedom-rpi/workflows/Docker%20CI%20buildx%20armhf+amd64%20v3/badge.svg?branch=master)
![Docker CI buildx armhf+amd64 v4](https://github.com/edgd1er/jeedom-rpi/workflows/Docker%20CI%20buildx%20armhf+amd64%20v4/badge.svg?branch=master)

![gh issues](https://badgen.net/github/open-issues/edgd1er/jeedom-rpi?icon=github&label=issues)
![Docker Pulls](https://badgen.net/docker/pulls/edgd1er/jeedom-rpi?icon=docker&label=pulls)
![Docker Stars](https://badgen.net/docker/stars/edgd1er/jeedom-rpi?icon=docker&label=stars)

![Docker Size v4](https://badgen.net/docker/size/edgd1er/jeedom-rpi/v4-latest?icon=docker&label=Docker%20size%20v4)
![ImageLayers v4](https://badgen.net/docker/layers/edgd1er/jeedom-rpi/v4-latest?icon=docker&label=Docker%20layers%20v4)

![Docker Size v3](https://badgen.net/docker/size/edgd1er/jeedom-rpi/v3-latest?icon=docker&label=Docker%20size%20v3)
![ImageLayers v3](https://badgen.net/docker/layers/edgd1er/jeedom-rpi/v4-latest?icon=docker&label=Docker%20layers%20v3)


Forked from https://github.com/CodaFog/jeedom-rpi

last build: 22/05/17 ([V4.2.16](https://github.com/jeedom/core/blob/V4-stable/core/config/version), [V3.3.59](https://github.com/jeedom/core/blob/master/core/config/version))

Please read [changelog](https://doc.jeedom.com/en_US/core/4.2/changelog?theme=light#Changelog%20Jeedom%20V4.2) form breaking changes in features

/!\ asof 2021/08/26, mysql image based on alpin:3.13 which require an updated libseccomp2 on the host (rpi) that rasbian does not have at the moment. 
* technical explanation: https://wiki.alpinelinux.org/wiki/Release_Notes_for_Alpine_3.13.0#time64_requirements
* two way to fix: https://docs.linuxserver.io/faq#libseccomp
  
  deb files: http://ftp.debian.org/debian/pool/main/libs/libseccomp/

A Jeedom Docker image for Raspberry Pi based on debian image.

Difference from fork:
- Update image, install a version at build time
- Use supervisor to handle cron, apache and logs. (allow proper shutdown through PID 1 signal)
- Image is ready to use 
- Updated base image (buster-slim)
- Added https support
- Healthcheck
- Handle services with supervisor.
- Able to redirect apache logs to stdout ( disable fail2ban as logs are not files anymore)
- At run time, can enable xdebug for dev purpose. (Env var : XDEBUG=1)
- When logs are note redirected to stdout, fail2ban is protecting services.
- Admin password is resetted to admin

Please note that:
- jeedom version (V3 or v4) will be downloaded during image building, so the core project is the version at build time.
- Jeedom V3 (named release) is deprecated. Image is built, but v4 is my daily drive.  
- upon upgrade, if no environment variable `JEEDOM_ENC_KEY` is set, the jeedom_encryption key will be changed, and decryption of encrypted values will be impossible. You can either restore a jeedom backup, set the `JEEDOM_ENC_KEY` variable, or have a SQL update query ready to reassign these values:
  apipro, apimarket, samba::backup::password, samba::backup::ip, samba::backup::username, ldap:password, ldap:host, ldap:username, dns::token, api
  (field names are extracted from L27: jeedom_core:/core/class/config.class.php)
  that key can be generated (genkey core/class/config.class.php) using: `cat /dev/urandom | tr -dc '0-9a-zA-Z' | fold -w 32 | head -1` and mounted as a binded volume
  Plugins store encrypted values (enedis, may be others ..), so association will have to be done again.


Images are build for arm/v6, arm/v7 and amd64

This readme shows a **Dockerfile** of a dockerized [Jeedom](https://www.jeedom.com) based on a debian buster slim image. 
The mysql database is based on linuxserver mariadb image on a distinct container.

Jeedom major version is given as a parameter, release if for jeedom v3, V4-stable for v4.

Docker Hub: https://hub.docker.com/r/edgd1er/jeedom-rpi

### Base Docker Images

* [linuxserver/mariadb](https://hub.docker.com/r/linuxserver/mariadb)
* [https://hub.docker.com/_/debian](https://www.balena.io/docs/reference/base-images/base-images/?ref=dockerhub)


### Installation

the docker-compose files are proposed as an example to build a running jeedom + mysql stack. 
mysql database is on a separate container.
example:

```bash
    docker-compose -f docker-compose.yml up -d
```

1. Install [Docker](https://www.docker.com/) on your Raspberry pi.

2. Rename docker-compose-armhf.yml to docker-compose.yml and define values in environment section.(mysql database, architecture disribution (amd64-debian, armv7hf-debian ), jeedom version (release, v4-stable), aptcacher if apt-cache-ng is installed, empty string if not. release is latest v3.

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

/!\ **/var/www/html/logs** (plugins logs) and **/var/logs/** (system logs) may clutter the container. It should be mounted in a volume.

|Container|volumes|content|
|---------|-------|------|
|Mysql|/config| database config+data|
|jeedom|/var/log|system's logs|
|jeedom|/var/www/html/log|jeedom plugins logs|
|jeedom|/var/www/html/plugins|jeedom's plugins|
|jeedom|/etc/ssl/certs/ssl-cert-snakeoil.pem|jeedom's https certificate|
|jeedom|/etc/ssl/certs/ssl-cert-snakeoil.key|jeedom's https certificate|

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

in Jeedom, application, static files and configurations are not always distinct. Container needs a strict separation between application, static files and configuration, either to mount a volume or use a bind volume.
As a result, jeedom container upgrade is not as easy as it could be. many files (static and configurations) are losts. Here is a list of folder where either static or conf files lost after each upgrade:

- /var/www/html/data/jeedom_encryption.key
- /var/www/html/data/customTemplates/dashboard
- /var/www/html/data/img
- /var/www/html/data/fonts

## Fixes broken plugins: pushbullet, speedtest

```bash
# pushbullet: replace object with jeeObject
docker-compose exec web sed -i 's/(object/(jeeObject/' /var/www/html/plugins/pushbullet/desktop/php/pushbullet.php
# pushbullet: replace obsolete websocket
docker-compose exec web bash mv /var/www/html/plugins/pushbullet/ressources/pushbullet_daemon/websocket /var/www/html/plugins/pushbullet/ressources/pushbullet_daemon/websocket.old
docker-compose exec web pip install websocket-client

#speedclient : change client version check to match current version
docker-compose exec web sed -Ei "s/line == 'Version: 2.[0-9].[0-9a-z]{1,3}/line == 'Version: 2.1.4b1'/" /var/www/html/plugins/speedtest/core/class/speedtest.class.php
docker-compose exec web grep -H "line == 'Version" /var/www/html/plugins/speedtest/core/class/speedtest.class.php
```

### Github

Githud Address : https://github.com/edgd1er/jeedom-rpi
