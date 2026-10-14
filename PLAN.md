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
1. [ ] Branch: repo is empty, so first commit goes to `main` (nothing to branch from). Write `LICENSE`, `NOTICE.md`. Check: `head -1 LICENSE` → `# Attribution-ShareAlike 4.0 International`.
2. [ ] Copy sheets: `cp ~/.claude/security/owasp/*.md skills/owasp/sheets/`. Check: `ls skills/owasp/sheets | wc -l` → `133`.
3. [ ] Write `skills/owasp/SKILL.md` from `~/.claude/security/INDEX.md`. Check: `scripts/check-index.sh` → `OK: 133 sheets, all indexed, no missing`.
4. [ ] Write `scripts/sync-owasp.sh`. Check: `scripts/sync-owasp.sh ae965343 && git status --porcelain skills/owasp/sheets` → empty (byte-identical reproduction).
5. [ ] Write `SECURITY-RULES.md` (from current `~/.claude/SECURITY.md`, line pointing to the skill). Check: `wc -c` < 2000.
6. [ ] Write `README.md`. Check: install command, `@` import line, token table, update steps, license section present.
7. [ ] Run `/ponytail-review` over scripts.
8. [ ] Commit (`feat: add owasp skill with OWASP cheat sheets`), review `git diff --staged` stat, push `main` (owner asked to push).
9. [ ] Dogfood install: `npx skills@latest add ralvares/claude-security-skills -g -y`. Check: `~/.claude/skills/owasp/SKILL.md` exists, `check-index.sh` passes against it.
10. [ ] Switch local setup: `~/.claude/SECURITY.md` = contents of `SECURITY-RULES.md`; move `~/.claude/security/` to `~/.claude/skills-archive/security-pre-skill/`. Check: fresh `claude -p "Plan a webhook receiver. Only list which OWASP files you would read."` invokes `owasp` and names `Webhook_Security.md`.

## Constraints
- Sheets are third-party content under CC BY-SA 4.0: keep attribution, state changes, same license for the repo.
- Public repo: no personal paths, emails, tokens or private project content. `grep -rn "ralvares\|/Users/" .` only matches the GitHub install URL.
- Scripts treat the cloned OWASP repo as untrusted: no `eval`, no executing its files, quoted variables, `set -euo pipefail`, temp dir removed on exit.
- Global rules files stay small (< 2 KB).

## Done when
- [ ] `scripts/check-index.sh` passes.
- [ ] `scripts/sync-owasp.sh ae965343` leaves no diff.
- [ ] Pushed to `origin/main`.
- [ ] Installed via `npx skills` and listed by Claude Code.
- [ ] Headless webhook test invokes the skill and reads only the webhook rows.
- [ ] `~/.claude/SECURITY.md` < 2 KB, old `~/.claude/security/` archived.

## Decisions
- Structure: one `owasp` skill (owner, 2026-10-14).
- License: CC BY-SA 4.0 for the whole repo (owner).
- Updates: manual script, no GitHub Action (owner).
- Always-on rules ship in the repo as `SECURITY-RULES.md` for `@` import (owner).
- Push to `main` directly: owner asked to push; repo is empty.
