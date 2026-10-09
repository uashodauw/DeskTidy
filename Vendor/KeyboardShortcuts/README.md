# KeyboardShortcuts (vendored)

Copy of [sindresorhus/KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) 2.3.0 (commit `045cf174010beb335fa1d2567d18c057b8787165`), MIT licensed (see `license`).

Only change: `Sources/KeyboardShortcuts/Utilities.swift` looks for its localization bundle in `Contents/Resources` of the app first. SwiftPM's generated `Bundle.module` only checks the .app root, but a code-signed app cannot contain files there.
