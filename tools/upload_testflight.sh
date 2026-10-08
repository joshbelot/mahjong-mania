#!/bin/zsh
# Ships a build to TestFlight (SPEC §16.3).
#
#   zsh -ic 'tools/upload_testflight.sh --dry-run'   # everything except the upload and the build bump
#   zsh -ic 'tools/upload_testflight.sh'             # the real thing
#
# Run it through `zsh -ic` so ~/.zshrc (DEVELOPMENT_TEAM, ASC_*) is loaded. Never use `set -x`, `env` or
# `echo $ASC_...` around this script: the values are credentials.
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: tools/upload_testflight.sh [--dry-run]

  --dry-run   Run tests, archive and export (no upload), leave the build number unchanged,
              commit and push nothing.
USAGE
}

DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $arg" >&2; usage >&2; exit 2 ;;
  esac
done

REPO_ROOT=${0:A:h:h}
cd "$REPO_ROOT"

step() { print -P "%F{green}==>%f $*" }
fail() { print -P "%F{red}error:%f $*" >&2; exit 1 }

# Replaces credential values with placeholders in anything printed from xcodebuild.
redact() {
  local script="s|__never_matches__|x|g"
  local pair name value
  for pair in "DEVELOPMENT_TEAM:<TEAM>" "ASC_KEY_ID:<KEY_ID>" "ASC_ISSUER_ID:<ISSUER_ID>"; do
    name=${pair%%:*}
    value=${(P)name:-}
    [[ -n "$value" ]] && script+=";s|${value}|${pair#*:}|g"
  done
  sed -e "$script"
}

# 1. Preflight ------------------------------------------------------------------------------------------
step "Preflight"
missing=()
for var in DEVELOPMENT_TEAM ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_PATH; do
  [[ -n "${(P)var:-}" ]] || missing+=("$var")
done
if (( ${#missing} > 0 )); then
  fail "Missing environment variables: ${missing[*]}. Run via: zsh -ic 'tools/upload_testflight.sh' so ~/.zshrc is loaded (see RELEASING.md)."
fi
KEY_PATH=${ASC_KEY_PATH/#\~/$HOME}
[[ -r "$KEY_PATH" ]] || fail "ASC_KEY_PATH does not point to a readable file (expected the AuthKey_<KEYID>.p8 you downloaded)."

for tool in xcodebuild xcodegen git; do
  command -v "$tool" >/dev/null 2>&1 || fail "'$tool' not found on PATH."
done
XCODE_MAJOR=$(xcodebuild -version | head -1 | sed -E 's/^Xcode ([0-9]+).*/\1/')
[[ "$XCODE_MAJOR" == <-> ]] || fail "Could not read the Xcode version."
(( XCODE_MAJOR >= 26 )) || fail "Xcode 26 or newer is required (found Xcode $XCODE_MAJOR). App Store Connect only accepts builds from the current SDK."

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "Not inside a git checkout."
[[ "$(git rev-parse --abbrev-ref HEAD)" == "main" ]] || fail "Releases are built from 'main'. Check it out first."
[[ -z "$(git status --porcelain)" ]] || fail "The working tree has uncommitted changes. Commit or stash them first."
git fetch origin main --quiet || fail "Could not fetch origin/main."
[[ "$(git rev-parse HEAD)" == "$(git rev-parse origin/main)" ]] || fail "Local main is not the same as origin/main. Pull (or push) first."

# 2. Clean checkout ---------------------------------------------------------------------------------------
TMP=$(mktemp -d "${TMPDIR:-/tmp}/mahjong-release.XXXXXX")
cleanup() {
  cd "$REPO_ROOT" 2>/dev/null || true
  git worktree remove --force "$TMP/release" >/dev/null 2>&1 || true
  rm -rf "$TMP"
}
trap cleanup EXIT

step "Creating a clean worktree of origin/main"
git worktree add --detach "$TMP/release" origin/main >/dev/null
cd "$TMP/release"
mkdir -p build

run_logged() {
  # run_logged <logfile> <command...>: keep the log, show a redacted tail on failure.
  local log=$1; shift
  if ! "$@" > "$log" 2>&1; then
    tail -60 "$log" | redact >&2
    fail "Command failed; see the output above (full log: ${log#$TMP/release/} in the temporary worktree)."
  fi
}

# 3. Tests first -------------------------------------------------------------------------------------------
step "Running tests (tools/test.sh)"
run_logged build/tests.log tools/test.sh

# 4. Bump ---------------------------------------------------------------------------------------------------
if (( DRY_RUN )); then
  BUILD=$(sed -nE 's/^ *CURRENT_PROJECT_VERSION: *"([0-9]+)".*/\1/p' project.yml | head -1)
  step "Dry run: keeping build number $BUILD"
else
  step "Bumping the build number"
  BUILD=$(tools/bump_build.sh)
fi
VERSION=$(sed -nE 's/^ *MARKETING_VERSION: *"([^"]+)".*/\1/p' project.yml | head -1)
xcodegen generate >/dev/null

# 5. Archive ------------------------------------------------------------------------------------------------
step "Archiving Mahjong Mania $VERSION ($BUILD)"
run_logged build/archive.log xcodebuild archive \
  -project MahjongMania.xcodeproj -scheme MahjongMania -configuration Release \
  -archivePath build/MahjongMania.xcarchive -destination 'generic/platform=iOS' \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID" DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM"

# 6. ExportOptions ------------------------------------------------------------------------------------------
if (( DRY_RUN )); then DESTINATION=export; else DESTINATION=upload; fi
cat > build/ExportOptions.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>${DESTINATION}</string>
  <key>teamID</key><string>${DEVELOPMENT_TEAM}</string>
  <key>signingStyle</key><string>automatic</string>
  <key>uploadSymbols</key><true/>
  <key>manageAppVersionAndBuildNumber</key><false/>
</dict>
</plist>
PLIST

# 7. Export / upload ----------------------------------------------------------------------------------------
if (( DRY_RUN )); then
  step "Exporting the archive (dry run: no upload)"
else
  step "Uploading to App Store Connect"
fi
run_logged build/export.log xcodebuild -exportArchive \
  -archivePath build/MahjongMania.xcarchive \
  -exportOptionsPlist build/ExportOptions.plist -exportPath build/export \
  -allowProvisioningUpdates -authenticationKeyPath "$KEY_PATH" \
  -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID"

# 8. Record the bump ----------------------------------------------------------------------------------------
if (( DRY_RUN )); then
  print "Dry run complete: archive and export succeeded. Nothing was uploaded and the build number is unchanged ($BUILD)."
  exit 0
fi

step "Recording build $BUILD in git"
git add project.yml
git commit -q -m "Bump build to $BUILD [skip ci]"
if git push -q origin HEAD:main; then
  cd "$REPO_ROOT"
  git pull -q --ff-only origin main || print "Note: run 'git pull' in your checkout to pick up the build bump."
else
  BRANCH="release/build-$BUILD"
  git push -q origin "HEAD:refs/heads/$BRANCH" || fail "Could not push the build bump. The upload succeeded; bump CURRENT_PROJECT_VERSION to $BUILD in project.yml yourself before the next release."
  print "main is protected, so the bump was pushed to '$BRANCH'. Open and merge a PR from it before the next release."
fi

# 9. Done ---------------------------------------------------------------------------------------------------
print "Uploaded Mahjong Mania $VERSION ($BUILD). Processing usually takes 5–30 minutes; you'll get an email and it will appear under TestFlight."
