# Origin of the sources in this folder

Every file here is the source of something shipped in `../bin/`. This repo is GPL-3.0 (see `../LICENSE`).

| File | Origin | License | What we changed |
|---|---|---|---|
| (upstream, not copied here) | [MathiasKowoll/MacGameFix](https://github.com/MathiasKowoll/MacGameFix), `fixes/fh5-netfix.c`, commit `881f3a96`. MacGameFix took it from [xvferxedd/fh5-d3dmetal-fix](https://github.com/xvferxedd/fh5-d3dmetal-fix) (commit `ebd20dbe`), which builds on [Andytizer/fh5-crossover-steam-fix](https://github.com/Andytizer/fh5-crossover-steam-fix) v1.0.1 | GPL-3.0 | Not stored in this repo; fetch `fixes/fh5-netfix.c` at that commit to reproduce the diff below |
| `fh6-netfix.c` | Derived from upstream `fixes/fh5-netfix.c` | GPL-3.0 | Our FH6 changes: `IPPROTO_IP` failures masked only on tracked UDP `AF_INET6`/`AF_UNSPEC` sockets; the IPv6 equivalent is applied first (`IP_TTL` -> `IPV6_UNICAST_HOPS`, `IP_DONTFRAGMENT` -> `IPV6_DONTFRAG`, multicast TTL/loop, `IP_TOS` -> `IPV6_TCLASS`); `WSAEOPNOTSUPP` also counts as maskable; socket-family tracking; log file `fh6-netfix.log`; Docker build. Builds `../bin/ws2_32-fh6.dll` |
| `fh6-vs-upstream.diff` | Ours | GPL-3.0 | The exact diff upstream `fh5-netfix.c` (MacGameFix commit `881f3a96`) -> `fh6-netfix.c` |
| `ec_detour.s` | Ours, a port of the `detour64-fex` steamclient64 hook of [Bridgeplay](https://github.com/raymondchins/Bridgeplay) (raymondchins, GPL-3.0) to the ARM64EC view of Wine's `ntdll.dll` | GPL-3.0 | Assembled with `clang --target=aarch64`; its bytes are embedded in `../tools/ntdll-steam-detour/patch_ntdll.py`, which writes `../bin/ntdll-FH-fex.dll` |

`../bin/run` is not generated from a source here: it is Bridgeplay's `run` script of the `bridgeplay-proton-winecx-11.17` tool
(Bridgeplay 0.7.64, GPL-3.0) with our edits, each marked `# FH-fex:`. The complete diff is `../docs/run-fex.patch`.
`../bin/pe.pl` is from Andytizer/fh5-crossover-steam-fix (via MacGameFix `fixes/pe.pl`), GPL-3.0, unchanged.
Per-binary details and hashes: `../bin/CREDITS.md`.
