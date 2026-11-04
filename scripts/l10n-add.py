#!/usr/bin/env python3
"""Add Indonesian translations to Shared/Localizable.xcstrings from a JSON object {english: indonesian}.

Usage: python3 -I scripts/l10n-add.py '{"Hello": "Halo"}'
"""
import json, sys
p = "Shared/Localizable.xcstrings"
cat = json.load(open(p))
for k, v in json.loads(sys.argv[1]).items():
    cat["strings"][k] = {"localizations": {"id": {"stringUnit": {"state": "translated", "value": v}}}}
json.dump(cat, open(p, "w"), indent=2, ensure_ascii=False, sort_keys=True)
print("catalog now has", sum(1 for v in cat["strings"].values() if v.get("localizations")), "translations")
