APP := dist/Focus.app

.PHONY: all build run install stop clean icon test

all: build

## Build Focus.app into dist/
build:
	@Scripts/build-app.sh

## Build and launch (replaces a running instance)
run: stop build
	@open $(APP)

## Copy the app to /Applications
install: build
	@rm -rf /Applications/Focus.app
	@cp -R $(APP) /Applications/Focus.app
	@echo "installed /Applications/Focus.app"

## Quit a running instance
stop:
	@pkill -x Focus || true

## Re-render the app icon on the next build
icon:
	@rm -f Bundle/AppIcon.icns

clean: stop
	@rm -rf .build dist Bundle/AppIcon.icns
