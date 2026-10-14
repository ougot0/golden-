#!/usr/bin/env python3
"""Copies screenshots exported by `xcresulttool export attachments` to readable names.

Usage: rename_screenshots.py <export dir with manifest.json> <destination dir>
Attachment names set in ScreenshotTests (e.g. "01-Aujourdhui") become "01-Aujourdhui.png".
"""
import json
import shutil
import sys
from pathlib import Path

src, dst = Path(sys.argv[1]), Path(sys.argv[2])
dst.mkdir(parents=True, exist_ok=True)
manifest = json.loads((src / "manifest.json").read_text())
count = 0
for test in manifest:
    for attachment in test.get("attachments", []):
        human = attachment.get("suggestedHumanReadableName", "")
        name = human.split("_")[0] if human else Path(attachment["exportedFileName"]).stem
        if not name[:2].isdigit():
            continue  # skip automatic attachments (failure screenshots, logs)
        shutil.copy(src / attachment["exportedFileName"], dst / f"{name}.png")
        count += 1
print(f"{count} screenshots copied to {dst}")
if count == 0:
    sys.exit("No screenshots found")
