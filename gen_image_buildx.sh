#!/usr/bin/env bash

# Local build for images tests
# multi arch possible for arm/V[6-7], amd64

#Variables
localDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
DKRFILE=${localDir}/Docker/Dockerfile.buildx
ARCHI=$(dpkg --print-architecture)
IMAGE=jeedom-rpi
DUSER=docker_login
[[ "${ARCHI}" != "armhf" ]] && isMultiArch=$(docker buildx ls | grep -c arm)
aptCacher=$(ip route get 1 | awk '{print $7}')
#PROGRESS=plain  #text auto plain
PROGRESS=auto  #text auto plain
#cache "--no-cache"
CACHE=""
# load => sdocker, push => registry
WHERE="--load"

#exit on error
set -xe

#fonctions
enableMultiArch() {
  docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
  docker buildx rm amd-arm
  docker buildx create --use --name amd-arm --driver-opt image=moby/buildkit:master --platform=linux/amd64,linux/arm64,linux/386,linux/arm/v7,linux/arm/v6
  docker buildx inspect --bootstrap amd-arm
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
WHERE="--push"
WHERE="--load"
#CACHE="--no-cache"

# x86
DISTRO="debian"
[[ $VERSION == "release" ]] && VERS="v3" || VERS="v4"
TAG="${IMAGE}:${VERS}-latest"
[[ "docker_login" != ${DUSER} ]] && TAG=${DUSER}/${TAG}

PTF=linux/arm/v7
#build multi arch images
if [ "${ARCHI}" == "amd64" ]; then
  PTF=linux/amd64
  # load is not compatible with multi arch build
  if [[ $WHERE == "--push" ]]; then
    PTF+=,linux/amd64,linux/arm64/v8,linux/arm/v7,linux/arm/v6
    #enable multi arch build framework
    [[ $isMultiArch -eq 0 ]] && enableMultiArch
  fi
fi

# when building multi arch, load is not possible
#[[ $PTF =~ , ]] && WHERE="--push"

echo -e "\nbuilding $TAG with version $VERSION on os $DISTRO using cache $CACHE and apt cache $aptCacher \n\n"

docker buildx build ${WHERE} --platform ${PTF} -f ${DKRFILE} --build-arg VERSION=$VERSION \
--build-arg DISTRO=$DISTRO $CACHE --progress $PROGRESS --build-arg aptCacher=$aptCacher \
-t $TAG ./Docker

if [[ "docker_login" != ${DUSER} ]]; then
  docker manifest inspect $TAG | grep -iE "architecture|variant"
  else
  docker inspect $TAG | grep -iE "architecture|variant"
  docker image ls |grep jeedom
fi
