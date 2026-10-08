#!/bin/zsh
# Increments CURRENT_PROJECT_VERSION in project.yml and prints the new build number.
set -euo pipefail
cd "${0:A:h}/.."

FILE=project.yml
PATTERN='^( *CURRENT_PROJECT_VERSION: *")([0-9]+)(")'
count=$(grep -cE "$PATTERN" "$FILE" || true)
if [[ "$count" != "1" ]]; then
  echo "Expected exactly one CURRENT_PROJECT_VERSION line in $FILE, found $count." >&2
  exit 1
fi
current=$(grep -E "$PATTERN" "$FILE" | sed -E "s/$PATTERN.*/\2/")
next=$((current + 1))
if [[ "$(uname)" == "Darwin" ]]; then
  sed -E -i '' "s/$PATTERN/\1${next}\3/" "$FILE"
else
  sed -E -i "s/$PATTERN/\1${next}\3/" "$FILE"
fi
echo "$next"
