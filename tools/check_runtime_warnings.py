#!/usr/bin/env python3
"""Fail the local gate when Xcode reports runtime warnings in a result bundle."""
import json
import subprocess
import sys

if len(sys.argv) != 2:
    sys.exit("usage: check_runtime_warnings.py RESULT.xcresult")

result = subprocess.run(
    ["xcrun", "xcresulttool", "get", "test-results", "summary", "--path", sys.argv[1], "--format", "json"],
    check=True, capture_output=True, text=True,
)
summary = json.loads(result.stdout)
warnings = summary.get("runtimeWarnings", [])
if warnings:
    for warning in warnings:
        print(f"Runtime warning: {warning.get('message', '(no message)')}", file=sys.stderr)
    sys.exit(f"{len(warnings)} runtime warning(s) in {sys.argv[1]}")
print("No Xcode runtime warnings.")
