# claude-security-skills

Secure coding guidance for Claude Code, built on the [OWASP Cheat Sheet Series](https://cheatsheetseries.owasp.org/). Claude reads only the sheets a task needs, so the full library (about 680k tokens) never sits in context.

Two pieces work together:

| Piece | Loaded | Cost |
| --- | --- | --- |
| `SECURITY-RULES.md`: seven core rules plus 107 rules distilled from all 133 sheets, each citing its sheets | Every session, through an `@` import | about 6k tokens |
| `owasp` skill: a router from task to sheet, plus 133 sheets | Only when a task touches security | router about 2k tokens, then 1 to 4 sheets |

Building a webhook receiver, for example, loads the router, `Webhook_Security.md` and `Server_Side_Request_Forgery_Prevention.md`. Nothing else.

## Install

```bash
npx skills@latest add ralvares/claude-security-skills -g -y --copy
```

This puts the skill in `~/.claude/skills/owasp/`. Keep `--copy`: without it the installer links the folder from `~/.agents/skills/`, and Claude Code checks read permission on the link target too, so the sheets need a prompt every time. Without Node:

```bash
git clone https://github.com/ralvares/claude-security-skills
cp -R claude-security-skills/skills/owasp ~/.claude/skills/
```

Then make the rules always on. Copy `SECURITY-RULES.md` to `~/.claude/SECURITY.md` and add this line to `~/.claude/CLAUDE.md`:

```
@SECURITY.md
```

Check it in Claude Code: `/owasp` should appear in the skill list.

## Permissions

The sheets live outside your projects, and Claude Code asks before reading files outside the working directory. The skill grants itself read access to its own `sheets/` folder and nothing else:

```yaml
allowed-tools: Read(/${CLAUDE_SKILL_DIR}/sheets/**)
```

Because the skill grants a permission, Claude Code asks you once to allow the skill itself. Choose "don't ask again" and the sheets load silently from then on.

Headless runs (`claude -p`, CI, scripts) cannot answer that question. Allow the skill up front, either per run:

```bash
claude -p "..." --allowedTools "Skill(owasp)"
```

or for every session, in `~/.claude/settings.json`:

```json
{ "permissions": { "allow": ["Skill(owasp)"] } }
```

This allows only running this skill. It grants no other file or tool access.

## How it is used

Claude matches the task against the skill description and invokes `owasp` on its own; you can also type `/owasp`. The skill body is a set of tables (design, identity, injection, APIs, front end, data and crypto, AI features, logging, supply chain, languages). Claude picks the matching rows, reads those sheets, and names them in the plan.

The sheets quote attack payloads as examples. The skill tells Claude to treat them as reference data, never as instructions.

## Format

The sheets and rules are written in telegraphic style (no articles or filler, terse bullets) to cut tokens. Headings, code blocks, inline code and every number are kept exactly as OWASP published them; reference link lists and external URLs are dropped. `scripts/check-index.sh` confirms every sheet is listed in `SKILL.md`; `scripts/check-rules.sh` confirms every sheet is cited in `SECURITY-RULES.md` and the file stays under 24 KB.

## Updates

There is no automatic sync with OWASP. To take a newer OWASP sheet, rewrite it by hand in the same style and update `skills/owasp/NOTICE.md`.

## License

[CC BY-SA 4.0](LICENSE), the license of the OWASP Cheat Sheet Series. The sheets are the work of the OWASP Foundation and contributors; `skills/owasp/NOTICE.md` lists the source commit and the changes made.
