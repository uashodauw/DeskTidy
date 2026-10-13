# 桌面清理（DeskTidy，暂定名）

一个 Mac 菜单栏小工具：给同时开着一堆 AI 工具干活的人，一键收起眼前不需要的应用，让屏幕清爽、切换不掉帧。

当前状态：**开发中**。第一版功能已完成，正在自己试用。

内置番茄钟：面板里点"开始专注"，屏幕角落出现玻璃小时钟；专注到点后提醒休息，休息时毛玻璃铺满屏幕（随时可跳过，不会收起或关闭任何应用）。时长和提醒方式在设置窗口的"专注"里改（面板最下面点"设置…"，或在面板里按 ⌘,）。

面板标题默认跟着系统外观：浅色是近黑，深色是白色。在设置的「清理」里可以改成自己的两种颜色。

## 装成应用（日常使用）

```bash
./scripts/build-app.sh
```

脚本会编译、打包出 `DeskTidy.app`，装进"应用程序"文件夹并启动。之后可以关掉终端，DeskTidy 继续在菜单栏运行；下次在启动台或聚焦搜索里搜"DeskTidy"打开。改了代码后重新运行这条命令即可更新。

第一次以应用方式启动时，会自动搬来之前用 `swift run` 时的设置（场景、提示音、快捷键），只搬一次。

## 做成安装包发给别人

```bash
./scripts/package-release.sh
```

生成 `build/DeskTidy（测试版）.dmg`（里面有应用和安装说明，做完会自动在访达里选中它），苹果芯片和 Intel 芯片的 Mac 都能用（需要 macOS 13 以上）。把这个文件发给对方，对方双击打开，把 DeskTidy 拖进"应用程序"即可。

- **没有苹果开发者账号（默认）**：用免费的临时签名。对方第一次打开时会提示"无法验证开发者"，需要在"系统设置 → 隐私与安全性"里点一次"仍要打开"。安装包里附了说明文件《打不开时看这里》。
- **有苹果开发者账号（每年 99 美元）**：对方双击就能直接打开，没有任何提示。先在钥匙串里装好 "Developer ID Application" 证书，并保存一次公证凭据：

  ```bash
  xcrun notarytool store-credentials desktidy --apple-id 你的AppleID --team-id 团队ID
  DEVELOPER_ID="Developer ID Application: 你的名字 (团队ID)" NOTARY_PROFILE=desktidy ./scripts/package-release.sh
  ```

应用图标的原图是 `Packaging/AppIcon.png`，由 `scripts/make-icon.py` 画出（需要 `pip install pillow`），打包时会自动转成 Mac 图标格式。

## 文档

- [需求文档](docs/Mac桌面清理工具需求文档.md)
- [技术方案](docs/Mac桌面清理工具技术方案.md)
- [任务清单](docs/Mac桌面清理工具任务清单.md)

## 运行环境

- macOS 13 或更高版本
- Xcode 15.3 或更高版本（从 App Store 免费安装）

## 在本地运行（开发时）

这种方式启动的 DeskTidy 挂在终端下面，关掉终端窗口它也会退出。日常使用请用上面的"装成应用"。

```bash
# 第一次使用：让终端使用 Xcode 自带的工具，并同意 Xcode 的许可协议
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept

# 进入项目目录后运行
swift run DeskTidy
```

第一次运行需要编译，可能需要一两分钟。快捷键库 KeyboardShortcuts 已放在 `Vendor/` 里，不需要联网下载。

运行成功后：
- 终端显示：`桌面清理 0.1.0 已启动，请看屏幕右上角菜单栏里的星星图标。`
- 屏幕右上角菜单栏出现一个三颗星星的黑白小图标；Dock 里没有图标。
- 点击图标，弹出面板，有"一键清理""一键恢复""退出"三个按钮（前两个暂时还不工作）。

退出：点面板里的"退出"，或在终端按 `Ctrl + C`。

## 运行测试

```bash
swift test
```

输出中能看到 `Executed N tests, with 0 failures`（N 是测试数量，会随开发增加）即为通过。之后可能还有一行 `Test run with 0 tests passed`，属于正常现象。

## 用 Xcode 打开

```bash
open Package.swift
```

Xcode 打开后，在顶部选择 `DeskTidy` 和 `My Mac`，点运行按钮（▶）。

## 目录结构

```text
Package.swift              项目配置：名字、支持的系统版本、依赖库
Sources/
  DeskTidy/                应用本体：菜单栏图标、面板界面、启动设置
    main.swift             应用入口：启动应用，并设置不在 Dock 显示图标
    AppDelegate.swift      创建菜单栏图标，点击时弹出面板
    SettingsWindowController.swift  设置窗口（透明玻璃，场景、清理、专注、快捷键四个标签）
    Focus*.swift           番茄钟：计时、角落小时钟、什么时候提醒
    BreakOverlayPresenter.swift  休息时铺满屏幕的毛玻璃
    Views/                 界面
  DeskTidyCore/            核心逻辑：清理规则、场景、番茄钟计时规则、数据存储（不含界面）
Tests/
  DeskTidyCoreTests/       核心逻辑的自动测试
Vendor/KeyboardShortcuts/  快捷键库（开源，改了一处资源查找位置，见其中的 README）
Packaging/                 应用信息（Info.plist）、图标原图、安装说明
scripts/                   打包脚本：build-app.sh 装到自己电脑，package-release.sh 做安装包
docs/                      需求文档、技术方案、任务清单
```
