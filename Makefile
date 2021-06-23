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
