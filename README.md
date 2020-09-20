Forked from https://github.com/CodaFog/jeedom-rpi

updated base image, added https support, healtcheck, handle services with supervisor.

Please note that jeedom version (V3 or v4) will be downloaded during install, so the core project is not requested in that branch. 

# jeedom-rpi

![Docker CI armhf+amd64 v3](https://github.com/edgd1er/jeedom-rpi/workflows/Docker%20CI%20armhf+amd64%20v3/badge.svg?branch=master)
![Docker CI armhf+amd64 v4](https://github.com/edgd1er/jeedom-rpi/workflows/Docker%20CI%20armhf+amd64%20v4/badge.svg?branch=master)

![.github/workflows/dockerimage-buildx-v3.yml](https://github.com/edgd1er/jeedom-rpi/workflows/.github/workflows/dockerimage-buildx-v3.yml/badge.svg)
![.github/workflows/dockerimage-buildx-v4.yml](https://github.com/edgd1er/jeedom-rpi/workflows/.github/workflows/dockerimage-buildx-v4.yml/badge.svg)

A Jeedom Docker image for Raspberry Pi based on balenalib and Hypriot mysql images.

This readme shows a **Dockerfile** of a dockerized [Jeedom](https://www.jeedom.com) based on a balena image. 
The mysql database is based on linuxserver mariadb image on a distinct container.

Jeedom major version is given as a parameter, minor version is the latest from release(v3) or V4-stable branches, at the timeof building
a amd64 version is proposed to test on intel cpu the container.

Docker Hub: https://hub.docker.com/r/edgd1er/jeedom-rpi


### Base Docker Images

* [linuxserver/mariadb](https://hub.docker.com/r/linuxserver/mariadb)
* [balenalib/armv7hf-debian:stretch-run](https://www.balena.io/docs/reference/base-images/base-images/?ref=dockerhub)


### Installation

the docker-compose files are proposed as an example to build a running jeedom + mysql stack. mysql database is on a separate container. There is a docker-compose-test to overload the docker-compose-armhf.yml file to test building on a x86 cpu.
example:
```bash
    docker-compose -f docker-compose-armhf.yml -f docker-compose-test.yml build
```

1. Install [Docker](https://www.docker.com/) on your Raspberry pi.

2. Rename docker-compose-test.yml to docker-compose.yml and define values in environment section.(mysql database, architecture disribution (amd64-debian, armv7hf-debian ), jeedom version (release, v4-stable), aptcacher if apt-cache-ng is installed, empty string if not. release is latest v3.

Values for armhf (-armhf.yml):

    * web
        * image: edgd1er/jeedom-rpi:armhf-latest
    * mysql
        * image: linuxserver/mariadb:arm32v7-latest
values for x86 (-test.yml)

    * web
        * image: edgd1er/jeedom-rpi:amd64-latest
    * mysql
        * image: mariadb/server
3.a build and start the stack for rapsberry:
```
    docker-compose -f docker-compose-armhf.yml build
    docker-compose -f docker-compose-armhf.yml up -d
```
3.b Start the stack for x86:
```
    docker-compose -f docker-compose-armhf.yml -f docker-compose-test.yml build
    docker-compose -f docker-compose-armhf.yml -f docker-compose-test.yml up -d
```
4.Connect to your Raspberry IP or x86, at port 9180, or 9443 with a web browser and enjoy playing with Jeedom.

### Environnement variables

The Jeedom user should be existing in the remote database. If the MYSQL_ERASE is set to yes, Mysql Root password should be in the command line that run the container. If the MYSQL_JEEDOM_DBNAME exists, it will then be dropped and recreated.

```   - TZ=Europe/Paris
      - ROOT_PASSWORD shell root password
      - MYSQL_JEEDOM_HOST mysql hostname
      - MYSQL_JEEDOM_PORT mysql port
      - MYSQL_JEEDOM_DBNAME mysql Database name
      - MYSQL_JEEDOM_USERNAME mysql jeedom username
      - MYSQL_JEEDOM_PASSWD mysql username password
```


### Example of a docker-compose

```
version: '3.5'
services:
  web:
    image: edgd1er/jeedom-rpi:armhf-latest
    #image: edgd1er/jeedom-rpi:amd86-latest
    restart: unless-stopped
    build:
      context: Docker
      dockerfile: Dockerfile
      args:
        #DISTRO: "amd64-debian"
        DISTRO: armv7hf-debian
        VERSION: release
        #version: v4-stable
        #aptcacher: 192.168.53.208
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
    #image: linuxserver/mariadb:arm32v7-latest
    image: mariadb/server
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

### Github

Githud Address : https://github.com/edgd1er/jeedom-rpi
