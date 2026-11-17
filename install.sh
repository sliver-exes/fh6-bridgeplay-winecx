#!/bin/sh
# Forza Horizon 6 (Steam) on Bridgeplay's WineCX 11.17 runner (Rosetta) with the D3DMetal d3d12 proxy and,
# by default, the MGF setup: MacGameFix's exception chain, the Rosetta trap boost, the spatial-audio dialogue
# fix and the C++ runtime override. One command: ./install.sh
#
# Credits (full list in bin/CREDITS.md and README.md):
#   d3d12 proxy: sliver-exes/fh5-d3dmetal-fix (GPL-3.0), built on tsshim from Highball by Gauthier
#     Piarrette (GPL-3.0). https://github.com/sliver-exes/fh5-d3dmetal-fix
#   --pacer proxy (d3d12-fh6.dll, Rosetta frame pacer): MacGameFix main @ ef19e41 (PR #89), by MathiasKowoll
#     (GPL-3.0), itself based on the Highball tsshim and xvferxedd/fh5-d3dmetal-fix. Unchanged by us.
#   MacGameFix by MathiasKowoll (GPL-3.0, Wine modules LGPL-2.1+), commit 881f3a96: the 27.0.0.41073 ntdll.dll
#     (exception chain, ALU bridge) and notproton-rosetta-trap-boost.dylib. https://github.com/MathiasKowoll/MacGameFix
#   Highball by Gauthier Piarrette: patch 0057 spatial mixer (TxCsOffc, PR #313, LGPL-2.1) and the concrt140 tweak.
#     https://github.com/gauthierpiarrette/highball-engine
#   Bridgeplay by raymondchins (GPL-3.0): runner, Steam tool, bridge, Steam detour. https://github.com/raymondchins/Bridgeplay
#   Wine / CodeWeavers CrossOver Wine (LGPL-2.1+); Apple D3DMetal (not shipped, used from your Bridgeplay install).
# This file: sliver-exes, GPL-3.0.
#
# Usage: ./install.sh [-y] [--plain] [--pacer] [--experimental-ntdll]
#   -y                    answer yes to every question (quits Steam, starts the game once if there is no prefix)
#   --plain               only the old plain D3DMetal-proxy route (plain tool only, no MGF runner/tool)
#   --pacer               use MacGameFix's d3d12 proxy with the Rosetta frame pacer instead of the plain proxy
#                         (MGF route only; run again without --pacer to go back)
#   --experimental-ntdll  plain route only: also install the unwind-patched ntdll.dll (did not fix FHE21)
# Default route: one MGF runner + bridge + Steam tool. Only one route stays installed (the other one's copies,
# which are ours and never Bridgeplay's stock files, are removed).
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=lib.sh
. "$HERE/lib.sh"

FH_YES=0; EXP_NTDLL=0; PLAIN=0; PACER=0
for a in "$@"; do
  case $a in
    -y|--yes) FH_YES=1 ;;
    --experimental-ntdll) EXP_NTDLL=1 ;;
    --plain) PLAIN=1 ;;
    --pacer) PACER=1 ;;
    -h|--help) sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown option $a (try --help)" ;;
  esac
done
export FH_YES

# ---- 1. prerequisites ------------------------------------------------------------------------
step "Checking prerequisites"
[ "$(uname -s)" = Darwin ] && [ "$(uname -m)" = arm64 ] || die "This needs an Apple Silicon Mac (arm64) running macOS."
for t in sed awk cmp shasum cp ln codesign; do command -v "$t" >/dev/null 2>&1 || die "missing tool: $t"; done
python3 -c 'pass' >/dev/null 2>&1 || die "python3 is needed (run: xcode-select --install), then run this again."
ok "Apple Silicon, python3"

[ -f "$HERE/bin/SHA256SUMS" ] || die "bin/SHA256SUMS is missing: use a full git clone of this repo."
bad=$(cd "$HERE/bin" && while read -r h f; do [ -n "$h" ] || continue; [ "$(sha "$f")" = "$h" ] || echo "$f"; done < SHA256SUMS)
[ -z "$bad" ] || die "files in bin/ do not match bin/SHA256SUMS: $bad (re-clone the repo)"
[ "$(sha "$HERE/bin/d3d12.dll")" = "$PROXY_SHA" ] || die "bin/d3d12.dll is not the expected proxy build."
[ "$(sha "$HERE/bin/d3d12-fh6.dll")" = "$PACER_SHA" ] || die "bin/d3d12-fh6.dll is not the expected pacer proxy build."
ok "bin/ files match SHA256SUMS (proxy sha256 $(printf %.8s "$PROXY_SHA")...)"

[ -d "$BP" ] || die "Bridgeplay is not installed. Get it from https://github.com/raymondchins/Bridgeplay/releases, open it once, and install its WineCX 11.17 runner."
for p in "$RUN_SRC/CrossOver" "$BP/bridge/wine/$SRC_BUILD" "$GPTK/x86_64-windows/d3d12.dll" "$GPTK/x86_64-unix/d3d12.so"; do
  [ -e "$p" ] || die "missing $p. Open Bridgeplay, install its WineCX 11.17 runner (it also sets up D3DMetal), then run this again."
done
[ "$PLAIN" = 0 ] || [ -e "$STEAM/compatibilitytools.d/$SRC_TOOL" ] || die "missing Bridgeplay's Steam tool $SRC_TOOL (needed by --plain). Open Bridgeplay, install its WineCX 11.17 runner, then run this again."
ok "Bridgeplay with WineCX 11.17 runner and D3DMetal found"

find_library || die "Forza Horizon 6 (Steam app $APPID) is not installed in any Steam library. Install it from Steam first."
[ -f "$GAME/forzahorizon6.exe" ] || die "Forza Horizon 6 is not fully installed (missing $GAME/forzahorizon6.exe). Let Steam finish the download."
ok "game: $GAME"


step "Steam"
ensure_steam_quit
mkdir -p "$CACHE" "$STATE"

# ---- 1b. prefix: this route needs the x86-64 (Rosetta) prefix ---------------------------------------
step "Wine prefix"
case $(pfx_arch) in
  aarch64)
    [ ! -e "$PFXDIR.fex" ] || die "$PFXDIR.fex already exists. Rename or move it by hand, then run this again."
    mv "$PFXDIR" "$PFXDIR.fex"; : > "$STATE/moved-fex"
    ok "arm64 (FEX) prefix moved to compatdata/$APPID.fex (nothing deleted)"
    if [ -e "$PFXDIR.rosetta" ] && [ "$(pfx_arch "$PFXDIR.rosetta/pfx")" = x86_64 ]; then
      mv "$PFXDIR.rosetta" "$PFXDIR"
      ok "Rosetta prefix restored from compatdata/$APPID.rosetta"
    else
      info "No Rosetta prefix to restore; a new one is created by the first start of the game (below)."
    fi ;;
  x86_64) ok "x86-64 (Rosetta) prefix already in place" ;;
  other)  warn "the prefix has an unexpected architecture; leaving it alone" ;;
  none)
    if [ ! -e "$PFXDIR" ] && [ -e "$PFXDIR.rosetta" ] && [ "$(pfx_arch "$PFXDIR.rosetta/pfx")" = x86_64 ]; then
      mv "$PFXDIR.rosetta" "$PFXDIR"; ok "Rosetta prefix restored from compatdata/$APPID.rosetta"
    else info "no prefix yet; it is created by the first start of the game (below)."; fi ;;
esac

TMP=$(mktemp -d "$CACHE/work.XXXXXX"); trap 'rm -rf "$TMP"' EXIT INT TERM

# apd12.dll = D3DMetal's d3d12.dll with its export name changed to apd12.dll (same length).
cp "$GPTK/x86_64-windows/d3d12.dll" "$TMP/apd12.dll"
python3 -I "$HERE/bin/pe_tools.py" rename-export "$TMP/apd12.dll" apd12.dll >/dev/null
if [ "$(sha "$TMP/apd12.dll")" = "$APD12_SHA" ]; then ok "apd12.dll built from your D3DMetal (the tested build)"
else warn "apd12.dll hash differs (different D3DMetal build than the tested 4.0 beta 3); continuing"; fi

# add_apd12 RUNNER_DIR: apd12.dll + apd12.so (a link to D3DMetal) in a runner copy
add_apd12() {
  cp "$TMP/apd12.dll" "$1/CrossOver/lib/wine/x86_64-windows/apd12.dll"
  ln -sfn "$GPTK/x86_64-unix/d3d12.so" "$1/CrossOver/lib/wine/x86_64-unix/apd12.so"
  ok "apd12.dll + apd12.so in the runner copy"
}

# ---- 1c. migrate old tool names: Bridgeplay's launch-option hook only handles bridgeplay-proton-* folders ----
for n in $OLD_TOOLNAMES; do
  if [ -d "$STEAM/compatibilitytools.d/$n" ]; then
    rm -rf "$STEAM/compatibilitytools.d/$n"; ok "removed old tool folder $n (renamed; launch options now work)"
  fi
done
[ ! -f "$STATE/prev-compat-tool" ] || case " $OLD_TOOLNAMES " in *" $(cat "$STATE/prev-compat-tool") "*) : > "$STATE/prev-compat-tool" ;; esac

# ---- 2. runner, bridge and Steam tool of the chosen route (the other route's copies are removed) ----------
mkdir -p "$BP/gamefixes"
if [ "$PLAIN" = 1 ]; then
  step "Plain route: runner crossover-$FH_BUILD (copy of WineCX 11.17)"
  if [ -e "$RUN_FH" ]; then ok "runner copy exists, keeping it"
  else info "copying runner (about 1.3 GB)"; cp -a "$RUN_SRC" "$RUN_FH"; ok "runner copied"; fi
  add_apd12 "$RUN_FH"

  NT="$RUN_FH/CrossOver/lib/wine/x86_64-windows/ntdll.dll"
  cur=$(sha "$NT")
  if [ "$EXP_NTDLL" = 1 ]; then
    if [ "$cur" = "$NTDLL_UNWIND_SHA" ]; then ok "experimental unwind ntdll already installed"
    elif [ "$cur" = "$NTDLL_STOCK_SHA" ]; then
      [ -e "$NT.fh6-orig" ] || cp -p "$NT" "$NT.fh6-orig"
      cp "$HERE/bin/ntdll-FH-winecx-unwind.dll" "$NT"
      ok "experimental unwind ntdll installed (original kept as ntdll.dll.fh6-orig)"
    else warn "runner ntdll.dll is not the expected stock build; experimental ntdll NOT installed"; fi
  elif [ "$cur" = "$NTDLL_UNWIND_SHA" ] && [ -e "$NT.fh6-orig" ]; then
    cp -p "$NT.fh6-orig" "$NT"; rm -f "$NT.fh6-orig"
    ok "stock ntdll restored (the experimental one is off unless you pass --experimental-ntdll)"
  else
    ok "stock ntdll (experimental unwind ntdll is off)"
  fi

  step "Plain route: bridge folder and Steam tool"
  [ -e "$BP/bridge/wine/$FH_BUILD" ] || cp -a "$BP/bridge/wine/$SRC_BUILD" "$BP/bridge/wine/$FH_BUILD"
  ok "bridge/wine/$FH_BUILD"
  rm -rf "$TOOL"; cp -a "$STEAM/compatibilitytools.d/$SRC_TOOL" "$TOOL"
  echo "$FH_BUILD" > "$TOOL/build"
  # Bridgeplay deletes unlisted bridgeplay-proton-* folders holding a file named flavor or its own run header.
  mv "$TOOL/flavor" "$TOOL/tool-flavor"
  sed -i '' -e '2s/^# bridgeplay CrossOver compatibility tool shim$/# bridgeplay-compatible custom tool shim (FH6 build, based on Bridgeplay run; not written by Bridgeplay)/' -e 's#\$np_tool_dir/flavor#$np_tool_dir/tool-flavor#g' "$TOOL/run"
  sed -i '' -e "s/\"$SRC_TOOL\"/\"$TOOLNAME\"/" -e "s/\"display_name\" \".*\"/\"display_name\" \"$TOOL_DISPLAY\"/" "$TOOL/compatibilitytool.vdf"
  ok "Steam tool $TOOLNAME"
  if [ -e "$RUN_MGF" ] || [ -e "$MGF_BRIDGE" ] || [ -e "$MGF_TOOL" ]; then
    rm -rf "$RUN_MGF" "$RUN_MGF.partial" "$MGF_BRIDGE" "$MGF_TOOL"
    ok "MGF runner, bridge and tool removed (they were our copies; only one route stays installed)"
  fi
  SEL=$TOOLNAME; SEL_DISPLAY=$TOOL_DISPLAY
else
  [ "$EXP_NTDLL" = 0 ] || warn "--experimental-ntdll belongs to the --plain route; ignored"
  step "MGF runner crossover-$MGF_BUILD (copy of WineCX 11.17 + MacGameFix ntdll, dialogue fix)"
  if [ -e "$RUN_MGF" ]; then ok "runner exists, keeping its folder"
  else
    info "cloning Bridgeplay's crossover-$SRC_BUILD (instant on APFS, otherwise a normal copy of about 1.3 GB)"
    rm -rf "$RUN_MGF.partial"
    cp -a -c "$RUN_SRC" "$RUN_MGF.partial" 2>/dev/null || { rm -rf "$RUN_MGF.partial"; cp -a "$RUN_SRC" "$RUN_MGF.partial"; }
    mv "$RUN_MGF.partial" "$RUN_MGF"
    ok "runner cloned"
  fi
  add_apd12 "$RUN_MGF"
  NTM="$MGF_WINE/x86_64-windows/ntdll.dll"
  if [ "$(sha "$NTM")" = "$MGF_NTDLL_SHA" ]; then ok "MGF ntdll.dll already in the runner"
  else
    [ -e "$NTM.mgf-orig" ] || cp -p "$NTM" "$NTM.mgf-orig"
    cp "$HERE/bin/ntdll-MGF-winecx.dll" "$NTM"
    ok "MGF ntdll.dll installed (previous one kept as ntdll.dll.mgf-orig)"
  fi
  WCA="$MGF_WINE/x86_64-unix/winecoreaudio.so"
  if [ "$(sha "$WCA")" = "$MGF_WCA_SHA" ]; then ok "spatial-audio winecoreaudio.so already in the runner"
  else
    [ -e "$WCA.cx" ] || cp -p "$WCA" "$WCA.cx"
    cp "$HERE/bin/winecoreaudio-MGF-x64.so" "$WCA"
    codesign --verify "$WCA" >/dev/null 2>&1 || codesign -s - -f "$WCA" >/dev/null 2>&1 || die "could not sign winecoreaudio.so"
    ok "dialogue fix: spatial-audio winecoreaudio.so installed (CrossOver's kept as winecoreaudio.so.cx)"
  fi

  step "MGF bridge folder and Steam tool"
  [ -e "$MGF_BRIDGE" ] || cp -a "$BP/bridge/wine/$SRC_BUILD" "$MGF_BRIDGE"
  cp "$HERE/bin/ntdll-MGF-winecx.dll" "$MGF_BRIDGE/x86_64-windows/ntdll.dll"
  ok "bridge/wine/$MGF_BUILD (same MGF ntdll.dll)"
  mkdir -p "$MGF_TOOL"
  for f in run compatibilitytool.vdf build tool-flavor toolmanifest.vdf notproton-rosetta-trap-boost.dylib; do
    cp -p "$HERE/bin/mgf/$f" "$MGF_TOOL/$f"
  done
  chmod +x "$MGF_TOOL/run"
  ok "Steam tool $MGF_TOOLNAME (trap boost on; off switch: file mgf-trap-boost.off in the tool folder)"
  if [ -e "$RUN_FH" ] || [ -e "$BP/bridge/wine/$FH_BUILD" ] || [ -e "$TOOL" ]; then
    rm -rf "$RUN_FH" "$BP/bridge/wine/$FH_BUILD" "$TOOL"
    ok "plain FH WineCX runner, bridge and tool removed (they were our copies; only one route stays installed)"
  fi
  SEL=$MGF_TOOLNAME; SEL_DISPLAY=$MGF_TOOL_DISPLAY
fi

step "Game config and game folder"
cat > "$TMP/gamefix.conf" <<'EOT'
# Forza Horizon 6: D3DMetal, NVIDIA RTX 4070 identity, load the d3d12 proxy from the game folder, MetalFX off
# (MetalFX off stops Apple Neural Engine errors and a hang after a resolution change; use FSR, not DLSS)
BACKEND=d3dmetal
D3DM_VENDOR_ID=4318
D3DM_DEVICE_ID=10118
DLLOVERRIDES=d3d12=n,b
D3DM_ENABLE_METALFX=0
EOT
if [ -f "$GAMEFIX" ] && ! cmp -s "$TMP/gamefix.conf" "$GAMEFIX" && [ ! -e "$GAMEFIX.fh6-bak" ]; then
  cp -p "$GAMEFIX" "$GAMEFIX.fh6-bak"; info "your previous gamefixes/$APPID.conf is kept as $APPID.conf.fh6-bak"
fi
cp "$TMP/gamefix.conf" "$GAMEFIX"
ok "gamefixes/$APPID.conf"
if [ "$PACER" = 1 ] && [ "$PLAIN" = 1 ]; then
  warn "--pacer belongs to the MGF route; ignored with --plain"; PACER=0
fi
if [ "$PACER" = 1 ]; then
  cp "$HERE/bin/d3d12-fh6.dll" "$GAME/d3d12.dll"
  ok "pacer proxy d3d12.dll (MacGameFix d3d12-fh6) in the game folder"
  info "Add NOTPROTON_ENV_MGF_FH6_ROSETTA_PACER=40 to the launch options to switch the pacer on (see README)."
else
  cp "$HERE/bin/d3d12.dll" "$GAME/d3d12.dll"
  ok "proxy d3d12.dll in the game folder"
fi

# ---- 3. Steam compatibility tool ----------------------------------------------------------------
# set_mapping: Forza Horizon 6 uses the tool of the chosen route. Sets MANUAL=1 if it cannot be done safely.
set_mapping() {
  MANUAL=0
  if [ -f "$VDF" ]; then
    [ -f "$STATE/prev-compat-tool" ] || { vdf_compat get "$APPID" > "$STATE/prev-compat-tool" || : > "$STATE/prev-compat-tool"; }
    if r=$(vdf_compat set "$APPID" "$SEL"); then
      ok "Steam config.vdf: app $APPID uses $SEL ($r; backup config.vdf.fh6-orig)"
    else MANUAL=1; fi
  else MANUAL=1; fi
}
step "Steam compatibility tool for Forza Horizon 6"
set_mapping
[ "$MANUAL" = 0 ] || warn "Could not set the tool in Steam's config automatically (do the one click below)."

# ---- 4. prefix: create it with one start of the game if it does not exist yet -------------------------
step "Prefix"
PENDING=0
if [ ! -f "$PFX/user.reg" ]; then
  if first_run_prefix; then
    set_mapping   # Steam rewrote its config while it ran: make sure the choice is still in it
  else
    PENDING=1
  fi
fi
if [ -f "$PFX/user.reg" ]; then
  cp "$TMP/apd12.dll" "$PFX/drive_c/windows/system32/apd12.dll"
  # HB_D3D12_REAL tells the proxy where the real D3DMetal is. Mac Steam cannot pass VAR=value
  # launch options (OS Error 260), so it goes into the prefix's Windows environment instead.
  if ! grep -q '^"HB_D3D12_REAL"=' "$PFX/user.reg"; then
    [ -f "$PFX/user.reg.fh6-orig" ] || cp "$PFX/user.reg" "$PFX/user.reg.fh6-orig"
    awk '{ print } /^\[Environment\]/ { e = 1; next }
         e && /^#time=/ { print "\"HB_D3D12_REAL\"=\"C:\\\\windows\\\\system32\\\\apd12.dll\""; e = 0 }' \
      "$PFX/user.reg" > "$TMP/user.reg"
    grep -q '^"HB_D3D12_REAL"=' "$TMP/user.reg" || die "no [Environment] section in $PFX/user.reg"
    cp "$TMP/user.reg" "$PFX/user.reg"
  fi
  ok "prefix has apd12.dll and HB_D3D12_REAL"
fi

# ---- done ---------------------------------------------------------------------------------------------
if [ "$PENDING" = 1 ]; then
  printf '\n%s%sAlmost done.%s Everything is installed except the game'"'"'s Wine prefix, which only exists after one start.\n' "$C_Y" "$C_B" "$C_N"
  info "Open Steam and press Play on Forza Horizon 6 once. Quit the game at the main menu (a FH206 dialog"
  info "may appear first, ignore it), quit Steam, then run ./install.sh again. It takes seconds."
else
  printf '\n%s%sDone.%s Now open Steam and press Play on Forza Horizon 6.\n' "$C_G" "$C_B" "$C_N"
fi
if [ "$MANUAL" = 1 ]; then
  info "One click first: Forza Horizon 6 > Properties > Compatibility > tick"
  info "\"Force the use of a specific Steam Play compatibility tool\" and pick"
  info "\"$SEL_DISPLAY\". (Launch Options can stay empty, or hold VAR=value %command% settings.)"
fi
[ "$PLAIN" = 1 ] || info "Tips (16 GB Macs): texture quality Very Low, Dynamic Optimization off, close other apps, restart before playing."
info "If the FH302 driver warning appears, click Ignore Warning."
info "Check anything with ./doctor.sh. Undo everything with ./uninstall.sh."
