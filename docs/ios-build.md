# GenZD (iOS) — architecture and build notes

Reference for working on the iOS build of this UZDoom fork. Written after a large
upstream merge; file/line references are accurate as of that merge and may drift.

- Fork: `yoshisuga/UZDoom` (`origin`), upstream `UZDoom/UZDoom` (`upstream`)
- iOS product name: **GenZD**, bundle id `com.yoshisuga.genZD`, deployment target 15.0
- Engine is C++20; the iOS shell is Swift/SwiftUI + Objective-C++

---

## 1. Architecture

**Everything is one Mach-O.** The engine, the SwiftUI launcher, touch controls, the
on-screen keyboard and gamepad handling all link into a single `zdoom` CMake target whose
`OUTPUT_NAME` is `GenZD`. There is no separate framework or dylib for the engine.

**Startup flow:**

1. A forked SDL2 (prebuilt static lib, `bin/iOS/sdl/libSDL2.a`) owns the app lifecycle.
   The fork adds a hook, `SDL_iOS_GetLaunchViewController()`, declared in
   `bin/iOS/sdl/include/SDL_iOS.h` and implemented in `src/ios/ios_launch.m:43`.
2. That returns the SwiftUI launcher, so the launcher is shown *before* SDL's main runs.
3. The user picks IWAD/mods; `src/ios/Launcher/LauncherView.swift:632` calls
   `startSDLMain(withArgs:)` with an argv built in `LauncherViewModel`.
4. `GZDoomVIewController.swift:59` calls `IOSUtils.shared().doMain()` →
   `IOSUtils.mm` `doMain` → `GameMain()`.

**`GameMain()` returns cleanly** (`src/d_main.cpp:4184`). It runs a full teardown
(`D_Cleanup`, `GC::FullGC`, `C_UninitCVars`, `delete Args`) and there is an iOS-specific
block near `src/d_main.cpp:4238` that resets `restart = 0` and calls
`FBaseCVar::DisableCallbacks()`. The engine was deliberately made re-entrant-ish here so
control can return to the shell rather than the process exiting.

### Shell ↔ engine boundary

Bidirectional, and it passes engine types — this matters for any refactor.

| Direction | Surface |
|---|---|
| shell → engine | `D_PostEvent(event_t*)`, `FArgs`/`Args`, `GameMain()`, `keydef.h` / `dikeys.h` / `m_joy.h` constants |
| engine → shell | `src/ios/ios-input-hook.h` (13 functions), `src/video-hook.h`, `FBasicStartupScreen` |

Sizes (rough): `src/ios/` is ~16.5k lines, but only ~1.4k sit in engine-coupled files
(`IOSUtils.mm` 1188 lines with ~316 engine-touching, `ios_input.mm`, `ios_start.mm`,
`ios_launch.m`). The rest is pure UIKit/SwiftUI with no engine dependency.

### Engine files carrying iOS patches

Only 8 files outside `src/ios/` have `__IPHONEOS__` / `TARGET_OS_IPHONE` guards:

```
src/video-hook.h
src/common/platform/posix/sdl/i_input.cpp
src/common/platform/posix/sdl/i_joystick.cpp
src/common/platform/posix/sdl/sdlglvideo.cpp
src/common/platform/posix/sdl/st_start.cpp
src/common/audio/music/i_soundfont.cpp
src/common/engine/i_net.cpp
src/playsim/bots/b_game.cpp
```

That's ~26 lines total. The iOS port is a small, portable patch on top of the engine.

### Renderer: Vulkan only

`sdlglvideo.cpp` tries Vulkan and falls back to **desktop** OpenGL, which iOS cannot
provide (the engine's GL backend needs GL 3.3+). The `gles` backend in
`src/common/rendering/gles` is the Android/EGL path and is not wired to SDL's iOS video
driver. **iOS is Vulkan-through-MoltenVK or nothing.** MoltenVK is loaded at runtime via
`SDL_Vulkan_LoadLibrary(NULL)`, resolved through rpath, so each build can ship its own.

`sdlglvideo.cpp` has a GenZD branch forcing `Priv::vulkanEnabled = true` on iOS; other
platforms use upstream's `vid_preferbackend == BACKEND_VULKAN`.

### Platform source selection

In `src/CMakeLists.txt` (~line 433), with `OSX_COCOA_BACKEND=0`:

- **Used on iOS:** `PLAT_SDL_SOURCES` + `PLAT_POSIX_SOURCES` + `PLAT_OSX_SOURCES`
- **Excluded:** `PLAT_COCOA_SOURCES`

So `posix/sdl/*` and `posix/osx/iwadpicker_cocoa.mm` compile together, but
`posix/cocoa/*` does not. This combination is not what upstream tests, and is the source
of several link errors (see §4).

---

## 2. Building

### Configure

```bash
mkdir -p build-ios.YYYYMMDD && cd build-ios.YYYYMMDD
cmake -G Xcode \
  -DCMAKE_TOOLCHAIN_FILE=/Users/yoshi/Code/personal/UZDoom/bin/iOS/ios.toolchain.cmake \
  -DPLATFORM=OS64 \
  -DENABLE_BITCODE=0 \
  -DHAVE_VULKAN=1 \
  -DHAVE_GLES2=0 \
  -DOSX_COCOA_BACKEND=0 \
  -DFORCE_INTERNAL_BZIP2=1 \
  -DFLUIDSYNTH_INCLUDE_DIR=/Users/yoshi/Code/personal/UZDoom/bin/iOS/include/fluidsynth \
  -DFLUIDSYNTH_LIBRARY=/Users/yoshi/Code/personal/UZDoom/bin/iOS/libfluidsynth.a \
  -DNO_ASSERTS=ON \
  ..
```

Then open `UZDoom.xcodeproj`, scheme `zdoom`, and build.

**The `FLUIDSYNTH_*` pair is load-bearing.** Without it ZMusic builds its bundled
FluidSynth, which does `pkg_search_module(GLIB REQUIRED glib-2.0)` and links Homebrew's
**macOS** glib into an iOS binary. Confirm with `Using external FluidSynth library: ...`
in the configure output.

**Do not pass** these — they are dead, overridden, or actively harmful:
`FORCE_INTERNAL_ZMUSIC` (removed upstream; ZMusic is now always built from source, and
`ZMUSIC_LIBRARIES`/`ZMUSIC_INCLUDE_DIR` get overwritten at `CMakeLists.txt:485-486`),
`FORCE_INTERNAL_JPEG`, `FORCE_INTERNAL_ZLIB` (no such options), `OPENAL_*` and
`DYN_OPENAL` (handled structurally now, see §4), `SDL2_INCLUDE_DIR`/`SDL2_LIBRARY`
(set in-tree), `-Dstricmp=`/`-Dstrnicmp=` (no-ops — those become CMake cache variables,
not compiler defines; the real ones come from `gz_require_stricmp` at
`CMakeLists.txt:239`), and `PKG_CONFIG_EXECUTABLE=/usr/local/...` (wrong path on Apple
Silicon; CMake finds `/opt/homebrew/bin/pkg-config` itself).

### Reference of last resort

`CMakeCache.txt` from a known-good build directory is the authority on what actually
worked. `grep ":UNINITIALIZED=" CMakeCache.txt` reconstructs the `-D` flags that were
passed. Validate any proposed configure change against that, not against upstream's
defaults — several flags are load-bearing for control flow in ways their names don't
suggest.

### ZERO_CHECK

CMake's Xcode generator adds a `ZERO_CHECK` aggregate target running
`CMakeScripts/ReRunCMake.make`, which watches ~182 CMake inputs and re-runs CMake when
any changes. Every other target depends on it, so it normally runs first.

- After editing any `CMakeLists.txt` / `.cmake`: build **ZERO_CHECK** (Product → Scheme →
  ZERO_CHECK, ⌘B), or run `cmake .` in the build dir. Both do the same thing.
- It has been observed **not** to fire on incremental retries of a failed build. If a
  CMake edit seems to have no effect, check whether `project.pbxproj` is older than your
  edit before debugging anything else.
- Because it silently regenerates the project, **hand-edited Xcode build settings are
  lost**. Never fix things in the Xcode GUI — change CMake or the cache.

### Assertions

`-DNO_ASSERTS=ON` (option added at `CMakeLists.txt:392`) adds `-DNDEBUG` to the Debug
C/C++ flags.

**`NDEBUG` changes the native-function ABI**: `VM_ARGS` at
`src/common/scripting/vm/vm.h:488` drops the `reginfo` parameter when it is defined. It
must therefore be uniform across everything that includes `vm.h` — which is why the
option sets it globally before any `add_subdirectory`, rather than per-target. Release,
MinSizeRel and RelWithDebInfo already get `-DNDEBUG` from CMake's own defaults.

### Game data (pk3) staging

Five archives must sit at the **root of the .app** (iOS bundles are flat), because
`BASEWAD` = `uzdoom.pk3` is resolved at runtime relative to `progdir`:
`uzdoom.pk3`, `brightmaps.pk3`, `lights.pk3`, `game_support.pk3`,
`game_widescreen_gfx.pk3` — plus `soundfonts/` and `fm_banks/`.

Upstream's `add_pk3` copies into `ZDOOM_RESOURCE_DIR`, which on Apple is
`${PROJECT_BINARY_DIR}/${ZDOOM_EXE_NAME}.app/Contents/Resources` — wrong app name
(`uzdoom` vs `GenZD`), macOS layout, and no per-config directory. On iOS that is a stray
directory that never ships. `genzd_target_config.cmake` therefore stages everything into
`$<TARGET_BUNDLE_DIR:zdoom>` with `POST_BUILD` commands on `zdoom` itself.

> **This must be POST_BUILD on `zdoom`.** A separate copy target referencing
> `$<TARGET_BUNDLE_DIR:zdoom>` gains an automatic dependency on `zdoom`, while `zdoom`
> already depends on the `*_pk3_copy` targets → CMake fails with an inter-target
> dependency cycle.

The pk3 list in `genzd_target_config.cmake` is **hardcoded**. If upstream adds a sixth
archive it must be added there; the symptom is a missing-lump error at startup, not a
build failure.

**pk3 staleness:** `add_pk3`'s `add_custom_command` declares `DEPENDS zipdir` — the
*tool*, not the data under `wadsrc*/static/**`. Upstream ZScript changes therefore do not
trigger a rebuild. After merging upstream, delete the pk3s from the build dir before
building, or you get a new engine with old scripts (which presents as script errors that
look like engine bugs).

---

## 3. Where things live

```
src/ios/                        iOS shell: SwiftUI launcher, touch controls, keyboard
src/ios/genzd_target_config.cmake   ALL iOS build config; included from src/CMakeLists.txt (~1580)
src/ios/ios-input-hook.h        engine → shell hook declarations (13 functions)
src/ios/IOSUtils.mm             the file that straddles both sides
bin/iOS/                        prebuilt deps: SDL2, MoltenVK, openal, WebP, VPX, fluidsynth
bin/iOS/sdl/SDL2 -> include     symlink so upstream's <SDL2/SDL.h> resolves (see §4)
libraries/                      vendored subtrees: ZMusic, ZWidget, ZVulkan, abseil, ...
```

`genzd_target_config.cmake` also globs `src/ios/**` with `file(GLOB_RECURSE)` and
**nothing in the tree uses `CONFIGURE_DEPENDS`**. New Swift/ObjC files under `src/ios/`
are therefore *not* picked up until CMake re-runs for some other reason. Fix:
`touch CMakeLists.txt`, then build. Engine sources are explicit lists, so upstream
additions come through fine.

---

## 4. Traps (all of these have bitten)

### Cross-compilation grabs Homebrew macOS libraries

The single most common failure. `find_package` / `pkg_check_modules` happily return
host-architecture libraries during an iOS cross-compile. **Tell:** a `/opt/homebrew/` path
in the error, or "building for 'iOS' but linking in dylib built for 'macOS'".

Known instances and their fixes:

- **glib** via ZMusic's bundled FluidSynth → pass `FLUIDSYNTH_INCLUDE_DIR`/`_LIBRARY`.
- **OpenAL** — `find_package(OpenAL)` finds the iOS SDK's *deprecated* `OpenAL.framework`,
  which then adds macOS-only `-framework AudioUnit -framework ApplicationServices`
  (`AudioUnit` on iOS is headers-only, no linkable binary). Fixed structurally with an
  empty iOS branch at `src/CMakeLists.txt:118`: iOS needs nothing here because
  `oalsound.h:48` has a `TARGET_OS_IPHONE` branch using in-tree `thirdparty/al.h`, and
  `genzd_target_config.cmake` links the bundled `openal.framework`.
- **SDL2 for ZWidget** — ZWidget is configured (`CMakeLists.txt:424`) long before
  `genzd_target_config.cmake` runs, so its own `find_package(SDL2)` used to pick up a host
  SDL (it was pointing at an entirely different repo). Fixed by setting
  `SDL2_INCLUDE_DIR`/`SDL2_LIBRARY` for iOS just before that `add_subdirectory`.

### The `zdoom` target compiles Swift

It mixes C, C++, Objective-C++ **and Swift**. `target_compile_options(zdoom ...)` applies
to *all* languages, so a Clang-only flag reaches `swiftc` and fails with
`Driver threw unknown argument`. Use `set_source_files_properties(... COMPILE_FLAGS ...)`
per file. The Xcode generator's support for `$<COMPILE_LANGUAGE:CXX>` is uneven, so
per-source is the safer tool.

### `-fconstexpr-steps` for `utility/name.cpp`

`FindDuplicates()` constexpr-sorts the ~1100-entry `PredefinedNames` array, exceeding
Clang's default 1048576 constexpr step limit under libc++ with PCH. Symptom:
`static assertion expression is not an integral constant expression`, with a note reading
`constexpr evaluation hit maximum step limit`. Fixed per-source at
`src/CMakeLists.txt:1286`. Not upstream's problem elsewhere — GCC's equivalent limit is
far higher and other standard libraries cost fewer steps.

### Audio decoders must be static, never dlopen'd

ZMusic defaults `DYN_MPG123=ON` and `DYN_SNDFILE=ON`, which makes it load decoders at
runtime via `dlopen("libmpg123.0.dylib")` / `dlopen("libsndfile.1.dylib")`. **Those files
cannot exist in an iOS app bundle**, so `IsMPG123Present()` / `IsSndFilePresent()` return
`false` and the decoders are silently unavailable — even though `libmpg123.a` and
`libsndfile.a` are linked into the binary.

Symptom: a mod plays **no sound at all** for its MP3/WAV/FLAC assets, with no error. OGG
still works (stb_vorbis is compiled in, see `sounddecoder.cpp`) and so does DMX, so this
presents as "some mods have sound, some don't" rather than as a total failure.

Fixed with iOS branches in `libraries/ZMusic/source/CMakeLists.txt` that define
`HAVE_SNDFILE` / `HAVE_MPG123` **without** the `DYN_` variants, taking the
`#if !defined DYN_MPG123 → return true` path. Do *not* let it fall through to
`find_package(SndFile)` / `find_package(MPG123)` — that hits the Homebrew trap above.

Consequence: once `libsndfile.a` is genuinely pulled into the link, its LAME (`lame_*`,
`id3tag_*`) and Opus (`opus_*`) references appear as undefined symbols. `bin/iOS/liblame.a`
and `bin/iOS/libopus.a` supply them and must be listed **after** `libsndfile.a` in
`genzd_target_config.cmake`.

Format → decoder map:

| Format | Handled by |
|---|---|
| DMX | engine native |
| OGG Vorbis | stb_vorbis, compiled in |
| MP3 | libmpg123 |
| WAV, FLAC | libsndfile |
| MIDI | FluidSynth (no system MIDI on iOS) |

### iOS SDK gaps vs macOS

- `CoreAudio/HostTime.h` — **macOS only**. iOS `CoreAudio.framework` ships only
  `CoreAudioTypes.h`. ZMusic's `music_coremidi_mididevice.mm` needs it, so
  `libraries/ZMusic/source/CMakeLists.txt` has an iOS branch (placed *before* the `APPLE`
  branch) leaving `HAVE_SYSTEM_MIDI` undefined. iOS uses FluidSynth for MIDI.
- `AudioUnit.framework` — present but **headers only**, no linkable binary. The
  implementation is in `AudioToolbox`.
- `ApplicationServices` — does not exist on iOS.

### `<SDL.h>` vs `<SDL2/SDL.h>`

Upstream includes SDL as `<SDL2/SDL.h>` (13 files), but the prebuilt iOS headers are flat
in `bin/iOS/sdl/include/`. Rather than diverge on every include line, there is a
**symlink** `bin/iOS/sdl/SDL2 -> include` and the parent dir is on the include path, so
both forms resolve. Keep taking upstream's include lines verbatim.

### FluidSynth version skew (benign, but know about it)

| Source | Version |
|---|---|
| `libraries/ZMusic/thirdparty/fluidsynth/include` (used for compiling) | 2.4.8 |
| `bin/iOS/libfluidsynth.a` (linked) | 2.5.2 |
| `bin/include/fluidsynth` (**untracked**, incomplete/stale) | 2.3.2 |

Compiling against 2.4.8 headers while linking 2.5.2 is fine — FluidSynth keeps ABI
compatibility across 2.x minors. `bin/iOS/include/fluidsynth` has the component headers
but **no `fluidsynth.h`**, so it cannot be used as an include root. Do not "fix" the
include dir to point at it or at `bin/include/fluidsynth`.

Related upstream bug, patched locally: `find_package(FluidSynth)` runs in
`libraries/ZMusic/thirdparty/CMakeLists.txt` but `FLUIDSYNTH_FOUND` is a *non-cache*
variable, invisible in the sibling `source/` scope. `source/CMakeLists.txt` therefore
always chose the internal target name and degraded to `-lfluidsynth`. Fixed by testing
`if(TARGET libfluidsynth)` — the imported target is created `GLOBAL`, so it is visible
everywhere.

### `I_PickIWad_Cocoa` signature split

`posix/sdl/i_system.cpp:60` declares and calls the **old** signature
`(WadStuff*, int, bool, int)`, while upstream's `posix/osx/iwadpicker_cocoa.mm` now
defines only `(FStartupSelectionInfo&)`. Those two files only compile together when
`OSX_COCOA_BACKEND=0` on Apple — i.e. exactly this configuration — so upstream never hits
it. `iwadpicker_cocoa.mm` carries a `TARGET_OS_IPHONE` stub with the old signature. The
picker is never shown on iOS (the SwiftUI launcher supplies the IWAD), so the stub logs
and returns 0.

### Merge fallout does not show up as conflicts

Several breakages after a big upstream merge produced **no** git conflict, because the
fork had *removed* something upstream later changed, or relied on a transitive include:

- `ios_start.mm` implemented 11 `FBasicStartupScreen::Net*` methods that upstream deleted
  wholesale (`a04b1d517a "Always use netgame ZWidget"`); also lost its transitive
  `basics.h` (needed for `min`) when `st_start.h` was trimmed to `<stdint.h>`.
- ZMusic's CoreMIDI file had been *deleted* in the fork and the merge restored it.

**Build early and often after a merge; the compiler finds these, git does not.**

---

## 5. Open work

- **iOS multiplayer is broken by the upstream merge.** Upstream removed the entire
  `FStartupScreen` net API in favour of a ZWidget lobby. The
  `IOS_ShowSystemModal` / `IOS_SpinRunLoop` / Bonjour hooks that drove
  `MultiplayerHostDiscovery.swift` and `MultiplayerStatusManager.swift` no longer have a
  call site. Those six `IOS_*` functions still exist in `IOSUtils.mm` and still compile;
  they are simply unreachable from the engine. Needs rebuilding against the new lobby.
- Upstream-worthy bug reports: the FluidSynth `_FOUND` scope bug; Apple+SDL backend not
  linking (`I_PickIWad_Cocoa`); the constexpr sort sitting on Clang's default step limit.
