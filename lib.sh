# shellcheck shell=sh disable=SC2034
# Shared helpers for install.sh, uninstall.sh and doctor.sh (main branch, Rosetta route: MGF runner by default,
# plain D3DMetal-proxy route with --plain). Sourced.
#
# Part of fh6-mac-fix, GPL-3.0. Runner/tool layout: Bridgeplay by raymondchins (GPL-3.0,
# https://github.com/raymondchins/Bridgeplay). Proxy: sliver-exes/fh5-d3dmetal-fix (GPL-3.0), built on
# tsshim from Highball by Gauthier Piarrette (GPL-3.0). MGF route: MacGameFix by MathiasKowoll (GPL-3.0,
# https://github.com/MathiasKowoll/MacGameFix, commit 881f3a96) and Highball patch 0057 (TxCsOffc, PR #313).
# See bin/CREDITS.md.

APPID=2483190
BP="$HOME/Library/Application Support/bridgeplay"
STEAM="$HOME/Library/Application Support/Steam"
STATE="$HOME/Library/Application Support/fh6-bridgeplay"
CACHE="$HOME/Library/Caches/fh6-bridgeplay"

SRC_BUILD=winecx-11.17
FH_BUILD=FH-winecx-11.17
SRC_TOOL=bridgeplay-proton-winecx-11.17
TOOLNAME=bridgeplay-proton-fh6-plain
# Names before Bridgeplay's launch-option hook (bridgeplay-proton-* folders only) was found out; install.sh removes them (ours, never stock).
OLD_TOOLNAMES="FH-bridgeplay-proton-winecx-11.17 MGF-bridgeplay-proton-winecx-11.17"
TOOL_DISPLAY="FH WineCX 11.17 (Forza Horizon, D3DMetal proxy)"
RUN_SRC="$BP/runners/crossover-$SRC_BUILD"
RUN_FH="$BP/runners/crossover-$FH_BUILD"
TOOL="$STEAM/compatibilitytools.d/$TOOLNAME"
GPTK="$BP/gptk/wine"
GAMEFIX="$BP/gamefixes/$APPID.conf"
VDF="$STEAM/config/config.vdf"

# MGF route (default): a second runner cloned from RUN_FH plus its own Steam tool.
MGF_BUILD=MGF-winecx-11.17
MGF_TOOLNAME=bridgeplay-proton-fh6-mgf
MGF_TOOL_DISPLAY="MGF WineCX 11.17 (FH6, MacGameFix exception chain)"
RUN_MGF="$BP/runners/crossover-$MGF_BUILD"
MGF_TOOL="$STEAM/compatibilitytools.d/$MGF_TOOLNAME"
MGF_BRIDGE="$BP/bridge/wine/$MGF_BUILD"
MGF_WINE="$RUN_MGF/CrossOver/lib/wine"
# bin/ntdll-MGF-winecx.dll: MacGameFix 41073 ntdll + our Bridgeplay Steam detour call + RtlVirtualUnwind2 fix.
MGF_NTDLL_SHA=840c31ccda0d036de26e520946c276f1acb9032b93024b6c40b65faf0bbbbfe7
# bin/winecoreaudio-MGF-x64.so: Wine 11.17 + Highball patch 0057 (dialogue fix).
MGF_WCA_SHA=6af37a791598d081ee7a9f3dbfb9b9e21ba8c699ff66050ef61aed9781082dbb
# bin/mgf/notproton-rosetta-trap-boost.dylib: MacGameFix, Developer ID signed.
MGF_BOOST_SHA=ce9dd6b0d23f350529cbc428a8b96c5b99ad7ba548ee750af82636671d118672

# Built files shipped in bin/ (also listed in bin/SHA256SUMS). Proxy: sliver-exes/fh5-d3dmetal-fix @ ebd20db.
PROXY_SHA=c5d48ab9de44e201fc1534a5d1d446055c5a0ecd066c85e1131702d9ad9115f7
APD12_SHA=af5db5201dfc2bb98febecafb69239a99c5b4a6b0bd3b1b0e6b24f2b75cbcbb5
# Experimental ntdll: stock WineCX 11.17 x86_64-windows/ntdll.dll -> unwind-patched.
NTDLL_STOCK_SHA=4573d521671a48212670e7543aa9ebf0921e383dada69477f677f435df2bef5a
NTDLL_UNWIND_SHA=c9e2141448125bae24ad7b53314431288d8422e169b18dfc3c9d9adf6b6515ac

# ---- output ----------------------------------------------------------------------------------
if [ -t 1 ]; then
  C_B=$(printf '\033[1m'); C_G=$(printf '\033[32m'); C_R=$(printf '\033[31m')
  C_Y=$(printf '\033[33m'); C_C=$(printf '\033[36m'); C_N=$(printf '\033[0m')
else
  C_B=""; C_G=""; C_R=""; C_Y=""; C_C=""; C_N=""
fi
step() { printf '\n%s==>%s %s%s%s\n' "$C_C$C_B" "$C_N" "$C_B" "$*" "$C_N"; }
ok()   { printf '  %s✓%s %s\n' "$C_G" "$C_N" "$*"; }
info() { printf '    %s\n' "$*"; }
warn() { printf '  %s!%s %s\n' "$C_Y" "$C_N" "$*" >&2; }
die()  { printf '\n%serror:%s %s\n' "$C_R$C_B" "$C_N" "$*" >&2; exit 1; }

sha() { shasum -a 256 "$1" 2>/dev/null | cut -d' ' -f1; }

# ask "question": 0 = yes. FH_YES=1 (or -y) answers yes; no terminal answers no.
ask() {
  [ "${FH_YES:-0}" = 1 ] && return 0
  [ -t 0 ] || return 1
  printf '  %s?%s %s [y/N] ' "$C_Y" "$C_N" "$1"
  read -r a || return 1
  case $a in y|Y|yes|YES) return 0 ;; esac
  return 1
}

# ---- Steam ---------------------------------------------------------------------------------
steam_running() { pgrep -x steam_osx >/dev/null 2>&1; }

ensure_steam_quit() {
  steam_running || { ok "Steam is not running"; return 0; }
  warn "Steam is running. It must be closed while files and its config change."
  ask "Quit Steam now?" || die "Quit Steam (menu Steam > Quit Steam), then run this again."
  osascript -e 'tell application "Steam" to quit' >/dev/null 2>&1 || true
  i=0
  while steam_running && [ "$i" -lt 40 ]; do sleep 1; i=$((i + 1)); done
  steam_running && die "Steam did not quit within 40 s. Quit it by hand (Steam > Quit Steam), then run this again."
  sleep 2
  ok "Steam closed"
}

# Sets LIB (the steamapps folder with the game), GAME, PFXDIR (compatdata/APPID), PFX. Returns 1 if not found.
find_library() {
  LIB=""
  if [ -f "$STEAM/steamapps/libraryfolders.vdf" ]; then
    while IFS= read -r dir; do
      [ -f "$dir/steamapps/appmanifest_$APPID.acf" ] && { LIB="$dir/steamapps"; break; }
    done <<EOF
$(sed -n 's/^[[:space:]]*"path"[[:space:]]*"\(.*\)"$/\1/p' "$STEAM/steamapps/libraryfolders.vdf")
EOF
  fi
  [ -n "$LIB" ] || return 1
  GAME="$LIB/common/ForzaHorizon6"
  PFXDIR="$LIB/compatdata/$APPID"
  PFX="$PFXDIR/pfx"
  return 0
}

# Machine type of a prefix's ntdll.dll (default: the game's prefix $PFX): aarch64, x86_64, or none.
pfx_arch() {
  f="${1:-$PFX}/drive_c/windows/system32/ntdll.dll"
  [ -f "$f" ] || { echo none; return 0; }
  python3 -I - "$f" <<'PY' 2>/dev/null || echo none
import struct, sys
d = open(sys.argv[1], "rb").read(4096)
m = struct.unpack_from("<H", d, struct.unpack_from("<I", d, 0x3C)[0] + 4)[0]
print({0xAA64: "aarch64", 0x8664: "x86_64"}.get(m, "other"))
PY
}

# vdf_compat get|set|unset APPID [NAME]  (edits Steam's CompatToolMapping; exit 3 = no mapping section)
vdf_compat() {
  python3 -I - "$VDF" "$@" <<'PY'
import os, shutil, sys
path, mode, app = sys.argv[1:4]
name = sys.argv[4] if len(sys.argv) > 4 else ""
L = open(path, encoding="utf-8", errors="surrogateescape").read().split("\n")
q = lambda s: s.strip()
mi = next((i for i, l in enumerate(L) if q(l) == '"CompatToolMapping"'), None)
if mi is None:
    sys.exit(3)
j = mi + 1
while q(L[j]) != "{":
    j += 1
def match(i):                      # index of the "}" that closes the "{" at line i
    d = 0
    while True:
        t = q(L[i])
        if t == "{": d += 1
        elif t == "}":
            d -= 1
            if d == 0: return i
        i += 1
k = match(j)
a = None; d = 0
for i in range(j, k + 1):
    t = q(L[i])
    if t == "{": d += 1
    elif t == "}": d -= 1
    elif d == 1 and t == '"%s"' % app:
        a = i; break
b = match(a + 1) if a is not None else None
cur = None
if a is not None:
    for i in range(a, b):
        if q(L[i]).startswith('"name"'):
            cur = L[i].split('"')[3]
if mode == "get":
    if cur is not None: print(cur)
    sys.exit(0)
if mode == "set":
    if cur == name: print("unchanged"); sys.exit(0)
    ind = L[mi][:len(L[mi]) - len(L[mi].lstrip())] + "\t"
    if a is not None:
        n = next(i for i in range(a, b) if q(L[i]).startswith('"name"'))
        L[n] = L[n].split('"')[0] + '"name"\t\t"%s"' % name
    else:
        L[j + 1:j + 1] = [ind + '"%s"' % app, ind + "{", ind + '\t"name"\t\t"%s"' % name,
                          ind + '\t"config"\t\t""', ind + '\t"priority"\t\t"250"', ind + "}"]
elif mode == "unset":
    if a is None: print("unchanged"); sys.exit(0)
    del L[a:b + 1]
if not os.path.exists(path + ".fh6-orig"):
    shutil.copy2(path, path + ".fh6-orig")
tmp = path + ".fh6-tmp"
open(tmp, "w", encoding="utf-8", errors="surrogateescape").write("\n".join(L))
shutil.copymode(path, tmp)
os.replace(tmp, path)
print("changed")
PY
}

# Download URL to DEST and check sha256. Resumes a partial .part file; shows curl's progress bar.
fetch() {
  url=$1; dest=$2; want=$3
  if [ -f "$dest" ] && [ "$(sha "$dest")" = "$want" ]; then ok "have $(basename "$dest")"; return 0; fi
  mkdir -p "$(dirname "$dest")"
  info "downloading $(basename "$dest")"
  curl -fL -C - --retry 3 --retry-delay 2 --progress-bar -o "$dest.part" "$url" \
    || [ "$(sha "$dest.part")" = "$want" ] \
    || die "download failed: $url (run again to resume)"
  if [ "$(sha "$dest.part")" != "$want" ]; then
    rm -f "$dest.part"
    die "sha256 mismatch for $url (partial file removed, run again)"
  fi
  mv "$dest.part" "$dest"
  ok "verified $(basename "$dest")"
}

# verify_sums DIR SUMSFILE: prints every path that is missing or differs; returns 1 if any.
verify_sums() {
  bad=0
  while read -r h f; do
    [ -n "$h" ] || continue
    if [ ! -e "$1/$f" ] || [ "$(sha "$1/$f")" != "$h" ]; then printf '%s\n' "$f"; bad=1; fi
  done < "$2"
  return $bad
}

# The directory of the running script (works for ./install.sh and sh path/install.sh).
repo_dir() { (cd "$(dirname "$1")" && pwd); }

# first_run_prefix: the game has no Wine prefix yet. Offers to start the game once through Steam (it creates the
# prefix on its first start), waits for compatdata/APPID/pfx/user.reg, waits for the game to be closed, then quits
# Steam. Returns 0 when the prefix exists, 1 when the user declined or it did not appear (install.sh then prints
# the manual steps). The caller has to have set the compatibility tool in Steam's config first.
first_run_prefix() {
  warn "The game has no Wine prefix yet (Steam creates it on the first start of the game)."
  ask "Start Forza Horizon 6 once now so it creates the prefix?" || return 1
  info "Starting Steam and the game. A FH206 dialog may appear: ignore it. Sign in to Steam if it asks."
  open "steam://rungameid/$APPID" || { warn "could not open Steam"; return 1; }
  i=0
  while [ ! -f "$PFX/user.reg" ] && [ "$i" -lt 900 ]; do
    sleep 2; i=$((i + 1))
    [ $((i % 15)) -ne 0 ] || info "waiting for the prefix... ($((i * 2)) s)"
  done
  [ -f "$PFX/user.reg" ] || { warn "the prefix did not appear within 30 minutes"; return 1; }
  ok "prefix created: $PFX"
  info "Now quit the game (the main menu is enough, or close the dialog). I continue when it is closed."
  sleep 10
  i=0
  while pgrep -f wineserver >/dev/null 2>&1 && [ "$i" -lt 600 ]; do
    sleep 3; i=$((i + 1))
    [ $((i % 10)) -ne 0 ] || info "waiting for the game to close... (quit it, then I go on)"
  done
  pgrep -f wineserver >/dev/null 2>&1 && warn "the game is still running; continuing anyway"
  ensure_steam_quit
  return 0
}
