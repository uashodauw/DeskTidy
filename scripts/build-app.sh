#!/bin/bash
# 把 DeskTidy 打包成 DeskTidy.app 并装进"应用程序"文件夹，之后不需要开着终端。
# 只给自己这台电脑用；做成发给别人的安装包用 scripts/package-release.sh。
set -euo pipefail

cd "$(dirname "$0")/.."
source scripts/lib/make-app.sh

make_app native
sign_adhoc

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
# 让访达和程序坞马上换成新图标
touch "$DEST_DIR/DeskTidy.app"
open "$DEST_DIR/DeskTidy.app"

echo "已安装到 $DEST_DIR/DeskTidy.app 并启动。现在可以关掉终端了。"
