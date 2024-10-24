.PHONY: help lint build

# Use bash for inline if-statements in arch_patch target
SHELL:=bash

# Enable BuildKit for Docker build
export DOCKER_BUILDKIT:=1
export aptCacher:=192.168.53.208
#export aptCacher:=""
progress:=auto #plain auto

# https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
help:
	@$(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>/dev/null | awk -v RS= -F: '/^# Fichiers/,/^# Base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | egrep -v -e '^[^[:alnum:]]' -e '^$@$$'

lint: ## stop all containers
	@echo "lint dockerfile ..."
	docker image pull hadolint/hadolint
	docker run -i --rm hadolint/hadolint < Docker/Dockerfile

buildv3: ## build v3 image
	@echo -e "build image ...v3"
	## docker-compose -f docker-compose-dev.yml build
	docker buildx build --load --progress plain --build-arg aptCacher="${aptCacher}" --build-arg VERSION="release" --build-arg DISTRO="buster-slim" -f Docker/Dockerfile.v3 -t edgd1er/jeedom-rpi:v3-latest ./Docker

build: ## build v4 image with bullseye
	@echo -e "\n\nbuild image ...v4"
	docker buildx build --load --progress plain --build-arg aptCacher="${aptCacher}" --build-arg VERSION="master" --build-arg DISTRO="bullseye-slim" -f Docker/Dockerfile -t edgd1er/jeedom-rpi:v4-latest ./Docker

buildb: ## build v4 image with buster
	@echo -e "\n\nbuild image ...v4 buster"
	docker buildx build --load --progress plain --build-arg aptCacher="${aptCacher}" --build-arg VERSION="master" --build-arg DISTRO="buster-slim" -f Docker/Dockerfile -t edgd1er/jeedom-rpi:buster-v4-latest ./Docker

alpha: ## build v4 alpha image --no-cache
	@echo -e "\n\nbuild image ...v4 alpha"
	docker buildx build --load --progress plain --build-arg aptCacher="${aptCacher}" --build-arg VERSION="alpha" --build-arg DISTRO="bookworm-slim" -f Docker/Dockerfile -t edgd1er/jeedom-rpi:alpha ./Docker

beta: ## build v4 beta image --no-cache
	@echo -e "\n\nbuild image ...v4 beta" --no-cache
	docker buildx build --load --progress plain  --build-arg aptCacher="${aptCacher}" --build-arg VERSION="beta" --build-arg DISTRO="bookworm-slim" -f Docker/Dockerfile -t edgd1er/jeedom-rpi:beta ./Docker

ver: ## check version
	@JDM_VER=$$( grep -oP "(?<=v)4\.[0-9\.]+" README.md |head -1) ; \
	jdm=$$( curl -s "https://raw.githubusercontent.com/jeedom/core/master/core/config/version"); \
	zwave=$$( curl -s "https://api.github.com/repos/zwave-js/zwave-js-ui/releases/latest" | jq -r .tag_name) ; \
	ZWAVE_VER=$$(grep -oP "(?<=ZWAVE_VERSION: ).+" .github/workflows/checkVersion.yml) ; \
	echo "v4 Jeedom local: $${JDM_VER} remote: $${jdm}" ; \
	jdmb=$$( curl -s "https://raw.githubusercontent.com/jeedom/core/beta/core/config/version"); \
	jdma=$$( curl -s "https://raw.githubusercontent.com/jeedom/core/alpha/core/config/version"); \
	echo "alpha: $${jdma}, beta: $${jdmb}" ; \
	echo "Zwave-ui-js local: $${ZWAVE_VER} remote: $${zwave#v*}" ; \
	if [[ $${jdm} != $${JDM_VER} ]]; then \
	  echo "Jeedom update detected: https://raw.githubusercontent.com/jeedom/core/master/core/config/version" ;\
	  sed -i -E "s/#JDM_VERSION:.+/#JDM_VERSION: $${jdm}/" docker-compose.yml; \
	  fi ; \
	if [[ $${zwave} != v$${ZWAVE_VER} ]]; then \
	  echo "zwave-js-ui update detected: https://raw.githubusercontent.com/zwave-js/zwave-js-ui/"; \
	  sed -i -E "s/ ZWAVE_VERSION:.+/ ZWAVE_VERSION: $${zwave#v*}/" .github/workflows/checkVersion.yml; \
	  sed -i -E "s/E_ZWAVEVER:-\".+/E_ZWAVEVER:-\"$${zwave#v*}\"}/" Docker/extras.sh; fi ;

run:
	@echo "run container"
	docker compose up --build
