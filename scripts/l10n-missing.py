#!/usr/bin/env python3
"""List strings extracted by the last build that are missing from Shared/Localizable.xcstrings.

Run after an xcodebuild with -derivedDataPath build:  python3 -I scripts/l10n-missing.py
"""
import glob, json, re
cat = json.load(open("Shared/Localizable.xcstrings"))["strings"]
found = set()
for f in glob.glob("build/**/*.stringsdata", recursive=True):
    for entries in json.load(open(f)).get("tables", {}).values():
        found.update(e["key"] for e in entries)
missing = sorted(k for k in found - set(cat) if re.search(r"[A-Za-z]{2,}", k.replace("%lld", "").replace("%@", "")))
print("\n".join(missing) if missing else "catalog complete")
