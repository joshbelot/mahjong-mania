#!/bin/zsh
# Local card-scanning experiment (docs/CARD_SCAN_EVALUATION.md). macOS only, no network.
#   tools/scan_eval.sh generate          regenerate the original corpus from the committed seed
#   tools/scan_eval.sh test              harness unit tests
#   tools/scan_eval.sh eval dev|held-out recognise and score a split (held-out needs corpus/freeze.json)
#   tools/scan_eval.sh quality dev|held-out
#   tools/scan_eval.sh owner             score private/card-scans against its answer key (aggregates only)
set -euo pipefail
cd "${0:A:h}/CardScanHarness"
case "${1:-}" in
  test) swift test ;;
  owner)
    ROOT="${SCAN_PRIVATE:-$(git rev-parse --show-toplevel)/private/card-scans}"
    swift build -c release 2>&1 | tail -1
    .build/release/cardscan owner --key "$ROOT/2026/answer-key.txt" --photos "$ROOT/2026/phone-photos" --web "$ROOT/web" ;;
  *) swift build -c release 2>&1 | tail -1; .build/release/cardscan "$@" ;;
esac
