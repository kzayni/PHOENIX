PROJECT := PHOENIX.xcodeproj
SCHEME := PHOENIX
CONFIGURATION ?= Debug
BUILD_DIR := $(CURDIR)/build
APP := $(BUILD_DIR)/Build/Products/$(CONFIGURATION)/PHOENIX.app

.PHONY: app run clean

app:
	xcodebuild \
		-project "$(PROJECT)" \
		-scheme "$(SCHEME)" \
		-configuration "$(CONFIGURATION)" \
		-destination 'platform=macOS' \
		-derivedDataPath "$(BUILD_DIR)" \
		CODE_SIGNING_ALLOWED=NO \
		build
	@echo "Built $(APP)"

run: app
	open "$(APP)"

clean:
	xcodebuild \
		-project "$(PROJECT)" \
		-scheme "$(SCHEME)" \
		-configuration "$(CONFIGURATION)" \
		-derivedDataPath "$(BUILD_DIR)" \
		clean
