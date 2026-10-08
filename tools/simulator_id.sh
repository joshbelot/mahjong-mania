#!/bin/zsh
# Prints the UDID of an available iPhone simulator (newest runtime, last listed iPhone that is not an SE).
set -euo pipefail
id=$(xcrun simctl list devices available | grep -E '^\s+iPhone' | grep -v 'SE' | tail -1 \
  | sed -E 's/.*\(([0-9A-Fa-f-]{36})\).*/\1/')
if [[ -z "$id" ]]; then
  echo "No available iPhone simulator found. Install an iOS runtime in Xcode > Settings > Components." >&2
  exit 1
fi
echo "$id"
