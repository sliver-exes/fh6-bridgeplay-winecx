#!/bin/sh
# Read-only health check for the main-branch install: prints PASS / FAIL / WARN lines and where the logs are.
# Changes nothing. Exit status 1 if any check FAILs.
#
# fh6-mac-fix, sliver-exes, GPL-3.0. Credits: see README.md and bin/CREDITS.md.
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=lib.sh
. "$HERE/lib.sh"

FAILS=0; WARNS=0
pass() { printf '  %sPASS%s %s\n' "$C_G" "$C_N" "$*"; }
fail() { printf '  %sFAIL%s %s\n' "$C_R" "$C_N" "$*"; FAILS=$((FAILS + 1)); }
wrn()  { printf '  %sWARN%s %s\n' "$C_Y" "$C_N" "$*"; WARNS=$((WARNS + 1)); }
check() { l=$1; shift; if "$@" >/dev/null 2>&1; then pass "$l"; else fail "$l"; fi; }

printf '%sFH6 (Rosetta: MGF runner + D3DMetal proxy) doctor%s (read-only)\n' "$C_B" "$C_N"

step "System"
check "Apple Silicon" test "$(uname -m)" = arm64
python3 -c 'pass' >/dev/null 2>&1 && pass "python3 available" || wrn "python3 missing (needed by install.sh)"
steam_running && wrn "Steam is running (fine for this check; quit it before install/uninstall)" || pass "Steam is not running"

step "Repository files"
if [ -f "$HERE/bin/SHA256SUMS" ]; then
  b=$(cd "$HERE/bin" && while read -r h f; do [ -n "$h" ] || continue; [ "$(sha "$f")" = "$h" ] || echo "$f"; done < SHA256SUMS)
  if [ -z "$b" ]; then pass "bin/ matches SHA256SUMS"; else fail "bin/ differs from SHA256SUMS: $b"; fi
else fail "bin/SHA256SUMS missing"; fi

if [ -d "$MGF_TOOL" ] || [ -d "$RUN_MGF" ]; then HAS_MGF=1; else HAS_MGF=0; fi
if [ -d "$TOOL" ] || [ -d "$RUN_FH" ]; then HAS_PLAIN=1; else HAS_PLAIN=0; fi

step "Bridgeplay"
check "Bridgeplay folder" test -d "$BP"
check "stock WineCX 11.17 runner (not modified by us)" test -d "$RUN_SRC/CrossOver"
check "stock bridge/wine/$SRC_BUILD" test -d "$BP/bridge/wine/$SRC_BUILD"
check "D3DMetal d3d12.dll (gptk)" test -f "$GPTK/x86_64-windows/d3d12.dll"

step "Installed route"
if [ "$HAS_MGF" = 1 ] && [ "$HAS_PLAIN" = 1 ]; then
  wrn "both routes are installed (MGF and plain); Steam would list two tools. Run ./install.sh (or ./install.sh --plain) to keep one"
elif [ "$HAS_MGF" = 1 ]; then pass "MGF route (default) is installed"
elif [ "$HAS_PLAIN" = 1 ]; then pass "plain route (--plain) is installed"
else fail "no route installed (run ./install.sh)"; fi

if [ "$HAS_MGF" = 1 ]; then
  step "MGF runner crossover-$MGF_BUILD (default route)"
  if [ -d "$RUN_MGF/CrossOver" ]; then
    pass "runner folder $RUN_MGF"
    check "apd12.dll in runner" test -f "$MGF_WINE/x86_64-windows/apd12.dll"
    [ "$(sha "$MGF_WINE/x86_64-windows/apd12.dll")" = "$APD12_SHA" ] \
      && pass "apd12.dll is the tested build" || wrn "apd12.dll differs from the tested D3DMetal 4.0b3 build"
    check "apd12.so link resolves to D3DMetal" test -e "$MGF_WINE/x86_64-unix/apd12.so"
  else fail "MGF runner missing: $RUN_MGF (run ./install.sh)"; fi
  [ "$(sha "$MGF_WINE/x86_64-windows/ntdll.dll")" = "$MGF_NTDLL_SHA" ] \
    && pass "runner ntdll.dll = MGF build (MacGameFix 41073 + Bridgeplay Steam detour + RtlVirtualUnwind2 fix)" \
    || fail "runner ntdll.dll is not the MGF build"
  [ "$(sha "$MGF_WINE/x86_64-unix/winecoreaudio.so")" = "$MGF_WCA_SHA" ] \
    && pass "dialogue fix: spatial-audio winecoreaudio.so in the runner" \
    || fail "dialogue fix missing: runner winecoreaudio.so is not the spatial-audio build"
  check "winecoreaudio.so signature valid" codesign --verify "$MGF_WINE/x86_64-unix/winecoreaudio.so"
  [ "$(sha "$MGF_BRIDGE/x86_64-windows/ntdll.dll")" = "$MGF_NTDLL_SHA" ] \
    && pass "bridge/wine/$MGF_BUILD ntdll.dll = MGF build" || fail "bridge/wine/$MGF_BUILD ntdll.dll missing or different"
  if [ -d "$MGF_TOOL" ]; then
    pass "MGF tool folder $MGF_TOOLNAME"
    for f in run compatibilitytool.vdf build tool-flavor toolmanifest.vdf notproton-rosetta-trap-boost.dylib; do
      [ "$(sha "$MGF_TOOL/$f")" = "$(sha "$HERE/bin/mgf/$f")" ] && pass "MGF tool/$f matches repo" || fail "MGF tool/$f missing or different"
    done
    [ "$(sha "$MGF_TOOL/notproton-rosetta-trap-boost.dylib")" = "$MGF_BOOST_SHA" ] && pass "trap boost dylib is MacGameFix's (sha256 $(printf %.8s "$MGF_BOOST_SHA")...)" || fail "trap boost dylib hash differs"
    check "trap boost dylib signature valid" codesign --verify "$MGF_TOOL/notproton-rosetta-trap-boost.dylib"
    [ -x "$MGF_TOOL/run" ] && pass "run is executable" || fail "run is not executable"
    [ -e "$MGF_TOOL/mgf-trap-boost.off" ] && wrn "trap boost switched off (mgf-trap-boost.off exists)" || pass "trap boost is on"
    grep -q "\"$MGF_TOOLNAME\"" "$MGF_TOOL/compatibilitytool.vdf" 2>/dev/null \
      && pass "tool registered in compatibilitytool.vdf as $MGF_TOOLNAME" || fail "compatibilitytool.vdf does not register $MGF_TOOLNAME"
    [ ! -e "$MGF_TOOL/flavor" ] && pass "no file named flavor in the tool (Bridgeplay would delete it)" || fail "$MGF_TOOL/flavor exists: Bridgeplay deletes unlisted bridgeplay-proton-* tools holding it; run ./install.sh"
  else fail "MGF tool folder missing: $MGF_TOOL"; fi
for n in $OLD_TOOLNAMES; do
  [ ! -d "$STEAM/compatibilitytools.d/$n" ] || wrn "old tool folder $n still present; run ./install.sh to migrate it"
done
fi

if [ "$HAS_PLAIN" = 1 ]; then
  step "Plain route: runner crossover-$FH_BUILD"
  if [ -d "$RUN_FH/CrossOver" ]; then
    pass "runner folder $RUN_FH"
    check "apd12.dll in runner" test -f "$RUN_FH/CrossOver/lib/wine/x86_64-windows/apd12.dll"
    [ "$(sha "$RUN_FH/CrossOver/lib/wine/x86_64-windows/apd12.dll")" = "$APD12_SHA" ] \
      && pass "apd12.dll is the tested build" || wrn "apd12.dll differs from the tested D3DMetal 4.0b3 build"
    check "apd12.so link resolves to D3DMetal" test -e "$RUN_FH/CrossOver/lib/wine/x86_64-unix/apd12.so"
    n=$(sha "$RUN_FH/CrossOver/lib/wine/x86_64-windows/ntdll.dll")
    if [ "$n" = "$NTDLL_UNWIND_SHA" ]; then wrn "experimental unwind ntdll is installed (off by default; did not fix FHE21)"
    elif [ "$n" = "$NTDLL_STOCK_SHA" ]; then pass "ntdll.dll is the stock one"
    else wrn "ntdll.dll is neither the known stock nor the experimental build"; fi
  else fail "runner copy missing: $RUN_FH (run ./install.sh --plain)"; fi
  check "bridge/wine/$FH_BUILD" test -d "$BP/bridge/wine/$FH_BUILD"
  check "Bridgeplay WineCX 11.17 Steam tool (source of the plain tool)" test -d "$STEAM/compatibilitytools.d/$SRC_TOOL"
  if [ -d "$TOOL" ]; then
    pass "tool folder $TOOLNAME"
    [ "$(cat "$TOOL/build" 2>/dev/null)" = "$FH_BUILD" ] && pass "tool build = $FH_BUILD" || fail "tool build file wrong"
    check "tool run script present" test -x "$TOOL/run"
    grep -q "\"$TOOLNAME\"" "$TOOL/compatibilitytool.vdf" 2>/dev/null \
      && pass "tool registered in compatibilitytool.vdf as $TOOLNAME" || fail "compatibilitytool.vdf does not register $TOOLNAME"
  else fail "tool folder missing: $TOOL"; fi
fi

step "Game config"
if [ -f "$GAMEFIX" ] && grep -q '^DLLOVERRIDES=d3d12=n,b' "$GAMEFIX"; then pass "gamefixes/$APPID.conf has DLLOVERRIDES=d3d12=n,b"
else fail "gamefixes/$APPID.conf missing or without DLLOVERRIDES=d3d12=n,b"; fi
grep -q '^D3DM_ENABLE_METALFX=0' "$GAMEFIX" 2>/dev/null && pass "gamefixes/$APPID.conf has D3DM_ENABLE_METALFX=0" \
  || wrn "gamefixes/$APPID.conf lacks D3DM_ENABLE_METALFX=0 (Apple Neural Engine errors, hang after a resolution change)"

step "Game, prefix, Steam mapping"
if find_library; then
  pass "game library: $LIB"
  [ -f "$GAME/forzahorizon6.exe" ] && pass "forzahorizon6.exe found" || fail "forzahorizon6.exe missing in $GAME"
  [ "$(sha "$GAME/d3d12.dll")" = "$PROXY_SHA" ] && pass "proxy d3d12.dll in the game folder (sha256 $(printf %.8s "$PROXY_SHA")...)" \
    || fail "proxy d3d12.dll missing or different in the game folder"
  if [ -f "$PFX/user.reg" ]; then
    case $(pfx_arch) in
      x86_64)  pass "Wine prefix is x86-64 (Rosetta)" ;;
      aarch64) fail "prefix is the arm64 (FEX) one: this route needs the x86-64 prefix; run ./install.sh to move it aside" ;;
      *)       wrn "prefix architecture unknown" ;;
    esac
    [ -d "$PFXDIR.fex" ] && info "arm64 (FEX) prefix kept as compatdata/$APPID.fex"
    [ -f "$PFX/drive_c/windows/system32/apd12.dll" ] && pass "apd12.dll in prefix system32" || fail "apd12.dll missing in the prefix (run ./install.sh again)"
    grep -q '^"HB_D3D12_REAL"=' "$PFX/user.reg" && pass "HB_D3D12_REAL set in user.reg" || fail "HB_D3D12_REAL missing in user.reg (run ./install.sh again)"
  else wrn "no prefix yet: it is created on the first Play, then run ./install.sh again"; fi
else fail "Forza Horizon 6 ($APPID) not found in any Steam library"; fi
if [ -f "$VDF" ] && python3 -c 'pass' >/dev/null 2>&1; then
  m=$(vdf_compat get "$APPID" 2>/dev/null); rc=$?
  if [ "$rc" = 3 ]; then wrn "Steam config has no CompatToolMapping yet: pick the tool once in the game's Properties"
  elif [ "$m" = "$MGF_TOOLNAME" ] && [ "$HAS_MGF" = 1 ]; then pass "Steam maps app $APPID to $MGF_TOOLNAME"
  elif [ "$m" = "$TOOLNAME" ] && [ "$HAS_PLAIN" = 1 ]; then pass "Steam maps app $APPID to $TOOLNAME (plain route)"
  else fail "Steam maps app $APPID to '${m:-nothing}' (expected the installed route's tool: $MGF_TOOLNAME, or $TOOLNAME with --plain); run ./install.sh"; fi
else wrn "could not read Steam's config.vdf"; fi

step "Logs"
info "Launcher log: $BP/launchers/$APPID/bridgeplay-wine.log"
[ -n "${PFXDIR:-}" ] && info "Run log:      $PFXDIR/bridgeplay-run.log"
info "Install state: $STATE"

printf '\n'
if [ "$FAILS" -eq 0 ]; then
  printf '%s%sAll checks passed%s (%s warning(s)).\n' "$C_G" "$C_B" "$C_N" "$WARNS"
else
  printf '%s%s%s check(s) FAILED%s (%s warning(s)). Run ./install.sh to repair.\n' "$C_R" "$C_B" "$FAILS" "$C_N" "$WARNS"
  exit 1
fi
