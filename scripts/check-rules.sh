#!/usr/bin/env bash
# Every sheet must be cited in SECURITY-RULES.md, and the file must stay
# under the always-on budget.
set -euo pipefail
cd "$(dirname "$0")/.."
budget=24576

cited=$( (grep -o '([A-Za-z0-9_.-]*\(, [A-Za-z0-9_.-]*\)*)' SECURITY-RULES.md || true) \
  | tr -d '()' | tr ',' '\n' | tr -d ' ' | sed 's/$/.md/' | sort -u)
present=$(cd skills/owasp/sheets && ls -- *.md | sort -u)
uncited=$(comm -13 <(echo "$cited") <(echo "$present"))
size=$(wc -c < SECURITY-RULES.md | tr -d ' ')

[ -n "$uncited" ] && echo "UNCITED (no rule in SECURITY-RULES.md):" && echo "$uncited"
[ "$size" -le "$budget" ] || echo "TOO BIG: $size bytes, budget $budget"
[ -z "$uncited" ] && [ "$size" -le "$budget" ] || exit 1
echo "OK: $(echo "$present" | wc -l | tr -d ' ') sheets cited, $size bytes"
