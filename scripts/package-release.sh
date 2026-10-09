#!/bin/bash
# 做成可以直接发给别人的安装文件 build/DeskTidy-<版本>.dmg（苹果芯片和 Intel 芯片的 Mac 都能用）。
#
# 没有苹果开发者账号时：用免费的临时签名。对方第一次打开要在"系统设置 > 隐私与安全性"里点一次"仍要打开"，
#   安装包里附了图文说明。
# 有苹果开发者账号（每年 99 美元）时：先设置下面两个环境变量，对方双击就能直接打开，不会有任何提示。
#   DEVELOPER_ID    钥匙串里的签名证书名，例如 "Developer ID Application: Zhang San (ABCDE12345)"
#   NOTARY_PROFILE  用 xcrun notarytool store-credentials 保存的公证凭据名
set -euo pipefail

cd "$(dirname "$0")/.."
source scripts/lib/make-app.sh

DEVELOPER_ID="${DEVELOPER_ID:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"

make_app universal

if [ -n "$DEVELOPER_ID" ]; then
    echo "正在用开发者证书签名..."
    for bundle in "$APP"/Contents/Resources/*.bundle; do
        [ -e "$bundle" ] && codesign --force --timestamp --sign "$DEVELOPER_ID" "$bundle"
    done
    codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID" "$APP"
else
    echo "没有设置 DEVELOPER_ID，使用免费的临时签名"
    sign_adhoc
fi
codesign --verify --strict --deep "$APP"

DMG="build/DeskTidy-$VERSION.dmg"
STAGING="build/dmg"
rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/应用程序"
if [ -z "$DEVELOPER_ID" ]; then
    cp Packaging/打不开时看这里.txt "$STAGING/"
fi

echo "正在制作安装文件..."
hdiutil create -volname "DeskTidy" -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGING"

if [ -n "$DEVELOPER_ID" ]; then
    codesign --force --timestamp --sign "$DEVELOPER_ID" "$DMG"
    if [ -n "$NOTARY_PROFILE" ]; then
        echo "正在提交苹果公证（一般几分钟）..."
        xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
        xcrun stapler staple "$DMG"
    else
        echo "⚠️  没有设置 NOTARY_PROFILE，没做公证：对方打开时仍会看到提示"
    fi
fi

echo ""
echo "完成：$DMG"
echo "支持的芯片：$(lipo -archs "$APP/Contents/MacOS/DeskTidy")"
echo "把这个文件发给别人即可。"
