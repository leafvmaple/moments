"""
MOV → animated WebP for iPhone Live Photos.

Detects loop point in padded Photos exports (e.g. 10s = original 3s × 3 loops)
and trims to one clean cycle. Outputs animated WebP suitable for embedding in
markdown as a regular <img> — works with medium-zoom out of the box.

Usage:
    python _mov_to_webp.py file.MOV [file2.MOV ...]
    python _mov_to_webp.py --with-mp4 file.MOV          # also emit file.mp4
    python _mov_to_webp.py --no-loop-detect file.MOV    # skip loop trim
    python _mov_to_webp.py --width 960 file.MOV         # scale (default 1280)

EXIF transfer (separate, run after):
    exiftool -TagsFromFile <static.HEIC> -DateTimeOriginal -GPSLatitude
        -GPSLatitudeRef -GPSLongitude -GPSLongitudeRef -overwrite_original file.webp

Deps: ffmpeg (winget install Gyan.FFmpeg), pillow, imagehash
"""

import subprocess
import sys
import os
import tempfile
import shutil


def _resolve(name):
    p = shutil.which(name)
    if p:
        return p
    fallback = (
        r"C:\Users\Administrator\AppData\Local\Microsoft\WinGet\Packages"
        r"\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe"
        rf"\ffmpeg-8.1.1-full_build\bin\{name}.exe"
    )
    if os.path.exists(fallback):
        return fallback
    raise RuntimeError(f"{name} not found — install via: winget install Gyan.FFmpeg")


FFMPEG = _resolve("ffmpeg")
FFPROBE = _resolve("ffprobe")


def get_duration(path):
    out = subprocess.run(
        [
            FFPROBE, "-v", "error",
            "-show_entries", "format=duration",
            "-of", "default=noprint_wrappers=1:nokey=1",
            path,
        ],
        capture_output=True, text=True,
    )
    return float(out.stdout.strip())


def detect_loop_point(path, min_loop_seconds=1.5, threshold=25):
    """Sample frames at 2fps via ffmpeg, then perceptual-hash each one.
    Returns (seconds_into_video_where_loop_starts, phash_distance) or None.
    """
    from PIL import Image
    import imagehash

    tmpdir = tempfile.mkdtemp(prefix="_loop_")
    try:
        subprocess.run(
            [
                FFMPEG, "-y", "-i", path,
                "-vf", "fps=2,scale=480:-1",
                "-q:v", "4",
                os.path.join(tmpdir, "f_%03d.jpg"),
            ],
            capture_output=True,
        )
        frames = sorted(
            os.path.join(tmpdir, f) for f in os.listdir(tmpdir)
        )
        if len(frames) < 4:
            return None

        ref = imagehash.phash(Image.open(frames[0]), hash_size=16)
        min_idx = int(min_loop_seconds * 2)  # 2 fps → 2 frames per second

        for i in range(min_idx, len(frames)):
            h = imagehash.phash(Image.open(frames[i]), hash_size=16)
            distance = h - ref
            if distance < threshold:
                return i * 0.5, distance
        return None
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)


def convert(src, trim_to=None, want_mp4=False, width=1280):
    base, _ = os.path.splitext(src)
    out_webp = base + ".webp"
    out_mp4 = base + ".mp4" if want_mp4 else None

    trim_args = ["-t", str(trim_to)] if trim_to else []

    subprocess.run(
        [
            FFMPEG, "-y", "-i", src, *trim_args,
            "-vf", f"scale={width}:-1,fps=24",
            "-loop", "0", "-q:v", "70",
            out_webp,
        ],
        capture_output=True,
    )

    if want_mp4:
        subprocess.run(
            [
                FFMPEG, "-y", "-i", src, *trim_args,
                "-vf", f"scale={width}:-1",
                "-c:v", "libx264", "-preset", "slow", "-crf", "23",
                "-movflags", "+faststart", "-an",
                out_mp4,
            ],
            capture_output=True,
        )

    return out_webp, out_mp4


def main():
    args = sys.argv[1:]
    no_loop = "--no-loop-detect" in args
    with_mp4 = "--with-mp4" in args
    width = 1280
    if "--width" in args:
        idx = args.index("--width")
        width = int(args[idx + 1])
        args = args[:idx] + args[idx + 2:]
    files = [a for a in args if not a.startswith("--")]

    if not files:
        print(__doc__)
        sys.exit(1)

    for src in files:
        if not os.path.exists(src):
            print(f"NOT FOUND: {src}")
            continue
        print(f"\n{src}")
        duration = get_duration(src)
        print(f"  duration: {duration:.2f}s")

        trim_to = None
        if not no_loop:
            result = detect_loop_point(src)
            if result:
                trim_to, distance = result
                print(
                    f"  loop detected at {trim_to:.1f}s "
                    f"(phash distance {distance})"
                )
            else:
                print("  no loop detected, using full duration")

        webp, mp4 = convert(src, trim_to=trim_to, want_mp4=with_mp4, width=width)
        size = os.path.getsize(webp) / 1024
        print(f"  -> {os.path.basename(webp)}: {size:.1f} KB")
        if mp4:
            size = os.path.getsize(mp4) / 1024
            print(f"  -> {os.path.basename(mp4)}: {size:.1f} KB")


if __name__ == "__main__":
    main()
