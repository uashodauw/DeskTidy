#!/bin/bash
# 组装 build/DeskTidy.app，被 build-app.sh（装到自己电脑）和 package-release.sh（发给别人）共用。
# 用法：make_app native     只编译本机芯片的版本，快
#       make_app universal  同时编译苹果芯片和 Intel 芯片，发给别人用

APP="build/DeskTidy.app"
VERSION="$(sed -n 's/.*version = "\(.*\)".*/\1/p' Sources/DeskTidyCore/AppInfo.swift)"

build_binary() {
    local mode="$1"
    if [ "$mode" = "universal" ]; then
        local slices=()
        for arch in arm64 x86_64; do
            echo "正在编译 $arch 版本..."
            if swift build -c release --arch "$arch"; then
                BIN_DIR="$(swift build -c release --arch "$arch" --show-bin-path)"
                # 新版 Xcode 的编译系统把不同芯片的结果放在同一个文件夹，下一次编译会覆盖，所以马上存一份
                cp "$BIN_DIR/DeskTidy" "build/DeskTidy-$arch"
                slices+=("build/DeskTidy-$arch")
            else
                echo "⚠️  $arch 版本编译失败，安装包里不会包含它"
            fi
        done
        if [ "${#slices[@]}" -eq 0 ]; then
            echo "编译失败" >&2
            exit 1
        fi
        lipo -create -output build/DeskTidy-binary "${slices[@]}"
        rm -f "${slices[@]}"
    else
        echo "正在编译（第一次可能要一两分钟）..."
        swift build -c release
        BIN_DIR="$(swift build -c release --show-bin-path)"
        cp "$BIN_DIR/DeskTidy" build/DeskTidy-binary
    fi
}

make_icon() {
    local iconset="build/AppIcon.iconset"
    rm -rf "$iconset"
    mkdir -p "$iconset"
    for size in 16 32 128 256 512; do
        sips -z "$size" "$size" Packaging/AppIcon.png --out "$iconset/icon_${size}x${size}.png" >/dev/null
        sips -z $((size * 2)) $((size * 2)) Packaging/AppIcon.png --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
    done
    iconutil -c icns "$iconset" -o "$APP/Contents/Resources/AppIcon.icns"
}

make_app() {
    mkdir -p build
    build_binary "$1"

    rm -rf "$APP"
    mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
    mv build/DeskTidy-binary "$APP/Contents/MacOS/DeskTidy"
    cp Packaging/Info.plist "$APP/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
    make_icon
    cp -R Packaging/Pet "$APP/Contents/Resources/Pet"

    # 资源包（快捷键录制框的文字）必须放在 Contents 里面：签名不允许 .app 最外层有别的文件
    for bundle in "$BIN_DIR"/*.bundle; do
        [ -e "$bundle" ] && cp -R "$bundle" "$APP/Contents/Resources/"
    done
}

# 不花钱的"临时签名"：苹果芯片的 Mac 不允许运行完全没签名的应用
sign_adhoc() {
    codesign --force --deep --sign - "$APP"
}
