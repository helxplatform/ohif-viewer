# Makefile for building the HeLx OHIF Viewer image.
#
# Run from this directory (`make build`) or from the repo root
# (`make -C .helx build`). The Docker build context is always the repo root.
#
# Adapted from the equivalent Makefile in helxplatform/rstudio-server, which in
# turn came from https://gist.github.com/mpneuried/0594963ad38e68917ef189b4e6a269db
#
# Change the default config with `make cnf="config_special.env" build`.
cnf ?= config.env
include $(cnf)
export $(shell sed 's/=.*//' $(cnf))

HELX_DIR := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
ROOT_DIR := $(abspath $(HELX_DIR)/..)
DOCKERFILE := $(HELX_DIR)/Dockerfile

# Stage 1 is upstream's own `builder` stage, built from the repo-root
# Dockerfile so the recipe for building the viewer is not duplicated here.
UPSTREAM_DOCKERFILE := $(ROOT_DIR)/Dockerfile
BUILDER_IMAGE := $(APP_NAME)-builder

GIT := git -C $(ROOT_DIR)
DATETIME := $(shell /bin/date "+%Y%m%d%H%M")
COMMIT_HASH := $(shell $(GIT) rev-parse --short HEAD)
COMMIT_DATETIME := $(shell $(GIT) log -1 --format=%cd --date=format:"%Y%m%d%H%M")
CURRENT_BRANCH := $(shell $(GIT) branch --show-current)
ifneq ($(shell $(GIT) status --porcelain),)
	# add the date/time and '-dirty' if the tree is dirty
	COMMIT_HASH := $(COMMIT_HASH)-$(DATETIME)-dirty
else
	# add the commit date/time if the tree is clean
	COMMIT_HASH := $(COMMIT_HASH)-$(COMMIT_DATETIME)
endif

BUILDER_BUILD_ARGS := --build-arg PUBLIC_URL=$(PUBLIC_URL_SENTINEL) \
                      --build-arg APP_CONFIG=$(APP_CONFIG)

BUILD_ARGS := --build-arg BUILDER_IMAGE=$(BUILDER_IMAGE) \
              --build-arg PUBLIC_URL=$(PUBLIC_URL_SENTINEL) \
              --build-arg HELX_PORT=$(CONTAINER_PORT)

.PHONY: help builder builder-nc build build-nc run shell stop release publish \
	publish-branch publish-latest publish-short-hash publish-version tag \
	tag-branch tag-latest tag-short-hash tag-version clean docker-clean

# HELP
# Outputs the help for each task.
# thanks to https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
help: ## This help.
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.DEFAULT_GOAL := help

builder: ## Build stage 1: upstream's `builder` stage, with the sentinel prefix.
	docker build --platform=$(PLATFORM) --progress=plain \
	  -f $(UPSTREAM_DOCKERFILE) --target builder $(BUILDER_BUILD_ARGS) \
	  -t $(BUILDER_IMAGE) $(ROOT_DIR)

builder-nc: ## Build stage 1 without caching.
	docker build --no-cache --platform=$(PLATFORM) --progress=plain \
	  -f $(UPSTREAM_DOCKERFILE) --target builder $(BUILDER_BUILD_ARGS) \
	  -t $(BUILDER_IMAGE) $(ROOT_DIR)

build: builder ## Build the image (both stages).
	docker build --platform=$(PLATFORM) --progress=plain \
	  -f $(DOCKERFILE) $(BUILD_ARGS) -t $(APP_NAME) $(ROOT_DIR)

build-nc: builder-nc ## Build the image without caching.
	docker build --no-cache --platform=$(PLATFORM) --progress=plain \
	  -f $(DOCKERFILE) $(BUILD_ARGS) -t $(APP_NAME) $(ROOT_DIR)

run: ## Run the container on the port configured in `config.env`.
	docker run -i -t --rm --env-file=$(HELX_DIR)/$(DOCKER_RUN_ENV_FILE) \
	  -u $(UID):$(GID) -p=$(HOST_PORT):$(CONTAINER_PORT) \
	  --name="$(APP_NAME)" $(APP_NAME)

shell: ## Open a shell in the image, bypassing the entrypoint.
	docker run -i -t --rm --env-file=$(HELX_DIR)/$(DOCKER_RUN_ENV_FILE) \
	  -u $(UID):$(GID) --entrypoint=/bin/sh $(APP_NAME)

up: build run ## Build, then run (alias for `build run`).

stop: ## Stop and remove a running container.
	docker stop $(APP_NAME); docker rm $(APP_NAME)

release: build-nc publish ## Build from scratch and publish.

# Docker publish
publish: publish-latest publish-branch publish-short-hash ## Publish tags
	@echo 'publish tags latest $(CURRENT_BRANCH) $(COMMIT_HASH) to $(IMAGE_REPO)'

publish-latest: tag-latest ## Publish the `latest` tagged container.
	@echo 'publish latest to $(IMAGE_REPO)'
	docker push $(IMAGE_REPO)/$(APP_NAME):latest

publish-branch: tag-branch ## Publish the `{CURRENT_BRANCH}` tagged container.
	@echo 'publish $(CURRENT_BRANCH) to $(IMAGE_REPO)'
	docker push $(IMAGE_REPO)/$(APP_NAME):$(CURRENT_BRANCH)

publish-short-hash: tag-short-hash ## Publish the short-hash tagged container.
	@echo 'publish $(COMMIT_HASH) to $(IMAGE_REPO)'
	docker push $(IMAGE_REPO)/$(APP_NAME):$(COMMIT_HASH)

publish-version: tag-version ## Publish the `{VERSION}` tagged container.
	@echo 'publish $(VERSION) to $(IMAGE_REPO)'
	docker push $(IMAGE_REPO)/$(APP_NAME):$(VERSION)

# Docker tagging
tag: tag-latest tag-branch tag-short-hash tag-version ## Generate container tags

tag-latest: ## Generate container `latest` tag
	@echo 'create tag latest'
	docker tag $(APP_NAME) $(IMAGE_REPO)/$(APP_NAME):latest

tag-branch: ## Generate container `{CURRENT_BRANCH}` tag
	@echo 'create tag $(CURRENT_BRANCH)'
	docker tag $(APP_NAME) $(IMAGE_REPO)/$(APP_NAME):$(CURRENT_BRANCH)

tag-short-hash: ## Generate container short-hash tag from the last commit, or the current datetime if the tree is dirty
	@echo 'create tag $(COMMIT_HASH)'
	docker tag $(APP_NAME) $(IMAGE_REPO)/$(APP_NAME):$(COMMIT_HASH)

tag-version: ## Generate container `{VERSION}` tag
	@echo 'create tag $(VERSION)'
	docker tag $(APP_NAME) $(IMAGE_REPO)/$(APP_NAME):$(VERSION)

clean: ## Remove the images built here. The builder image is several GB.
	docker rmi -f $(APP_NAME) $(BUILDER_IMAGE)

docker-clean: ## Prune unused images, containers, and networks from the local Docker system.
	docker system prune -f
