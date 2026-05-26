PREFIX ?= /usr/local

.PHONY: build install uninstall clean test

build:
	swift build -c release

install: build
	cp .build/release/rem $(PREFIX)/bin/rem

uninstall:
	rm -f $(PREFIX)/bin/rem

test:
	swift test

clean:
	swift package clean
