# LC Mem Editor

[日本語版はこちら → README.md](README.md)

A tweak (dylib) for LiveContainer (LC) that provides Cheat Engine / GameGuardian-style
memory search, edit, and value-freezing for iOS apps running on top of LC.

It is injected via LC's TweakLoader and runs **in-process** with the target app.
It never uses `task_for_pid` or similar privileged APIs — it only reads/writes its own
process memory (`mach_task_self()`) via `mach_vm_*` APIs.

## Features

- Drop the dylib into LC's Tweaks folder and assign it as the target app's Tweak Folder — no extra configuration needed
- Search a value → get a list of candidate addresses → edit/freeze individual candidates
- Narrowing search that re-scans the previous candidate set as values change in-game
- Freeze uses a **write-loop approach** (rewrites every 100ms); no thread suspension
- Supported types: Int8/16/32/64, UInt8/16/32/64, Float, Double, String (UTF-8, substring match)
- Float/Double comparisons use a small tolerance (GameGuardian-like fuzzy matching)
- Default scan targets writable anonymous (malloc-family) memory only, for speed; a full-memory scan option is also available
- The panel overlays on top of the target app; taps outside the panel/toggle pass straight through to the app underneath

## Explicitly out of scope

- Pausing/resuming the whole game (in-process injection would also freeze the UI/controls; value-freeze is used instead)
- Advanced features like code patching, pointer-chain scanning, or memory dumping

## Build

Requires an already-configured Theos installation.

```bash
export THEOS=~/.theos
make
```

The build output is `.theos/obj/debug/LCMemEditor.dylib`. For a release build, use `make FINALPACKAGE=1`.

## Install

1. Copy the built `LCMemEditor.dylib` into LiveContainer's Tweaks folder
2. Set the target app's Tweak Folder to a folder containing this dylib
3. Launch the app — a translucent round toggle button ("M") appears as an overlay

## Usage

1. Tap the toggle button to open the panel
2. Pick a scan type via the "型" (type) button (Int32, Float, String, etc.)
3. Enter a value and tap "検索(新規)" (New Search) to get a candidate address list
4. Change the value in-game, enter the new value, and tap "絞込" (Narrow) to shrink the candidate list
5. Edit a value inline in a row and press Enter/Return to write it immediately
6. Tap "固定" (Freeze) on a row to add/remove that address from the freeze set
7. Use the "フリーズ実行中/停止中" button at the bottom of the panel to start/stop the write loop for all frozen entries

The panel header and the toggle button can both be dragged to reposition them.

## Architecture

- `Sources/MEMachVM.h` — manually declares prototypes for `mach_vm_region_recurse` /
  `mach_vm_read` / `mach_vm_write`, which the iOS SDK header blocks with `#error`
  (the symbols still exist in libSystem at runtime, so this works)
- `Sources/MemScanner.*` — core region enumeration, scanning, narrowing, and read/write logic
- `Sources/FreezeManager.*` — write-loop freeze implementation using a `dispatch_source` timer
- `Sources/MEOverlayWindow.*` / `MEOverlayViewController.*` / `MEResultCell.*` — the UI overlay
- `Sources/MEConstructor.m` — auto-starts on dylib load via `__attribute__((constructor))`

## Notice

Use this only on apps you own or are otherwise authorized to modify, e.g. for
single-player or personal testing purposes. Do not use it to cheat in online or
multiplayer contexts.
