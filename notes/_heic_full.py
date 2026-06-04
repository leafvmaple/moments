"""HEIC → full-quality JPG via pillow-heif.

Use: python _heic_full.py IMG_xxxx [IMG_yyyy ...]  (no .HEIC extension)
Output: _full_<name>.jpg in cwd, original size preserved.
"""
from PIL import Image
import pillow_heif
import sys

pillow_heif.register_heif_opener()
for n in sys.argv[1:]:
    img = Image.open(n + ".HEIC")
    img.save("_full_" + n + ".jpg", quality=92)
    print("full", n, img.size)
