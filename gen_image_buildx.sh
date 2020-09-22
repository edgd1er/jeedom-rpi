#!/usr/bin/env bash

#Variables
localDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
DKRFILE=${localDir}/Docker/Dockerfile.buildx
ARMDKRFILE=${DKRFILE}.armhf
ARCHI=$(dpkg --print-architecture)
IMAGE=jeedom-rpi
DUSER=edgd1er
isMultiArch=$("${ARCHI}" != "armhf" ]] && (docker buildx ls | grep -c arm))
aptCacher=$(ip route get 1 | awk '{print $7}')
PROGRESS=plain  #text auto plain
CACHE=""
WHERE="--load"

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
[[ "$HOSTNAME" =~ holdom ]] && aptCacher=""
[[ ! -f ${DKRFILE} ]] && echo -e "\nError, Dockerfile is not found\n" && exit 1
[[ $isMultiArch -eq 0 ]] && echo -e "\nbuildx builder is not mutli arch (arm + x86_64)\n"
#generateDockerfileARM

# V3
#VERSION="release"
#V4
VERSION="V4-stable"

#WHERE="--push"
WHERE="--output=type=docker"
CACHE="--no-cache"

# x86
DISTRO="debian"
[[ $VERSION == "release" ]] && VERS="v3" || VERS="v4"
TAG="${DUSER}/${IMAGE}:${VERS}-latest"

if [ "${ARCHI}" == "armhf" ]; then
    PTF=linux/arm/v7
  else
    PTF=linux/amd64
    #PTF=linux/arm/v7,linux/arm/v6
fi

# building process to long for multi pf building in one command
# => ERROR exporting to oci image format                                                                                                             0.0s
#------
# > exporting to oci image format:
#------
#failed to solve: rpc error: code = Unknown desc = docker exporter does not currently support exporting manifest lists

echo -e "\nbuilding $TAG with version $VERSION on os $DISTRO using cache $CACHE and apt cache $aptCacher \n\n"

docker buildx build ${WHERE} --platform ${PTF} -f ${DKRFILE} --build-arg VERSION=$VERSION \
--build-arg DISTRO=$DISTRO $CACHE --progress $PROGRESS --build-arg aptCacher=$aptCacher \
-t $TAG ./Docker

if [ "$(uname -m | cut -c1-3)" != "arm" ]; then
  #PTF=linux/amd64,linux/arm/v7
  PTF=linux/arm/v7
  #PTF=linux/amd64,linux/arm64/v8,linux/arm/v6,linux/arm/v7
  echo -e "\nadding ARM architecture to build: $PTF\n"
docker buildx build ${WHERE} --platform ${PTF} -f ${DKRFILE} --build-arg VERSION=$VERSION \
--build-arg DISTRO=$DISTRO $CACHE --progress $PROGRESS --build-arg aptCacher=$aptCacher \
-t $TAG ./Docker
fi

docker manifest inspect $TAG | grep -E "architecture|variant"
