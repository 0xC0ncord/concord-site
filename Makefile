NO_COLOR = \033[0m
O1_COLOR = \033[0;01m
O2_COLOR = \033[32;01m

PREFIX = "$(O2_COLOR)==>$(O1_COLOR)"
SUFFIX = "$(NO_COLOR)"

MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
OUTPUT_DIR = public

.PHONY: setup server clean build release post

default: build

setup:
	@echo -e $(PREFIX) $@ $(SUFFIX)
	cd $(MAKEFILE_DIR)

clean: setup
	@echo -e $(PREFIX) $@ $(SUFFIX)
	rm -rf $(OUTPUT_DIR) .hugo_build.lock

build: setup clean
	@echo -e $(PREFIX) $@ $(SUFFIX)
	hugo

release: setup clean
	@echo -e $(PREFIX) $@ $(SUFFIX)
	hugo --minify

server: setup clean
	@echo -e $(PREFIX) $@ $(SUFFIX)
	hugo server

post: setup
	@echo -e $(PREFIX) $@ $(SUFFIX)
	POST_PATH="content/posts/$(shell date +%Y)/$(shell date +%m)"; \
	POST_NAME="$(shell bash -c 'read -p "Post name?: " name; echo "$${name}"')"; \
	mkdir -p $${POST_PATH}; \
	hugo new $${POST_PATH}/$${POST_NAME}.md; \
	vi $${POST_PATH}/$${POST_NAME}.md
