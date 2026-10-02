#!/usr/bin/env bash
# 在 macOS 上一键生成未签名的离线 IPA（不上传 App Store、不签名）。
# 用法：bash build_ipa.sh
set -euo pipefail

PROJECT="ElectronicQueueCard.xcodeproj"
SCHEME="ElectronicQueueCard"
CONFIG="Release"
DERIVED="build"
APP_NAME="ElectronicQueueCard"
OUT_IPA="ElectronicQueueCard-unsigned.ipa"

echo "==> 清理并编译 (Release, iphoneos, 未签名)"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -sdk iphoneos \
  -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  clean build

APP_PATH="$DERIVED/Build/Products/$CONFIG-iphoneos/$APP_NAME.app"
if [ ! -d "$APP_PATH" ]; then
  echo "错误：未找到 $APP_PATH" >&2
  exit 1
fi

echo "==> 打包为未签名 IPA"
rm -rf Payload
mkdir -p Payload
cp -R "$APP_PATH" Payload/
zip -qr "$OUT_IPA" Payload
rm -rf Payload

echo "完成：$(pwd)/$OUT_IPA"
