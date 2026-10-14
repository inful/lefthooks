# Makefile — central management for github.com/inful/lefthooks.
#
# Targets:
#   make help            — list targets
#   make test            — run the commit-msg test suite
#   make validate        — lefthook validate the central config
#   make dump            — print the merged config as JSON
#   make install-into REPO=/path/to/consumer
#                        — install shared hooks into one consumer
#   make install-all     — install shared hooks into all known consumers
#                          (override CONSUMERS=... to use a different list)

CENTRAL_ROOT := $(shell pwd)

# Default list of consumers — overridable: `make install-all CONSUMERS=...`.
# Paths assume macOS with the inful user's typical layout.
CONSUMERS ?= \
	/Users/inful/Code/github.com/inful/deeplink \
	/Users/inful/Code/github.com/inful/docbuilder \
	/Users/inful/Code/github.com/inful/docbuilder-daemon-decompose \
	/Users/inful/Code/github.com/inful/mreview \
	/Users/inful/Code/github.com/inful/readeckorator \
	/Users/inful/Code/github.com/inful/repo-mr-file

.PHONY: help test validate dump install-into install-all

help:
	@echo "Targets:"
	@echo "  make test                                Run the commit-msg test suite"
	@echo "  make validate                            Validate the central lefthook config"
	@echo "  make dump                                Print the merged config as JSON"
	@echo "  make install-into REPO=/path/to/consumer Install shared hooks into one consumer"
	@echo "  make install-all                         Install shared hooks into all known consumers"

test:
	@bash tests/check-conventional-commit_test.sh

validate:
	@command -v lefthook >/dev/null 2>&1 || { echo "lefthook not on PATH"; exit 1; }
	@lefthook validate

dump:
	@command -v lefthook >/dev/null 2>&1 || { echo "lefthook not on PATH"; exit 1; }
	@lefthook dump

install-into:
	@if [ -z "$${REPO:-}" ]; then \
		echo "Usage: make install-into REPO=/path/to/consumer"; \
		exit 2; \
	fi
	@bash bin/install-into.sh "$${REPO}"

install-all:
	@for c in $(CONSUMERS); do \
		echo ""; \
		echo "==> $$c"; \
		bash bin/install-into.sh "$$c" || exit 1; \
	done