.PHONY: help lint build

# Use bash for inline if-statements in arch_patch target
SHELL:=bash

# Enable BuildKit for Docker build
export DOCKER_BUILDKIT:=1
export aptCacher:=
progress:=auto #plain auto

# https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
help:
	@$(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>/dev/null | awk -v RS= -F: '/^# Fichiers/,/^# Base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | egrep -v -e '^[^[:alnum:]]' -e '^$@$$'

lint: ## stop all containers
	@echo "lint dockerfile ..."
	docker image pull hadolint/hadolint
	docker run -i --rm hadolint/hadolint < Docker/Dockerfile.buildx

buildv3: ## build v3 image
	@echo -e "build image ...v3"
	## docker-compose -f docker-compose-dev.yml build
	docker buildx build --load --progress plain --build-arg aptCacher="${aptCacher}" --build-arg VERSION="release" --build-arg DISTRO="buster-slim" -f Docker/Dockerfile.buildx -t edgd1er/jeedom-rpi:v3-latest ./Docker

build: ## build v4 image
	@echo -e "\n\nbuild image ...v4"
	docker buildx build --load --progress plain --build-arg aptCacher="${aptCacher}" --build-arg VERSION="V4-stable" --build-arg DISTRO="buster-slim" -f Docker/Dockerfile.buildx -t edgd1er/jeedom-rpi:v4-latest ./Docker

run:
	@echo "run container"
	docker-compose up
