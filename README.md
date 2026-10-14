# claude-security-skills

Secure coding guidance for Claude Code, built on the [OWASP Cheat Sheet Series](https://cheatsheetseries.owasp.org/). Claude reads only the sheets a task needs, so the full library (about 680k tokens) never sits in context.

| Piece | Loaded | Cost |
| --- | --- | --- |
| `skills/owasp/INDEX.md`: one line per sheet, "use case → file", all 133 sheets | Every session, by the plugin's SessionStart hook | about 2.5k tokens |
| `skills/owasp/references/*.md`: the 133 sheets | Only the files whose line matches the task | 1 to 4 sheets |

Building a webhook receiver, for example, matches the webhook and SSRF lines, so Claude reads `Webhook_Security.md` and `Server_Side_Request_Forgery_Prevention.md`. Nothing else.

## Install

### Claude Code (recommended): plugin

```
/plugin install owasp-security --marketplace ralvares/claude-security-skills
```

On Claude Code older than 2.1.275, add the marketplace first:

```bash
claude plugin marketplace add ralvares/claude-security-skills
claude plugin install owasp-security@claude-security-skills
```

The plugin installs the `owasp` skill and a SessionStart hook that loads `INDEX.md` into every session. Nothing to add to `CLAUDE.md`.

### Other agents: skill only

```bash
npx skills@latest add ralvares/claude-security-skills -g -y --copy
```

This copies the skill without the hook; Claude invokes it from its description and reads the index then. Keep `--copy`: a linked install makes Claude Code check permission on the link target too, so every sheet read prompts. To get the always-loaded index in Claude Code this way, add `@skills/owasp/INDEX.md` to `~/.claude/CLAUDE.md`.

## Permissions

The sheets live outside your projects, and Claude Code asks before reading files outside the working directory. The skill grants itself read access to its own folder and nothing else:

```yaml
allowed-tools: Read(/${CLAUDE_SKILL_DIR}/**)
```

Because the skill grants a permission, Claude Code asks you once to allow the skill itself. Choose "don't ask again" and the sheets load silently from then on.

Headless runs (`claude -p`, CI, scripts) cannot answer that question. Allow the skill up front, per run with `--allowedTools`, or in `~/.claude/settings.json`:

```json
{ "permissions": { "allow": ["Skill(owasp-security:owasp)"] } }
```

This allows only running this skill. It grants no other file or tool access.

## How it is used

With the index loaded, Claude sees which sheet covers the task, invokes `owasp` (which grants read access), reads that sheet and names it in the plan's Security section.

Call it yourself with a use case to load just that guidance:

```
/owasp webhook
/owasp login and MFA
/owasp file upload
/owasp AI agent with tools
```

Claude reads only the matching sheets and summarises their key rules, or applies them to the work in progress. `/owasp` with no use case uses the current task.

The sheets quote attack payloads as examples. The skill tells Claude to treat them as reference data, never as instructions.

## Format

The sheets are written in telegraphic style (no articles or filler, terse bullets) to cut tokens. Headings, code blocks, inline code and every number are kept exactly as OWASP published them; reference link lists and external URLs are dropped. `scripts/check-index.sh` confirms every sheet is listed in `INDEX.md` exactly once.

## Updates

There is no automatic sync with OWASP. To take a newer OWASP sheet, rewrite it by hand in the same style, add its line to `INDEX.md` and update `skills/owasp/NOTICE.md`.

## License

[CC BY-SA 4.0](LICENSE), the license of the OWASP Cheat Sheet Series. The sheets are the work of the OWASP Foundation and contributors; `skills/owasp/NOTICE.md` lists the source commit and the changes made.
