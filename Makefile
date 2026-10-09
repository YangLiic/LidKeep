SHELL := /bin/bash
.PHONY: all app run preview cli test release clean
all: app
app:
	./scripts/build.sh
run: app
	open dist/LidKeep.app
preview: app
	LIDKEEP_PREVIEW=1 dist/LidKeep.app/Contents/MacOS/LidKeep
cli: app
	dist/LidKeep.app/Contents/MacOS/LidKeep status
test:
	./scripts/test.sh
release: app
	./scripts/package.sh
clean:
	rm -rf .build dist/LidKeep.app dist/LidKeep-*.zip dist/LidKeep-*.dmg dist/SHA256SUMS dist/RELEASE-INFO.txt
