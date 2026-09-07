export DEVELOPER_DIR := /Applications/Xcode.app/Contents/Developer

PROJECT := StayUp.xcodeproj
SCHEME  := StayUp
DEST    := platform=macOS,arch=arm64
XCB     := xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DEST)' -configuration Debug

.PHONY: gen build test run release install zip clean

gen:
	xcodegen generate

build: gen
	$(XCB) build

test: gen
	$(XCB) test

run: build
	@APP=$$($(XCB) -showBuildSettings 2>/dev/null \
		| awk -F' = ' '/ BUILT_PRODUCTS_DIR/ {print $$2; exit}')/StayUp.app; \
	pkill -x StayUp || true; \
	open "$$APP"

# A real build, checked before it is trusted: signature, hardened runtime,
# bundle id. See scripts/release.sh.
release:
	./scripts/release.sh

# The same, then put in /Applications and relaunched from there. Where it has
# to live for "Launch at login" to work at all: macOS will not register a login
# item for an app in a build directory.
install:
	./scripts/release.sh install

# And something to carry to another Mac.
zip:
	./scripts/release.sh zip

clean:
	rm -rf build DerivedData $(PROJECT)
