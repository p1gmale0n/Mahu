PROJECT := Mahu.xcodeproj
SCHEME := Mahu
CONFIGURATION := Debug
DERIVED_DATA := build/DerivedData
APP_BUNDLE := build/Mahu.app
BUILT_APP := $(DERIVED_DATA)/Build/Products/$(CONFIGURATION)/Mahu.app
BUILT_BACKGROUND_RESOURCE := $(BUILT_APP)/Contents/Resources/background.png
BUILT_SOUND_RESOURCE := $(BUILT_APP)/Contents/Resources/break-completion.caf
APP_BACKGROUND_RESOURCE := $(APP_BUNDLE)/Contents/Resources/background.png
APP_SOUND_RESOURCE := $(APP_BUNDLE)/Contents/Resources/break-completion.caf

.PHONY: build
build:
	xcodebuild build \
		-project "$(PROJECT)" \
		-scheme "$(SCHEME)" \
		-configuration "$(CONFIGURATION)" \
		-destination "platform=macOS" \
		-derivedDataPath "$(DERIVED_DATA)" \
		CODE_SIGNING_ALLOWED=NO
	test -f "$(BUILT_BACKGROUND_RESOURCE)"
	test -f "$(BUILT_SOUND_RESOURCE)"
	mkdir -p "build"
	rm -rf "$(APP_BUNDLE)"
	cp -R "$(BUILT_APP)" "$(APP_BUNDLE)"
	test -f "$(APP_BACKGROUND_RESOURCE)"
	test -f "$(APP_SOUND_RESOURCE)"
	@printf 'Built %s\n' "$(APP_BUNDLE)"

.PHONY: lint
lint:
	@command -v swiftlint >/dev/null 2>&1 || { \
		printf 'SwiftLint is not installed. Install it with: brew install swiftlint\n' >&2; \
		exit 127; \
	}
	swiftlint lint --config .swiftlint.yml
