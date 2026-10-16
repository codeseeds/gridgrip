#!/usr/bin/env bash
# build-app.sh 로 GridGrip.app 을 만든 뒤, Applications 바로가기를 함께 담은 build/GridGrip-<버전>.dmg 를 만든다.
# 창 배경·아이콘 배치는 dmgbuild(uvx 로 실행, uv 필요)가 scripts/dmg-settings.py 대로 넣는다.
# SIGN_IDENTITY 를 지정하면 DMG 도 같은 인증서로 서명한다.
# NOTARY_PROFILE(xcrun notarytool store-credentials 로 저장한 이름)을 지정하면 공증 후 스테이플까지 한다.
# build/ 밖의 파일은 만들거나 지우지 않는다.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"

APP_NAME="GridGrip"
VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$ROOT/Support/Info.plist")"
DMG_PATH="$ROOT/build/$APP_NAME-$VERSION.dmg"
DMGBUILD_VERSION="1.6.5"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"

SIGN_IDENTITY="$SIGN_IDENTITY" "$ROOT/scripts/build-app.sh"

rm -f "$DMG_PATH"
uvx --from "dmgbuild==$DMGBUILD_VERSION" dmgbuild \
    -s "$ROOT/scripts/dmg-settings.py" \
    -D app="$ROOT/build/$APP_NAME.app" \
    -D background="$ROOT/Support/dmg-background.png" \
    -D volume_icon="$ROOT/Support/AppIcon.icns" \
    "$APP_NAME" "$DMG_PATH" >/dev/null

if [ "$SIGN_IDENTITY" != "-" ]; then
    codesign --force --sign "$SIGN_IDENTITY" --timestamp "$DMG_PATH"
fi

if [ -n "$NOTARY_PROFILE" ]; then
    xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG_PATH"
    spctl --assess --type open --context context:primary-signature --verbose "$DMG_PATH"
fi

hdiutil verify "$DMG_PATH" >/dev/null
shasum -a 256 "$DMG_PATH"
echo "$DMG_PATH"
