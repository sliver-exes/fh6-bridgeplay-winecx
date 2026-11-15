# winecoreaudio spatial mixer (dialogue fix)

Forza Horizon 6 opens a 12-channel (7.1.4) spatial-audio bed. The Highball engine r3 audio driver sets up 12 channels but nothing mixes them
down, so only front left/right are heard and the centre channel, which carries voices and dialogue, is silent.

Highball engine r5 contains patch 0057, a spatial mixer that folds the bed into your speakers or headphones (12-channel stream
rendered through `AUSpatialMixer`; Highball [PR #313](https://github.com/gauthierpiarrette/highball/pull/313) by TxCsOffc). r3 and r5 are the
same Wine 11.18 with the same driver interface, so r5's `winecoreaudio.so` is a drop-in. This repo ships that one file, unmodified
(LGPL-2.1+): `bin/winecoreaudio-hb-r5.so`, sha256 `03adf57cf363677a9a454bef9eb36fd94b6b04bc0c9d910466f2902434e7cde9`.
We ship it rather than make you download the 400 MB r5 engine for one file.

## Check it against the release

The file is `lib/wine/aarch64-unix/winecoreaudio.so` inside the Highball engine r5 release
`engine-arm64-wine-11.18-20261108T132317Z-spatial-0056-0057` ([highball-engine](https://github.com/gauthierpiarrette/highball-engine/releases)),
whose tarball has sha256 `6721b1f4ee2665283f7c16e4e0b3cf5737c454399fac3d74657fde181d148f33`:

    # (the path inside the tarball may differ: list it with tar tzf)
    tar xzf engine-arm64-wine-11.18-...-spatial-0056-0057.tar.gz engine/lib/wine/aarch64-unix/winecoreaudio.so
    shasum -a 256 engine/lib/wine/aarch64-unix/winecoreaudio.so      # 03adf57c...

Source: Wine tag `wine-11.18`, `dlls/winecoreaudio.drv/coreaudio.c`, plus the patches in highball-engine `patches-arm64/` (0056, 0057).
Side/back speaker placement (patch 0056, in r5's `mmdevapi.dll`) is not applied; it does not affect dialogue.

Install and undo: Step 4 in the main README. With the driver in place Wine logs `12-channel stream ... rendered by AUSpatialMixer`.
