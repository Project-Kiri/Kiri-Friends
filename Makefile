SHELL := /bin/bash

SWIFT := swift
XCRUN := xcrun
XCODEBUILD := xcodebuild
XCODEGEN := xcodegen
NPM := npm
APPLE_DIR := apps/apple
SERVER_DIR := server
PLUGINS_DIR := plugins
XCODE_PROJECT ?= KiriFriends.xcodeproj
DERIVED_DATA ?= build/DerivedData
IPHONE_SCHEME ?= KiriFriendsPhoneApp
WATCH_SCHEME ?= KiriFriendsWatchApp
MAC_SCHEME ?= KiriFriendsBuddyMac
IPHONE_SIMULATOR ?=
WATCH_SIMULATOR ?=
IPHONE_DESTINATION ?= generic/platform=iOS Simulator
WATCH_DESTINATION ?= generic/platform=watchOS Simulator
MAC_DESTINATION ?= generic/platform=macOS
IPHONE_BUNDLE_ID ?= com.kirifriends.phone
WATCH_BUNDLE_ID ?= com.kirifriends.phone.watchapp
MAC_BUNDLE_ID ?= com.kirifriends.buddy.mac

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show available commands.
	@awk 'BEGIN {FS = ":.*##"; printf "Kiri Friends development commands:\n\n"} /^[a-zA-Z0-9_-]+:.*##/ {printf "  %-18s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.PHONY: dev
dev: ## Show dev targets. Choose one: dev-iphone, dev-watch, dev-mac, dev-relay, dev-server, or dev-plugin.
	@$(MAKE) help

.PHONY: generate
generate: ## Generate KiriFriends.xcodeproj using XcodeGen.
	@command -v $(XCODEGEN) >/dev/null || { \
		echo "xcodegen is required to generate $(XCODE_PROJECT)."; \
		echo "Install it with: brew install xcodegen"; \
		exit 1; \
	}
	$(XCODEGEN) generate

.PHONY: dev-iphone
dev-iphone: require-xcode-project require-ios-runtime ## Build, install, and launch the iPhone companion in Simulator.
	@DEVICE_ID=$$( \
		$(XCRUN) simctl list devices available | awk -v requested="$(IPHONE_SIMULATOR)" '\
			/^-- iOS / { in_section = 1; next } \
			/^-- / { in_section = 0 } \
			in_section && /\([A-F0-9-]{36}\)/ { \
				line = $$0; \
				name = line; \
				sub(/^[[:space:]]*/, "", name); \
				sub(/[[:space:]]+\([A-F0-9-]{36}\).*/, "", name); \
				if (requested == "" || name == requested) { print line; exit } \
			}' | sed -E 's/.*\(([A-F0-9-]{36})\).*/\1/' \
	); \
	test -n "$$DEVICE_ID" || { echo "No matching iOS Simulator device found. Set IPHONE_SIMULATOR=\"<device name>\"."; exit 1; }; \
	$(XCRUN) simctl boot "$$DEVICE_ID" 2>/dev/null || true; \
	echo "Using iOS Simulator $$DEVICE_ID"
	$(XCODEBUILD) -project "$(XCODE_PROJECT)" -scheme "$(IPHONE_SCHEME)" -destination '$(IPHONE_DESTINATION)' -derivedDataPath "$(DERIVED_DATA)" build
	@APP_PATH=$$(find "$(DERIVED_DATA)/Build/Products" -path "*Debug-iphonesimulator/$(IPHONE_SCHEME).app" -print -quit); \
		test -n "$$APP_PATH" || { echo "Could not find built iPhone app for scheme $(IPHONE_SCHEME)."; exit 1; }; \
		DEVICE_ID=$$( \
			$(XCRUN) simctl list devices available | awk -v requested="$(IPHONE_SIMULATOR)" '\
				/^-- iOS / { in_section = 1; next } \
				/^-- / { in_section = 0 } \
				in_section && /\([A-F0-9-]{36}\)/ { \
					line = $$0; \
					name = line; \
					sub(/^[[:space:]]*/, "", name); \
					sub(/[[:space:]]+\([A-F0-9-]{36}\).*/, "", name); \
					if (requested == "" || name == requested) { print line; exit } \
				}' | sed -E 's/.*\(([A-F0-9-]{36})\).*/\1/' \
		); \
		$(XCRUN) simctl install "$$DEVICE_ID" "$$APP_PATH"; \
		$(XCRUN) simctl launch "$$DEVICE_ID" "$(IPHONE_BUNDLE_ID)"

.PHONY: dev-watch
dev-watch: require-xcode-project require-watch-runtime ## Build, install, and launch the Watch app in Watch Simulator.
	@DEVICE_ID=$$( \
		$(XCRUN) simctl list devices available | awk -v requested="$(WATCH_SIMULATOR)" '\
			/^-- watchOS / { in_section = 1; next } \
			/^-- / { in_section = 0 } \
			in_section && /\([A-F0-9-]{36}\)/ { \
				line = $$0; \
				name = line; \
				sub(/^[[:space:]]*/, "", name); \
				sub(/[[:space:]]+\([A-F0-9-]{36}\).*/, "", name); \
				if (requested == "" || name == requested) { print line; exit } \
			}' | sed -E 's/.*\(([A-F0-9-]{36})\).*/\1/' \
	); \
	test -n "$$DEVICE_ID" || { echo "No matching watchOS Simulator device found. Set WATCH_SIMULATOR=\"<device name>\"."; exit 1; }; \
	$(XCRUN) simctl boot "$$DEVICE_ID" 2>/dev/null || true; \
	echo "Using watchOS Simulator $$DEVICE_ID"
	$(XCODEBUILD) -project "$(XCODE_PROJECT)" -scheme "$(WATCH_SCHEME)" -destination '$(WATCH_DESTINATION)' -derivedDataPath "$(DERIVED_DATA)" build
	@APP_PATH=$$(find "$(DERIVED_DATA)/Build/Products" -path "*Debug-watchsimulator/$(WATCH_SCHEME).app" -print -quit); \
		test -n "$$APP_PATH" || { echo "Could not find built Watch app for scheme $(WATCH_SCHEME)."; exit 1; }; \
		DEVICE_ID=$$( \
			$(XCRUN) simctl list devices available | awk -v requested="$(WATCH_SIMULATOR)" '\
				/^-- watchOS / { in_section = 1; next } \
				/^-- / { in_section = 0 } \
				in_section && /\([A-F0-9-]{36}\)/ { \
					line = $$0; \
					name = line; \
					sub(/^[[:space:]]*/, "", name); \
					sub(/[[:space:]]+\([A-F0-9-]{36}\).*/, "", name); \
					if (requested == "" || name == requested) { print line; exit } \
				}' | sed -E 's/.*\(([A-F0-9-]{36})\).*/\1/' \
		); \
		$(XCRUN) simctl install "$$DEVICE_ID" "$$APP_PATH"; \
		$(XCRUN) simctl launch "$$DEVICE_ID" "$(WATCH_BUNDLE_ID)"

.PHONY: dev-mac
dev-mac: require-xcode-project ## Build and launch the Kiri Buddy macOS app.
	$(XCODEBUILD) -project "$(XCODE_PROJECT)" -scheme "$(MAC_SCHEME)" -destination '$(MAC_DESTINATION)' -derivedDataPath "$(DERIVED_DATA)" build
	@APP_PATH=$$(find "$(DERIVED_DATA)/Build/Products" -path "*Debug/$(MAC_SCHEME).app" -print -quit); \
		test -n "$$APP_PATH" || { echo "Could not find built Mac app for scheme $(MAC_SCHEME)."; exit 1; }; \
		echo "Launching $$APP_PATH"; \
		open "$$APP_PATH"

.PHONY: build-mac
build-mac: ## Build the Mac Buddy library + executable through SwiftPM.
	cd $(APPLE_DIR) && $(SWIFT) build --target KiriFriendsBuddyMac

.PHONY: test-mac
test-mac: ## Run KiriFriendsMacBuddyKit Swift tests.
	cd $(APPLE_DIR) && $(SWIFT) test --filter KiriFriendsMacBuddyKitTests

.PHONY: dev-server
dev-server: ## Start Cloud Relay TypeScript dev watch mode.
	cd $(SERVER_DIR) && $(NPM) run typecheck -- --watch

.PHONY: dev-relay
dev-relay: ## Run the Cloud Relay HTTP server (127.0.0.1:8585 by default).
	cd $(SERVER_DIR) && $(NPM) run start

.PHONY: debug-relay
debug-relay: ## Run the Cloud Relay debug CLI against an already-running relay.
	cd $(SERVER_DIR) && $(NPM) run debug -- $(ARGS)

.PHONY: verify-watch-assets
verify-watch-assets: ## SHA-diff the Watch theme assets against KiriFriendsBuddyMac canonical files.
	bash Scripts/verify-watch-assets.sh

.PHONY: generate-watch-animation-assets
generate-watch-animation-assets: ## Generate Watch animation frames from Mac Buddy canonical SVG assets.
	node Scripts/generate-watch-animation-frames.mjs

.PHONY: dev-plugin
dev-plugin: ## Start CLI plugin TypeScript dev watch mode.
	cd $(PLUGINS_DIR) && $(NPM) run typecheck -- --watch

.PHONY: swift-build
swift-build: ## Build all Apple Swift targets.
	cd $(APPLE_DIR) && $(SWIFT) build

.PHONY: run-watch
run-watch: dev-watch ## Alias for dev-watch.

.PHONY: require-xcode-project
require-xcode-project:
	@if [ ! -d "$(XCODE_PROJECT)" ]; then \
		echo "No $(XCODE_PROJECT) found. Generating it from project.yml..."; \
		$(MAKE) generate; \
	fi

.PHONY: require-ios-runtime
require-ios-runtime:
	@$(XCRUN) simctl list runtimes available | awk '/iOS/ { found = 1 } END { exit found ? 0 : 1 }' || { \
		echo "No iOS Simulator runtime is installed."; \
		echo "Install one from Xcode > Settings > Components, then rerun this command."; \
		exit 1; \
	}

.PHONY: require-watch-runtime
require-watch-runtime:
	@$(XCRUN) simctl list runtimes available | awk '/watchOS/ { found = 1 } END { exit found ? 0 : 1 }' || { \
		echo "No watchOS Simulator runtime is installed."; \
		echo "Xcode has the watchOS SDK, but CoreSimulator has no watchOS runtime available."; \
		echo "Install watchOS Simulator from Xcode > Settings > Components, then rerun this command."; \
		exit 1; \
	}

.PHONY: boot-watch-simulator
boot-watch-simulator: ## Boot a default Apple Watch simulator if available.
	@DEVICE_ID=$$( \
		$(XCRUN) simctl list devices available | awk -v requested="$(WATCH_SIMULATOR)" '\
			/^-- watchOS / { in_section = 1; next } \
			/^-- / { in_section = 0 } \
			in_section && /\([A-F0-9-]{36}\)/ { \
				line = $$0; \
				name = line; \
				sub(/^[[:space:]]*/, "", name); \
				sub(/[[:space:]]+\([A-F0-9-]{36}\).*/, "", name); \
				if (requested == "" || name == requested) { print line; exit } \
			}' | sed -E 's/.*\(([A-F0-9-]{36})\).*/\1/' \
	); \
	test -n "$$DEVICE_ID" || { echo "No matching watchOS Simulator device found. Set WATCH_SIMULATOR=\"<device name>\"."; exit 1; }; \
	$(XCRUN) simctl boot "$$DEVICE_ID" 2>/dev/null || true; \
	echo "Using watchOS Simulator $$DEVICE_ID"

.PHONY: test
test: test-apple test-server test-plugins ## Run all workspace tests (Apple Swift suite covers Mac Buddy).

.PHONY: test-apple
test-apple: ## Run Apple Swift tests (includes Mac Buddy kit).
	cd $(APPLE_DIR) && $(SWIFT) test

.PHONY: test-server
test-server: ## Run Cloud Relay tests.
	cd $(SERVER_DIR) && $(NPM) test

.PHONY: test-plugins
test-plugins: ## Run CLI plugin tests.
	cd $(PLUGINS_DIR) && $(NPM) test

.PHONY: typecheck
typecheck: typecheck-server typecheck-plugins ## Run TypeScript typechecks.

.PHONY: typecheck-server
typecheck-server: ## Typecheck Cloud Relay.
	cd $(SERVER_DIR) && $(NPM) run typecheck

.PHONY: typecheck-plugins
typecheck-plugins: ## Typecheck CLI plugins.
	cd $(PLUGINS_DIR) && $(NPM) run typecheck

.PHONY: clean
clean: ## Clean build artifacts.
	cd $(APPLE_DIR) && $(SWIFT) package clean
	rm -rf $(APPLE_DIR)/.build/
	rm -rf $(SERVER_DIR)/dist/ $(PLUGINS_DIR)/dist/
	rm -rf "$(DERIVED_DATA)"
