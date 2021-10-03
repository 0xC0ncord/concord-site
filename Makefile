OUTPUT_DIR = public

.PHONY: build clean

default: all

all: clean build

server: clean
	hugo server

clean:
	rm -rf $(OUTPUT_DIR)

build:
	hugo

release:
	hugo --minify

post:
	POST_PATH="content/posts/$(shell date +%Y)/$(shell date +%m)"; \
	POST_NAME="$(shell bash -c 'read -p "Post name?: " name; echo "$${name}"')"; \
	mkdir -p $${POST_PATH}; \
	hugo new $${POST_PATH}/$${POST_NAME}.md; \
	vi $${POST_PATH}/$${POST_NAME}.md
