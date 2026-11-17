This is the Rosetta (D3DMetal + MacGameFix) route. The recommended route is FEX on `main`.

# fh6-mac-fix: Rosetta + D3DMetal + MacGameFix route

## Which branch should I use?

| Branch | Stack | Observed (our own tests, 16 GB Mac) |
|---|---|---|
| [`main`](https://github.com/sliver-exes/fh6-mac-fix/tree/main) (recommended) | native arm64 Wine + FEX + KosmicKrisp | No once-a-second freezes. Online works. Uses the most RAM. Needs macOS 27. No install scripts: manual or agent-guided steps. |
| [`rosetta-d3dmetal`](https://github.com/sliver-exes/fh6-mac-fix/tree/rosetta-d3dmetal) (this branch) | Rosetta + D3DMetal + MacGameFix | Uses less memory and is faster per frame. With the frame pacer (below) it plays smoothly at a steady 40 to 60 fps. The FHE21 crash can still happen at start-up. Slow texture streaming and short hitches on 16 GB. Once-a-second freezes cut to about a tenth, not removed. DLSS does not work. |

This branch has its own `./install.sh` (below).

Fixes and tools to run **Forza Horizon 6 (Steam)** on an Apple Silicon Mac under Wine with Rosetta and Apple's D3DMetal, using the d3d12 proxy from
[sliver-exes/fh5-d3dmetal-fix](https://github.com/sliver-exes/fh5-d3dmetal-fix). The installer and guide below are written and tested for
[Bridgeplay](https://github.com/raymondchins/Bridgeplay)'s **WineCX 11.17** runner with Steam (see "Tested setup"); users of CrossOver, NotProton or other Wine
wrappers can adapt the files at their own risk (that is your lookout; names, paths and hashes here are specific to the tested setup).

This branch has two routes, chosen by one flag:

| Route | Command | What you get |
|---|---|---|
| **MGF (default)** | `./install.sh` | The best Rosetta setup we have tested: smooth, the once-a-second freezes cut to about 10%, dialogue and voices work. Add `--pacer` for the frame pacer (see "Recommended setup"). FHE21 can still happen at start-up (see "Known limits"). A new runner and Steam tool, "MGF WineCX 11.17", built on [MacGameFix](https://github.com/MathiasKowoll/MacGameFix) plus Highball's audio fix. |
| MGF + pacer | `./install.sh --pacer` | The MGF route plus MacGameFix's frame pacer, the setup we tested most recently (2026-11-17). Details in "Recommended setup". |
| Plain (old) | `./install.sh --plain` | Only the D3DMetal proxy that gets past the FH206 start-up error. Freezes about once a second, FHE21 can crash it, no dialogue. Kept as an option. |

Only one route is installed at a time, so Steam shows one Rosetta tool for the game. Running the other route's
command swaps it (our copies of the other route are removed; Bridgeplay's stock runner and tool are never touched).

Without the proxy, FH6 stops at the start with *"Your graphics card is not supported. (Code: FH206)"* and
*"Unable to detect graphics driver version. (Code: FH302)"* and only a **Quit** button.

> **Want no 1-second freezes at all?** The [`main` branch](https://github.com/sliver-exes/fh6-mac-fix/tree/main)
> runs the game on native arm64 Wine with FEX, where the anti-tamper's exceptions stay inside the process and the
> freezes are gone. It is slower per frame than this branch. The two branches can be switched between: each
> installer moves the other's Wine prefix aside (never deleting it) and puts yours back.

## First time? Step by step

Written for someone who has never used the Terminal. You need an Apple Silicon Mac (macOS 27), Steam with Forza Horizon 6
installed, and [Bridgeplay](https://github.com/raymondchins/Bridgeplay) (a free app that runs Windows games on the Mac).

**Before you start (once):**

1. Install Bridgeplay, **open it once**, and let it install its runner called **WineCX 11.17** (it asks, or find it in its
   runner settings). To check, the Terminal command `ls ~/Library/Application\ Support/bridgeplay/runners` must list
   `crossover-winecx-11.17`.
2. Start Steam once, make sure Forza Horizon 6 is installed, then **quit Steam** (Steam menu > Quit Steam). The script
   needs Steam closed, and asks to close it for you.

**Install:**

3. Press `Cmd` + `Space`, type `Terminal`, press `Return`. A window with a blinking cursor opens. The first time you use
   `git`, macOS may offer to install the "command line developer tools". Click **Install** and wait for it to finish
   (this also gives you `python3`, which the script needs), then paste the commands again.
4. Paste these three lines, one at a time, pressing `Return` after each:

   ```sh
   git clone -b rosetta-d3dmetal https://github.com/sliver-exes/fh6-mac-fix
   cd fh6-mac-fix
   ./install.sh
   ```

   The script takes about a minute. It makes a copy of the runner (about 1.3 GB, instant on a normal Mac disk), so nothing in Bridgeplay is changed. You will see lines starting with a green tick when a step worked. If something is missing the
   script says in plain words what to do and stops; fix that and run `./install.sh` again (it is safe to repeat).
5. If this is a brand-new install of the game (it has never been started), the script asks "start the game once?". Answer `y`: Steam opens, the game starts and shows an error dialog (FH206, expected) or the menu. Close the game, and the script finishes by itself. If it says "Done", the install worked.

**Play, in Steam:**

6. Open Steam, go to your Library, click **Forza Horizon 6**. Right-click it > **Properties** > **Compatibility**: it should
   already say "Force the use of a specific Steam Play compatibility tool" with **MGF WineCX 11.17 (FH6, MacGameFix exception chain)** selected. (If not, tick the
   box and pick it from the list.)
7. Click **Play**. If a warning about the graphics driver (FH302) appears, click **Ignore Warning**.

**Check that everything is fine:** back in the Terminal run `./doctor.sh`. It changes nothing and prints PASS, WARN or
FAIL for each part. The last line says "All checks passed" when everything is right. A FAIL line says what to do.

**Undo everything:** `./uninstall.sh`. It removes only what the installer added; your game, saves and Bridgeplay stay.

## Quick start

```sh
git clone -b rosetta-d3dmetal https://github.com/sliver-exes/fh6-mac-fix
cd fh6-mac-fix
./install.sh
```

Then open Steam and press **Play** on Forza Horizon 6. The script checks everything first and tells you what to
fix if something is missing. If the game has no Wine prefix yet (a fresh install), the script offers to start the
game once for you (`open steam://rungameid/2483190`), waits for the prefix to appear, asks you to quit the game
(the FH206 dialog is expected once), and then finishes by itself. If you answer N, it installs everything else and
tells you to press Play once, quit at the menu, and run `./install.sh` again, which takes seconds. `./install.sh -y`
answers yes to every question. Check the result any time with `./doctor.sh`. If the FH302 driver warning appears,
click **Ignore Warning**.

## Recommended setup (tested 2026-11-17)

This is what gave the smoothest play on an M5 MacBook Air (16 GB, 60 Hz screen, macOS 27.0.1).

**1. Install with the pacer.** In the Terminal: `./install.sh --pacer`. It puts MacGameFix's `d3d12-fh6.dll` in the
game folder (as `d3d12.dll`) instead of the plain proxy. Besides the start-up fix, it runs a small "pacer" thread that keeps Rosetta's store
of translated code small, so the 0.1 to 0.17 s stop Rosetta makes every ~10 seconds (when that store fills and is
emptied) becomes too short to notice. It loads Apple's real D3DMetal as `apd12.dll`, which the installer already provides. Run
`./install.sh` again without `--pacer` to go back to the plain proxy. The file is MacGameFix's, unchanged (commit
`ef19e41`, see `bin/CREDITS.md`).

**2. Steam launch options.** Forza Horizon 6 > Properties > General > Launch Options. Paste this whole line:

```
BRIDGEPLAY_DISABLE_HIDRAW=1 NOTPROTON_PERF_OVERLAY=summary NOTPROTON_ENV_WINENCPU=8 D3DM_MAX_FPS=60 NOTPROTON_ENV_MGF_FH6_ROSETTA_PACER=40 NOTPROTON_ROSETTA_TRAP_BOOST=1 %command%
```

**Important, on Bridgeplay: the pacer setting needs the `NOTPROTON_ENV_` prefix.** Bridgeplay (like NotProton) starts
the game with an empty environment and passes on only the variables it knows (`D3DM_*`, `ROSETTA_*`,
`NOTPROTON_ENV_*` and a few more). So `MGF_FH6_ROSETTA_PACER=40` written plainly never reaches the game, and the pacer
silently does nothing. `NOTPROTON_ENV_MGF_FH6_ROSETTA_PACER=40` does. (We saw this on Bridgeplay; on real NotProton
with MacGameFix installed it may differ.) The same rule applies to any other variable meant for the game.

**How to check the pacer is running:** after one start of the game, the file `C:\mgf\fh6-pacer-<number>.log` exists
inside the game's Wine prefix (`~/Library/Application Support/Steam/steamapps/compatdata/2483190/pfx/drive_c/mgf/`)
and gets a new line every 10 seconds while you play. No file means the pacer is not on.

What the options do: `D3DM_MAX_FPS=60` caps at the screen's 60 Hz. The pacer value (1 to 100) is how much of the time the pacer thread works;
40 to 50 was best in MacGameFix's tests and 40 is what we played. MacGameFix's guide uses `D3DM_MAX_FPS=48` on ProMotion
screens; on a fixed 60 Hz screen a 48 cap judders, so use 60. `NOTPROTON_ENV_WINENCPU=8` tells the game it has 8 CPU cores. `NOTPROTON_ROSETTA_TRAP_BOOST=1` is the
trap boost (the MGF tool on this branch already has it on by default, so it changes nothing here). On a Mac with fans,
MacGameFix also has a fan setting (`MGF_FANS=max`); it does nothing on a fanless MacBook Air.

**3. In-game settings.** Frame rate: **Unlimited** (the caps above do the work). Upscaling: **FSR 3.1.5, Quality**
(not DLSS, see "Known limits"). If the game still feels locked at 30 fps, a hidden value is left over from an earlier
30 fps choice. With the game closed, open the file
`~/Library/Application Support/Steam/steamapps/compatdata/2483190/pfx/drive_c/users/<your Mac user name>/AppData/Local/ForzaHorizon6/LocalStorage_Shared/ForzaUserConfigSelections/UserConfigSelections`
in a text editor and look for `PresentInterval`. **2** means a 30 fps cap; set it to **0**.

## Requirements

- Apple Silicon Mac. Tested on an M5 MacBook Air (16 GB) with macOS 27.0.1.
- [Bridgeplay](https://github.com/raymondchins/Bridgeplay) 0.7.64 or newer, opened once, with its **WineCX 11.17**
  runner installed (it also provides D3DMetal). Its files are read and copied, never changed.
- Forza Horizon 6 installed in Steam (any Steam library).
- `python3` (Xcode command-line tools: `xcode-select --install`).
- About 1.5 GB free for the runner copy (on APFS it is a space-free clone). No downloads: everything needed is in `bin/`.

## What each fix does (MGF route)

**Exception chain, ALU bridge (MacGameFix's `ntdll.dll`).** The game's anti-tamper deliberately raises about 4.5
million illegal-instruction exceptions. Under Rosetta each one is a round trip through the kernel, which shows up as
a freeze of about a second. MacGameFix's `ntdll.dll` handles many of those exceptions inside the process (the
"exception chain", and the "ALU bridge" for simple arithmetic instructions the anti-tamper uses), so the kernel trip
never happens. The tool's `run` script switches it on with three settings (`WINE_SOFTWARE_EXCEPTION_CHAIN=1`,
`ALU_BRIDGE=1`, `BRIDGE_RESUME=0`; `EXCEPTION_STATS=1` keeps its counters on). It only acts for `forzahorizon6.exe`
(checked against the exe's PE header), so other games ignore it. No game file is changed.

**Trap boost (`notproton-rosetta-trap-boost.dylib`, MacGameFix).** Exceptions that remain are handled by one Rosetta
thread per process, which runs at normal priority and waits for a CPU core when the game keeps them all busy. The
boost raises that thread's priority once a second. On by default. Turn it off by creating an empty file
`mgf-trap-boost.off` in `Steam/compatibilitytools.d/bridgeplay-proton-fh6-mgf/`, or with
`MGF_TRAP_BOOST=0` in Steam's environment.

**Steam detour and unwind fix (ours, in the same `ntdll.dll`).** Bridgeplay's launcher expects the runner's `ntdll`
to hook the Steam client DLL; MacGameFix's build has the function but never calls it, so we added the call (logic
by Bridgeplay). We also added a fix that stops `RtlVirtualUnwind2` writing through NULL optional arguments. About
200 bytes in total; `tools/port_ntdll_hooks.py` rebuilds the file from MacGameFix's original and checks hashes.

**Spatial audio, for missing dialogue (`winecoreaudio.so`).** FH6 does not use the Mac's stereo output format; it opens
a 12-channel (7.1.4) spatial-audio bed. Stock Wine on macOS sets up 12 channels but nothing mixes them down, so only
front left and right are heard and the **centre channel, which carries voices and dialogue, is silent**. Highball's
patch 0057 (by TxCsOffc, Highball PR #313) folds the bed down through Apple's spatial mixer. CrossOver's driver is a
different build from Highball's, so Highball's binary is not a drop-in; we compile Wine 11.17's driver plus that
patch (`tools/winecoreaudio/build.sh`). The runner's original is kept as `winecoreaudio.so.cx`. Side effect: the
microphone-permission prompt of CrossOver's build is gone (the game does not record).

**C++ runtime override (the FHE21 crash).** Wine's built-in `concrt140` has a race in its concurrent vector that
crashes FH6 (error FHE21). The tool forces Microsoft's own `concrt140` (`concrt140=n,b`), the Highball tweak
`concrt140-native`. We narrowed it to that one DLL because forcing the whole native Visual C++ set cost dialogue
audio in our tests.

**MetalFX off.** `gamefixes/2483190.conf` sets `D3DM_ENABLE_METALFX=0`. This stops Apple Neural Engine errors and a
hang after a resolution change. Consequence: DLSS is not available; use **FSR** in the game's graphics settings. See "Known limits" for what happens if you turn it on.

## What install.sh changes

1. Asks to quit Steam if it is running (Steam rewrites its config on exit).
2. **Prefix**: this route needs the x86-64 (Rosetta) prefix. If the game's prefix is the arm64 (FEX) one, it is moved
   aside to `compatdata/2483190.fex` and an earlier `compatdata/2483190.rosetta` is put back. Nothing is deleted;
   the FEX route on `main` does the reverse by hand.
3. Builds `apd12.dll` from your own D3DMetal (the proxy needs it under that name).
4. **Default (MGF) route**: clones Bridgeplay's stock `crossover-winecx-11.17` to `crossover-MGF-winecx-11.17`
   (instant on APFS), adds `apd12.dll`/`apd12.so`, puts the MGF `ntdll.dll` and the spatial-audio `winecoreaudio.so`
   into it (originals kept as `ntdll.dll.mgf-orig` and `winecoreaudio.so.cx`), creates `bridge/wine/MGF-winecx-11.17`
   with the same `ntdll.dll`, and the Steam tool `bridgeplay-proton-fh6-mgf` (`run`, the trap-boost dylib and
   three small files from `bin/mgf/`). Shown in Steam as **MGF WineCX 11.17 (FH6, MacGameFix exception chain)**.
   Nothing of the plain route is installed; leftovers of it (our copies) are removed.
5. **`--plain` route**: instead copies the stock runner to `crossover-FH-winecx-11.17` (plus `apd12`), creates the
   tool `bridgeplay-proton-fh6-plain` and `bridge/wine/FH-winecx-11.17`, and removes our MGF copies.
6. Writes `gamefixes/2483190.conf` (a previous one is kept as `2483190.conf.fh6-bak`) and adds the proxy `d3d12.dll` to
   the game folder.
7. Sets Forza Horizon 6's compatibility tool in Steam's `config.vdf` (backup `config.vdf.fh6-orig`), or prints the
   one click if that cannot be done safely.
8. If there is no prefix yet: offers to start the game once, waits for `compatdata/2483190/pfx/user.reg`, waits until
   you quit the game, quits Steam, then adds `apd12.dll` and `HB_D3D12_REAL` to the new prefix.

It is safe to run again (every step checks hashes and skips what is done). `./install.sh -y` answers yes to every
question. A copy of the prefix's `user.reg` from before the change is kept as `user.reg.fh6-orig`.

## Tested setup

| | Installer route as shipped | Recommended setup (2026-11-17) |
|---|---|---|
| Machine | Apple M5 MacBook Air, 16 GB, macOS 27 | Apple M5 MacBook Air, 16 GB, macOS 27.0.1, 60 Hz screen |
| Game | Forza Horizon 6, Steam app 2483190, build 26422872 (legitimately owned) | same |
| Runner | Bridgeplay 0.7.64, `crossover-winecx-11.17` | Highball r32 (Wine 11.0) with MacGameFix's ntdll patches 0023 to 0025 ported to it |
| D3DMetal | 4.0 beta 3 | 4.0 beta 3 (Apple GPTK 4.0 beta 3, the newest on 2026-11-17) |
| d3d12 proxy | `fh5-d3dmetal-fix` commit `ebd20db`, `bin/d3d12.dll` SHA-256 `c5d48ab9...9115f7` | MacGameFix `d3d12-fh6.dll` (pacer), MacGameFix commit `ef19e41` (PR #89), SHA-256 `4028c3f3...8e35e` |
| MGF | MacGameFix commit `881f3a96` (v1.6.3), ntdll 27.0.0.41073, trap boost sha256 `ce9dd6b0...8672` | trap boost from `ef19e41` (same file, `ce9dd6b0...8672`) |
| GPU identity | NVIDIA RTX 4070 (vendor 4318, device 10118) | same |
| Audio | Wine 11.17 `winecoreaudio.drv` + Highball patch 0057 | not re-tested |
| Online | not covered | works with the x86-64 `ws2_32` netfix (see "Online play") |
| Result | Smooth, 1-second freezes cut to about 10%, dialogue works (confirmed by the user) | Smooth at a steady 40 to 60 fps; FHE21 at start-up in about half of launches; hitches of 0.3 to 0.8 s every 30 to 60 s |

**Not verified:** the pacer (`./install.sh --pacer`) on this branch's `crossover-MGF-winecx-11.17` runner copy. It was
tested on the Highball r32 runner. CrossOver 26.3.0 ships an older D3DMetal (3.0): do not use it for this route.

Other versions are untested. The MacGameFix `ntdll.dll` is built for CrossOver Preview 20261015 and is used here in
Bridgeplay's CrossOver-based 11.17 runner; that combination is what we tested.

## Known limits and tips

- **16 GB Macs are memory-limited.** Streaming is slow, so crowds and scenery appear late; there is memory
  compression; after an off-road reset the screen can stay black for about 2 minutes. Tips: texture quality **Very
  Low**, **Dynamic Optimization off**, close other apps, restart the Mac before playing. 32 GB Macs do much better.
- **Do not clean the D3DMetal shader cache.** It lives at `$(getconf DARWIN_USER_CACHE_DIR)d3dm`
  (`/var/folders/.../C/d3dm`). Rebuilding it costs minutes of stutter; cleaning tools such as Mole or "Clean My Mac"
  may offer to remove it. Leave it alone.
- **DLSS (MetalFX) does not work.** On an M5 with macOS 27.0.1 and D3DMetal 4.0 beta 3 it fails: the Apple Neural
  Engine logs "doCompileModel ... Bad argument", then `MTL4CommandQueueErrorDomain` error 1 (command buffer errors),
  then a hang or an FHC20 "Video Card Crash". It happened both when switched on in the middle of a session and when
  switched on before launch. DLSS in Forza Horizon 5 works on the same Mac; FH6 ships a newer DLSS (including ray
  reconstruction and DirectSR), which is the likely difference. Use **FSR 3.1.5 Quality**. Only if you want to try it
  yourself: `D3DM_ENABLE_METALFX=1` in the launch options.
- **FHE21 at start-up (about half of launches).** Usually during the intro drive. The log shows a 60-second wait on a
  critical section, then `AGX: exceeded compiled variants footprint limit` (Apple's GPU driver has a limit on the number
  of compiled shader variants). Starting the game again usually gets past it. The FEX route on `main` does not have it.
- **Short hitches in play.** 0.3 to 0.8 seconds every 30 to 60 seconds on 16 GB (memory pressure plus shader
  compiles).
- The once-a-second freezes are cut to about a tenth, not removed. For none at all use the FEX route on `main`.
- The MGF `run` script is pinned to Bridgeplay 0.7.64's. A newer Bridgeplay will not update it (the plain tool is a
  copy of Bridgeplay's and follows it after a re-run of `./install.sh`).
- The MacGameFix `ntdll.dll` and trap boost are matched to one build of `forzahorizon6.exe`; after a game update
  they may stop acting (the game still starts).

## How the plain route works

FH6 asks D3D12 which shader model the GPU supports. D3DMetal does not recognise the newer model numbers and fails
the call, so the game reports FH206. The proxy `d3d12.dll` sits in front of D3DMetal, forwards everything to it, and
fixes this call and a few other gaps (timestamp queries, descriptor size, dual-source blending). See the upstream
README for details.

Getting it to load under Bridgeplay's WineCX needs these pieces, all created by `install.sh`:

| Piece | Where | Why |
|---|---|---|
| Runner copy `crossover-MGF-winecx-11.17` (`crossover-FH-winecx-11.17` with `--plain`) | `~/Library/Application Support/bridgeplay/runners/` | Keeps the stock runner untouched |
| `apd12.dll` + link `apd12.so` → D3DMetal `d3d12.so` | Runner copy, `lib/wine/x86_64-windows` and `x86_64-unix` | The real D3DMetal under another name, so the proxy can load it. Both halves must sit in the runner, or loading fails with error 1114 |
| `apd12.dll` | Game prefix `system32` | Path the proxy is pointed at |
| Patched ntdll folder `MGF-winecx-11.17` (`FH-winecx-11.17` with `--plain`) | `bridgeplay/bridge/wine/` | Bridgeplay needs one per runner name. Without it Steam shows **OS Error 260** |
| Steam tool `bridgeplay-proton-fh6-mgf` (`bridgeplay-proton-fh6-plain` with `--plain`) | `Steam/compatibilitytools.d/` | Shows up as **MGF WineCX 11.17 (FH6, MacGameFix exception chain)** (**FH WineCX 11.17 (Forza Horizon, D3DMetal proxy)** with `--plain`) |
| `d3d12.dll` (proxy, from `bin/`) | Game folder | Windows loads DLLs from the game folder first |
| `gamefixes/2483190.conf` | `bridgeplay/gamefixes/` | `BACKEND=d3dmetal`, NVIDIA RTX 4070 IDs, `DLLOVERRIDES=d3d12=n,b` (lets the proxy load), `D3DM_ENABLE_METALFX=0` |
| `HB_D3D12_REAL` | Prefix `user.reg`, `[Environment]` | Tells the proxy where the real D3DMetal is |

Launch options work (see "Launch options" above). Settings are also set through the files above.

### Experimental: unwind-patched ntdll (plain route, optional)

`bin/ntdll-FH-winecx-unwind.dll` is a 74-byte patch of the plain runner's `ntdll.dll` that was tried against the
FHE21 crash. **It did not fix FHE21** (the MGF route's `concrt140` override did), so it is off by default.
`./install.sh --plain --experimental-ntdll` installs it into the plain runner copy (the original is kept as
`ntdll.dll.fh6-orig`); running `./install.sh --plain` without the flag restores the stock one. Bytes:
`docs/ntdll-unwind-bytes.txt`.

## Launch options

`VAR=value %command%` in Steam's launch options now works with both routes, for example
`BRIDGEPLAY_RAW_CONTROLLERS=0 %command%` or `NOTPROTON_ENV_FOO=bar %command%`.

Why it failed before: Mac Steam hands the launch command to the compatibility tool without a shell, so `VAR=value`
was taken as the program name and Wine reported "OS Error 260". Bridgeplay fixes that with a hook
(`dylib/hooks/hook_launch.c`, it wraps the command in `/bin/sh -c`), but the hook only fires when the tool's folder
name starts with `bridgeplay-proton` (`np_compat_runs_tool` and `has_tool_prefix` in `dylib/feats/compat.c`). Our
tools were called `MGF-bridgeplay-proton-winecx-11.17` and `FH-bridgeplay-proton-winecx-11.17`, which the hook
ignored. They are now `bridgeplay-proton-fh6-mgf` and `bridgeplay-proton-fh6-plain`. `install.sh` removes the old
folders (ours, never stock tools) and fixes Steam's mapping. Check: `bridgeplay.log` shows
`[launch] handed to /bin/sh -c: ...` after Play.

Related trap: Bridgeplay deletes any unlisted `bridgeplay-proton-*` folder that contains a file named `flavor`
(`remove_unlisted_tools` and `written_here` in `compat.c`), or whose `run` starts with Bridgeplay's own header line.
So our tools keep their flavor in `tool-flavor` and their `run` carries a different header line. Do not rename
them back.

Source and credit: Bridgeplay by raymondchins, GPL-3.0, https://github.com/raymondchins/Bridgeplay (checked against
commit 50652f8 and the installed 0.7.64 build 81). Our change: the folder names, the `tool-flavor` file, one header line.

### All launch options (MGF tool)

Put them in Steam: Forza Horizon 6 > Properties > General > Launch Options, as `NAME=value %command%` (several can
be chained: `D3DM_MAX_FPS=60 MTL_HUD_ENABLED=1 %command%`). **Every value this tool sets itself is only a default**:
a launch option with the same name always wins, and `bridgeplay-run.log` (in `compatdata/2483190/`) says which one
applied, as `<NAME> from launch options` or `<NAME> default`. An empty value (`NAME= %command%`) counts as not set.

| Option | What it does | Default | Example |
|---|---|---|---|
| `NOTPROTON_ENV_WINE_SOFTWARE_EXCEPTION_CHAIN` | MacGameFix exception chain in the runner's ntdll (cuts the once-a-second freeze). MGF tool only | `1` | `NOTPROTON_ENV_WINE_SOFTWARE_EXCEPTION_CHAIN=0 %command%` |
| `NOTPROTON_ENV_WINE_SOFTWARE_ALU_BRIDGE` | MacGameFix ALU bridge (second of its three ntdll switches) | `1` | `NOTPROTON_ENV_WINE_SOFTWARE_ALU_BRIDGE=0 %command%` |
| `NOTPROTON_ENV_WINE_SOFTWARE_BRIDGE_RESUME` | MacGameFix bridge-resume switch | `0` | `NOTPROTON_ENV_WINE_SOFTWARE_BRIDGE_RESUME=1 %command%` |
| `NOTPROTON_ENV_WINE_SOFTWARE_EXCEPTION_STATS` | Keeps ntdll's in-memory exception counters on | `1` | `NOTPROTON_ENV_WINE_SOFTWARE_EXCEPTION_STATS=0 %command%` |
| `MGF_TRAP_BOOST` | Rosetta trap boost dylib (MacGameFix) injected into the game. `0` = off (the file `mgf-trap-boost.off` in the tool folder does the same) | `1` | `MGF_TRAP_BOOST=0 %command%` |
| `MGF_MSVC_OVERRIDES` | Replaces the tool's own DLL override entry for the C++ runtime (native `concrt140` first, avoids a crash in Wine's builtin one) | `concrt140=n,b` | `MGF_MSVC_OVERRIDES=concrt140=b %command%` |
| `WINEDLLOVERRIDES` or `BRIDGEPLAY_DLLOVERRIDES` | Your own DLL overrides. They are **added after** everything the tool and the gamefix conf set, and Wine takes the last entry **per DLL**, so yours win for the DLLs you name and every other default stays | none | `BRIDGEPLAY_DLLOVERRIDES="concrt140=b" %command%` |
| `BRIDGEPLAY_RAW_CONTROLLERS` | Games read gamepads directly (needed because macOS Steam has no virtual gamepad). `0` = stock behaviour (pads Steam Input claims are hidden from the game) | `1` | `BRIDGEPLAY_RAW_CONTROLLERS=0 %command%` |
| `BRIDGEPLAY_BACKEND` | Graphics backend: `dxmt`, `dxvk`, `wined3d` or `d3dmetal` (this branch is tested with `d3dmetal` only) | `d3dmetal` (from `gamefixes/2483190.conf`) | `BRIDGEPLAY_BACKEND=d3dmetal %command%` |
| `D3DM_MAX_FPS` | D3DMetal frame rate cap. Use your screen's refresh rate: 60 on a fixed 60 Hz screen | unset (no cap) | `D3DM_MAX_FPS=60 %command%` |
| `NOTPROTON_ENV_MGF_FH6_ROSETTA_PACER` | Frame rate target of the pacer (needs `./install.sh --pacer`). **Needs the `NOTPROTON_ENV_` prefix on Bridgeplay**; without it the game never sees it. 40 on a 60 Hz screen; MacGameFix suggests 48 for ProMotion | unset (pacer off) | `NOTPROTON_ENV_MGF_FH6_ROSETTA_PACER=40 %command%` |
| `NOTPROTON_ENV_WINENCPU` | CPU core count the game sees | unset | `NOTPROTON_ENV_WINENCPU=8 %command%` |
| `NOTPROTON_PERF_OVERLAY` | Notproton/Bridgeplay on-screen performance summary | unset (off) | `NOTPROTON_PERF_OVERLAY=summary %command%` |
| `D3DM_ENABLE_METALFX` | D3DMetal MetalFX upscaling. Off because it caused Apple Neural Engine errors, hangs and an FHC20 crash on our test Mac | `0` (from the gamefix conf) | `D3DM_ENABLE_METALFX=1 %command%` |
| `D3DM_VENDOR_ID`, `D3DM_DEVICE_ID` | GPU identity D3DMetal reports (decimal PCI ids) | `4318`, `10118` (NVIDIA RTX 4070, from the gamefix conf) | `D3DM_VENDOR_ID=4318 D3DM_DEVICE_ID=10118 %command%` |
| `MTL_HUD_ENABLED` | Apple's Metal performance HUD | unset (off) | `MTL_HUD_ENABLED=1 %command%` |
| `NOTPROTON_ENV_<NAME>` | Gives the game `<NAME>=value` for any variable the tool does not know by name | none | `NOTPROTON_ENV_WINEDEBUG=-all %command%` |

Bridgeplay's own options (not ours, listed so you know they exist; see Bridgeplay for details):
`BRIDGEPLAY_RETINA`, `BRIDGEPLAY_VSYNC`, `BRIDGEPLAY_STDOUT_NULL`, `BRIDGEPLAY_HIDE_WINE_EXPORTS`,
`BRIDGEPLAY_PERF_OVERLAY`, `BRIDGEPLAY_FRAMEGEN`, `BRIDGEPLAY_FPS_LIMIT`, `BRIDGEPLAY_SCALING_FILTER`,
`BRIDGEPLAY_DISABLE_HIDRAW`, `BRIDGEPLAY_HIDE_LAUNCHER_TILE`. We have not tested these with Forza Horizon 6.

The `--plain` tool is Bridgeplay's own `run` (not edited by us), so only the `BRIDGEPLAY_*`, `D3DM_*`, `MTL_*` and
`NOTPROTON_ENV_*` rows apply to it.

## Online play (optional, manual)

Joining online sessions needs a small `ws2_32.dll` proxy (the "netfix", see `tools/ws2_32-netfix-x86/README.md`). The
x86-64 build is `bin/ws2_32-fh6-x86.dll`; it works on this route (tested 2026-11-17). `install.sh` does not install it. Close Steam and the game, then
from the repository folder:

```sh
S="$HOME/Library/Application Support/Steam/steamapps/compatdata/2483190/pfx/drive_c/windows/system32"
cp "$S/ws2_32.dll" "$S/ws2_32.dll.fh6-stock"
cp "$S/ws2_32.dll.fh6-stock" "$S/ws2_o.dll"
python3 -I bin/pe_tools.py rename-export "$S/ws2_o.dll" ws2_o.dll
cp bin/ws2_32-fh6-x86.dll "$S/ws2_32.dll"
```

Check: `ws2_o.dll` and `ws2_32.dll.fh6-stock` should be the size of the runner's own `ws2_32.dll` (about 250 KB; if the
prefix copy is much smaller, copy the runner's file from `.../CrossOver/lib/wine/x86_64-windows/ws2_32.dll` instead).
To undo: `cp "$S/ws2_32.dll.fh6-stock" "$S/ws2_32.dll"` and delete `ws2_o.dll`. Do not run it twice (the second time
it would overwrite the stock copy with the proxy); undo first.

## Rebuilding the shipped binaries

- `bin/ntdll-MGF-winecx.dll`: `python3 -I tools/port_ntdll_hooks.py MacGameFix-ntdll.dll out.dll`, where the input is
  `engine/modules/27.0.0.41073/x86_64-windows/ntdll.dll` from MacGameFix commit `881f3a96`. Both hashes are checked.
- `bin/winecoreaudio-MGF-x64.so`: `sh tools/winecoreaudio/build.sh WORKDIR` (downloads `wine-11.17.tar.xz`, applies
  Highball's patch 0057, builds with Apple clang; reproduced byte for byte).
- `docs/run-mgf.patch` is the diff of the MGF `run` against Bridgeplay's.
- `bin/ws2_32-fh6-x86.dll`: see `tools/ws2_32-netfix-x86/README.md` (Docker build; not byte-identical on rebuild).
- `bin/d3d12-fh6.dll` is not built here: it is MacGameFix's file from commit `ef19e41` (GPL-3.0; source in that repository).
- Background notes: `docs/audio-research.md`.

## Uninstall

```sh
./uninstall.sh
```

Removes whichever route is installed (runner copy, bridge folder, Steam tool), the proxy `d3d12.dll` (plain or pacer), `apd12.dll` and the
`user.reg` entry, and puts Steam's previous tool choice for the game back. If `install.sh` moved an arm64 (FEX)
prefix aside, it is put back and the Rosetta prefix is kept as `compatdata/2483190.rosetta`. Stock runners and saves
are not touched.

## Doctor

`./doctor.sh` is read-only. It prints PASS / FAIL / WARN for: repo file hashes, Bridgeplay files, which route is
installed (and warns if both are), the MGF runner (`apd12`, `ntdll.dll`, audio driver, signatures, bridge folder), the
MGF tool, its registration in `compatibilitytool.vdf` and trap-boost dylib (or the same for the plain route), the
proxy in the game folder (plain or pacer), the prefix architecture and additions, the gamefix, the Steam tool mapping,
and prints where the logs are.

## Troubleshooting

| Problem | Cause / fix |
|---|---|
| `Bridgeplay ... missing` | Install Bridgeplay, open it once, install its WineCX 11.17 runner, run `./install.sh` again. |
| OS Error 260 | Your launch options are wrong (see "Launch options"), or the `bridge/wine/MGF-winecx-11.17` (or `FH-winecx-11.17`) folder is missing: run `./install.sh`. |
| FH206 still appears | Run `./doctor.sh`. The prefix needs `apd12.dll` and `HB_D3D12_REAL`; if there was no prefix at install time, run `./install.sh` again after the first Play. Also check `bridgeplay-run.log` in `compatdata/2483190` for `DLLOVERRIDES=d3d12=n,b from the user conf`. |
| `install.sh` says `2483190.fex already exists` | A second FEX prefix backup is in the way. Rename it by hand and run again. |
| Error 1114 loading `apd12` | `apd12.dll` or `apd12.so` is missing from the runner copy. Run `./install.sh`. |
| The Bridgeplay launcher hangs on "Waiting for the game to open…" | The game crashed at start. Read `~/Library/Application Support/bridgeplay/launchers/2483190/bridgeplay-wine.log` and look for `tsshim:` lines. |
| Tool missing from Steam's list | A Bridgeplay update may have removed it. Run `./install.sh`. |
| FHE21 crash on the plain tool | Use the MGF tool (the default route). FHE21 can still happen at start-up on the MGF tool, see above. |
| No dialogue | `./doctor.sh` must show "dialogue fix: spatial-audio winecoreaudio.so in the runner". If Bridgeplay re-set-up the runner it may have been overwritten: run `./install.sh`. |
| Apple Neural Engine errors, a hang, or an FHC20 "Video Card Crash" | MetalFX/DLSS is on. `D3DM_ENABLE_METALFX=0` must be in `gamefixes/2483190.conf` (`./doctor.sh` checks it) and you must not have `D3DM_ENABLE_METALFX=1` in the launch options. Use FSR. |
| FHE21 at start-up, log says `AGX: exceeded compiled variants footprint limit` | Apple GPU driver limit. Start the game again; it usually passes. |
| Stuck at 30 fps | `PresentInterval` is 2 in `UserConfigSelections`; set it to 0 with the game closed (see "Recommended setup"). |
| No `fh6-pacer-<number>.log` in the prefix's `C:\mgf` | The pacer is not on. Use `NOTPROTON_ENV_MGF_FH6_ROSETTA_PACER=40` (with the prefix) and `./install.sh --pacer`. |
| Black screen for about 2 minutes after an off-road reset | Streaming on a 16 GB Mac. Wait; see the tips above. |
| A freeze of about one second, now and then | Cut to about 10% by MGF, not removed. Use the FEX route on `main` for none. |
| Trap boost misbehaves | Create `mgf-trap-boost.off` in the MGF tool folder. |

## FAQ

**Which branch and route?** the default MGF route is the best on this branch; `main` (FEX) removes the
freezes entirely at lower raw speed. `--plain` only if you want the minimal change.

**Is MacGameFix a DRM bypass?** Its author states no game bytes, license check or return value are changed; it is a
software emulation of the anti-tamper's own illegal-instruction stubs, gated to one exact `forzahorizon6.exe`. We use it
unmodified (plus the Steam detour call). Judge it by its own README and source.

**16 GB or 32 GB RAM?** 16 GB works with the limits listed above. 32 GB is better.

**Does it touch my game files?** Only one DLL (the proxy) is added to the game folder. Nothing is changed or removed
from your game, and `./uninstall.sh` takes the DLL out again.

## Credits and license

Everything here stands on other people's work. Shipped files are listed one by one in
[`bin/CREDITS.md`](bin/CREDITS.md).

| Project | Owner | License | Used here | What we changed |
|---|---|---|---|---|
| [MacGameFix](https://github.com/MathiasKowoll/MacGameFix) | MathiasKowoll | GPL-3.0 (app), LGPL-2.1+ (Wine modules) | Commit `881f3a96e2b7` (v1.6.3): `engine/modules/27.0.0.41073/x86_64-windows/ntdll.dll` (exception chain, ALU bridge), `fixes/notproton-rosetta-trap-boost.dylib` (sha256 `ce9dd6b0…8672`), the three exception-chain settings | ntdll: Steam detour call and RtlVirtualUnwind2 fix added (about 200 bytes); trap boost: none |
| [Highball](https://github.com/gauthierpiarrette/highball) and [highball-engine](https://github.com/gauthierpiarrette/highball-engine) | Gauthier Piarrette | GPL-3.0 (app), LGPL-2.1+ (engine) | Patch 0057, spatial mixer for surround beds (author TxCsOffc, [highball PR #313](https://github.com/gauthierpiarrette/highball/pull/313)); tsshim (basis of the proxy); the `concrt140-native` tweak (highball-db, CC0) | Patch unmodified, compiled by us against Wine 11.17 |
| [fh5-d3dmetal-fix](https://github.com/sliver-exes/fh5-d3dmetal-fix) (d3d12 proxy, `pe_tools.py`) and tsshim | sliver-exes (built on Highball's tsshim, with the memory fix "memfix" by xvferxedd) | GPL-3.0 | Commit `ebd20db`: `bin/d3d12.dll` (hash kept), `bin/pe_tools.py` | Nothing, byte-identical |
| [Bridgeplay](https://github.com/raymondchins/Bridgeplay) (a fork of NotProton) | raymondchins | GPL-3.0 | 0.7.64: the WineCX 11.17 runner, Steam tool and its `run`, bridge folder, per-game config, Steam detour logic; copied and renamed by `install.sh` | `run`: edits marked `# MGF:` (`docs/run-mgf.patch`); copies renamed; `apd12` files added |
| [Wine](https://www.winehq.org/) and [CodeWeavers](https://www.codeweavers.com/) CrossOver Wine sources | Wine project, CodeWeavers | LGPL-2.1+ | The runner (Bridgeplay's CrossOver-based 11.17 build), `wine-11.17` `winecoreaudio.drv`, the base of MacGameFix's `ntdll.dll` | See above |
| Apple Game Porting Toolkit / D3DMetal | Apple | Apple license | Used from your own Bridgeplay install; **not shipped** | `apd12.dll` is built locally from it by renaming one export |

This repo is **GPL-3.0** (`LICENSE`); the LGPL-2.1 text for Wine, Highball's patch and the MacGameFix Wine modules is
in `LICENSES/`. Forza Horizon 6 is a trademark of Microsoft. You need your own copy of the game. Not affiliated with
the projects above.
