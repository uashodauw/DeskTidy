# 桌面清理（DeskTidy，暂定名）

一个 Mac 菜单栏小工具：给同时开着一堆 AI 工具干活的人，一键收起眼前不需要的应用，让屏幕清爽、切换不掉帧。

当前状态：**开发中**。能在菜单栏显示图标和面板，还没有业务功能。

## 文档

- [需求文档](docs/Mac桌面清理工具需求文档.md)
- [技术方案](docs/Mac桌面清理工具技术方案.md)
- [任务清单](docs/Mac桌面清理工具任务清单.md)

## 运行环境

- macOS 13 或更高版本
- Xcode 15.3 或更高版本（从 App Store 免费安装）

## 在本地运行

```bash
# 第一次使用：让终端使用 Xcode 自带的工具，并同意 Xcode 的许可协议
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept

# 进入项目目录后运行
swift run DeskTidy
```

第一次运行会从 GitHub 下载依赖库，可能需要一两分钟。

运行成功后：
- 终端显示：`桌面清理 0.1.0 已启动，请看屏幕右上角菜单栏里写着「清理」的图标。`
- 屏幕右上角菜单栏出现一个三颗星星的黑白小图标，旁边写着"清理"；Dock 里没有图标。
- 点击图标，弹出面板，有"一键清理""一键恢复""退出"三个按钮（前两个暂时还不工作）。

退出：点面板里的"退出"，或在终端按 `Ctrl + C`。

## 运行测试

```bash
swift test
```

输出中能看到 `Executed 2 tests, with 0 failures` 即为通过。之后可能还有一行 `Test run with 0 tests passed`，属于正常现象。

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
    Views/                 界面
  DeskTidyCore/            核心逻辑：清理规则、场景、数据存储（不含界面）
Tests/
  DeskTidyCoreTests/       核心逻辑的自动测试
docs/                      需求文档、技术方案、任务清单
```
