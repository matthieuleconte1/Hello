#!/bin/zsh
# ./build.sh          → compile build/Hello.app
# ./build.sh install  → compile, copie dans /Applications et lance
# ./build.sh dist     → binaire universel (Apple Silicon + Intel) empaqueté dans build/Hello-<version>.dmg
set -euo pipefail
cd "$(dirname "$0")"

XCODE_DEV=/Applications/Xcode.app/Contents/Developer
if [[ "${1:-}" == "dist" ]]; then
    # Le build multi-architecture passe par xcbuild, fourni par Xcode.
    DEVELOPER_DIR="$XCODE_DEV" swift build -c release --arch arm64 --arch x86_64
    BIN="$(DEVELOPER_DIR="$XCODE_DEV" swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/Hello"
else
    swift build -c release
    BIN=.build/release/Hello
fi

# Icône : le logo dessiné par Scripts/make-icon.swift (Resources/AppIcon.icns).
# Une icône Liquid Glass (Resources/AppIcon.icon, Icon Composer) est utilisée à la place si elle existe et que Xcode est là.
rm -rf build/icon && mkdir -p build/icon
if [[ -d "$XCODE_DEV" && -d Resources/AppIcon.icon ]]; then
    # Chemins absolus : actool délègue à un agent persistant qui peut garder un autre dossier courant.
    DEVELOPER_DIR="$XCODE_DEV" xcrun actool "$PWD/Resources/AppIcon.icon" --compile "$PWD/build/icon" --platform macosx \
        --minimum-deployment-target 14.0 --app-icon AppIcon --output-partial-info-plist "$PWD/build/icon/partial.plist" >/dev/null
else
    if [[ ! -f Resources/AppIcon.icns ]]; then
        swift Scripts/make-icon.swift
        iconutil -c icns build/AppIcon.iconset -o Resources/AppIcon.icns
    fi
    cp Resources/AppIcon.icns build/icon/AppIcon.icns
fi

APP=build/Hello.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Hello"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp build/icon/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
[[ -f build/icon/Assets.car ]] && cp build/icon/Assets.car "$APP/Contents/Resources/Assets.car"
codesign --force --sign - "$APP" >/dev/null
echo "✓ $APP"

if [[ "${1:-}" == "install" ]]; then
    pkill -x Hello 2>/dev/null || true
    pkill -x Halo 2>/dev/null || true          # ancien nom de l'app
    rm -rf /Applications/Hello.app /Applications/Halo.app
    cp -R "$APP" /Applications/
    open /Applications/Hello.app
    echo "✓ installé dans /Applications et lancé"
fi

if [[ "${1:-}" == "dist" ]]; then
    VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist)
    DMG="build/Hello-$VERSION.dmg"
    STAGE=build/dmg
    rm -rf "$STAGE" "$DMG"
    mkdir -p "$STAGE"
    cp -R "$APP" "$STAGE/"
    ln -s /Applications "$STAGE/Applications"
    cp Resources/LISEZ-MOI.txt "$STAGE/LISEZ-MOI.txt"
    hdiutil create -volname "Hello $VERSION" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null
    rm -rf "$STAGE"
    echo "✓ $DMG (à envoyer)"
fi
