#!/usr/bin/env bash

#Variables
localDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
DKRFILE=${localDir}/Docker/Dockerfile
ARMDKRFILE=${DKRFILE}.armhf
ARCHI=$(dpkg --print-architecture)
IMAGE=jeedom-rpi

aptCacher=$(ip route get 1 | awk '{print $7}')
aptCacher=

#Fonctions

#function
# add cross build tag if we are on a x86
generateDockerfileARM(){
    if [ "${ARCHI}" != "armhf" ]; then
        sed '/^MAINTAINER .*/i RUN \[ "cross\-build-start" \]' ${DKRFILE} > ${ARMDKRFILE}
        echo 'RUN [ "cross-build-end" ]' | tee -a ${ARMDKRFILE}
    fi
}

#Main
[[ ! -f ${DKRFILE} ]] && echo -e "\nError, Dockerfile is not found\n" && exit 1
generateDockerfileARM

# V3
VERSION="release"
#V4
#VERSION="V4-stable"

# x86
DISTRO="amd64-debian"
[[ $VERSION == "release"  ]] && VERS="v3" || VERS="v4"
TAG="edgd1er/jeedom-rpi:${VERS}-${DISTRO%%-*}-latest"

if [ "$(uname -m | cut -c1-3)" != "arm" ]; then
    docker build --load -f ${DKRFILE} --build-arg VERSION=$VERSION --build-arg DISTRO=$DISTRO --build-arg aptCacher=$aptCacher -t $TAG ./Docker
    #[[ $? ]] && docker push $TAG
fi

# armhf
DISTRO="armv7hf-debian"
[[ $VERSION == "release"  ]] && VERS="v3" || VERS="v4"
TAG="edgd1er/jeedom-rpi:${VERS}-${DISTRO%%-*}-latest"
docker build --load -f ${ARMDKRFILE} --build-arg VERSION=$VERSION --build-arg DISTRO=$DISTRO --build-arg aptCacher=$aptCacher -t $TAG ./Docker
#[[ $? ]] && docker push $TAG

exit
#Build
#docker build --cpu-shares 512 -f Dockerfile.armhf -t edgd1er/jeedom-rpi:armhf-latest .
