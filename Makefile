APP := /Applications/Focus.app

.PHONY: all build run stop clean icon test

all: build

## Build Focus.app and install it to /Applications
build:
	@Scripts/build-app.sh

## Build, install and launch (replaces a running instance)
run: stop build
	@open $(APP)

## Quit a running instance
stop:
	@pkill -x Focus || true

## Re-render the app icon on the next build
icon:
	@rm -f Bundle/AppIcon.icns

clean: stop
	@rm -rf .build dist Bundle/AppIcon.icns
