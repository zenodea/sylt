.PHONY: build run bundle open test
build:
	swift build
test:
	swift test
run: build
	.build/debug/ControlIsland
bundle:
	scripts/bundle.sh
open: bundle
	pkill -x ControlIsland || true
	open build/ControlIsland.app
