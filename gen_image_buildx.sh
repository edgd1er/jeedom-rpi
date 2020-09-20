#!/usr/bin/env bash

#Variables
localDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
DKRFILE=${localDir}/Docker/Dockerfile.buildx
ARMDKRFILE=${DKRFILE}.armhf
ARCHI=$(dpkg --print-architecture)
IMAGE=jeedom-rpi
isMultiArch=$(docker buildx ls | grep -c arm)
aptcacher=$(ip route get 1 | awk '{print $7}')

#exit on error
set -xe

#Fonctions
#use buildx

# add cross build tag if we are on a x86
generateDockerfileARM() {
  if [ "${ARCHI}" != "armhf" ]; then
    sed '/^MAINTAINER .*/i RUN \[ "cross\-build-start" \]' ${DKRFILE} >${ARMDKRFILE}
    echo 'RUN [ "cross-build-end" ]' | tee -a ${ARMDKRFILE}
  fi
}

#Main
[[ "$HOSTNAME" =~ holdom2* ]] && aptCacher=""
[[ ! -f ${DKRFILE} ]] && echo -e "\nError, Dockerfile is not found\n" && exit 1
[[ $isMultiArch -eq 0 ]] && echo -e "\nError, buildx builder is not mutli arch (arm + x86_64)\n"

#generateDockerfileARM

# V3
VERSION="release"
#V4
#VERSION="V4-stable"

WHERE="--push"
WHERE="--load"
# x86
DISTRO="debian"
[[ $VERSION == "release" ]] && VERS="v3" || VERS="v4"
TAG="edgd1er/jeedom-rpi:${VERS}-latest"

aptCacher=""

PTF=linux/arm/v7
if [ "$(uname -m | cut -c1-3)" != "arm" ]; then
  PTF=linux/amd64,linux/arm64/v8,linux/arm/v7
fi

docker buildx build ${WHERE} --platform ${PTF} -f ${DKRFILE} --build-arg VERSION=$VERSION --build-arg DISTRO=$DISTRO --build-arg aptcacher=$aptcacher -t $TAG ./Docker
