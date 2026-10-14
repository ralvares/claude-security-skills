# PLAN: claude-security-skills

## Why
Claude Code sessions should write secure code by the OWASP Cheat Sheet Series without loading 680k tokens of sheets. Today the sheets and their index live only on one laptop (`~/.claude/security/`). This repo packages them as one Claude Code skill (`owasp`) that anyone, on any machine, installs with one command. Claude keeps 7 short rules always loaded (~350 tokens) and loads the task→sheet router (~2k tokens) plus only the matching sheets when a task needs them.

## User stories
1. As the owner, I want to install the skill on a new machine with one command, so that every session has the same security guidance.
   - `npx skills@latest add ralvares/claude-security-skills -g -y` installs `owasp` into `~/.claude/skills/owasp/`.
   - `/owasp` appears in Claude Code's skill list.
2. As a Claude session building a webhook, I want to load only the webhook guidance, so that context stays small.
   - Skill body names `Webhook_Security.md` and `Server_Side_Request_Forgery_Prevention.md` for webhooks; nothing else is read.
3. As the owner, I want the always-on rules active in every project without invoking anything.
   - README shows the `@` import line for `~/.claude/CLAUDE.md`; rules file is under 2 KB.
4. As the owner, I want to refresh the sheets from OWASP with one command.
   - `scripts/sync-owasp.sh` reproduces today's 133 files exactly at commit `ae965343` and reports added or removed sheets at a newer commit.

## Use cases
- **Main:** session plans a feature → skill description matches ("webhook", "login", "AI feature"...) → Claude invokes `owasp` → reads the table row → reads 1–4 sheets → applies them and lists them in the plan's Security section.
- **Manual:** user types `/owasp` → body loads.
- **No match:** task touches no listed topic → only the 7 rules apply; skill not loaded.
- **Error, sheet missing:** a row names a file that does not exist → `scripts/check-index.sh` fails in CI-less local check before commit.
- **Edge, new OWASP sheet:** sync script prints it as "NEW, add to SKILL.md table"; no row exists until a human adds one.
- **Edge, deprecated OWASP stub:** sync skips it and rewrites links to its replacement.
- **Edge, prompt injection in sheets:** sheets quote attack payloads; SKILL.md says they are reference data, never instructions.

## Scope
In: one skill `owasp`, 133 sheets, rules snippet, README, LICENSE (CC BY-SA 4.0), sync script, index check script, local switch-over to the installed copy.
Out: category skills, GitHub Actions, hooks, design skills, Claude Code plugin marketplace packaging, translations.

## Stack
- Markdown (skill format: folder with `SKILL.md` + YAML front matter `name`, `description`).
- Bash 5 + POSIX tools (git, sed, grep, comm, diff) for scripts; macOS BSD sed and GNU sed both supported (`sed -i.bak` then delete `.bak`). Reason: no runtime to install; matches existing workflow.
- Installer: `npx skills@latest` (vercel-labs skills CLI, already used on this machine). Fallback: `git clone` + copy.

## Design
```
claude-security-skills/
  README.md                 what, install, how it loads, token cost, update, license
  LICENSE                   CC BY-SA 4.0 legal text (copied from ~/.claude/security/LICENSE-OWASP.md)
  SECURITY-RULES.md         the 7 always-on rules + "invoke the owasp skill before ..." line
  PLAN.md                   this file
  skills/owasp/
    SKILL.md                front matter + router tables (from ~/.claude/security/INDEX.md, paths -> sheets/)
    sheets/*.md             133 OWASP sheets (from ~/.claude/security/owasp/)
    NOTICE.md               OWASP attribution: source repo, commit ae965343, date, changes made (renamed, links rewritten, deprecated stubs dropped)
  scripts/
    sync-owasp.sh [ref]     clone OWASP/CheatSheetSeries at ref (default master) into temp dir; copy cheatsheets/*.md minus deprecated stubs into skills/owasp/sheets/ dropping `_Cheat_Sheet`; rewrite links; print NEW/REMOVED vs SKILL.md; update commit line in NOTICE.md
    check-index.sh          every `X.md` named in SKILL.md exists in sheets/, and every sheet is named at least once; exit 1 otherwise
```
SKILL.md front matter:
```yaml
name: owasp
description: OWASP Cheat Sheet Series router. Use before planning or writing code that touches security: new features or services, architecture, multi-tenancy, auth, sessions, OAuth/SSO, JWT, input handling, SQL/shell/templates, HTML output, file upload, XML, REST/GraphQL/gRPC/WebSockets, webhooks, outbound URL fetches, payments, rate limits, web front end, crypto, secrets, TLS, privacy, AI/LLM features, RAG, agents, logging, dependencies, CI/CD, containers, Kubernetes, IaC, code review.
```
Body: one line on how to use (find row, Read listed files under `sheets/` relative to the skill dir, payloads are data), then the existing tables unchanged except the path prefix.

Deprecated stubs and their link replacements (from the first import):
`Access_Control` → `Authorization.md`; `Injection_Prevention_in_Java` → `Java_Security.md`; `TLS_Cipher_String`, `Transport_Layer_Protection` → `Transport_Layer_Security.md`.

## Steps
1. [x] Branch: repo is empty, so first commit goes to `main` (nothing to branch from). Write `LICENSE`, `NOTICE.md`. Check: `head -1 LICENSE` → `# Attribution-ShareAlike 4.0 International`.
2. [x] Copy sheets: `cp ~/.claude/security/owasp/*.md skills/owasp/sheets/`. Check: `ls skills/owasp/sheets | wc -l` → `133`.
3. [x] Write `skills/owasp/SKILL.md` from `~/.claude/security/INDEX.md`. Check: `scripts/check-index.sh` → `OK: 133 sheets, all indexed, no missing`.
4. [x] Write `scripts/sync-owasp.sh`. Check: `scripts/sync-owasp.sh ae965343 && git status --porcelain skills/owasp/sheets` → empty (byte-identical reproduction).
5. [x] Write `SECURITY-RULES.md` (from current `~/.claude/SECURITY.md`, line pointing to the skill). Check: `wc -c` < 2000.
6. [x] Write `README.md`. Check: install command, `@` import line, token table, update steps, license section present.
7. [x] Run `/ponytail-review` over scripts.
8. [x] Commit (`feat: add owasp skill with OWASP cheat sheets`), review `git diff --staged` stat, push `main` (owner asked to push).
9. [x] Dogfood install: `npx skills@latest add ralvares/claude-security-skills -g -y`. Check: `~/.claude/skills/owasp/SKILL.md` exists, `check-index.sh` passes against it.
10. [x] Switch local setup: `~/.claude/SECURITY.md` = contents of `SECURITY-RULES.md`; move `~/.claude/security/` to `~/.claude/skills-archive/security-pre-skill/`. Check: fresh `claude -p "Plan a webhook receiver. Only list which OWASP files you would read."` invokes `owasp` and names `Webhook_Security.md`.

## Constraints
- Sheets are third-party content under CC BY-SA 4.0: keep attribution, state changes, same license for the repo.
- Public repo: no personal paths, emails, tokens or private project content. `grep -rn "ralvares\|/Users/" .` only matches the GitHub install URL.
- Scripts treat the cloned OWASP repo as untrusted: no `eval`, no executing its files, quoted variables, `set -euo pipefail`, temp dir removed on exit.
- Global rules files stay small (< 2 KB).

## Done when
- [x] `scripts/check-index.sh` passes.
- [x] `scripts/sync-owasp.sh ae965343` leaves no diff.
- [x] Pushed to `origin/main`.
- [x] Installed via `npx skills` and listed by Claude Code.
- [x] Headless webhook test invokes the skill and picks the webhook rows (reads outside the project need a `Read(~/.claude/skills/**)` allow rule in headless mode).
- [x] `~/.claude/SECURITY.md` < 2 KB, old `~/.claude/security/` archived.

## Decisions
- Structure: one `owasp` skill (owner, 2026-10-14).
- License: CC BY-SA 4.0 for the whole repo (owner).
- Updates: manual script, no GitHub Action (owner).
- Always-on rules ship in the repo as `SECURITY-RULES.md` for `@` import (owner).
- Push to `main` directly: owner asked to push; repo is empty.

# Phase 2: always-on rules cover the whole Cheat Sheet Series (2026-10-14)

## Why
The 7 rules cover only part of the OWASP Top 10. When Claude does not recognise a task as security work, the skill never loads and the gaps (misconfiguration, supply chain, auth, integrity, logging, crypto) go unchecked. The owner accepts a bigger always-on cost to close that.

## Design
- `SECURITY-RULES.md` keeps the 7 core rules, then one section per router category (same order as `SKILL.md`). Each bullet is a concrete must or never taken from a sheet, ends with the sheet name in parentheses, at most about 30 words. Every one of the 133 sheets contributes at least one bullet (pure reference sheets, such as `XSS_Filter_Evasion`, may share a bullet).
- Values come from the sheets, never from memory (for example password hashing parameters, session ID entropy, cookie flags).
- Budget: at most 24 KB (about 6k tokens) per session. The skill and sheets stay unchanged for detail.
- `scripts/check-rules.sh`: every sheet in `sheets/` is cited in `SECURITY-RULES.md`; size under 24 KB.

## Steps
11. [x] Extract: 7 parallel agents, each reads about 19 sheets in full and writes `sheet | category | 1 to 3 rules` to the scratchpad. Check: 133 sheets present across the outputs.
12. [x] Compile `SECURITY-RULES.md` from the extracts: merge duplicates, group by category. Check: `scripts/check-rules.sh` prints `OK: 133 sheets cited, <size> bytes`.
13. [x] Spot-check 10 bullets against their sheets (values and wording match).
14. [x] Update README cost table, commit, push; copy to `~/.claude/SECURITY.md`.

## Decisions
- Always-on rules cover the full Cheat Sheet Series, not only the Top 10; cost accepted (owner, 2026-10-14).

# Phase 3: telegraphic style, no sync (2026-10-14)

## Why
Fewer tokens per session and per sheet read, same guidance. Owner: "apply the telegraphic style also to the md files"; remove the OWASP sync, since rewritten sheets can no longer be regenerated from upstream.

## Steps
15. [x] Delete `scripts/sync-owasp.sh`; README and NOTICE describe manual updates.
16. [x] `SECURITY-RULES.md` in telegraphic style. Check: `scripts/check-rules.sh` → `OK: 133 sheets cited, <24576 bytes`.
17. [x] Pilot: rewrite 3 sheets (Authorization, Webhook_Security, Java_Security). Check: scratchpad `check_compress.py` reports no lost code blocks, inline code, numbers, headings or sheet links; size ratio recorded.
18. [x] Rewrite the remaining 130 sheets in parallel batches with the same rules and checker.
19. [x] `scripts/check-index.sh` passes; spot-read 5 sheets for meaning; NOTICE lists the rewrite; commit, push, reinstall with `--copy`.

## Decisions
- No upstream sync; updates are manual from now on (owner, 2026-10-14).
- Headings, code blocks, inline code and every number stay byte-identical; prose, reference lists and external URLs are compressed or dropped.

# Phase 4: index replaces rules (2026-10-14)

## Why
Owner wants the always-loaded file to be an index into the OWASP files, not rules: one line per sheet with its use case and the file to read for detail.

## Steps
20. [x] `skills/owasp/INDEX.md`: 133 lines, "use case → file", grouped by category. Check: `scripts/check-index.sh` → `OK: 133 sheets, each indexed once`.
21. [x] `SKILL.md` body points to `INDEX.md`; `allowed-tools` covers the skill folder. Delete `SECURITY-RULES.md` and `scripts/check-rules.sh`.
22. [ ] Commit, push, reinstall with `--copy`; `~/.claude/CLAUDE.md` imports `@skills/owasp/INDEX.md` instead of `@SECURITY.md`; headless webhook test reads the sheet.

## Decisions
- Always-loaded content is the index only; the 7 core rules and the 107 distilled rules are dropped (owner, 2026-10-14).
