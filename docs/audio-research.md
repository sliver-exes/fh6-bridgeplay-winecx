# Dialogue / spatial-audio research notes (2026-11-14)

Our own notes, kept for reference. Section B is the arm64 (FEX route, `main` branch) fix, section C the Rosetta (MGF runner) fix of this branch. Paths in these notes point at our working folders, not at this repo. Upstream credits: Highball (Gauthier Piarrette, highball-engine patches 0056/0057, PR #313 by TxCsOffc), Wine (WineHQ), CodeWeavers.


Nothing on the live system was changed. Game was running (Rosetta MGF) the whole time and was not touched.
All builds/tests: ~/claude-tmp/fh6-audio2/ (cloned runners with `cp -c`, throwaway prefixes pfx/rosetta and pfx/fex, no game).

## Verdict
| Setup | Fix | Binary? | Tested without game |
|---|---|---|---|
| FEX (r3 engine, wine 11.18) | copy Highball r5's `aarch64-unix/winecoreaudio.so` into the runner (optionally also its 2 mmdevapi.dll) | yes, r5 file, ABI-identical | yes: runner copy loads it, 12ch stream now logs "rendered by AUSpatialMixer" |
| Rosetta (CrossOver 11.17) | drop-in of Highball x64 r24+ is NOT ABI-compatible. Use `winecoreaudio.so` rebuilt by us from upstream Wine 11.17 + Highball patch 0057 | yes, built locally | yes: same log line on the 11.17 runner copy |
| A (registry/mix-format knob) | does not exist in Wine 11.17/11.18 for this path | none | proven by source + probe |

## Root cause (confirmed by the game's own log, not just the PR)
- ~/claude-tmp/fh6-loadorder.log (game pid 0144, Highball engine): the game calls `ISpatialAudioClient::GetMaxDynamicObjectCount` (twice), then Wine prints `12-channel stream (mask 0x2d63f) rendered by AUSpatialMixer`. So FH6 does not use the device mix format. Its FMOD output activates a spatial-audio bed: mask 0x2D63F = 7.1.4, 12 float channels. The game binary has the strings `ISpatialAudioClient::ActivateSpatialAudioStream (for spatial)`, `ISpatialAudioObject::GetBuffer (for spatial bed channel %d)`, and "Cannot find ISpatialAudioClient interface".
- Wine's `SAC_ActivateSpatialAudioStream` (dlls/mmdevapi/spatialaudio.c) builds a 12ch EXTENSIBLE format and calls `IAudioClient::Initialize(... AUTOCONVERTPCM ...)`. Stock winecoreaudio (coreaudio.c `ca_setup_audiounit`) sets the AUHAL unit to 12ch with a channel bitmap and nothing mixes it down. Highball PR #313 (author TxCsOffc, merged) measured on macOS 27.0.1: only FL/FR come out; centre (dialogue/voices), sides, backs, heights are silent.
- Probe on both stock runners (my test exe, below): GetMixFormat = 2ch 0x3 48 kHz; IsFormatSupported(12ch) = S_FALSE with a stereo "closest"; Initialize(12ch, AUTOCONVERTPCM) = S_OK and plays with no mixer message. That is the silent-centre path. Same on Rosetta 11.17 and FEX r3.
- `ISpatialAudioClient` in Wine: `GetNativeStaticObjectTypeMask` = E_NOTIMPL (0x80004001), `GetMaxDynamicObjectCount` = 0 (S_OK). Activate always succeeds; there is no registry switch to make it fail.

## A. Why no registry/.reg fix exists
Checked in upstream wine-11.17 source (identical coreaudio.c/spatialaudio.c in 11.18; also fetched from the official 11.17 tarball, matches the GitHub tag):
- `unix_get_mix_format` (winecoreaudio.drv/coreaudio.c) reads only `kAudioDevicePropertyPreferredChannelLayout` / `StreamConfiguration` from macOS. No registry input. The only `HKCU\Software\Wine\Drivers\winecoreaudio.drv\devices\*` values are device GUIDs (devenum.c:179-232).
- mmdevapi `PKEY_AudioEndpoint_PhysicalSpeakers` is writable in the registry (devenum.c:552, "make read-write by not overwriting"), but GetMixFormat (client.c:881) never uses it, and the probe shows the mix is ALREADY stereo. The game ignores the mix format anyway (spatial bed above). So a stereo/5.1 report changes nothing.
- FH6 in-game Audio_SpeakerSetup_{Headphones,HomeCinema,NightTime,SmallSpeakers,TV} exist, but these look like dynamic-range presets, not channel count (unverified; I did not find a game setting that disables the spatial path). The FMOD strings `AOPT_SpeakerMode` / `setSoftwareFormat(speakermode...)` are internal.
So A cannot work without changing code. (No .reg lines to give.)

## B. FEX: swap in r5 winecoreaudio.so
ABI check (done):
- r3 engine = wine 11.18 `fh6-native-r3-fex0034`; r5 = wine 11.18 `spatial-0056-0057`: same Wine version, same coreaudio.c plus patch 0057 only (Highball notes "applies to Wine 11.18 without offset").
- Both .so import the same 4 symbols from ntdll.so (`___wine_dbg_header/_output/_strdup`, `_ntdll_umbstowcs`), link the same frameworks, `@rpath/ntdll.so`; r5 adds only HB_SPATIAL / spatial_* strings.
- Our runner's winecoreaudio.so (md5 10b7ca07...) and both mmdevapi.dll are byte-identical to r3, so r5's files are drop-ins.
Test (done, copy of runner `crossover-FH-fex`, throwaway prefix, probe exe, no game):
1. baseline r3: Initialize(12ch) S_OK, no mixer line.
2. only `aarch64-unix/winecoreaudio.so` = r5 (md5 5126f2d1bb3521b9c362905ba4300535): S_OK and `winecoreaudio: 12-channel stream (mask 0x2d63f) rendered by AUSpatialMixer for built-in speakers on a 2-channel device`.
3. plus r5 `aarch64-windows/mmdevapi.dll` and `i386-windows/mmdevapi.dll`: same result, no errors.
Minimal fix (needs approval, game closed):
```
R=~/Library/Application\ Support/bridgeplay/runners/crossover-FH-fex/CrossOver/lib/wine
cp -c "$R/aarch64-unix/winecoreaudio.so" "$R/aarch64-unix/winecoreaudio.so.r3"
cp ~/claude-tmp/highball-arm64/unpacked/r5/engine-tar/engine/lib/wine/aarch64-unix/winecoreaudio.so "$R/aarch64-unix/winecoreaudio.so"
```
Optional (correct side/back placement of the 7.1.4 bed, patch 0056, not needed for dialogue because FC is channel index 2 in both orders): same for `aarch64-windows/mmdevapi.dll` and `i386-windows/mmdevapi.dll` (back up as .r3).
The r5 .so is already ad-hoc signed (verified `codesign -dv`).
Env: `HB_SPATIAL=speakers|headphones|external` forces the output type, `HB_SPATIAL=0` turns the mixer off (launch option `HB_SPATIAL=headphones %command%` if the guess is wrong, e.g. on AirPods/Bluetooth it picks headphones by itself).
Revert: `cp -c winecoreaudio.so.r3 winecoreaudio.so` (and the .r3 mmdevapi files).
Risk: low. Single unix lib, same Wine version. Leaves r3 ntdll.so/winmm untouched (those differ in r5 but are not needed).

## C. Rosetta: Highball x64 engine is not a drop-in; build from source instead
- Highball x64 engines r24+ are CrossOver 26.3 = Wine 11.0 (`engine-wine-11.0-...`, r33 = 20261112 gst-rpath-0030). Their spatial code is patch 0023 (= spike/patches/winecoreaudio-crossover26.3-spatial-mixer.patch) on the 11.0 tree.
- ABI mismatch with our CrossOver 11.17 runner (verified from source, 11.0 vs 11.17 coreaudio.c): in 11.0 the driver is a PE `winecoreaudio.drv` with its own unixlib.h and `__wine_unix_call_funcs` = {process_attach, NI, main_loop, get_endpoint_ids, create_stream, ..., timer_loop, get_render_buffer, ...}. In 11.17 there is no PE drv, mmdevapi owns the interface (mmdevapi/unixlib.h enum, 37 entries), and the table is {NI x4, get_endpoint_ids, create_stream, ..., get_render_buffer, ...} (no timer_loop). Indices shift, so an 11.0 .so called by our 11.17 mmdevapi.dll would call wrong functions. I did not download the 335 MB engine tarball because of this.
- Our runner `.../crossover-MGF-winecx-11.17/.../x86_64-unix/winecoreaudio.so` (md5 a699711112c5e58f45f76b966eb0251f, modified Nov 10) is CrossOver's build: upstream 11.17 plus a microphone-permission dialog (AppKit/AVFoundation, strings "Microphone/audio capture permission was denied").
- Highball arm64 patches target upstream Wine 11.18; coreaudio.c and spatialaudio.c are byte-identical in 11.17 and 11.18, and patch 0057 applies cleanly to 11.17 (`patch -p1`, no offset). So: build 11.17 + 0057.
Build (done, ~/claude-tmp/fh6-audio2/build/build-x64-winecoreaudio.sh): official wine-11.17.tar.xz (46.7 MB, dl.winehq.org) headers + patched coreaudio.c, Apple clang `-arch x86_64`, linked against the runner's own ntdll.so, ad-hoc signed. widl is not installed, so `build/x64/shim/{mmdeviceapi,audioclient}.h` hand-define the few enum/constants needed (AUDCLNT_E_* values are the Windows HRESULTs, 0x889000nn).
Output: `~/claude-tmp/fh6-audio2/build/x64/winecoreaudio.so`, 77 KB, sha256 6af37a791598d081ee7a9f3dbfb9b9e21ba8c699ff66050ef61aed9781082dbb (md5 896a05d13615b5c62604596f90d20f4c). Exports only `___wine_unix_call_funcs`, `___wine_unix_call_wow64_funcs`, like the original.
Test (done, clone of crossover-MGF-winecx-11.17, throwaway prefix): driver loads, GetMixFormat/IsFormatSupported/Initialize all unchanged, plus `winecoreaudio: 12-channel stream (mask 0x2d63f) rendered by AUSpatialMixer for built-in speakers on a 2-channel device`. Baseline original .so: no such line. (First two builds failed to load: undefined `KSDATAFORMAT_SUBTYPE_*` because the shim pulled ksmedia.h before initguid.h; fixed.)
Minimal fix (needs approval, game closed):
```
R=~/Library/Application\ Support/bridgeplay/runners/crossover-MGF-winecx-11.17/CrossOver/lib/wine/x86_64-unix
cp -c "$R/winecoreaudio.so" "$R/winecoreaudio.so.cx"
cp ~/claude-tmp/fh6-audio2/build/x64/winecoreaudio.so "$R/winecoreaudio.so"
codesign -s - -f "$R/winecoreaudio.so"
```
Revert: `cp -c winecoreaudio.so.cx winecoreaudio.so`.
Risks: (1) loses CrossOver's microphone-permission prompt (irrelevant for the game; capture is unused). (2) Built with hand-written shims, not the real widl headers: only enum/constant values, same bits as Windows, and it runs in the test. (3) Rebuilt-by-us binary; keep the `.cx` backup. (4) Stray runner "set up" in Bridgeplay could overwrite it (verify_runner only compares ntdll.dll). Same caveat for the other Rosetta runners (crossover-FH-winecx-11.17, crossover-winecx-11.17) if used; apply per runner.
Not done: patch 0056 (mmdevapi static-object order, side/back swap) needs a PE cross build of mmdevapi.dll (no mingw here, Colima is off, and RAM is tight while the game runs). Cosmetic: affects side vs back placement only; dialogue (FC, index 2) is unaffected.

## Rosetta extra finding: native MS VC++ runtime is still fully forced
- User note: "in rosetta before audio is working but now after this fix". run script line 3116 (`mgf_msvc="concrt140=n,b"  # narrowed: full native msvcp/vcruntime set lost dialogue audio`) says the full native set cost dialogue, and was narrowed to concrt140. BUT the last launch (bridgeplay-run.log line 2095, 11:27) still shows `WINEDLLOVERRIDES=concrt140=n,b;msvcp140=n,b;msvcp140_1=n,b;msvcp140_2=n,b;msvcp140_atomic_wait=n,b;msvcp140_codecvt_ids=n,b;vcamp140=n,b;vccorlib140=n,b;vcomp140=n,b;vcruntime140=n,b;vcruntime140_1=n,b;...`.
- Cause: run script `native_vc_runtime()` (line ~3035/3100, called at 3311) adds `=n,b` for every non-"Wine builtin DLL" file in the prefix's system32. The Rosetta prefix has native Microsoft concrt140/msvcp140*/vcamp140/vccorlib140/vcomp140/vcruntime140* in system32 and syswow64 (dated May 27, from the Highball recipe). So the "narrowing" in `mgf_msvc` never takes effect.
- Hypothesis (unverified, only the code comment and the user's memory): the full native set silences dialogue on Rosetta, independent of the 12ch issue. To test: append `msvcp140,msvcp140_1,msvcp140_2,msvcp140_atomic_wait,msvcp140_codecvt_ids,vcamp140,vccorlib140,vcomp140,vcruntime140,vcruntime140_1=b` to the DLLOVERRIDES line of ~/Library/Application Support/bridgeplay/gamefixes/2483190.conf (`DLLOVERRIDES=d3d12=n,b;...=b`). Order in the log shows gamefix entries come after the auto list and the script comment says the last entry wins, so it should override; I did not test that parse. Revert: restore the single-DLL line `DLLOVERRIDES=d3d12=n,b`.
- It could fit both ways: Highball's db says voices were missing on every Mac before the spatial mixer, i.e. also on Rosetta. So "dialogue worked once on Rosetta" is plausible only if the game took a different audio path then; the spatial fix is the evidence-backed one, the override test is the cheap second experiment. Do one change at a time.

## Test tool (reusable)
- `~/claude-tmp/fh6-audio2/build/mixfmt.c` + `mklink.py`: freestanding x86-64 console exe built with Apple clang `-target x86_64-pc-windows-msvc -c` plus a ~100-line COFF->PE linker (no mingw/lld/Docker needed). Prints GetMixFormat, IsFormatSupported(12ch 0x2d63f), Initialize(12ch AUTOCONVERTPCM)+1 s render (silence), ISpatialAudioClient results. Pass `tone=2` on the command line to render a 5% 440 Hz tone on channel 2 (centre) instead of silence; I did not run that while you were playing.
- Runner: `~/claude-tmp/fh6-audio2/runwine.sh <rosetta|fex> <prefix> <exe>`; `probe.sh` wraps it; logs in `results/`.
- Real-ear check still needed: with the fix in, trigger a Jordan/Anna call or intro dialogue.

## Credits
- Wine: WineHQ, https://www.winehq.org, LGPL-2.1+, source wine-11.17 (dlls/winecoreaudio.drv, dlls/mmdevapi) and wine-11.0. CrossOver Wine: CodeWeavers (LGPL), our Rosetta runner is their 11.17 build.
- Spatial-mixer fix and measurements: Highball, gauthierpiarrette/highball-engine (LGPL-2.1) patches-arm64/0056 and 0057 (branch arm64-spatial-audio, engine r5 = engine-arm64-wine-11.18-20261108T132317Z-spatial-0056-0057), carried from the Intel line's patches 0022/0023; patch author credited as TxCsOffc, gauthierpiarrette/highball PR #313 (GPL-3.0 app repo, spike/patches/*crossover26.3*). Highball db fh6-db.json entry on engine r24.
- What we changed: B uses their r5 file unmodified; C is their unmodified patch 0057 applied to Wine 11.17, compiled by us with hand-written audioclient/mmdeviceapi shim headers and ad-hoc signed.
- Earlier research: research/fh6-audio.md (AudioQuality theory ruled out).
