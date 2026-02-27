APP_NAME = VoiceOverlay
BUNDLE_ID = com.anti.VoiceOverlay
EXECUTABLE = $(APP_NAME)
BUILD_DIR = build
APP_DIR = $(BUILD_DIR)/$(APP_NAME).app
CONTENTS_DIR = $(APP_DIR)/Contents
MACOS_DIR = $(CONTENTS_DIR)/MacOS
RESOURCES_DIR = $(CONTENTS_DIR)/Resources

SWIFTC = swiftc
SWIFT_FILES = $(wildcard Sources/*.swift)
SWIFT_FLAGS = -O -parse-as-library
SIGN_APP ?= 1

.PHONY: all clean run build test lint-docs

all: build

build: $(APP_DIR)

$(APP_DIR): $(SWIFT_FILES) Info.plist
	@echo "=> Building $(APP_NAME)..."
	@mkdir -p $(MACOS_DIR)
	@mkdir -p $(RESOURCES_DIR)
	@$(SWIFTC) $(SWIFT_FLAGS) $(SWIFT_FILES) -o $(MACOS_DIR)/$(EXECUTABLE)
	@cp Info.plist $(CONTENTS_DIR)/Info.plist
	@cp Resources/AppIcon.icns $(RESOURCES_DIR)/AppIcon.icns
	@echo "APPL????" > $(CONTENTS_DIR)/PkgInfo
	@find $(APP_DIR) -name ".DS_Store" -delete
	@xattr -rc $(APP_DIR) || true
	@if [ "$(SIGN_APP)" = "1" ]; then \
		codesign --force --deep --sign - $(APP_DIR); \
	else \
		echo "=> Skipping codesign (SIGN_APP=$(SIGN_APP))"; \
	fi
	@echo "=> Build successful: $(APP_DIR)"

run: build
	@echo "=> Running $(APP_NAME)..."
	@open $(APP_DIR)

clean:
	@echo "=> Cleaning up build directory..."
	@rm -rf $(BUILD_DIR)

test:
	@echo "=> Running tests..."
	@swift test

lint-docs:
	@echo "=> Linting documentation..."
	@./scripts/check_docs.sh
