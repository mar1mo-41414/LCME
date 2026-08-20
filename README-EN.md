# LCME (LiveContainer Memory Editor)

[日本語版はこちら → README.md](README.md)

**LCME** provides Cheat Engine / GameGuardian-style memory search, edit, and
value-freezing for iOS apps running on top of LiveContainer (LC).

- Search a value, narrow down candidate addresses, and edit or freeze them
- Includes a range search for values that keep fluctuating, and a way to add an
  address directly if you already know it
- For implementation details and how it works internally, see [docs/TECHNICAL-EN.md](docs/TECHNICAL-EN.md)

## Requirements

- Targets iOS apps running under **LiveContainer, on a non-jailbroken device — no
  jailbreak required.**
- Built against iOS 26+
- LCME is loaded as a dylib into the same process as the target app via LC's
  TweakLoader; it never uses privileged, cross-process APIs like `task_for_pid`

## Install

The easiest way is to grab `LCMemEditor.dylib` from [Releases](../../releases) — each
tag is built automatically. To build it yourself instead:

1. Build this repo with an already-configured Theos installation

   ```bash
   export THEOS=~/.theos
   make
   ```

   This produces `.theos/obj/debug/LCMemEditor.dylib`

2. Copy the built `LCMemEditor.dylib` into LiveContainer's Tweaks folder
3. Set the target app's Tweak Folder to a folder containing this dylib
4. Launch the app — a green round toggle button ("LCME") appears as an overlay on the right side of the screen

## Usage

1. Tap the toggle button to open the panel
2. Pick a scan type via the "型" (type) button (Int32, Float, String, etc.)
3. Enter a value and tap "検索(新規)" (New Search) to get a candidate address list
   - Turn on "範囲検索" (Range search) to switch to min/max fields and find candidates
     within that range (useful for HP, currency, etc. that keep changing)
4. Change the value in-game, enter the new value, and tap "絞込" (Narrow) to shrink the candidate list
5. Edit a value inline in a row and press Enter/Return to write it immediately
6. Tap "固定" (Freeze) on a row to add/remove that address from the freeze set
7. Use the "フリーズ実行中/停止中" button at the bottom to start/stop the write loop for all frozen entries
8. If you already know an address, type it in hex into "0xアドレス直接指定" and tap "追加" (Add)

While the panel is open, the candidate list keeps refreshing automatically, so you can
watch values change in real time. Both the panel header and the toggle button can be
dragged to reposition them.

## Notice

Use this only on apps you own or are otherwise authorized to modify, e.g. for
single-player or personal testing purposes. Do not use it to cheat in online or
multiplayer contexts.
