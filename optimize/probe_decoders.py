"""Report which FFmpeg decoders were actually compiled into a build.

Usage:  python probe_decoders.py <path-to-bin-dir>

Asks libavcodec directly via avcodec_find_decoder_by_name() instead of
searching the DLL for codec names. String matching is unreliable in both
directions here:

  - False positives: FFmpeg's codec descriptor table lists every codec it
    knows about whether or not the decoder was built, and MOV FourCC tables
    carry names like "apch"/"apcn" regardless.
  - False negatives: encoder symbols such as "prores_ks" are present while
    the decoder may not be, and decoder log strings move between releases.

Exits non-zero if any decoder in REQUIRED is missing, so CI fails loudly
rather than shipping a build that cannot open the studio's dailies.
"""

import ctypes
import os
import sys

# Codecs the build is expected to handle. ProRes and DNxHD are the ones that
# matter for review work; the rest are baseline.
REQUIRED = ["prores", "h264", "hevc", "aac"]
OPTIONAL = ["dnxhd", "ac3", "mpeg4", "mpeg2video", "mjpeg", "vp9", "dvvideo", "qtrle"]


def main():
    if len(sys.argv) < 2:
        print("usage: probe_decoders.py <bin-dir>", file=sys.stderr)
        return 2

    bindir = os.path.abspath(sys.argv[1])
    if not os.path.isdir(bindir):
        print("not a directory: %s" % bindir, file=sys.stderr)
        return 2

    # The avcodec DLL pulls in avutil/swresample from the same folder.
    if hasattr(os, "add_dll_directory"):
        os.add_dll_directory(bindir)

    candidates = [f for f in os.listdir(bindir) if f.startswith("avcodec")]
    if not candidates:
        print("no avcodec library found in %s" % bindir, file=sys.stderr)
        return 1

    av = ctypes.CDLL(os.path.join(bindir, candidates[0]))
    av.avcodec_find_decoder_by_name.restype = ctypes.c_void_p
    av.avcodec_find_decoder_by_name.argtypes = [ctypes.c_char_p]
    av.avcodec_version.restype = ctypes.c_uint

    v = av.avcodec_version()
    print("%s  (avcodec %d.%d.%d)" % (candidates[0], v >> 16, (v >> 8) & 0xFF, v & 0xFF))
    print()

    def has(name):
        return bool(av.avcodec_find_decoder_by_name(name.encode()))

    missing_required = []

    print("  required:")
    for name in REQUIRED:
        ok = has(name)
        print("    %-12s %s" % (name, "yes" if ok else "MISSING"))
        if not ok:
            missing_required.append(name)

    print("  optional:")
    for name in OPTIONAL:
        print("    %-12s %s" % (name, "yes" if has(name) else "no"))

    if missing_required:
        print()
        print("FAIL: required decoders missing: %s" % ", ".join(missing_required))
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
