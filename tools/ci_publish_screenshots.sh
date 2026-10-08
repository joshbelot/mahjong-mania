#!/bin/bash
# CI helper: copies exported xcresult screenshots (downscaled) to the `ci-screenshots` branch under
# pr-<number>/ so they can be reviewed without downloading the Actions artifact.
# Usage: tools/ci_publish_screenshots.sh <exported-dir> <pr-number>
set -euo pipefail
SRC=${1:?exported attachments dir}
PR=${2:?pr number}
WORK=$(mktemp -d)
OUT="$WORK/out"
mkdir -p "$OUT"

python3 - "$SRC" "$OUT" <<'PY'
import json, os, shutil, sys, re
src, out = sys.argv[1], sys.argv[2]
manifest = os.path.join(src, "manifest.json")
count = 0
if os.path.exists(manifest):
    data = json.load(open(manifest))
    for test in data:
        for att in test.get("attachments", []):
            name = att.get("suggestedHumanReadableName") or att["exportedFileName"]
            name = re.sub(r"_\d+_[0-9A-Fa-f-]{36}", "", name)
            name = re.sub(r"[^A-Za-z0-9._-]", "_", name)
            f = os.path.join(src, att["exportedFileName"])
            if os.path.exists(f):
                ext = os.path.splitext(att["exportedFileName"])[1] or ".png"
                if not name.endswith(ext):
                    name += ext
                shutil.copy(f, os.path.join(out, name))
                count += 1
print(f"collected {count} attachments")
PY

for f in "$OUT"/*.png; do
  [ -e "$f" ] || continue
  sips -Z 700 "$f" >/dev/null
done

REPO_URL="https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"
cd "$WORK"
if git clone -q --depth 1 --branch ci-screenshots "$REPO_URL" repo 2>/dev/null; then
  :
else
  mkdir repo && cd repo && git init -q -b ci-screenshots && git remote add origin "$REPO_URL" && cd ..
fi
cd repo
git config user.name "ci-screenshots"
git config user.email "ci-screenshots@users.noreply.github.com"
rm -rf "pr-$PR"
mkdir -p "pr-$PR"
cp "$OUT"/* "pr-$PR"/ 2>/dev/null || true
git add -A
if git diff --cached --quiet; then
  echo "No screenshot changes"
else
  git commit -q -m "Screenshots for PR $PR @ ${GITHUB_SHA:-unknown}"
  git push -q origin ci-screenshots
  echo "Published to branch ci-screenshots under pr-$PR/"
fi
