#!/usr/bin/env python3
import os, json

ROOT = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.join(ROOT, "TinyFoodTour/Assets.xcassets")

# name -> (r, g, b) 0-1 range, derived from hex
colors = {
    "Tomato":    (0.757, 0.012, 0.012),  # #C20303
    "Burgundy":  (0.490, 0.133, 0.282),  # #7D2248
    "TFTOrange": (0.769, 0.361, 0.165),  # #C45C2A
    "Olive":     (0.306, 0.376, 0.208),  # #4E6035
    "TFTPink":   (0.788, 0.380, 0.478),  # #C9617A
    "Cream":     (0.980, 0.965, 0.925),  # #FAF6EC
    "CreamDark": (0.918, 0.894, 0.812),  # #EAE4CF
    "TFTSlate":  (0.180, 0.239, 0.278),  # #2E3D47
    "SlateMid":  (0.353, 0.416, 0.459),  # #5A6A75
}

for name, (r, g, b) in colors.items():
    d = os.path.join(ASSETS, f"{name}.colorset")
    os.makedirs(d, exist_ok=True)
    contents = {
        "colors": [{
            "color": {
                "color-space": "srgb",
                "components": {
                    "alpha": "1.0",
                    "red":   f"{r:.3f}",
                    "green": f"{g:.3f}",
                    "blue":  f"{b:.3f}",
                }
            },
            "idiom": "universal"
        }],
        "info": {"author": "xcode", "version": 1}
    }
    with open(os.path.join(d, "Contents.json"), "w") as f:
        json.dump(contents, f, indent=2)
    print(f"  {name}")

print("Done.")
