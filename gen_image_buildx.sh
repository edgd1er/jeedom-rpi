#!/usr/bin/env bash

#Variables
localDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
DKRFILE=${localDir}/Docker/Dockerfile.buildx
ARCHI=$(dpkg --print-architecture)
IMAGE=jeedom-rpi
DUSER=docker_login
isMultiArch=[[ $("${ARCHI}" != "armhf" ]] && (docker buildx ls | grep -c arm))
aptCacher=$(ip route get 1 | awk '{print $7}')
#PROGRESS=plain  #text auto plain
PROGRESS=auto  #text auto plain
CACHE=""
WHERE="--load"

#exit on error
set -xe

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
#CACHE="--no-cache"

# x86
DISTRO="debian"
[[ $VERSION == "release" ]] && VERS="v3" || VERS="v4"
TAG="${DUSER}/${IMAGE}:${VERS}-latest"

if [ "${ARCHI}" == "armhf" ]; then
    PTF=linux/arm/v7
  else
    PTF=linux/amd64
    [[ $isMultiArch -gt 0 ]] && PTF=linux/arm/v7,linux/arm/v6,linux/amd64
fi

# when building multi arch, load is not possible
[[ $PTF =~ , ]] && WHERE="--push"

echo -e "\nbuilding $TAG with version $VERSION on os $DISTRO using cache $CACHE and apt cache $aptCacher \n\n"

docker buildx build ${WHERE} --platform ${PTF} -f ${DKRFILE} --build-arg VERSION=$VERSION \
--build-arg DISTRO=$DISTRO $CACHE --progress $PROGRESS --build-arg aptCacher=$aptCacher \
-t $TAG ./Docker

docker manifest inspect $TAG | grep -E "architecture|variant"
