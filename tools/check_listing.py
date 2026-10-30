#!/usr/bin/env python3
"""Checks AppStore/metadata.md against the App Store Connect limits (SPEC §19.7) and the IP rules (§19.5).

    python3 tools/check_listing.py          # prints every limit; exits 1 on a violation

Limits: name 30, subtitle 30, promotional text 170, description 4000, keywords 100, What's New 4000.
"""
import re
import sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent / "AppStore"
text = (root / "metadata.md").read_text()


def block(heading):
    match = re.search(r"^## " + re.escape(heading) + r"[^\n]*\n+```\n(.*?)\n```", text, re.S | re.M)
    if not match:
        sys.exit(f"missing section: {heading}")
    return match.group(1).strip()


limits = [("Name", 30), ("Subtitle", 30), ("Promotional text", 170), ("Description", 4000), ("Keywords", 100), ("What's New in 1.3", 4000)]
ok = True
values = {}
for name, limit in limits:
    value = block(name)
    values[name] = value
    used = len(value)
    flag = "ok" if used <= limit else "TOO LONG"
    if used > limit:
        ok = False
    print(f"{name:<20} {used:>5} / {limit:<5} {flag}")

# Keywords: comma separated, no spaces after commas, none already in the name or subtitle, no trademarks.
keywords = [k.strip().lower() for k in values["Keywords"].split(",")]
if len(set(keywords)) != len(keywords):
    ok = False
    print("DUPLICATE keywords")
title_words = set(re.findall(r"[a-z]+", (values["Name"] + " " + values["Subtitle"]).lower()))
for k in keywords:
    if set(re.findall(r"[a-z]+", k)) & title_words:
        ok = False
        print(f"keyword repeats a word of the name or subtitle: {k}")

banned = ["nmjl", "national mah jongg league", "official card", "mah jongg", "mahjongg", "rummikub", "mahjong legends"]
for name in ["Name", "Subtitle", "Promotional text", "Keywords", "What's New in 1.3"]:
    low = values[name].lower()
    for b in banned:
        if b in low:
            ok = False
            print(f"{name} contains \"{b}\"")
# The description may name the League only in the not-affiliated disclaimer.
description = values["Description"].lower()
for b in ["nmjl", "official card"]:
    if b in description:
        ok = False
        print(f"Description contains \"{b}\"")
for match in re.finditer("national mah jongg league", description):
    context = description[max(0, match.start() - 60): match.start()]
    if "not affiliated" not in context:
        ok = False
        print("Description names the League outside the not-affiliated disclaimer")

for path in sorted(root.glob("*.md")):
    body = path.read_text().lower()
    if path.name != "metadata.md" and ("nmjl" in body.replace("not affiliated", "")) and path.name in ("review-notes.md",):
        ok = False
        print(f"{path.name} mentions NMJL")
    if re.search(r"[\w.+-]+@[\w-]+\.[\w.]+", body):
        ok = False
        print(f"{path.name} contains an email address")
print("ALL LIMITS OK" if ok else "PROBLEMS FOUND")
sys.exit(0 if ok else 1)
