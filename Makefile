PROJECT := PHOENIX.xcodeproj
SCHEME := PHOENIX
CONFIGURATION ?= Debug
BUILD_DIR := $(CURDIR)/build
APP := $(BUILD_DIR)/Build/Products/$(CONFIGURATION)/PHOENIX.app
CMAKE_BUILD_DIR ?= $(CURDIR)/build-cmake

.PHONY: app run core cli cpp-test clean

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

core:
	cmake -S . -B "$(CMAKE_BUILD_DIR)" -DCMAKE_BUILD_TYPE=$(CONFIGURATION) -DBUILD_TESTING=ON
	cmake --build "$(CMAKE_BUILD_DIR)" --target PhoenixCore --parallel

cli:
	cmake -S . -B "$(CMAKE_BUILD_DIR)" -DCMAKE_BUILD_TYPE=$(CONFIGURATION) -DBUILD_TESTING=ON
	cmake --build "$(CMAKE_BUILD_DIR)" --target phoenix --parallel

cpp-test:
	cmake -S . -B "$(CMAKE_BUILD_DIR)" -DCMAKE_BUILD_TYPE=$(CONFIGURATION) -DBUILD_TESTING=ON
	cmake --build "$(CMAKE_BUILD_DIR)" --target PhoenixCoreTests --parallel
	ctest --test-dir "$(CMAKE_BUILD_DIR)" --output-on-failure

clean:
	xcodebuild \
		-project "$(PROJECT)" \
		-scheme "$(SCHEME)" \
		-configuration "$(CONFIGURATION)" \
		-derivedDataPath "$(BUILD_DIR)" \
		clean
