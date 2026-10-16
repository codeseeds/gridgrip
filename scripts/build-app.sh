#!/usr/bin/env bash
# swift build -c release 산출물을 build/GridGrip.app 으로 조립하고 서명한다.
# SIGN_IDENTITY 를 지정하면 그 인증서(예: "Developer ID Application: ...")로, 없으면 ad-hoc 으로 서명한다.
# build/ 밖의 파일은 만들거나 지우지 않는다. 경로에 공백이 있을 수 있으므로 모든 경로 변수는 큰따옴표로 감싼다.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"

APP_NAME="GridGrip"
EXECUTABLE="GridGrip"
APP_DIR="$ROOT/build/$APP_NAME.app"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"

swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/$EXECUTABLE"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN" "$APP_DIR/Contents/MacOS/$EXECUTABLE"
cp "$ROOT/Support/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$ROOT/Support/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
cp -R "$ROOT/Support/Localization/"*.lproj "$APP_DIR/Contents/Resources/"

if [ "$SIGN_IDENTITY" = "-" ]; then
    codesign --force --options runtime --sign - --timestamp=none "$APP_DIR"
else
    codesign --force --options runtime --sign "$SIGN_IDENTITY" --timestamp "$APP_DIR"
fi
codesign --verify --strict "$APP_DIR"

echo "$APP_DIR"
