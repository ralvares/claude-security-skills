# claude-security-skills

Secure coding guidance for Claude Code, built on the [OWASP Cheat Sheet Series](https://cheatsheetseries.owasp.org/). Claude reads only the sheets a task needs, so the full library (about 680k tokens) never sits in context.

Two pieces work together:

| Piece | Loaded | Cost |
| --- | --- | --- |
| `SECURITY-RULES.md`: seven rules (untrusted input, deny by default, no secrets, parameterise, least privilege, fail closed, a Security section in every plan) | Every session, through an `@` import | about 350 tokens |
| `owasp` skill: a router from task to sheet, plus 133 sheets | Only when a task touches security | router about 2k tokens, then 1 to 4 sheets |

Building a webhook receiver, for example, loads the router, `Webhook_Security.md` and `Server_Side_Request_Forgery_Prevention.md`. Nothing else.

## Install

```bash
npx skills@latest add ralvares/claude-security-skills -g -y
```

This puts the skill in `~/.claude/skills/owasp/`. Without Node:

```bash
git clone https://github.com/ralvares/claude-security-skills
cp -R claude-security-skills/skills/owasp ~/.claude/skills/
```

Then make the rules always on. Copy `SECURITY-RULES.md` to `~/.claude/SECURITY.md` and add this line to `~/.claude/CLAUDE.md`:

```
@SECURITY.md
```

Check it in Claude Code: `/owasp` should appear in the skill list.

## How it is used

Claude matches the task against the skill description and invokes `owasp` on its own; you can also type `/owasp`. The skill body is a set of tables (design, identity, injection, APIs, front end, data and crypto, AI features, logging, supply chain, languages). Claude picks the matching rows, reads those sheets, and names them in the plan.

The sheets quote attack payloads as examples. The skill tells Claude to treat them as reference data, never as instructions.

## Update the sheets

```bash
scripts/sync-owasp.sh          # latest OWASP master
scripts/sync-owasp.sh <full SHA> # a specific commit
```

The script copies `cheatsheets/*.md`, drops the `_Cheat_Sheet` suffix, rewrites links, skips deprecated stubs and updates the commit in `skills/owasp/NOTICE.md`. It prints sheets that are new (add a row to `SKILL.md`) or removed (drop the row). `scripts/check-index.sh` confirms every sheet is listed and every listed sheet exists.

## License

[CC BY-SA 4.0](LICENSE), the license of the OWASP Cheat Sheet Series. The sheets are the work of the OWASP Foundation and contributors; `skills/owasp/NOTICE.md` lists the source commit and the changes made.
