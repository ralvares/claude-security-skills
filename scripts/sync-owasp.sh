#!/usr/bin/env bash
# Refresh skills/owasp/sheets from OWASP/CheatSheetSeries.
# Usage: scripts/sync-owasp.sh [branch, tag or full commit SHA]   (default: master)
set -euo pipefail
ref="${1:-master}"
root="$(cd "$(dirname "$0")/.." && pwd)"
dest="$root/skills/owasp/sheets"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

git init --quiet "$tmp/src"
git -C "$tmp/src" fetch --quiet --depth 1 https://github.com/OWASP/CheatSheetSeries "$ref"
git -C "$tmp/src" checkout --quiet FETCH_HEAD -- cheatsheets
commit="$(git -C "$tmp/src" rev-parse --short=8 FETCH_HEAD)"

# Deprecated stubs: dropped, links point to their replacements.
deprecated='^(Access_Control|Injection_Prevention_in_Java|TLS_Cipher_String|Transport_Layer_Protection)_Cheat_Sheet\.md$'

before="$(cd "$dest" && ls -- *.md | sort)"
rm -f "$dest"/*.md
for f in "$tmp/src/cheatsheets"/*.md; do
  name="$(basename "$f")"
  [[ "$name" =~ $deprecated ]] && continue
  sed -E \
    -e 's/Access_Control_Cheat_Sheet\.md/Authorization.md/g' \
    -e 's/Injection_Prevention_in_Java_Cheat_Sheet\.md/Java_Security.md/g' \
    -e 's/(TLS_Cipher_String|Transport_Layer_Protection)_Cheat_Sheet\.md/Transport_Layer_Security.md/g' \
    -e 's/([A-Za-z0-9_.-]+)_Cheat_Sheet\.md/\1.md/g' \
    "$f" > "$dest/${name/_Cheat_Sheet.md/.md}"
done
after="$(cd "$dest" && ls -- *.md | sort)"

sed -i.bak -E "s/^Source commit: \`[0-9a-f]+\` \(imported [0-9-]+\)\./Source commit: \`$commit\` (imported $(date +%F))./" "$root/skills/owasp/NOTICE.md"
rm -f "$root/skills/owasp/NOTICE.md.bak"

echo "Synced $(echo "$after" | wc -l | tr -d ' ') sheets from $commit"
comm -13 <(echo "$before") <(echo "$after") | sed 's/^/NEW, add a row to SKILL.md: /'
comm -23 <(echo "$before") <(echo "$after") | sed 's/^/REMOVED, drop from SKILL.md: /'
"$root/scripts/check-index.sh" || true
