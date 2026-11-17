# ws2_32 network fix, x86-64 build (online play on the Rosetta route)

A small `ws2_32.dll` proxy that lets Forza Horizon 6 join online sessions. Wine does not implement
`SIO_UDP_NETRESET`, and macOS refuses IPv4-level socket options on the game's dual-stack IPv6 UDP socket (port 3074).
The proxy reports those calls as successful, as Windows does. Everything else is forwarded to a renamed copy of the
runner's own `ws2_32.dll` (`ws2_o.dll`).

This is the x86-64 build for the Rosetta route. The arm64 build for the FEX route is on the `main` branch.

- Prebuilt: `../../bin/ws2_32-fh6-x86.dll` (sha256 in `../../bin/SHA256SUMS`), 134 exports, tested online 2026-11-17.
- `fh6-netfix.c`: source. Its header comment still says "FEX route"; the code is identical, only the target differs
  (`x86_64-w64-mingw32-clang`, see `build-fh6-netfix.sh`).
- `fh6-vs-upstream.diff`: our changes against `fh5-netfix.c.upstream` (MacGameFix commit `881f3a96`).
- `ws2_32.def`: export list, made by the build script from the runner's x86-64 `ws2_32.dll`. It must match that file.
- `pe.py`: PE export reader used by the build script.

## Build

Needs Docker and `python3`; nothing is installed on the host. On a Mac with Colima, keep the folder under your home
directory so Docker can see it.

```sh
IMAGE=mstorsjo/llvm-mingw:20261020 bash build-fh6-netfix.sh \
  "$HOME/Library/Application Support/bridgeplay/runners/<runner>/CrossOver/lib/wine/x86_64-windows/ws2_32.dll" out.dll
```

A rebuild matches the 134 exports but is not byte-identical to the prebuilt file (we got sha256 `184725db...`), so use
the prebuilt file for the hash-checked install. Not covered by `./install.sh`: see "Online play" in the main README.

## Credits

[MathiasKowoll/MacGameFix](https://github.com/MathiasKowoll/MacGameFix) `fixes/fh5-netfix.c` and build scripts
(GPL-3.0, commit `881f3a96`), from [xvferxedd/fh5-d3dmetal-fix](https://github.com/xvferxedd/fh5-d3dmetal-fix)
(`ebd20dbe`) and [Andytizer/fh5-crossover-steam-fix](https://github.com/Andytizer/fh5-crossover-steam-fix) v1.0.1.
Our FH6 changes: `fh6-vs-upstream.diff`. License: GPL-3.0, see `../../LICENSE`.
