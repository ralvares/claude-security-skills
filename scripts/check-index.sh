#!/usr/bin/env bash
# Every sheet named in SKILL.md must exist, and every sheet must be named.
set -euo pipefail
cd "$(dirname "$0")/../skills/owasp"

named=$( (grep -o '`[A-Za-z0-9_.-]*\.md`' SKILL.md || true) | tr -d '`' | sort -u)
present=$(cd sheets && ls -- *.md | sort -u)

missing=$(comm -23 <(echo "$named") <(echo "$present"))
unindexed=$(comm -13 <(echo "$named") <(echo "$present"))

[ -n "$missing" ] && echo "MISSING (named in SKILL.md, no file):" && echo "$missing"
[ -n "$unindexed" ] && echo "UNINDEXED (file, not in SKILL.md):" && echo "$unindexed"
[ -z "$missing$unindexed" ] || exit 1
echo "OK: $(echo "$present" | wc -l | tr -d ' ') sheets, all indexed, no missing"
