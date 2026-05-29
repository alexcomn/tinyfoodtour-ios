#!/usr/bin/env python3
"""
Generates iOS app icon set and launch image from splash-logo.png.

App icon: tomato red (#C20303) background, centred logo at ~55% of tile.
Launch image: same treatment at 2732×2732 (universal iPad/iPhone storyboard).
"""
import os, math
from PIL import Image, ImageDraw

ROOT        = os.path.dirname(os.path.abspath(__file__))
LOGO_SRC    = os.path.join(ROOT, "../tiny-food-tour/src/assets/splash-logo.png")
ICON_DIR    = os.path.join(ROOT, "TinyFoodTour/Assets.xcassets/AppIcon.appiconset")
LAUNCH_DIR  = os.path.join(ROOT, "TinyFoodTour/Assets.xcassets/LaunchImage.imageset")
TOMATO      = (249, 6, 6, 255)   # #F90606 — matches Splash.tsx bg-tomato (HSL 0 96% 50%)

os.makedirs(ICON_DIR,   exist_ok=True)
os.makedirs(LAUNCH_DIR, exist_ok=True)

logo_src = Image.open(LOGO_SRC).convert("RGBA")

# ── Helpers ───────────────────────────────────────────────────────────────────
def make_tile(size: int, logo_fraction: float = 0.55) -> Image.Image:
    """Creates a square tile with tomato bg and centred logo."""
    tile = Image.new("RGBA", (size, size), TOMATO)
    logo_size = int(size * logo_fraction)
    logo = logo_src.copy()
    # The source is portrait (1080×1920); crop to the central square third
    # (the logo mark lives in the middle third vertically)
    w, h = logo.size
    crop_h = w  # square crop
    top = (h - crop_h) // 2
    logo = logo.crop((0, top, w, top + crop_h))
    logo = logo.resize((logo_size, logo_size), Image.LANCZOS)
    x = (size - logo_size) // 2
    y = (size - logo_size) // 2
    tile.paste(logo, (x, y), logo)
    return tile.convert("RGB")

def make_launch(size: int = 375) -> Image.Image:
    """Creates a square launch image (centred logo, ~65% of canvas width).
    UILaunchScreen centers this on the Tomato background color."""
    img = Image.new("RGBA", (size, size), TOMATO)
    logo_size = int(size * 0.65)
    logo = logo_src.copy()
    w, h = logo.size
    crop_h = w
    top = (h - crop_h) // 2
    logo = logo.crop((0, top, w, top + crop_h))
    logo = logo.resize((logo_size, logo_size), Image.LANCZOS)
    x = (size - logo_size) // 2
    y = (size - logo_size) // 2
    img.paste(logo, (x, y), logo)
    return img.convert("RGB")

# ── App icon sizes required by Xcode ─────────────────────────────────────────
# (points, scale) → filename
icon_specs = [
    # iPhone notifications
    (20, 2), (20, 3),
    # iPhone settings / Spotlight
    (29, 2), (29, 3),
    # Spotlight
    (40, 2), (40, 3),
    # iPhone app
    (60, 2), (60, 3),
    # iPad notifications
    (20, 1), (20, 2),
    # iPad settings
    (29, 1), (29, 2),
    # iPad spotlight
    (40, 1), (40, 2),
    # iPad app
    (76, 1), (76, 2),
    # iPad Pro app
    (83, 2),   # 83.5 → 167px
    # App Store
    (1024, 1),
]

image_entries = []
seen = set()
for pts, scale in icon_specs:
    px = pts * scale
    if pts == 83:
        px = 167  # 83.5@2x
    if px in seen:
        continue
    seen.add(px)
    filename = f"Icon-{px}.png"
    tile = make_tile(px)
    tile.save(os.path.join(ICON_DIR, filename))
    print(f"  icon {px}×{px} → {filename}")
    image_entries.append((pts, scale, filename))

# ── AppIcon Contents.json ─────────────────────────────────────────────────────
def scale_str(s): return f"{s}x"

images_json = ""
for pts, scale, fname in image_entries:
    pt_str = "83.5" if pts == 83 else str(pts)
    images_json += f"""    {{
      "filename" : "{fname}",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "{pt_str}x{pt_str}",
      "scale" : "{scale}x"
    }},\n"""

# Also add required 1024 App Store entry without scale key
images_json = images_json.rstrip(",\n")

contents = f"""{{
  "images" : [
{images_json}
  ],
  "info" : {{
    "author" : "xcode",
    "version" : 1
  }}
}}
"""
with open(os.path.join(ICON_DIR, "Contents.json"), "w") as f:
    f.write(contents)
print("  AppIcon Contents.json written")

# ── Launch image — three scale variants ──────────────────────────────────────
# Target display size: 375×375pt (fits within any iPhone width).
# The UILaunchScreen UIColorName provides the full-bleed Tomato background;
# this image sits centered on top of it.
# Logo at 65% of canvas = ~244pt wide = ~63% of a 390pt screen.
LAUNCH_PT = 375  # logical points

launch_scales = [(1, LAUNCH_PT), (2, LAUNCH_PT * 2), (3, LAUNCH_PT * 3)]
launch_images = []
for scale, px in launch_scales:
    fname = f"LaunchImage{'@' + str(scale) + 'x' if scale > 1 else ''}.png"
    img = make_launch(px)
    img.save(os.path.join(LAUNCH_DIR, fname))
    launch_images.append((scale, fname))
    print(f"  launch image {px}×{px}px @{scale}x → {fname}")

launch_contents = '{\n  "images" : [\n'
for scale, fname in launch_images:
    launch_contents += f'    {{\n      "filename" : "{fname}",\n      "idiom" : "universal",\n      "scale" : "{scale}x"\n    }},\n'
launch_contents = launch_contents.rstrip(",\n") + "\n  ],\n"
launch_contents += '  "info" : {\n    "author" : "xcode",\n    "version" : 1\n  }\n}\n'

with open(os.path.join(LAUNCH_DIR, "Contents.json"), "w") as f:
    f.write(launch_contents)
print("  LaunchImage Contents.json written")
print("Done.")
