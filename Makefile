NO_COLOR = \033[0m
O1_COLOR = \033[0;01m
O2_COLOR = \033[32;01m

PREFIX = "$(O2_COLOR)==>$(O1_COLOR)"
SUFFIX = "$(NO_COLOR)"

MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
OUTPUT_DIR = public

DEPLOY_HOST := concord.sh
DEPLOY_DIR := /var/www/concord/htdocs
DEPLOY_OWNER := root:nginx
DEPLOY_PERMS := u=rwX,go=rX
DEPLOY_SELINUX := 1

.PHONY: setup server clean build release post deploy

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

deploy: release
	@echo -e $(PREFIX) $@ $(SUFFIX)
	scp -r $(OUTPUT_DIR) $(DEPLOY_HOST):.tmp-deploy
	ssh -t $(DEPLOY_HOST) "sudo -p '(%u@%H) sudo password: ' -- sh -c 'rm -vrf $(DEPLOY_DIR) && \
		mv -v /home/$$USER/.tmp-deploy $(DEPLOY_DIR) && \
		chown -Rv $(DEPLOY_OWNER) $(DEPLOY_DIR) && \
		chmod -Rv $(DEPLOY_PERMS) $(DEPLOY_DIR) && \
		([ "$(DEPLOY_SELINUX)" == "1" ] && restorecon -RFv $(DEPLOY_DIR))'"
