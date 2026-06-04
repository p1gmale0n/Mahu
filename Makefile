PROJECT := Mahu.xcodeproj
SCHEME := Mahu
CONFIGURATION := Debug
DERIVED_DATA := build/DerivedData
APP_BUNDLE := build/Mahu.app
BUILT_APP := $(DERIVED_DATA)/Build/Products/$(CONFIGURATION)/Mahu.app

.PHONY: build
build:
	xcodebuild build \
		-project "$(PROJECT)" \
		-scheme "$(SCHEME)" \
		-configuration "$(CONFIGURATION)" \
		-destination "platform=macOS" \
		-derivedDataPath "$(DERIVED_DATA)" \
		CODE_SIGNING_ALLOWED=NO
	mkdir -p "build"
	rm -rf "$(APP_BUNDLE)"
	cp -R "$(BUILT_APP)" "$(APP_BUNDLE)"
	@printf 'Built %s\n' "$(APP_BUNDLE)"
