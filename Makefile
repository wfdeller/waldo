# Makefile for Waldo Swift Package

.PHONY: build clean test run install help

# Default target
all: build

# Build the project
build:
	swift build

# Build in release mode
release:
	swift build -c release

# Run tests
test:
	swift test

# Clean build artifacts
clean:
	swift package clean

# Run the executable
run:
	swift run waldo

# Install the executable to /usr/local/bin
install: release
	cp .build/release/waldo /usr/local/bin/

# Update dependencies
update:
	swift package update

# Resolve dependencies
resolve:
	swift package resolve

# Generate Xcode project
xcode:
	swift package generate-xcodeproj

# Show package info
info:
	swift package describe

# Format code (requires swift-format)
format:
	swift-format --in-place --recursive Sources/ Tests/

# Lint code (requires SwiftLint)
lint:
	swiftlint

# Help target
help:
	@echo "Available targets:"
	@echo "  build     - Build the project"
	@echo "  release   - Build in release mode"
	@echo "  test      - Run tests"
	@echo "  clean     - Clean build artifacts"
	@echo "  run       - Run the executable"
	@echo "  install   - Install executable to /usr/local/bin"
	@echo "  update    - Update dependencies"
	@echo "  resolve   - Resolve dependencies"
	@echo "  xcode     - Generate Xcode project"
	@echo "  info      - Show package information"
	@echo "  format    - Format code (requires swift-format)"
	@echo "  lint      - Lint code (requires SwiftLint)"
	@echo "  help      - Show this help message"