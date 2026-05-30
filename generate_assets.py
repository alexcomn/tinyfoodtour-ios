#!/usr/bin/env python3
"""
Generates iOS app icon set and launch image.

App icon:  Tomato (#F90606) background + clean "tft" wordmark in white.
           Photo-crop approach was muddy at small sizes; flat text scales to any size.
Launch:    Same tomato bg + centred splash-logo.png at 65% width (three scale variants).
"""
import os
from PIL import Image, ImageDraw, ImageFont

ROOT        = os.path.dirname(os.path.abspath(__file__))
LOGO_SRC    = os.path.join(ROOT, "../tiny-food-tour/src/assets/splash-logo.png")
ICON_DIR    = os.path.join(ROOT, "TinyFoodTour/Assets.xcassets/AppIcon.appiconset")
LAUNCH_DIR  = os.path.join(ROOT, "TinyFoodTour/Assets.xcassets/LaunchImage.imageset")
TOMATO      = (249, 6, 6, 255)   # #F90606

os.makedirs(ICON_DIR,   exist_ok=True)
os.makedirs(LAUNCH_DIR, exist_ok=True)

# ── App icon: flat "tft" text on tomato ───────────────────────────────────────
# "tft" (lowercase, white) with wide letter-spacing on a solid Tomato tile.
# Looks crisp at every size from 20px to 1024px.

def make_icon_tile(size: int) -> Image.Image:
    tile = Image.new("RGB", (size, size), TOMATO[:3])
    draw = ImageDraw.Draw(tile)

    # Three separate letters spaced manually for clean tracking
    # Use the system sans font if available, else fall back to default
    font_size = max(8, int(size * 0.32))
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", font_size)
    except Exception:
        try:
            font = ImageFont.truetype("/System/Library/Fonts/Arial.ttf", font_size)
        except Exception:
            font = ImageFont.load_default()

    text = "tft"
    # Measure text width to centre it
    bbox = draw.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]

    x = (size - tw) / 2 - bbox[0]
    y = (size - th) / 2 - bbox[1]

    draw.text((x, y), text, fill=(255, 255, 255), font=font)
    return tile

# ── Launch image: centred splash-logo on tomato ───────────────────────────────
logo_src = Image.open(LOGO_SRC).convert("RGBA")

def make_launch(px: int) -> Image.Image:
    """Square canvas, tomato bg, splash-logo centred at 65% width."""
    img = Image.new("RGBA", (px, px), TOMATO)
    logo_size = int(px * 0.65)
    logo = logo_src.copy()
    w, h = logo.size
    crop_h = w
    top = (h - crop_h) // 2
    logo = logo.crop((0, top, w, top + crop_h))
    logo = logo.resize((logo_size, logo_size), Image.LANCZOS)
    x = (px - logo_size) // 2
    y = (px - logo_size) // 2
    img.paste(logo, (x, y), logo)
    return img.convert("RGB")

# ── Generate icon sizes ───────────────────────────────────────────────────────
icon_specs = [
    (20, 2), (20, 3),
    (29, 2), (29, 3),
    (40, 2), (40, 3),
    (60, 2), (60, 3),
    (20, 1), (29, 1),
    (40, 1), (76, 1), (76, 2),
    (83, 2),    # 83.5@2x = 167px
    (1024, 1),
]

image_entries = []
seen = set()
for pts, scale in icon_specs:
    px = 167 if pts == 83 else pts * scale
    if px in seen:
        continue
    seen.add(px)
    fname = f"Icon-{px}.png"
    make_icon_tile(px).save(os.path.join(ICON_DIR, fname))
    image_entries.append((pts, scale, fname))
    print(f"  icon {px}px — {fname}")

# Contents.json
imgs_json = ""
for pts, scale, fname in image_entries:
    pt_str = "83.5" if pts == 83 else str(pts)
    imgs_json += f'    {{\n      "filename" : "{fname}",\n      "idiom" : "universal",\n      "platform" : "ios",\n      "size" : "{pt_str}x{pt_str}",\n      "scale" : "{scale}x"\n    }},\n'
imgs_json = imgs_json.rstrip(",\n")
with open(os.path.join(ICON_DIR, "Contents.json"), "w") as f:
    f.write(f'{{\n  "images" : [\n{imgs_json}\n  ],\n  "info" : {{\n    "author" : "xcode",\n    "version" : 1\n  }}\n}}\n')
print("  AppIcon Contents.json written")

# ── Generate launch image (3 scale variants) ──────────────────────────────────
LAUNCH_PT = 375
launch_scales = [(1, LAUNCH_PT), (2, LAUNCH_PT * 2), (3, LAUNCH_PT * 3)]
launch_images = []
for scale, px in launch_scales:
    fname = f"LaunchImage{'@' + str(scale) + 'x' if scale > 1 else ''}.png"
    make_launch(px).save(os.path.join(LAUNCH_DIR, fname))
    launch_images.append((scale, fname))
    print(f"  launch {px}×{px}px @{scale}x → {fname}")

launch_json = '{\n  "images" : [\n'
for scale, fname in launch_images:
    launch_json += f'    {{\n      "filename" : "{fname}",\n      "idiom" : "universal",\n      "scale" : "{scale}x"\n    }},\n'
launch_json = launch_json.rstrip(",\n") + "\n  ],\n"
launch_json += '  "info" : {\n    "author" : "xcode",\n    "version" : 1\n  }\n}\n'
with open(os.path.join(LAUNCH_DIR, "Contents.json"), "w") as f:
    f.write(launch_json)
print("  LaunchImage Contents.json written")
print("Done.")
