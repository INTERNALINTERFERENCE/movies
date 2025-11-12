.PHONY: build build-r install clean help

# Default target
help:
	@echo "Available targets:"
	@echo "  make build-r     - Build and install release version on iPhone"
	@echo "  make build       - Build release version only (no install)"
	@echo "  make install     - Install release build on connected iPhone"
	@echo "  make clean       - Clean build files"
	@echo "  make help        - Show this help message"
	@echo ""
	@echo "Note: Use 'make build-r' (not 'make build -r')"

# Build and install release version
build-r:
	@echo "🔨 Building iOS release version..."
	@cd /Users/anton/Desktop/client/flutter && flutter build ios --release
	@echo "📱 Installing on iPhone..."
	@cd /Users/anton/Desktop/client/flutter && flutter install --release -d 00008030-001E08892113402E
	@echo "✅ Done! App should be on your iPhone home screen."

# Build release only (without install)
build:
	@echo "🔨 Building iOS release version (no install)..."
	@cd /Users/anton/Desktop/client/flutter && flutter build ios --release
	@echo "✅ Build complete! Use 'make install' to install on device."

# Install release build on connected device
install:
	@echo "📱 Installing release build on iPhone..."
	@cd /Users/anton/Desktop/client/flutter && flutter install --release -d 00008030-001E08892113402E
	@echo "✅ Installation complete!"

# Clean build files
clean:
	@echo "🧹 Cleaning build files..."
	@cd /Users/anton/Desktop/client/flutter && flutter clean
	@echo "✅ Clean complete!"

