Forked from https://github.com/CodaFog/jeedom-rpi

# jeedom-rpi
![Docker CI buildx armhf+amd64 v3](https://github.com/edgd1er/jeedom-rpi/workflows/Docker%20CI%20buildx%20armhf+amd64%20v3/badge.svg?branch=master)
![Docker CI buildx armhf+amd64 v4](https://github.com/edgd1er/jeedom-rpi/workflows/Docker%20CI%20buildx%20armhf+amd64%20v4/badge.svg?branch=master)

[![GitHub issues](https://img.shields.io/github/issues/edgd1er/jeedom-rpi.svg)](https://GitHub.com/edgd1er/jeedom_rpi.js/issues/)
[![Docker Stars](https://img.shields.io/docker/stars/edgd1er/jeedom-rpi.svg?maxAge=604800)](https://store.docker.com/community/images/edgd1er/jeedom-rpi)
[![Docker Pulls](https://img.shields.io/docker/pulls/edgd1er/jeedom-rpi.svg?maxAge=604800)](https://store.docker.com/community/images/edgd1er/jeedom-rpi)

last build: 21/02/19 (V4.1.20, V3.3.55)

A Jeedom Docker image for Raspberry Pi based on debian image.

Difference from fork:
- update image, install a version at build time
- use supervisor to handle cron, apache and logs. (allow proper shutdown through PID 1 signal)
- image is ready to use 
- updated base image (buster-slim)
- added https support
- healthcheck
- handle services with supervisor.
- able to redirect apache logs to stdout
- at run time, can enable xdebug for dev purpose. (Env var : XDEBUG=1)

Please note that:
- jeedom version (V3 or v4) will be downloaded during image building, so the core project is the version at build time.
- upon upgrade, the jeedom_encryption key will be changed, and decryption of encrypted values will be impossible. You can either restore a jeedom backup, save that key and put it back, or have a SQL update query ready to reassign theese values:
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
As a result, jeedom container upgrade is not transparent. many files (static and configurations) are losts. Here is a list of folder where either static or conf files are found:

- /var/www/html/data/jeedom_encryption.key


### Github

Githud Address : https://github.com/edgd1er/jeedom-rpi
