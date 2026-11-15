# fh6-mac-fix: Forza Horizon 6 on Apple Silicon Wine (FEX route)

Fixes and tools to run **Forza Horizon 6 (Steam)** on an Apple Silicon Mac **without the once-a-second freeze** that the Rosetta route has. The game runs on a
native arm64 Wine with [FEX](https://github.com/FEX-Emu/FEX) (x86-64 emulation inside the process) and Vulkan-on-Metal
([KosmicKrisp](https://www.mesa3d.org/)). It uses the engine and the Forza Horizon 6 recipe of [Highball](https://github.com/gauthierpiarrette/highball).
The files in this repo are: a patched `ntdll.dll`, the Steam tool `run` script with our changes, the dialogue (spatial audio) fix, the online (`ws2_32`) fix and the
runner assembly steps. The step-by-step guide below is written and tested for [Bridgeplay](https://github.com/raymondchins/Bridgeplay) with Steam;
users of CrossOver, NotProton or other Wine wrappers can adapt the files at their own risk (that is your lookout; paths, names and hashes in the guide are specific to the tested setup).

No game files are included or modified. You need your own legitimately owned Steam copy of Forza Horizon 6.

## Which branch should I use?

| Branch | Stack | Observed (our own tests, 16 GB Mac) |
|---|---|---|
| [`main`](https://github.com/sliver-exes/fh6-mac-fix/tree/main) (this one, recommended) | native arm64 Wine + FEX + KosmicKrisp | No once-a-second freezes. Online works. Uses the most RAM. Needs macOS 27. |
| [`rosetta-d3dmetal`](https://github.com/sliver-exes/fh6-mac-fix/tree/rosetta-d3dmetal) | Rosetta + D3DMetal + MacGameFix | Higher frame rates and less memory, but the anti-tamper freeze, a rare FHE21 crash and slow texture streaming on 16 GB. |

The other branch has its own README and files.

## Tested setup

| | |
|---|---|
| Machine | Apple M5 MacBook Air, 16 GB, macOS 27 |
| Game | Forza Horizon 6, Steam app 2483190 (legitimately owned) |
| Wine wrapper | Bridgeplay 0.7.64 with Steam (the guide below is written for this setup) |
| Engine | Highball arm64 engine **r3**: Wine 11.18 ARM64X, FEX 2610 with patches through 0034, vkd3d-proton, KosmicKrisp |
| Audio driver | Highball engine **r5** `winecoreaudio.so` (spatial mixer): dialogue and voices work |
| Settings | Very Low, FSR3 mode 1, 1280x800, PresentInterval 2, AudioQuality 1 |
| Result | Plays without the 1-second freezes. On 16 GB there is some stutter from memory pressure only |
| Online | Session join works with the network fix: the log shows `SIO_UDP_NETRESET`, `IP_TTL`, `IP_DONTFRAGMENT` and option 76 forced to success on the Xbox UDP socket (port 3074) |

Other hardware, game builds and engine versions are untested. Several patches only accept the exact stock files named below.

## What it does

The game's anti-tamper deliberately raises about **4.5 million** illegal-instruction exceptions (`#UD`, `c000001d`). Under Rosetta every one is a
signal round trip through the kernel, which shows up as a hitch of about one second. With FEX inside an arm64 Wine the same exceptions are raised
and handled **inside the process**, so the hitches are gone. The cost is that x86-64 code is translated by FEX, so raw speed is lower than Rosetta's.
Rosetta's own trap path has a floor of about 16 us per trap in a bare C test on an M5 (about 41 us measured inside the game); no Wine or D3DMetal
setting changes it. FEX is the emulator itself and jumps straight to its handler.

What this repo puts in place (each is a step below):

| Piece | Where | Why |
|---|---|---|
| Runner `crossover-FH-fex` (Highball arm64 engine r3) | `bridgeplay/runners/` | Wine 11.18 ARM64X with FEX in `xtajit64.dll` |
| vkd3d-proton as builtin DLLs | runner `lib/wine/aarch64-windows`, originals kept as `*.wine-orig` | Direct3D 12 on Vulkan |
| KosmicKrisp + `libMoltenVK.dylib` | runner `renderers/kosmickrisp`, `lib/` | Vulkan driver on Metal |
| Signed `WineLoader.app` | runner `lib/wine/aarch64-unix/`, linked as `wine` | Carries the cross-architecture entitlement; from the Highball release |
| `bin/wineserver-arm64` link | runner | The name Bridgeplay's `run` looks for |
| `lsteamclient` (arm64 .so, x86-64 + i386 .dll) | runner | Copied from your Bridgeplay files |
| Patched `ntdll.dll` (`bin/ntdll-FH-fex.dll`) | runner `aarch64-windows`, and `bridge/wine/FH-fex/` | Bridgeplay's steamclient64 hook ported to ARM64EC (hook at RVA 0x97724, code cave at 0xE0C00). Original kept as `ntdll.dll.notproton-orig` |
| `winecoreaudio.so` from Highball engine r5 | runner `aarch64-unix/` (r3 one kept as `.r3`) | The dialogue fix: FH6 asks for a 12-channel spatial bed, r3 drops the centre channel |
| Steam tool `bridgeplay-proton-fh6-fex` | `Steam/compatibilitytools.d/` | `build` = `FH-fex`, `tool-flavor` = `fex`. Its `run` is Bridgeplay's with every change marked `# FH-fex:` (diff: `docs/run-fex.patch`) |
| ws2_32 proxy (network fix) | prefix `system32/ws2_32.dll` (original kept as `ws2_32.dll.mgf-stock`), `ws2_o.dll`, a `user.reg` override for `forzahorizon6.exe` only | Lets the game's Xbox UDP socket survive, see `tools/ws2_32-netfix/README.md` |
| Fresh arm64 prefix | `compatdata/2483190` | An x86-64 (Rosetta) prefix cannot be reused |

### Changes in the `run` script (all marked `# FH-fex:`, all only defaults that a launch option overrides)

- Highball's Forza Horizon 6 recipe for app 2483190 only: the `HB_FEX_*` fast-path and self-modifying-code switches, `FEX_*`, `VKD3D_*`, `DXVK_CONFIG`, `HB_KK_NO_UBO_ROBUST`.
- The vkd3d-proton graphics DLLs are forced to builtin; DYLD fallback paths for libMoltenVK and GStreamer; Vulkan goes straight to KosmicKrisp (no implicit layers).
- **Persistent shader caches** (new): `MESA_SHADER_CACHE_DIR=$HOME/Library/Caches/fh6-kk-mesa` (KosmicKrisp) and
  `VKD3D_SHADER_CACHE_PATH=Z:$HOME/Library/Caches/fh6-vkd3d` (vkd3d-proton, as a `Z:` path because it opens the folder from inside Wine). Both live outside
  the prefix and the game folder, so a prefix swap, a Steam verify or a runner rebuild keeps the caches warm.
- **`DXVK_CONFIG` memory default** (changed): budget, device memory and shared memory are all `4096` MB (the recipe's `3/8 of RAM` budget and `8192` device memory
  were too much for a 16 GB Mac). Real Metal allocation was about 2x the budget, and 6144 swapped. vkd3d-proton ignores the DXGI budget; the game sizes its
  allocations from `DedicatedVideoMemory`, which is why device memory is lowered too. A low-VRAM warning in the game is expected. The GPU identity (Intel Arc A750)
  stays.
- **Performance overlay and scaling filter** loaded late (new path): the arm64 loader refuses `DYLD_INSERT_LIBRARIES` (Wine dies with `c0000018`), so `run` leaves it
  unset and lsteamclient loads Bridgeplay's shim once Wine is up (`NOTPROTON_PERF_OVERLAY`, `NOTPROTON_SCALING_FILTER`). No quick-settings panel and no Cmd-Q hook on this route.
- Launch options work: the tool's folder is called `bridgeplay-proton-fh6-fex`, because Bridgeplay's launch-option hook (`hook_launch.c`) only wraps the command in `/bin/sh -c`
  for folders whose name starts with `bridgeplay-proton`. The flavor file is called `tool-flavor` because Bridgeplay deletes unlisted `bridgeplay-proton-*` folders that hold
  a file named `flavor`. Do not rename either.

## Prebuilt files

Everything in `bin/` is used by the install steps; every file has a `.sha256`. `bin/CREDITS.md` lists origin, license and changes of each.

| File | What |
|---|---|
| `run`, `compatibilitytool.vdf`, `build`, `tool-flavor`, `toolmanifest.vdf` | The Steam tool |
| `ntdll-FH-fex.dll` | Highball r3 `ntdll.dll` with the Steam detour (rebuild: `tools/ntdll-steam-detour/`) |
| `winecoreaudio-hb-r5.so` | Highball r5 audio driver, unmodified (`tools/winecoreaudio-spatial/`) |
| `ws2_32-fh6.dll`, `pe.pl` | Network fix proxy (rebuild: `tools/ws2_32-netfix/`) and the Perl export-rename helper |
| `RUNNER.sums` | Hashes of the key files in the finished runner (used by `shasum -c`) |

The engine, KosmicKrisp, vkd3d-proton and `WineLoader.app` are not stored here; Step 2 downloads them from Highball and checks their hashes.

## Build

The prebuilt files are the install source. To rebuild or check them:

- `ntdll-FH-fex.dll`: `python3 -I tools/ntdll-steam-detour/patch_ntdll.py STOCK_NTDLL OUT_NTDLL` (asserts the stock and output hashes).
- `ws2_32-fh6.dll`: `tools/ws2_32-netfix/build.sh <runner aarch64-windows/ws2_32.dll>` (Docker with `mstorsjo/llvm-mingw`, nothing installed on the host).
- `winecoreaudio-hb-r5.so`: extract it from the Highball r5 release tarball, see `tools/winecoreaudio-spatial/README.md`.

## Install

There are two ways: let an AI coding agent do it from a prompt (Option A), or follow the steps yourself (Option B). Option A is only a guided
version of Option B, so Option B is the specification for both.

What you need first: an Apple Silicon Mac on **macOS 27 or newer** (the Highball arm64 engine needs it), [Bridgeplay](https://github.com/raymondchins/Bridgeplay)
0.7.64 or newer **opened once** with its **WineCX 11.17** runner installed (only its files are read), Steam with your own copy of Forza Horizon 6
(app 2483190) installed, about 4 GB free and a connection for 420 MB of hash-checked downloads, and nothing else (the steps use curl, tar, ditto, shasum, codesign and Perl, which macOS ships).
32 GB of RAM is recommended; 16 GB works with some stutter. Paths use `$HOME`; nothing here needs `sudo`.

### Option A - Install with an AI coding agent

Use an agent that can run shell commands on your Mac (Claude Code, Codex, and similar). Clone this repo, open the agent in the clone, and paste the prompt
below. The agent first looks at your machine and reports, then gives you a numbered plan and waits for your approval before it changes anything. Read the
plan; you are still the one who approves each change.

```text
You are installing the Forza Horizon 6 FEX fix from this repository onto my Mac. The spec is "Option B - Manual install" in README.md: read it fully first
and follow it exactly (same paths, same commands, same order). Do not invent other methods. There are no install scripts in this repo on purpose.

Rules:
1. Inspect first, change nothing. Report: macOS version, RAM, is Steam installed and running, is Bridgeplay installed (app version) and does
   "$HOME/Library/Application Support/bridgeplay/runners/crossover-winecx-11.17" exist, is Forza Horizon 6 (Steam app 2483190) installed and in which Steam
   library, which runners exist under "$HOME/Library/Application Support/bridgeplay/runners", which tools exist under
   "$HOME/Library/Application Support/Steam/compatibilitytools.d", whether the game's prefix (compatdata/2483190/pfx) exists and its architecture
   (arm64 or x86-64), and whether the game folder looks untouched.
2. Then write a numbered plan that maps to the steps of Option B, with the exact files each step creates, changes or replaces. STOP and wait for my explicit
   approval. Do not start before I say so.
3. Verify every download and every file from this repo against its sha256 (the values in README.md Option B and the .sha256 files in bin/) before using it.
   If a hash does not match, stop and tell me; do not continue.
4. Before replacing or editing an existing file, keep a copy as Option B says (.orig, .r3, .mgf-stock, .wine-orig, .notproton-orig). Never overwrite an existing
   backup; if one exists, stop and ask. After each step print what changed. At the end print an "undo list" (every file or folder created, every backup made).
5. Do not install host packages (no brew, pip, npm, etc.). macOS tools (curl, tar, ditto, shasum, perl, codesign, cp, ln, sed) are fine.
6. Never touch game files, saves or anything in the Wine prefix except what Option B names (Step 8 to 10). Never move a prefix without my approval.
   Do not delete anything that is not in the undo list.
7. Do not edit Steam's own config files (config.vdf, localconfig.vdf). Tell me the one thing to set in Steam myself (Step 7) and the launch options (Step 11).
8. Do not publish, upload or push anything, and do not send any file from my machine anywhere.
9. Do not start Steam, Wine or the game yourself; ask me to do that and wait. Quit Steam only with my approval.
10. Follow the online step (Step 10) and the optional steps only if I say so.
```

### Option B - Manual install

Open Terminal and set these once (zsh or bash); the steps use them. Nothing is installed on your Mac except files in the folders named here.

```sh
BP="$HOME/Library/Application Support/bridgeplay"
STEAM="$HOME/Library/Application Support/Steam"
STOCK="$BP/runners/crossover-winecx-11.17/CrossOver"     # Bridgeplay's stock runner, only read
RUN="$BP/runners/crossover-FH-fex"                       # the runner we build
CX="$RUN/CrossOver"
TOOL="$STEAM/compatibilitytools.d/bridgeplay-proton-fh6-fex"
BRIDGE="$BP/bridge/wine/FH-fex"
APPID=2483190
DL="$HOME/Library/Caches/fh6-mac-fix"                    # downloads (420 MB), safe to delete afterwards
REPO=/path/to/your/clone/of/this/repo
mkdir -p "$DL"
# the Steam library that holds the game (the default is $STEAM/steamapps)
LIB=$(sed -n 's/^[[:space:]]*"path"[[:space:]]*"\(.*\)"$/\1/p' "$STEAM/steamapps/libraryfolders.vdf" |
  while IFS= read -r d; do [ -f "$d/steamapps/appmanifest_$APPID.acf" ] && { echo "$d/steamapps"; break; }; done)
GAME="$LIB/common/ForzaHorizon6"; PFXDIR="$LIB/compatdata/$APPID"; PFX="$PFXDIR/pfx"
echo "$LIB"; ls "$GAME/forzahorizon6.exe"
```

Check that your clone is intact; every line must say `OK`:

```sh
cd "$REPO/bin" && for f in *.sha256; do shasum -a 256 -c "$f"; done
```

**Quit Steam (menu Steam > Quit Steam) before Steps 5, 6 and 10.** Steam rewrites its config on exit, and Bridgeplay reads its `tools` list when Steam starts.

**Step 1 - Check the prerequisites.**

```sh
sw_vers -productVersion                 # 27 or newer
uname -m                                # arm64
ls -d "$BP" "$STOCK" "$STEAM/compatibilitytools.d/bridgeplay-proton-winecx-11.17"
shasum -a 256 "$BP/bridge/aarch64-unix/lsteamclient.so" \
  "$STOCK/lib/wine/x86_64-windows/lsteamclient.dll" "$STOCK/lib/wine/i386-windows/lsteamclient.dll"
df -h "$HOME/Library" | tail -1         # about 4 GB free
test ! -e "$RUN" && echo "no FH-fex runner yet (good)"
```

Verify: the three hashes must be (Bridgeplay 0.7.64 or newer; a different hash means a different Bridgeplay build, which is untested):

    c9aa5c3a6e77ea119eb8853d36f27c98283b1ff78b49f6b883c8bcd2829d7cd8   bridge/aarch64-unix/lsteamclient.so
    a1ac0255166cbf6e2c6c85da86e6987ab0794ab263998a69b1d8f881a8c32397   x86_64-windows/lsteamclient.dll
    e949602020314b67917626bd85114a92506e7de74812b9cd7fb45db9129aecbc   i386-windows/lsteamclient.dll

**Step 2 - Download the Highball pieces and check them.** Resumable (`-C -`); run the same command again after an interruption.

```sh
cd "$DL"
REL=https://github.com/gauthierpiarrette/highball-engine/releases/download
E=engine-arm64-wine-11.18-20261103T154050Z-fh6-native-r3-fex0034.tar.gz
K=kosmickrisp-arm64-20261101T180026Z-push.tar.gz
R=renderers-arm64-20261031T230303Z-manual.tar.gz
H=Highball-0.10.27.zip
curl -fL -C - --retry 3 -o "$E" "$REL/${E%.tar.gz}/$E"
curl -fL -C - --retry 3 -o "$K" "$REL/${K%.tar.gz}/$K"
curl -fL -C - --retry 3 -o "$R" "$REL/${R%.tar.gz}/$R"
curl -fL -C - --retry 3 -o "$H" "https://github.com/gauthierpiarrette/highball/releases/download/v0.10.27/$H"
cat > SHA256SUMS.dl <<EOF
49aca95de5241aef08842feed6235cd92c9d62226b3433c4d9af332a90cdf100  $E
7fe4d482dbe154f372a9bc91051337e9fea0a0a7e619c7277fce61e7b712761f  $K
1b101d93ad23ec72a89216388f250afcbd9b64babb49f21cc5feccea05fbac37  $R
a32bfe1211076cbcde7a5928743d9d341078a20793e26803a98cf0b75a8f6d98  $H
EOF
shasum -a 256 -c SHA256SUMS.dl
```

Verify: four `OK` lines. If one fails, delete that file and download it again; do not continue with a file that does not match.

**Step 3 - Build the runner.** It is built in `$RUN.partial` and moved into place only when it checks out. Your stock runners are not touched.

```sh
test ! -e "$RUN" || { echo "runner already exists: see Uninstall first"; false; }
WORK="$DL/work"; rm -rf "$WORK" "$RUN.partial"; mkdir -p "$WORK"/eng "$WORK"/kk "$WORK"/rend "$WORK"/hb "$RUN.partial"
tar -xzf "$DL/$E" -C "$WORK/eng"
tar -xzf "$DL/$K" -C "$WORK/kk"
tar -xzf "$DL/$R" -C "$WORK/rend"
ditto -x -k "$DL/$H" "$WORK/hb"
C="$RUN.partial/CrossOver"; A="$C/lib/wine/aarch64-unix"; W="$C/lib/wine/aarch64-windows"
mv "$WORK/eng/engine" "$C"
mv "$WORK/eng/frameworks" "$C/frameworks"
ln -s CrossOver/frameworks "$RUN.partial/frameworks"
shasum -a 256 "$W/ntdll.dll"
```

Verify: the stock r3 `ntdll.dll` is `77904aabc9286200ac48a187e7a7dc2f9a4d1dd9ddeaea2c6ca1a66ec8711a44`. Stop if it differs.

Loader: Highball's signed `WineLoader.app` carries the cross-architecture entitlement that lets the arm64 process host x86-64 code; the engine's own unsigned loaders stay as `*.unsigned`.

```sh
mv "$C/bin/wine" "$C/bin/wine.unsigned"
mv "$A/wine" "$A/wine.unsigned"
ditto "$WORK/hb/Highball.app/Contents/Helpers/WineLoader.app" "$A/WineLoader.app"
codesign --verify --deep --strict "$A/WineLoader.app" && echo signature-ok
ln -s ../lib/wine/aarch64-unix/wine "$C/bin/wine"
ln -s WineLoader.app/Contents/MacOS/wine "$A/wine"
mkdir -p "$A/wine.app/Contents/MacOS"
ln -s ../../../ntdll.so "$A/wine.app/Contents/MacOS/ntdll.so"
ln -s ../../../WineLoader.app/Contents/MacOS/wine "$A/wine.app/Contents/MacOS/wine"
ln -s wineserver "$C/bin/wineserver-arm64"
```

Vulkan (KosmicKrisp behind the loader name winevulkan opens) and Direct3D (vkd3d-proton as the builtin DLLs; the originals stay as `*.wine-orig`):

```sh
cp -p "$WORK/kk/lib/libMoltenVK.dylib" "$C/lib/libMoltenVK.dylib"
mkdir -p "$C/renderers"
cp -a "$WORK/kk/renderers/kosmickrisp" "$C/renderers/kosmickrisp"
for n in d3d10core d3d11 d3d12 d3d12core dxgi; do
  mv "$W/$n.dll" "$W/$n.dll.wine-orig"
  cp -p "$WORK/rend/renderers/vkd3d/wine/aarch64-windows/$n.dll" "$W/$n.dll"
done
```

The patched `ntdll.dll` (the stock one stays as `.notproton-orig`) and lsteamclient from your Bridgeplay files:

```sh
mv "$W/ntdll.dll" "$W/ntdll.dll.notproton-orig"
cp "$REPO/bin/ntdll-FH-fex.dll" "$W/ntdll.dll"
cp -p "$BP/bridge/aarch64-unix/lsteamclient.so" "$A/lsteamclient.so"
mkdir -p "$C/lib/wine/x86_64-windows"
cp -p "$STOCK/lib/wine/x86_64-windows/lsteamclient.dll" "$C/lib/wine/x86_64-windows/lsteamclient.dll"
cp -p "$STOCK/lib/wine/i386-windows/lsteamclient.dll" "$C/lib/wine/i386-windows/lsteamclient.dll"
echo "highball-arm64-wine11.18-r3-fex0034 + kosmickrisp-20261101 + vkd3d-20261031 (fh6-mac-fix)" > "$RUN.partial/.fh6-fex-version"
cd "$C" && shasum -a 256 -c "$REPO/bin/RUNNER.sums" | grep -v ': OK$'; echo "(nothing above this line = all 26 files OK)"
```

Verify: no line other than the last one is printed. If something is listed, fix it before the next command. Then move the runner into place:

```sh
rm -rf "$RUN" && mv "$RUN.partial" "$RUN" && rm -rf "$WORK"
ls "$CX/bin/wine" "$CX/bin/wineserver-arm64"
```

**Step 4 - Dialogue fix and the Bridgeplay bridge copy of `ntdll.dll`.**

```sh
A="$CX/lib/wine/aarch64-unix"
cp -p "$A/winecoreaudio.so" "$A/winecoreaudio.so.r3"          # keep the r3 driver (if the .r3 exists already, stop)
cp -p "$REPO/bin/winecoreaudio-hb-r5.so" "$A/winecoreaudio.so"
shasum -a 256 "$A/winecoreaudio.so"
mkdir -p "$BRIDGE/aarch64-windows"
cp "$REPO/bin/ntdll-FH-fex.dll" "$BRIDGE/aarch64-windows/ntdll.dll"
shasum -a 256 "$CX/lib/wine/aarch64-windows/ntdll.dll" "$BRIDGE/aarch64-windows/ntdll.dll"
```

Verify: `winecoreaudio.so` is `03adf57cf363677a9a454bef9eb36fd94b6b04bc0c9d910466f2902434e7cde9`; both `ntdll.dll` lines are `52416b5bfa5d6e1c3a895c26cb01fca031dae4084bd4192fcdd7701581d057aa`.
Revert the audio driver with `cp -p "$A/winecoreaudio.so.r3" "$A/winecoreaudio.so"`. Bridgeplay keeps one `ntdll.dll` per build name for its Steam bridge; this is it for the build `FH-fex`.

**Step 5 - Install the Steam tool (Steam quit).**

```sh
test ! -d "$STEAM/compatibilitytools.d/FH-bridgeplay-proton-fex" || echo "old tool folder FH-bridgeplay-proton-fex exists: it is an earlier version of this tool; remove it with rm -r"
mkdir -p "$TOOL"
for f in run compatibilitytool.vdf build tool-flavor toolmanifest.vdf; do cp "$REPO/bin/$f" "$TOOL/$f"; done
chmod +x "$TOOL/run"
ls "$TOOL"; cat "$TOOL/build" "$TOOL/tool-flavor"
```

Verify: the folder holds exactly those five files (no file named `flavor`), `build` says `FH-fex`, `tool-flavor` says `fex`, and
`shasum -a 256 "$TOOL/run"` equals `bin/run.sha256`. Bridgeplay's `tools` list is not touched: Bridgeplay only deletes unlisted tools that hold a file named `flavor`.

**Step 6 - The Wine prefix.** An x86-64 (Rosetta) prefix cannot be reused by this runner. Check what you have:

```sh
perl -e 'open F,"<:raw",$ARGV[0] or die "no prefix yet\n"; read F,$d,4096; $o=unpack("V",substr($d,0x3c,4)); printf "%04x\n",unpack("v",substr($d,$o+4,2))' "$PFX/drive_c/windows/system32/ntdll.dll"
```

- `aa64`: an arm64 prefix; keep it.
- `8664`: the old Rosetta prefix. Move it aside (nothing is deleted; if `compatdata/2483190.rosetta` exists, stop and rename it yourself first):

  ```sh
  mv "$PFXDIR" "$PFXDIR.rosetta"
  ls -d "$PFXDIR".fex "$PFXDIR".aa64 2>/dev/null    # an arm64 prefix parked earlier by a route switch or an undo
  ```

  If one of those exists and its `ntdll.dll` says `aa64` (same check, with the path of that folder), put it back with `mv "$PFXDIR.aa64" "$PFXDIR"`. You then keep
  your Xbox sign-in. Otherwise Steam makes a fresh arm64 prefix at the first Play and you sign in to Xbox again.
- "no prefix yet": nothing to do; the prefix is created at Step 8.

**Step 7 - Tell Steam to use the tool.** Start Steam. In Library, right-click **Forza Horizon 6** > Properties > Compatibility: tick "Force the use of a specific Steam Play
compatibility tool" and choose **FH WineFEX 11.18 arm64 (Highball r3, vkd3d)**. If it is not in the list, quit Steam completely and start it again, and re-check Step 5.
Launch options come in Step 11 (they can stay empty for now). This step is done by hand on purpose: editing Steam's `config.vdf` while Steam runs is lost, and the repo does not edit it.

**Step 8 - First launch (only if there was no prefix).** The prefix `compatdata/2483190/pfx` is created at the first start. Press Play, wait until the game window opens (the first
start takes about 10 minutes, "Optimizing for your PC", and asks you to sign in to Xbox once; a FH206 dialog may appear, ignore it), then quit the game and quit Steam.
Check that it exists: `ls "$PFX/user.reg"`. Steps 9 and 10 need the prefix and a stopped game.

**Step 9 - Recommended graphics settings (optional).** In the game's graphics menu set: quality **Very Low**, upscaling **FSR3 (mode 1)**, resolution **1280x800**, present interval **2**, audio quality **1**.
These follow the Forza Horizon 6 recipe of Highball's highball-db and are what the tested setup used. Nothing is copied by this step; skip it if you have settings you like.

**Step 10 - Online: the ws2_32 network fix (Steam and the game closed, no wineserver).** Without it the game cannot join sessions (see `tools/ws2_32-netfix/README.md`).
The proxy `bin/ws2_32-fh6.dll` forwards to the runner's own `ws2_32`, which you provide as `ws2_o.dll` (a renamed copy of the runner's `ws2_32.dll`).

```sh
pgrep -f wineserver && echo "a wineserver is running: quit the game and Steam first (the prefix would be overwritten when it exits)"
RW="$CX/lib/wine"; SYS="$PFX/drive_c/windows/system32"
shasum -a 256 "$RW/aarch64-windows/ws2_32.dll"
```

Verify: `068aa9ca7e66828a4a10c882023fabf68d3d1727a4a04831f8a6e75879742ea5` (the stock r3 file the proxy was built for; another hash needs a rebuild with `tools/ws2_32-netfix/build.sh`). Then:

```sh
# 1. runner: a copy of ws2_32.dll with its internal export name renamed, plus the Unix half as a link
cp "$RW/aarch64-windows/ws2_32.dll" "$RW/aarch64-windows/ws2_o.dll"
perl "$REPO/bin/pe.pl" rename-export "$RW/aarch64-windows/ws2_o.dll" ws2_o.dll
ln -sf ws2_32.so "$RW/aarch64-unix/ws2_o.so"
shasum -a 256 "$RW/aarch64-windows/ws2_o.dll"
# 2. prefix: the renamed copy, the proxy (original kept as .mgf-stock)
cp "$RW/aarch64-windows/ws2_o.dll" "$SYS/ws2_o.dll"
test -e "$SYS/ws2_32.dll.mgf-stock" || cp -p "$SYS/ws2_32.dll" "$SYS/ws2_32.dll.mgf-stock"
cp "$REPO/bin/ws2_32-fh6.dll" "$SYS/ws2_32.dll"
shasum -a 256 "$SYS/ws2_32.dll"
# 3. registry: only forzahorizon6.exe loads the proxy (keep a copy of user.reg first)
cp -n "$PFX/user.reg" "$PFX/user.reg.fh6-bak"
if grep -qi 'AppDefaults\\\\forzahorizon6.exe\\\\DllOverrides' "$PFX/user.reg"; then
  echo "override section already present: check that it has \"*ws2_32\" and \"ws2_32\" = native,builtin"
else
  printf '\n[Software\\\\Wine\\\\AppDefaults\\\\forzahorizon6.exe\\\\DllOverrides] %s\n#time=%x\n"*ws2_32"="native,builtin"\n"ws2_32"="native,builtin"\n' \
    "$(date +%s)" "$(perl -e 'print((time+11644473600)*10000000)')" >> "$PFX/user.reg"
fi
tail -5 "$PFX/user.reg"
```

Verify: `ws2_o.dll` is `fd80e911ceddb21f5ec0e800795ff71559d5abfd39b19e0b3c9ea1e553728d4b`; `system32/ws2_32.dll` equals `bin/ws2_32-fh6.dll.sha256`; `user.reg` ends with the section with both values.
To test, start the game with the launch option `NOTPROTON_ENV_MGF_FH5_NETLOG=1` (Step 11) and open `fh6-netfix.log` in the game folder: lines with `forced-success` for the UDP socket (the
`WSAIoctl ... code=0x9800000f` and `setsockopt level=0 option=14/4` calls), and the socket stays open.

The runner part (`ws2_o.dll`, `ws2_o.so`) lives in the runner folder, so rebuilding or updating the runner drops it: repeat the first block of this step.

**Step 11 - Launch options (Steam, one line).** Forza Horizon 6 > Properties > General > Launch options. Recommended:

    BRIDGEPLAY_DISABLE_HIDRAW=1 NOTPROTON_PERF_OVERLAY=summary NOTPROTON_SCALING_FILTER=integer %command%

- `BRIDGEPLAY_DISABLE_HIDRAW=1` makes a DualSense go through SDL as an Xbox-style controller.
- `NOTPROTON_PERF_OVERLAY=summary` shows Bridgeplay's performance overlay; `NOTPROTON_SCALING_FILTER=integer` selects its `integer` scaling filter. Both are off by default; remove
  them if you do not want the overlay.

Optional extras, see "Environment variables" below: `NOTPROTON_ENV_MGF_FH5_NETLOG=1`, `NOTPROTON_ENV_MGF_FH5_NETFIX=0`, `NOTPROTON_ENV_DXVK_CONFIG=...`.
Check that the options work: `bridgeplay.log` shows `[launch] handed to /bin/sh -c: ...` after Play, and `compatdata/2483190/bridgeplay-run.log` says for every setting
`FH-fex: <NAME> from launch options` or `FH-fex: <NAME> default: <value>`.

**Step 12 - Play and check.** Press Play. If a warning about the graphics driver (FH302) appears, click **Ignore Warning**. Read-only checks of the install:

```sh
cd "$CX" && shasum -a 256 -c "$REPO/bin/RUNNER.sums" | grep -vc ': OK$'      # 0 = every runner file is as expected
readlink "$CX/bin/wine" "$CX/lib/wine/aarch64-unix/wine" "$CX/bin/wineserver-arm64"
codesign --verify --deep --strict "$CX/lib/wine/aarch64-unix/WineLoader.app" && echo signature-ok
codesign -d --entitlements - "$CX/lib/wine/aarch64-unix/WineLoader.app" 2>&1 | grep cross-architecture-support
ls "$TOOL"; test ! -e "$TOOL/flavor" && echo "no file named flavor (good)"
```

Expected: `0`, the three link targets `../lib/wine/aarch64-unix/wine`, `WineLoader.app/Contents/MacOS/wine`, `wineserver`, `signature-ok`, the entitlement line and `signature`.
In the log `~/Library/Application Support/bridgeplay/launchers/2483190/bridgeplay-wine.log` Wine says `12-channel stream ... rendered by AUSpatialMixer` when the audio fix works.

**Step 13 - After updates.** A Bridgeplay update can change `bridge/`, `tools` or the stock runner. A Steam game update can reset nothing here (the game folder is not touched). After an update re-check:
Step 12; the hash of `$BRIDGE/aarch64-windows/ntdll.dll` (`52416b5b...`); Steam's mapping of the game to the tool. If you rebuild the runner (Step 3), redo Step 4 and the runner part of Step 10.

### Uninstall / undo

Quit Steam and the game first. Each block undoes one step; run only the ones you want.

```sh
# Step 11 / 7: in Steam clear the launch options and the forced compatibility tool for the game.
# Step 10: network fix (restore the stock ws2_32, drop the renamed copies and the registry section)
SYS="$PFX/drive_c/windows/system32"; RW="$CX/lib/wine"
test ! -e "$SYS/ws2_32.dll.mgf-stock" || mv -f "$SYS/ws2_32.dll.mgf-stock" "$SYS/ws2_32.dll"
rm -f "$SYS/ws2_o.dll" "$RW/aarch64-windows/ws2_o.dll"
test "$(readlink "$RW/aarch64-unix/ws2_o.so")" = ws2_32.so && rm -f "$RW/aarch64-unix/ws2_o.so"
perl -0pi -e 's/\n?\[Software\\\\Wine\\\\AppDefaults\\\\forzahorizon6\.exe\\\\DllOverrides\][^\n]*\n(?:(?!\[)[^\n]*\n)*//i' "$PFX/user.reg"
# (or restore the copy: mv "$PFX/user.reg.fh6-bak" "$PFX/user.reg")
# Steps 5, 4, 3: the Steam tool, the bridge copy and the runner
rm -r "$TOOL" "$BRIDGE" "$RUN"
# Step 6: if you moved a Rosetta prefix aside, park the arm64 one and put the Rosetta one back (nothing is deleted)
test ! -e "$PFXDIR.rosetta" || { mv "$PFXDIR" "$PFXDIR.aa64" && mv "$PFXDIR.rosetta" "$PFXDIR"; }
# Step 2: the downloads (420 MB) and the shader caches
rm -r "$DL"
rm -r "$HOME/Library/Caches/fh6-kk-mesa" "$HOME/Library/Caches/fh6-vkd3d"
```

Verify: `ls "$BP/runners"` no longer lists `crossover-FH-fex`. Your game files, saves, stock Bridgeplay runners and `compatdata` are not removed (the arm64 prefix is kept as
`compatdata/2483190.aa64`); delete a prefix only after copying out the save and profile files. The last two `rm` lines delete caches; they are rebuilt on the next run.
Steam's own mapping of the game to the tool is a one-click change in Properties > Compatibility.

## Environment variables and launch options

Put them in Steam: Forza Horizon 6 > Properties > General > Launch Options, as `NAME=value %command%` (several can be chained). **Every value this tool sets itself is only a default**: a launch option
with the same name wins, and `compatdata/2483190/bridgeplay-run.log` says which applied. An empty value (`NAME= %command%`) counts as not set. The settings marked "app 2483190" are Highball's
Forza Horizon 6 recipe and are only applied for this game.

| Option | What it does | Default |
|---|---|---|
| `BRIDGEPLAY_DISABLE_HIDRAW=1` | DualSense through SDL as an Xbox-style controller | off (recommended on) |
| `NOTPROTON_PERF_OVERLAY=summary`, `NOTPROTON_SCALING_FILTER=integer` | Bridgeplay's overlay and scaling filter, loaded late by lsteamclient | off |
| `NOTPROTON_FRAMEGEN` | Bridgeplay frame generation. Not tested on this route | `0` |
| `NOTPROTON_ENV_MGF_FH5_NETLOG=1` | The network fix proxy writes `fh6-netfix.log` in the game folder | off |
| `NOTPROTON_ENV_MGF_FH5_NETFIX=0` | Network fix proxy forwards everything unchanged (A/B test) | on |
| `NOTPROTON_ENV_DXVK_CONFIG=...` | See below: replaces the whole default string | `dxgi.maxVideoMemoryBudget=4096;dxgi.maxDeviceMemory=4096;dxgi.maxSharedMemory=4096;` + GPU identity (app 2483190) |
| `DXVK_CONFIG` | Same thing when given as a plain launch option | as above |
| `MESA_SHADER_CACHE_DIR`, `MESA_SHADER_CACHE_MAX_SIZE` | KosmicKrisp shader cache folder and size | `~/Library/Caches/fh6-kk-mesa`, `4G` |
| `VKD3D_SHADER_CACHE_PATH` | vkd3d-proton shader cache folder, written as a `Z:` path | `Z:$HOME/Library/Caches/fh6-vkd3d` |
| `HB_FEX_FAST_LEGACY_UD`, `HB_FEX_FAST_PREFIX_UD`, `HB_FEX_DIRECT_SIGILL` | Highball's fast paths for the anti-tamper's illegal-instruction exceptions (app 2483190) | `1` each |
| `HB_FEX_SMC_INLINE`, `..._RETIRE_PROT`, `..._RETIRE_FREE`, `..._RETIRE_UNMAP`, `..._KEEP_READ`, `..._BLOCK_REMOVE`, `HB_FEX_SMC_RETIRE`, `HB_FEX_SMC_REINSTATE`, `HB_FEX_SMC_RETIRE_FAULTS`, `HB_FEX_CALLRET_EPOCH`, `HB_FEX_SMC_CACHE_FILTER`, `HB_FEX_MAPJIT`, `HB_DIRECT_CONTINUE` | Highball's self-modifying-code handling and FEX switches (app 2483190) | `1` each |
| `HB_FEX_SMC_GRAVE_SETS`, `HB_FEX_SMC_INLINE_MS`, `HB_FEX_PRIVATE_CHURN` | Sizes and timings of that handling | `16384`, `10000`, `20000` |
| `HB_FEX_SMC_REPLAY` | Highball SMC replay | `0` |
| `HB_KK_NO_UBO_ROBUST` | KosmicKrisp: no robust uniform-buffer access (app 2483190) | `1` |
| `FEX_SMCCHECKS`, `FEX_DISKCACHE`, `FEX_X87REDUCEDPRECISION` | FEX self-modifying-code check mode, on-disk code cache, x87 precision | `mtrack`, `0`, `1` |
| `VKD3D_FEATURE_LEVEL`, `VKD3D_SHADER_MODEL`, `VKD3D_CONFIG` | vkd3d-proton feature level, shader model, options (`VKD3D_CONFIG` replaces the whole list) | `12_1`, `6_6`, `no_staggered_submit` |
| `VKD3D_DEBUG`, `DXVK_LOG_LEVEL` | Log levels | `err`, `warn` |
| `VKD3D_RELAX_DEVICE_CAPS`, `DXVK_RELAX_FEATURES` | Let vkd3d-proton / DXVK start on KosmicKrisp although some device capabilities are missing | `1` each |
| `WINEDLLOVERRIDES` or `BRIDGEPLAY_DLLOVERRIDES` | Your own DLL overrides. Wine takes the last entry per DLL, so yours win for the DLLs you name | none |
| `BRIDGEPLAY_RAW_CONTROLLERS` | Games read gamepads directly. `0` = stock behaviour | `1` |
| `NOTPROTON_ENV_<NAME>` | Gives the game `<NAME>=value` for any variable the tool does not know by name | none |

The one-line descriptions of the `HB_*` switches are inferred from their names and Highball's recipe; Highball does not document them. `D3DM_*` and `CX_GRAPHICS_BACKEND=d3dmetal` are dropped on this engine (no D3DMetal).

**`DXVK_CONFIG` replaces the whole string, so it must repeat the identity keys.** The default carries the GPU identity the game needs (Intel Arc A750). To change only the memory numbers use, for example:

    DXVK_CONFIG='dxgi.maxVideoMemoryBudget=3072;dxgi.maxDeviceMemory=3072;dxgi.maxSharedMemory=3072;dxgi.customVendorId=8086;dxgi.customDeviceId=56a1;dxgi.customDeviceDesc="Intel(R) Arc(TM) A750 Graphics"' %command%

Leaving out `customVendorId`, `customDeviceId` and `customDeviceDesc` makes the game see another GPU identity, which can bring back the FH302 / unsupported-GPU behaviour.

## Hidden game settings (optional, partly unverified)

These keys are in the game's `UserConfigSelections` file but not in its settings menu. They were copied from an FH5 user config and tried on FH6 for less memory use and fewer particles;
the effect of some of them is **not verified** on FH6. Game closed, make a backup first (`cp -n`), then edit the values in
`$PFX/drive_c/users/steamuser/AppData/Local/ForzaHorizon6/LocalStorage_Shared/ForzaUserConfigSelections/UserConfigSelections` (inside the `<Selections>` list, same format as the existing lines):

| Key | Default in the file | Tried value |
|---|---|---|
| `ParticleRateScale` | `1.000000` | `0.100000` |
| `MegaTextureLowSpeedBudget` | `0.025000` | `0.001000` |
| `MegaTextureHighSpeedBudget` | `0.003000` | `0.001000` |
| `CarTextureMIPsDropped` | (absent) | add `<CarTextureMIPsDropped isDynamic="0" dynamicValue="Default" name="Default" value="2"/>` |
| `PlayerCarLiveryResolution`, `OpponentCarLiveryResolution` | (absent) | add the same line with value `1024` |

Undo: copy your backup back. The game may rewrite the file when you change settings in its menu.

## Known issues

- **Memory.** 16 GB Macs work but are memory-limited: expect some stutter, slow streaming (crowds and scenery appear late) and memory compression. With `DXVK_CONFIG` at 4096 the process footprint
  went from about 17 GB to about 15 GB steady in our tests (a footprint above RAM means mostly swapped; RSS stays near 3 GB). Tips: texture quality Very Low, Dynamic Optimization off, **restart the Mac before playing**, close browsers
  and other apps.
- **Where the memory goes** (profiling notes): vkd3d-proton does not enforce the DXGI budget on this stack, and the game sizes its pools from the adapter's `DedicatedVideoMemory`, so lowering only the budget did not help;
  device memory had to be lowered too. KosmicKrisp also keeps every Metal heap resident. The rest of the growth is the game's own heap during streaming, which levels off once you stop moving through new areas.
- A **low-VRAM warning** in the game is expected with the 4096 MB setting.
- The game shows an **FH302** driver-version warning at start. Click **Ignore Warning**.
- First start takes about 10 minutes (shader and "Optimizing for your PC") and asks for an Xbox sign-in once.
- Wine dies with `failed to map the shared user data: c0000018`: a dylib was injected into the loader (Steam overlay, notproton overlay). Highball's loader maps a fixed address that the injection takes. `run` switches overlay injection
  off on this runner; do not re-enable it.
- A graphics DLL "wrong version" or an old d3d12 loaded: the vkd3d-proton DLLs must be builtin. `run` sets `dxgi,d3d11,d3d10core,d3d12,d3d12core=b` before your launch options. Remove any `d3d12=n,b` from your own `WINEDLLOVERRIDES`.
- FH206 or FH302 dialog: wrong tool or an old prefix. The prefix must be arm64 (Step 6) and Steam must map the game to `bridgeplay-proton-fh6-fex` (Step 7).
- No voices or dialogue: check Step 4 (the r5 `winecoreaudio.so`) and the game's own audio volumes.
- "Unable to join session" / no online: check Step 10; then test with `NOTPROTON_ENV_MGF_FH5_NETLOG=1`.
- The D3DMetal-only crash "AGX compiled variants footprint" does not apply to this route (it does not use D3DMetal).
- **FSR sharpness.** The recommended settings use FSR3 (mode 1). If the picture looks soft, raise the sharpness slider in the game's graphics settings; this repo does not change it.
- Other logs: `~/Library/Application Support/bridgeplay/launchers/2483190/bridgeplay-wine.log` and `compatdata/2483190/bridgeplay-run.log`.

## Credits

Everything here stands on other people's work. Shipped files are listed one by one in [`bin/CREDITS.md`](bin/CREDITS.md); sources in [`src/ORIGIN.md`](src/ORIGIN.md).

| Project | Owner | License | Used here | What we changed |
|---|---|---|---|---|
| [Highball](https://github.com/gauthierpiarrette/highball), [highball-engine](https://github.com/gauthierpiarrette/highball-engine) and [highball-db](https://github.com/gauthierpiarrette/highball-db) | Gauthier Piarrette | GPL-3.0 (app), LGPL-2.1+ (engine), CC0 (db) | Engine `arm64-kk-wine11.18-r3` (release `engine-arm64-wine-11.18-20261103T154050Z-fh6-native-r3-fex0034`), the FEX patches, Highball 0.10.27 `WineLoader.app`, the Forza Horizon 6 recipe and its settings | Nothing in the downloads; engine pieces are rearranged into a Bridgeplay runner; memory defaults of the recipe lowered in `run` |
| Highball engine **r5** (release `engine-arm64-wine-11.18-20261108T132317Z-spatial-0056-0057`, sha256 `6721b1f4...8f33`), patch 0057 spatial mixer by TxCsOffc ([highball PR #313](https://github.com/gauthierpiarrette/highball/pull/313)) | Gauthier Piarrette; TxCsOffc | LGPL-2.1+ | One file, `winecoreaudio.so` (`bin/winecoreaudio-hb-r5.so`), for the dialogue fix | None: shipped byte for byte |
| [Bridgeplay](https://github.com/raymondchins/Bridgeplay) (a fork of NotProton) | raymondchins | GPL-3.0 | 0.7.64: the `run` script, `lsteamclient`, steamclient64 detour logic, performance overlay and scaling filter, runner and tool layout | `run`: arm64 branches marked `# FH-fex:`; detour ported to ARM64EC in `ntdll` |
| [Wine](https://www.winehq.org/) and [CodeWeavers](https://www.codeweavers.com/) CrossOver sources | The Wine project, CodeWeavers | LGPL-2.1+ | Wine 11.18 in the engine; its `ntdll.dll` is patched | 816 bytes patched in `ntdll.dll` |
| [FEX-Emu](https://github.com/FEX-Emu/FEX) | Ryan Houdek and contributors | MIT | FEX 2610 inside `xtajit64.dll` (Highball's patches through 0034, 0034 by ineshd) | None by us |
| [vkd3d-proton](https://github.com/HansKristian-Work/vkd3d-proton) | Hans-Kristian Arntzen, Valve and contributors | LGPL-2.1 | Direct3D 12 on Vulkan, commit `3b10bd7a` | Highball's patches 0001 to 0010; none by us |
| [DXVK](https://github.com/doitsujin/dxvk) | Philip Rebohle | zlib | The `dxgi` side of Highball's renderer (adapter identity and memory settings the recipe sets) | None |
| [Mesa KosmicKrisp](https://www.mesa3d.org/) and MoltenVK loader name; steamac patches | Mesa project, LunarG, steamac | MIT, Apache-2.0 | Vulkan on Metal (Mesa commit `ce576c29`) | Highball and steamac patches; none by us |
| [MacGameFix](https://github.com/MathiasKowoll/MacGameFix) (`fixes/fh5-netfix.c`, `pe.pl`, commit `881f3a96`), [xvferxedd/fh5-d3dmetal-fix](https://github.com/xvferxedd/fh5-d3dmetal-fix) (`ebd20dbe`), [Andytizer/fh5-crossover-steam-fix](https://github.com/Andytizer/fh5-crossover-steam-fix) v1.0.1 | MathiasKowoll; xvferxedd; Andytizer | GPL-3.0 | The ws2_32 proxy source and the export-rename helper (network fix) | FH6 changes: masking only on tracked UDP IPv6 sockets, IPv6 equivalents applied first, `fh6-netfix.log`, Docker build (`src/fh6-vs-upstream.diff`) |
| [Highball issue #415](https://github.com/gauthierpiarrette/highball/issues/415) | Reporter and Highball maintainers | n/a | The report of the once-per-few-seconds frame drops in Forza Horizon 6 that led to this analysis | n/a |
| Apple Game Porting Toolkit / D3DMetal | Apple | Apple license | Not used and not shipped on this route (used on `rosetta-d3dmetal`) | n/a |

## Disclaimer

No game files or Microsoft, Playground Games or Apple code are included. It works only with a legitimately owned Steam copy of the game, and no other game's or emulator's files are shipped or linked.
Forza Horizon 6 is a trademark of Microsoft. This project is not affiliated with or endorsed by Playground Games, Microsoft, Apple, Bridgeplay, Highball or any project above. Use at your own risk.

## License

GPL-3.0, see `LICENSE`. License texts that upstream requires are in `LICENSES/` (LGPL-2.1 for Wine and vkd3d-proton, MIT for FEX). Per-file origin: `bin/CREDITS.md`, `src/ORIGIN.md`.
