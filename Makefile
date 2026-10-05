.PHONY: build run bundle open test
build:
	swift build
test:
	swift test
run: build
	.build/debug/Sylt
bundle:
	scripts/bundle.sh
open:
	pkill -x Sylt || true
	$(MAKE) bundle
	open build/Sylt.app
