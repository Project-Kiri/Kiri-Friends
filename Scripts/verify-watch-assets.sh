#!/usr/bin/env bash
# verify-watch-assets.sh
# Compares the buddy theme assets bundled in KiriFriendsWatchKit's Asset
# Catalog against the canonical copies in KiriFriendsBuddyMac. Any
# drift (different file, missing file, extra file) fails the script,
# preventing the two AGPL bundles from silently diverging over time.
#
# Run via `make verify-watch-assets` or directly.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WATCH_ROOT="$REPO_ROOT/apps/apple/Sources/KiriFriendsWatchKit/Resources/Themes.xcassets"
MAC_BUDDY_ROOT="$REPO_ROOT/apps/apple/Sources/KiriFriendsBuddyMac/Resources/Themes"

if [[ ! -d "$WATCH_ROOT" ]]; then
  echo "verify-watch-assets: missing $WATCH_ROOT" >&2
  exit 1
fi
if [[ ! -d "$MAC_BUDDY_ROOT" ]]; then
  echo "verify-watch-assets: missing $MAC_BUDDY_ROOT" >&2
  exit 1
fi

fail=0

# Mac Buddy stores all clawd SVGs under svg/, calico under assets/,
# cloudling under assets/. The Watch catalog uses one imageset per
# asset. For each Watch imageset we look up the corresponding Mac Buddy
# canonical file and diff by SHA-256.
canonical_path() {
  local theme="$1"
  local filename="$2"
  case "$theme" in
    clawd)
      echo "$MAC_BUDDY_ROOT/clawd/svg/$filename"
      ;;
    calico|cloudling)
      echo "$MAC_BUDDY_ROOT/$theme/assets/$filename"
      ;;
    *)
      echo ""
      ;;
  esac
}

while IFS= read -r imageset; do
  theme="$(basename "$(dirname "$imageset")")"
  # The imageset directory holds exactly one source file plus
  # Contents.json. Pick the non-Contents file.
  payload="$(find "$imageset" -type f ! -name 'Contents.json' -print -quit)"
  if [[ -z "$payload" ]]; then
    echo "verify-watch-assets: $imageset has no source asset" >&2
    fail=1
    continue
  fi

  filename="$(basename "$payload")"
  canonical="$(canonical_path "$theme" "$filename")"
  if [[ -z "$canonical" || ! -f "$canonical" ]]; then
    echo "verify-watch-assets: cannot locate canonical $theme/$filename (expected $canonical)" >&2
    fail=1
    continue
  fi

  watch_sha="$(shasum -a 256 "$payload" | awk '{print $1}')"
  canonical_sha="$(shasum -a 256 "$canonical" | awk '{print $1}')"
  if [[ "$watch_sha" != "$canonical_sha" ]]; then
    echo "verify-watch-assets: SHA drift on $theme/$filename" >&2
    echo "  watch:     $watch_sha  $payload" >&2
    echo "  buddyMac:  $canonical_sha  $canonical" >&2
    fail=1
  fi
done < <(find "$WATCH_ROOT" -name '*.imageset' -type d)

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi
echo "verify-watch-assets: all Watch buddy assets match KiriFriendsBuddyMac canonical files."
