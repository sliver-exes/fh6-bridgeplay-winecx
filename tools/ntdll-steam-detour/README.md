# ntdll steam detour (ARM64EC port)

Bridgeplay makes Steam's `steamclient64.dll` load by detouring a function inside Wine's `ntdll.dll`. The stock Highball arm64 engine r3
has no such detour, so `patch_ntdll.py` writes one into the ARM64EC view of its `aarch64-windows/ntdll.dll`.

`bin/ntdll-FH-fex.dll` is the result. You do not have to run the script; run it to check the shipped file or to rebuild it.

    python3 -I tools/ntdll-steam-detour/patch_ntdll.py STOCK_NTDLL OUT_NTDLL

- Input must be the stock r3 `ntdll.dll`, sha256 `77904aabc9286200ac48a187e7a7dc2f9a4d1dd9ddeaea2c6ca1a66ec8711a44` (the script asserts it).
- Output is `52416b5bfa5d6e1c3a895c26cb01fca031dae4084bd4192fcdd7701581d057aa` (asserted; equals `bin/ntdll-FH-fex.dll`).
- Two edits: 4 bytes at RVA `0x97724` (`ldr x8,[sp,#0x60]` -> `b 0x1800e0c00`) and 812 bytes of detour code in the zero padding at RVA `0xE0C00`.
- The detour source is `src/ec_detour.s` (assembled with `clang --target=aarch64`; the bytes are embedded in the script).

The same file is installed twice: as the runner's `aarch64-windows/ntdll.dll` and as `bridgeplay/bridge/wine/FH-fex/aarch64-windows/ntdll.dll`.

Credit: the detour logic is [Bridgeplay](https://github.com/raymondchins/Bridgeplay)'s `detour64-fex` (raymondchins, GPL-3.0); Wine
(LGPL-2.1+) and the engine build are by the Wine project and Highball (Gauthier Piarrette). Our change: the ARM64EC port.
