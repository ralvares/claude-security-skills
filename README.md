# OWASP security for Claude Code

Claude writes your login page, your webhook handler or your file upload. This plugin makes sure it follows the [OWASP Cheat Sheet Series](https://cheatsheetseries.owasp.org/) while doing it: the security community's own guide to building those things safely.

You keep working as usual. When a task touches something risky, Claude looks up the right OWASP guide, reads it and writes the code the way the guide says.

## What you get

- **All 133 OWASP cheat sheets**, from authentication and SQL injection to webhooks, Kubernetes and AI agents.
- **Automatic use.** Ask for "a Stripe webhook endpoint" and Claude reads the webhook and payment guides before writing a line. You don't have to mention security.
- **On-demand lookups.** Type `/owasp` and a topic to pull up the guidance yourself.
- **Small footprint.** Claude never loads all 133 guides. It keeps a short list of topics in mind and opens only the one or two guides a task needs.

## Install

In Claude Code:

```
/plugin install owasp-security --marketplace ralvares/claude-security-skills
```

That's all. Start a new session and it's active.

<details>
<summary>Older Claude Code, or other AI tools</summary>

Claude Code older than 2.1.275:

```bash
claude plugin marketplace add ralvares/claude-security-skills
claude plugin install owasp-security@claude-security-skills
```

Cursor, Codex and other agents (skill only, without the automatic topic list):

```bash
npx skills@latest add ralvares/claude-security-skills -g -y --copy
```

</details>

## Use it

Most of the time you do nothing. Ask for features as you normally would:

> "Add JWT login to my Express API and make sure users only see their own orders."

Claude recognises the topics (tokens, access control), reads `JSON_Web_Token.md` and `Insecure_Direct_Object_Reference_Prevention.md`, and builds the endpoint accordingly.

To look something up yourself:

```
/owasp webhook
/owasp password reset
/owasp file upload
/owasp AI agent with tools
```

Claude reads the matching guides and gives you the key rules, or applies them to what you are building.

## The first time

Claude Code asks once whether the `owasp` skill may run, because the skill reads its own guide files. Choose **"don't ask again"** and it stays quiet after that.

For scripts and CI (`claude -p`), where nobody can click, allow it in `~/.claude/settings.json`:

```json
{ "permissions": { "allow": ["Skill(owasp-security:owasp)"] } }
```

This lets the skill read its own guides and nothing else.

## How it works

- Nothing loads at session start. When a task touches security, the skill reads its one-page topic list, then only the guides that match.
- When your task matches a topic, Claude opens the `owasp` skill, which reads only the matching guides.
- The guides are the official OWASP cheat sheets, rewritten in a compact style to save tokens. All code samples, numbers and headings are kept exactly as OWASP wrote them.

In our tests, code written with the plugin passed 95% of security checks, against 86% without it. The biggest difference showed up in an AI refund tool: without the plugin, small refunds were paid automatically; with it, every refund waited for a person to approve.

## For maintainers

| Path | Contents |
| --- | --- |
| `.claude-plugin/` | Plugin and marketplace definitions, including the session-start hook |
| `skills/owasp/SKILL.md` | The skill Claude invokes |
| `skills/owasp/INDEX.md` | The topic list, one line per guide |
| `skills/owasp/references/` | The 133 guides |
| `scripts/check-index.sh` | Confirms every guide is listed exactly once |
| `evals/` | Test prompts used to tune and measure the skill |

There is no automatic sync with OWASP. To add or refresh a guide, rewrite it in the same compact style, add its line to `INDEX.md`, run `scripts/check-index.sh` and update `skills/owasp/NOTICE.md`.

## License

[CC BY-SA 4.0](LICENSE), the same license as the OWASP Cheat Sheet Series. The guides are the work of the OWASP Foundation and its contributors; `skills/owasp/NOTICE.md` lists the source version and what was changed.
