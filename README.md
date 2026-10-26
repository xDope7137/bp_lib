# bp_lib

> **Full documentation: [https://docs.bhavikp.in/scripts/bp-lib/](https://docs.bhavikp.in/scripts/bp-lib/)**  
> Install steps, every config option, exports and fixes for common problems.

FiveM compatibility library for BP Development resources. It is a fork of [peuren_lib](https://peuren.dev) by Peuren, under the MIT licence in `LICENSE`.

## Download

Get the latest zip from [Releases](https://github.com/xDope7137/bp_lib/releases). It extracts to a folder named **`bp_lib`**, ready to drop into `resources/`.

1. Download `bp_lib-vX.Y.Z.zip` from the latest release.
2. Extract it and move the `bp_lib` folder into `resources/`.
3. Add `ensure bp_lib` to `server.cfg`, after your framework and `ox_lib` and before any BP Development script.

Keep the folder name `bp_lib`. Every dependent script calls `exports['bp_lib']`.

## Documentation

Install guide, config keys and the Core API: [https://docs.bhavikp.in/scripts/bp-lib/](https://docs.bhavikp.in/scripts/bp-lib/)

## Auto-detection

Leaving a compatibility option in `shared/config.lua` set to `nil` tells the library to pick the matching adapter when one of the supported resources is already running on your server. The detected selection is cached in `Config.AutoDetected` for debugging when `Config.Debug` is enabled.

## Releases

A release is built when a `v*` tag is pushed. The tag should match the `version` in `fxmanifest.lua`.
