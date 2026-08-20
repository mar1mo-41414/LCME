# LCME Technical Details

[日本語版はこちら → TECHNICAL.md](TECHNICAL.md)

This document explains how the implementation works, for developers. For installation
and usage, see [README-EN.md](../README-EN.md).

## Source layout

| File | Role |
|---|---|
| `Sources/MEMachVM.h` | Manually declares prototypes for `mach_vm_*` functions that the iOS SDK blocks with `#error` |
| `Sources/MemScanner.*` | Core region enumeration, scanning, narrowing, and read/write logic |
| `Sources/FreezeManager.*` | Write-loop freeze implementation |
| `Sources/MEOverlayWindow.*` | Topmost overlay `UIWindow`; passes taps outside the panel through to the app below |
| `Sources/MEOverlayViewController.*` | The toggle button and panel UI |
| `Sources/MEResultCell.*` | One row of the result list (address, value edit, freeze toggle) |
| `Sources/MEConstructor.m` | Auto-starts on dylib load via `__attribute__((constructor))` |
| `Sources/MEDefs.*` | Supported value types and constants (e.g. tolerance) |

## Why this works without a jailbreak

This tweak never uses privileged, cross-process APIs like `task_for_pid` or `ptrace`.
Because LiveContainer's TweakLoader loads the dylib **into the same process as the target
app**, calling `mach_vm_read` / `mach_vm_write` / `mach_vm_region_recurse` against
`mach_task_self()` (its own task port) is enough to read, write, and enumerate memory.
Operating on your own process is an ordinary, sandbox-permitted operation available to any
app — it requires no jailbreak and no special entitlement.

The iOS SDK header (`<mach/mach_vm.h>`) blocks these functions with `#error`, but the
actual symbols still exist in libSystem at runtime, so `Sources/MEMachVM.h` manually
declares just the prototypes, which is enough to compile and link.

## How scanning works

1. Enumerate every memory region of the target task via `mach_vm_region_recurse` (descending recursively through submaps as needed)
2. Only consider writable (`VM_PROT_WRITE`) regions
3. By default, restrict further to **anonymous (malloc-family) regions** — `share_mode == SM_PRIVATE` with no external pager — which keeps the scan fast and heap-focused. Turning on full scan removes this restriction
4. Read each region in 4MB chunks via `mach_vm_read`, scanning at a stride equal to the type's byte size (numeric types) or byte-by-byte (strings). Each chunk overlaps the next by `type size - 1` bytes so matches spanning a chunk boundary aren't missed

Comparison rules differ by type:

- Integers and strings: exact match (`memcmp`)
- Float/double: fuzzy match with a small tolerance (`MEFloatTolerance` = 0.01, `MEDoubleTolerance` = 0.0001), similar to GameGuardian's fuzzy comparison
- Range search (min–max): the candidate bytes are converted to `double` and compared against the range. Int64/UInt64 can lose precision past 2^53, but this is not an issue for typical in-game values

Narrowing re-reads only the addresses already in the candidate list rather than rescanning
memory, so it stays fast even with many candidates.

## How freeze works

`FreezeManager` runs a repeating `dispatch_source` timer (100ms interval) that rewrites
every registered address via `mach_vm_write`. It uses a **write-loop** rather than thread
suspension, because suspending the app's UI thread from an in-process injection would also
freeze the overlay itself, making it impossible to unfreeze. The entry array is accessed
from both the main thread (UI) and the timer thread, so it's protected with `@synchronized`.

## UI implementation notes

- **Pass-through taps**: `MEOverlayWindow` overrides `hitTest:withEvent:` and returns `nil`
  whenever the hit view is the root view controller's own view (i.e. empty space outside
  the panel/toggle). This tells UIKit to route the touch to the next window behind it
  (the target app itself), so anything outside the panel passes straight through
- **Live-updating candidate list**: while the panel is open, values are refreshed every
  0.5s. Naively calling `UITableView reloadData` triggers cell reuse (dequeue), which broke
  `firstResponder` state (and dismissed the keyboard) even for a cell currently being
  edited. This was fixed by directly rewriting the currently visible cells instead
- **Tap detection**: dragging the toggle button uses a `UIPanGestureRecognizer`, but that
  recognizer never transitions to `Began`/`Ended` (and so never fires its callback) unless
  the touch moves past a minimum distance. So plain taps are detected via the standard
  `UIButton` `touchUpInside` event instead

## Explicitly out of scope

- Pausing/resuming the whole game (in-process injection would also freeze the UI/overlay;
  per-value freeze is used instead by design)
- Advanced features like code patching, pointer-chain scanning, memory dumping, or a Lua
  scripting engine (out of scope in favor of staying "simple, iOS 26, LiveContainer")

## Building from source

```bash
export THEOS=~/.theos
make
```

Output: `.theos/obj/debug/LCMemEditor.dylib`. For a release build, use `make FINALPACKAGE=1`.
