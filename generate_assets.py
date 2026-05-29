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

def make_launch(size: int = 2732) -> Image.Image:
    """Creates the universal launch storyboard image (centred logo, ~28% width)."""
    img = Image.new("RGBA", (size, size), TOMATO)
    logo_size = int(size * 0.28)
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

# ── Launch image ──────────────────────────────────────────────────────────────
launch_img = make_launch(2732)
launch_path = os.path.join(LAUNCH_DIR, "LaunchImage.png")
launch_img.save(launch_path)
print(f"  launch image 2732×2732 → LaunchImage.png")

launch_contents = """{
  "images" : [
    {
      "filename" : "LaunchImage.png",
      "idiom" : "universal",
      "scale" : "1x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
"""
with open(os.path.join(LAUNCH_DIR, "Contents.json"), "w") as f:
    f.write(launch_contents)
print("  LaunchImage Contents.json written")
print("Done.")
