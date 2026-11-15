#!/bin/sh
# Undoes ./install.sh (main branch): removes whichever route is installed (the MGF runner copy, bridge folder and Steam
# tool, or the plain FH WineCX ones), the proxy d3d12.dll in the game folder and the prefix additions, and restores Steam's previous tool
# choice for Forza Horizon 6. If install moved an arm64 (FEX) prefix aside, it is put back (the Rosetta prefix
# is kept as compatdata/2483190.rosetta); nothing is ever deleted from a prefix.
# Stock Bridgeplay runners, game files and saves are not touched.
#
# fh6-mac-fix, sliver-exes, GPL-3.0. Credits: see README.md and bin/CREDITS.md
# (MacGameFix, Highball, Bridgeplay, fh5-d3dmetal-fix, Wine/CodeWeavers).
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=lib.sh
. "$HERE/lib.sh"

FH_YES=0
for a in "$@"; do
  case $a in
    -y|--yes) FH_YES=1 ;;
    -h|--help) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown option $a (try --help)" ;;
  esac
done
export FH_YES

step "Steam"
ensure_steam_quit

step "Removing files"
for d in "$RUN_MGF" "$MGF_BRIDGE" "$MGF_TOOL" "$RUN_FH" "$BP/bridge/wine/$FH_BUILD" "$TOOL"; do
  if [ -e "$d" ]; then rm -rf "$d"; ok "removed ${d#"$HOME/Library/Application Support/"}"; fi
done
for n in $OLD_TOOLNAMES; do
  d="$STEAM/compatibilitytools.d/$n"
  if [ -e "$d" ]; then rm -rf "$d"; ok "removed old tool folder $n"; fi
done
rm -rf "$RUN_MGF.partial"
ok "runner copies, bridge folders and Steam tools of ours are gone (stock Bridgeplay files untouched)"
if [ -f "$GAMEFIX" ] && grep -q 'load the d3d12 proxy from the game folder' "$GAMEFIX"; then
  rm -f "$GAMEFIX"; ok "gamefixes/$APPID.conf removed"
fi

if find_library; then
  if [ -f "$GAME/d3d12.dll" ] && [ "$(sha "$GAME/d3d12.dll")" = "$PROXY_SHA" ]; then
    rm -f "$GAME/d3d12.dll"; ok "proxy d3d12.dll removed from the game folder"
  fi
  rm -f "$PFX/drive_c/windows/system32/apd12.dll"
  if [ -f "$PFX/user.reg" ]; then
    sed -i '' '/^"HB_D3D12_REAL"=/d' "$PFX/user.reg"
    rm -f "$PFX/user.reg.fh6-orig"
    ok "prefix additions removed"
  fi
else
  info "game not found in any Steam library; nothing to clean there"
fi

step "Wine prefix"
if find_library && [ -f "$STATE/moved-fex" ] && [ -e "$PFXDIR.fex" ] && [ "$(pfx_arch "$PFXDIR.fex/pfx")" = aarch64 ]; then
  if [ -e "$PFXDIR" ]; then
    dest="$PFXDIR.rosetta"
    [ ! -e "$dest" ] || dest="$PFXDIR.rosetta.$(date +%Y%m%d%H%M%S)"
    mv "$PFXDIR" "$dest"
    ok "Rosetta prefix kept as $(basename "$dest")"
  fi
  mv "$PFXDIR.fex" "$PFXDIR"
  ok "arm64 (FEX) prefix restored to compatdata/$APPID"
else
  ok "no moved FEX prefix to restore; the current prefix is left alone"
fi

step "Steam compatibility tool"
if [ -f "$VDF" ] && python3 -c 'pass' >/dev/null 2>&1; then
  prev=""
  [ -f "$STATE/prev-compat-tool" ] && prev=$(cat "$STATE/prev-compat-tool")
  [ "$prev" != "$TOOLNAME" ] && [ "$prev" != "$MGF_TOOLNAME" ] || prev=""
  case " $OLD_TOOLNAMES " in *" $prev "*) prev="" ;; esac
  cur=$(vdf_compat get "$APPID" 2>/dev/null || true)
  case " $OLD_TOOLNAMES " in *" $cur "*) cur=$TOOLNAME ;; esac
  if [ "$cur" = "$TOOLNAME" ] || [ "$cur" = "$MGF_TOOLNAME" ] || [ -z "$cur" ]; then
    if [ -n "$prev" ]; then
      vdf_compat set "$APPID" "$prev" >/dev/null && ok "Forza Horizon 6 compatibility tool set back to $prev"
    else
      vdf_compat unset "$APPID" >/dev/null && ok "Forza Horizon 6 compatibility tool choice cleared"
    fi
  else
    ok "Steam uses '$cur' for the game, not our tool; left as it is"
  fi
else
  warn "Could not edit Steam's config. In Steam: Forza Horizon 6 > Properties > Compatibility, pick WineCX 11.17."
fi

rm -rf "$STATE"
printf '\n%s%sDone.%s If Steam still shows a tool for Forza Horizon 6, set it back to WineCX 11.17.\n' "$C_G" "$C_B" "$C_N"
info "Steam's config backup from the first install is config/config.vdf.fh6-orig."
