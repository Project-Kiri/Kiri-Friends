.PHONY: swift-build run-watch test test-apple test-server test-plugins clean help

SWIFT := swift
XCRUN := xcrun
APPLE_DIR := apps/apple

# Default target
all: swift-build

# Build all targets
swift-build:
	cd $(APPLE_DIR) && $(SWIFT) build

# Run watchOS app on simulator
run-watch:
	@echo "Building and running watchOS app on simulator..."
	$(XCRUN) simctl boot "Apple Watch Series 10 (46mm)" 2>/dev/null || true
	cd $(APPLE_DIR) && $(SWIFT) run KiriFriendsWatchApp

# Run all workspace tests
test: test-apple test-server test-plugins

test-apple:
	cd $(APPLE_DIR) && $(SWIFT) test

test-server:
	cd server && npm test

test-plugins:
	cd plugins && npm test

# Clean build artifacts
clean:
	cd $(APPLE_DIR) && $(SWIFT) package clean
	rm -rf $(APPLE_DIR)/.build/
	rm -rf server/dist/ plugins/dist/
	rm -rf DerivedData/

# Show help
help:
	@echo "Available targets:"
	@echo "  swift-build  - Build all targets"
	@echo "  run-watch    - Build and run watchOS app on simulator"
	@echo "  test         - Run all workspace tests"
	@echo "  test-apple   - Run Swift tests"
	@echo "  test-server  - Run Cloud Relay tests"
	@echo "  test-plugins - Run CLI plugin tests"
	@echo "  clean        - Clean build artifacts"
	@echo "  help         - Show this help message"
