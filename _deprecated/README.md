# Deprecated tuning files

These files were removed on 2026-08-29 because **none of them had any effect**.
They are kept here only for reference; nothing loads them.

## `rv_prefs_NVIDIA_RTX3060`, `rv_prefs_AMD_RX5700`, `rv_prefs_IntelUHD770_noGPU`

Flat `key=value` files using invented key names. RV stores preferences through
Qt's `QSettings` in **INI format with groups**, and it silently ignores keys it
does not recognise. Every key in these files matched zero occurrences in the
source tree:

| Key used | Occurrences in `src/` |
| --- | --- |
| `threading.numThreads` | 0 |
| `cache.lookAheadCacheSize` | 0 |
| `exr.numScanlineThreads` | 0 |
| `movie.hwaccel` | 0 |
| `dpx.readThreads` | 0 |
| `display.uploadThreads` | 0 |
| `ocio.cacheAllLUTs` | 0 |
| `audio.preloadSeconds` | 0 |

The real names are in `src/lib/app/RvCommon/RvPreferences.cpp` — for example
`readerThreads`, `lookAheadCacheSize64New`, `regionCacheSize64New`,
`bufferWait`, `maxBitDepth`, `useThreadedUpload3`.

`movie.hwaccel` deserves a specific note: it could never have worked. The only
hardware-decode path in OpenRV is VideoToolbox on Apple silicon, guarded by
`RV_FFMPEG_USE_VIDEOTOOLBOX` and limited to ProRes
(`src/lib/image/MovieFFMpeg/MovieFFMpeg.cpp:1419`). FFmpeg is configured with
`--disable-vaapi` and no `--enable-nvdec` / `--enable-cuda` / `--enable-d3d11va`,
so on Windows every frame is decoded on the CPU regardless of this setting.

Replaced by: **`optimize/Install-PixrockPrefs.ps1`**

## `Install-RVPrefs.ps1`

Deployed the above files to `%APPDATA%\RV\rv_prefs`. That is the wrong location
twice over — wrong filename and wrong directory. RV reads
`%APPDATA%\ASWF\OpenRV.ini`, built from `RV_INTERNAL_ORGANIZATION_NAME` /
`RV_INTERNAL_APPLICATION_NAME` in `CMakeLists.txt`. `%APPDATA%\RV\` is used for
support files (Mu, Packages, Profiles), never for preferences.

## `rv_cache_prewarm.mu`

Would not have compiled. It called three things that do not exist in RV's Mu API:

- `prefetch(int)` — `prefetch` is a C++-only `ImageRenderer` method, never bound
  into Mu. The `-prefetch` command-line flag is an unrelated boolean that
  controls threaded texture upload.
- `registerMinorMode(...)` — zero occurrences in the source tree. Real modes
  subclass `MinorMode` (see `src/plugins/rv-packages/*/`).
- `SourceMediaInfo.mediaType` — not a field of that struct.

The `try { } catch (...)` around the body would not have rescued it either;
these are compile-time failures, not runtime exceptions.

It was also unnecessary. RV's look-ahead cache already fills ahead of the
playhead; sizing it correctly (which the replacement script does) is the
supported way to get the same result.
