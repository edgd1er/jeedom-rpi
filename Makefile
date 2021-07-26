.PHONY: help lint build

# Use bash for inline if-statements in arch_patch target
SHELL:=bash

# Enable BuildKit for Docker build
export DOCKER_BUILDKIT:=1


# https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
help:

lint: ## stop all containers
	@echo "lint dockerfile ..."
	docker run -i --rm hadolint/hadolint < Docker/Dockerfile.buildx

build: ## build image
	@echo "build image ..."
	docker-compose -f docker-compose-dev.yml build

run:
	@echo "run container"
	docker-compose up
