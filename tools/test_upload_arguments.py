#!/usr/bin/env python3
"""Exercise release argument rejection before credential or network preflight."""
import subprocess
import tempfile
from pathlib import Path

root = Path(__file__).resolve().parent.parent
script = root / "tools" / "upload_testflight.sh"
with tempfile.TemporaryDirectory(prefix="mahjong-ipa-args-") as directory:
    tmp = Path(directory)
    existing = tmp / "existing.ipa"
    existing.write_bytes(b"preserve")
    cases = [
        (["--ipa-output"], "requires a path"),
        (["--ipa-output", str(tmp / "new.ipa")], "requires --dry-run"),
        (["--dry-run", "--ipa-output", "relative.ipa"], "absolute path"),
        (["--dry-run", "--ipa-output", str(existing)], "already exists"),
        (["--dry-run", "--ipa-output", str(tmp / "missing" / "new.ipa")], "parent directory does not exist"),
        (["--dry-run", "--ipa-output", str(root / "inside.ipa")], "outside the checkout"),
        (["--unexpected"], "Unknown argument"),
    ]
    for arguments, expected in cases:
        result = subprocess.run(["zsh", str(script), *arguments], capture_output=True, text=True, cwd=root)
        if result.returncode != 2 or expected not in result.stderr:
            raise AssertionError(f"{arguments}: exit {result.returncode}, stderr: {result.stderr}")
    assert existing.read_bytes() == b"preserve"
    assert subprocess.run(["zsh", str(script), "--help"], capture_output=True, cwd=root).returncode == 0
print(f"Release arguments: {len(cases)} rejection cases and help passed; existing destination preserved.")
