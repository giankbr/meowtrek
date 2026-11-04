#!/usr/bin/env python3
"""Copy illustrator PNGs into Shared/Art.xcassets as image sets.

Usage: python3 -I scripts/import-art.py <folder-with-pngs>
Files must be named exactly as in docs/art/asset-list.csv (e.g. top_hat.png, cat_fur_ginger.png).
"""
import csv, json, shutil, sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent
catalog = root / "Shared" / "Art.xcassets"
expected = {row[0] for row in list(csv.reader(open(root / "docs/art/asset-list.csv")))[1:]}

src = Path(sys.argv[1]) if len(sys.argv) > 1 else sys.exit(__doc__)
added, unknown = 0, []
for png in sorted(src.glob("*.png")):
    if png.name not in expected:
        unknown.append(png.name)
        continue
    name = png.stem
    s = catalog / f"{name}.imageset"
    s.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(png, s / png.name)
    json.dump({"images": [{"filename": png.name, "idiom": "universal"}],
               "info": {"author": "xcode", "version": 1},
               "properties": {"preserves-vector-representation": False}}, open(s / "Contents.json", "w"), indent=1)
    added += 1

have = {p.name.removesuffix(".imageset") + ".png" for p in catalog.glob("*.imageset")}
print(f"imported {added}; catalog now has {len(have)}/{len(expected)} assets")
if unknown: print("skipped (name not in asset list):", ", ".join(unknown))
missing = sorted(expected - have)
if missing: print(f"still missing {len(missing)}:", ", ".join(missing[:20]) + (" …" if len(missing) > 20 else ""))
