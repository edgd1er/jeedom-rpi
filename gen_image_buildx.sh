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
set -e

#fonctions
enableMultiArch() {
  docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
  docker buildx rm amd-arm
  docker buildx create --use --name amd-arm --driver-opt image=moby/buildkit:master --platform=linux/amd64,linux/arm64,linux/386,linux/arm/v7,linux/arm/v6
  docker buildx inspect --bootstrap amd-arm
}

usage() {
  echo -e "\n$0:\t [h,l,n,p,v,x]"
  echo -e "\t-h\tHelp: cette aide"
  echo -e "\t-l\tload: load into docker only"
  echo -e "\t-n\tno-cache: force building from scratch"
  echo -e "\t-p\tpush: to docker hub"
  echo -e "\t-v\tVersion: 4 or 3"
  echo -e "\t-x\tVerbose"
}

#Main
[[ "$HOSTNAME" =~ holdom ]] && aptCacher=""
[[ ! -f ${DKRFILE} ]] && echo -e "\nError, Dockerfile is not found\n" && exit 1
[[ $isMultiArch -eq 0 ]] && echo -e "\nbuildx builder is not mutli arch (arm + x86_64)\n"

#Main
#defaults
VERSION="V4-stable"
WHERE="--load"
CACHE=""

#process options
while getopts "hlnpv:x" option; do
  case $option in
  h)
    usage
    exit 1
    ;;
  l)
    WHERE="--load"
    ;;
  n)
    CACHE="--no-cache"
    ;;
  p)
    WHERE="--push"
    ;;
  v)
    [[ 4 -eq ${OPTARG} ]] && VERSION="V4-stable"
    [[ 3 -eq ${OPTARG} ]] && VERSION="release"
    ;;
  x)
    set -x
    ;;
  esac
done


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

echo -e "\nWhere: \e[32m$WHERE\e[0m,  building \e[32m$TAG\e[0m with version \e[32m$VERSION\e[0m on os \e[32m$DISTRO\e[0m using cache \e[32m$CACHE\e[0m and apt cache \e[32m$aptCacher\e[0m for platform \e[32m${PTF}\e[0m\n\n"

docker buildx build ${WHERE} --platform ${PTF} -f ${DKRFILE} --build-arg VERSION=$VERSION \
--build-arg DISTRO=$DISTRO $CACHE --progress $PROGRESS --build-arg aptCacher=$aptCacher \
-t $TAG ./Docker

if [[ "docker_login" != "${DUSER}" ]]; then
  docker manifest inspect $TAG | grep -iE "architecture|variant"
  else
  docker inspect $TAG | grep -iE "architecture|variant"
  docker image ls |grep jeedom
fi
