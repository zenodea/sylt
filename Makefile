.PHONY: build run bundle open
build:
	swift build
run: build
	.build/debug/ControlIsland
bundle:
	scripts/bundle.sh
open: bundle
	pkill -x ControlIsland || true
	open build/ControlIsland.app
