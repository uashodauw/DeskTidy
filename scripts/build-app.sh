#!/bin/bash
# 把 DeskTidy 打包成 DeskTidy.app 并装进"应用程序"文件夹，之后不需要开着终端。
# 只给自己这台电脑用；发给别人需要签名和公证（任务 21）。
set -euo pipefail

cd "$(dirname "$0")/.."

echo "正在编译（第一次可能要一两分钟）..."
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"

APP="build/DeskTidy.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/DeskTidy" "$APP/Contents/MacOS/DeskTidy"
cp Packaging/Info.plist "$APP/Contents/Info.plist"

VERSION="$(sed -n 's/.*version = "\(.*\)".*/\1/p' Sources/DeskTidyCore/AppInfo.swift)"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"

# SwiftPM 生成的代码只会在 .app 的最外层找依赖库的资源包（快捷键录制框的文字），放别处会找不到
for bundle in "$BIN_DIR"/*.bundle; do
    [ -e "$bundle" ] && cp -R "$bundle" "$APP/"
done

if [ -w /Applications ]; then
    DEST_DIR="/Applications"
else
    DEST_DIR="$HOME/Applications"
    mkdir -p "$DEST_DIR"
fi

# 先关掉正在运行的 DeskTidy（包括用 swift run 启动的），否则会出现两个菜单栏图标
pkill -x DeskTidy 2>/dev/null || true
sleep 1

rm -rf "$DEST_DIR/DeskTidy.app"
cp -R "$APP" "$DEST_DIR/"
open "$DEST_DIR/DeskTidy.app"

echo "已安装到 $DEST_DIR/DeskTidy.app 并启动。现在可以关掉终端了。"
