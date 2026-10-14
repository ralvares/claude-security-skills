#!/usr/bin/env bash
# Every sheet must appear in INDEX.md exactly once, and every file named
# there must exist.
set -euo pipefail
cd "$(dirname "$0")/../skills/owasp"

all=$( (grep -o '`[A-Za-z0-9_.-]*\.md`' INDEX.md || true) | tr -d '`' | sort)
named=$(echo "$all" | uniq)
dupes=$(echo "$all" | uniq -d)
present=$(cd references && ls -- *.md | sort -u)

missing=$(comm -23 <(echo "$named") <(echo "$present"))
unindexed=$(comm -13 <(echo "$named") <(echo "$present"))

[ -n "$missing" ] && echo "MISSING (in INDEX.md, no file):" && echo "$missing"
[ -n "$unindexed" ] && echo "UNINDEXED (file, not in INDEX.md):" && echo "$unindexed"
[ -n "$dupes" ] && echo "LISTED TWICE:" && echo "$dupes"
[ -z "$missing$unindexed$dupes" ] || exit 1
echo "OK: $(echo "$present" | wc -l | tr -d ' ') sheets, each indexed once"
