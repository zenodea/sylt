.PHONY: build run bundle open test
build:
	swift build
test:
	swift test
run: build
	.build/debug/ControlIsland
bundle:
	scripts/bundle.sh
open:
	pkill -x ControlIsland || true
	$(MAKE) bundle
	open build/ControlIsland.app
