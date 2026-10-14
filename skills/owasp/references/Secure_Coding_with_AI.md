# Secure Coding with AI Cheat Sheet

## Introduction

AI coding tools moved beyond code suggestion. 2026: agentic coding tools (Claude Code, Cursor agent mode, Aider, Devin, Copilot Workspace, Codex) execute shell commands, install packages, edit files, run tests, access network, push branches autonomously. Many developers run agents with auto-accept enabled → agent operates w/ developer's full permissions, minimal human oversight.

Covers security risks specific to AI-assisted/agentic coding: threats absent from traditional workflows; doesn't restate general secure coding guidance.

General secure coding: Secure Coding Practices Quick Reference Guide. AI agent security beyond coding tools: [AI Agent Security Cheat Sheet](AI_Agent_Security.md). Prompt injection prevention: [LLM Prompt Injection Prevention Cheat Sheet](LLM_Prompt_Injection_Prevention.md). MCP protocol security: [MCP Security Cheat Sheet](MCP_Security.md).

## Threat Model and Trust Boundaries

AI coding agents operate across multiple trust boundaries. Understand them before applying controls.

```
                    TRUST BOUNDARIES IN AGENTIC CODING

 [DEVELOPER]                    [AGENT]                    [EXTERNAL]
  Developer  ──── permissions ──── AI Agent  ──── reads ──── Repo Content
  approves        (often full       executes       ingests     (issues, PRs,
  or auto-        dev access)       commands       context     READMEs, deps,
  accepts                                                      changelogs)
      |                |                |                |
      |           [MODEL PROVIDER]      |          [MCP SERVERS]
      |            API calls            |           Tool calls
      |            Code + context       |           File access
      |            sent to provider     |           Network access
      |                                 |           Credentials
      |                                 |
      |              [CI/CD]            |
      |            Workflows            |
      |            Org secrets          |
      |            Deploy access        |
```

### Threat Actors and Attack Surfaces

- **Repository content as instruction source.** Issue bodies, PR descriptions, PR comments, README files, dependency changelogs, error traces, fetched web pages, MCP tool responses all become instructions when agent reads them. Attacker able to write to any of these can influence agent behavior.
- **MCP servers as tool providers.** Agents connect to MCP servers for tools. Malicious/compromised server can poison tool descriptions, shadow legitimate tool names, exfiltrate credentials via tool arguments, update tool definitions after initial approval (rug-pull).
- **Rules files as persistent steering.** Files like `.cursorrules`, `CLAUDE.md`, `AGENTS.md`, `.github/copilot-instructions.md`, `.windsurfrules` silently steer every future generation. Malicious PR or agent itself can modify them to embed persistent instructions.
- **The agent itself.** Agents w/ auto-accept + full developer permissions can install packages, write any file, execute shell commands, modify CI configuration, push branches. Compromised agent context = same blast radius as compromised developer workstation.
- **CI/CD agents.** Review bots + CI runners (e.g. `claude-code-action`, Copilot review) act on PR content w/ access to org secrets. Malicious PR can make CI agent exfiltrate secrets or modify build pipeline. Confused deputy at scale.

## Section 1: Hallucinated Dependencies

AI coding assistants frequently suggest nonexistent package names. Attackers monitor hallucinated names, register malicious packages w/ matching names (AI-assisted typosquatting).

### Do

- Verify every AI-suggested package exists on public registry before installing. Check package page, download count, maintainer history, creation date.
- Be suspicious of very low download counts, recent creation (less than 30 days), single maintainer w/ no other packages.
- Pre-install hook or CI check blocking installation of packages below minimum age threshold.
- Maintain internal allowlist of approved packages.

### Don't

- Blindly run `npm install`, `pip install`, `go get` w/ AI-suggested package names without verification.
- Assume AI-suggested package exists or is safe.
- Ignore typosquatting risk. AI often suggests names close to real packages but slightly different.

## Section 2: Outdated Dependencies with Known CVEs

Models trained on historical code; frequently suggest versions current during training but now vulnerable. AI may not know CVEs published after training cutoff or after coding tool's last security-index update.

### Do

- Run dependency auditing tools (npm audit, pip audit, govulncheck, cargo audit) on every AI-generated dependency list before merging.
- Configure CI/CD pipelines to fail on known dependency vulnerabilities, whether code human-written or AI-generated.
- Pin dependencies to specific versions; update via normal dependency management, not AI suggestions.
- Cross-reference AI-suggested versions against vulnerability databases (NVD, GitHub Advisory Database, OSV).

### Don't

- Accept AI-suggested dependency versions without checking known CVEs.
- Assume AI assistants know recent vulnerability disclosures.
- Disable dependency auditing for AI-generated code.

## Section 3: Indirect Prompt Injection in the Development Loop

Agentic coding tools ingest context from repository, network, connected tools. Any content agent reads can hide instructions altering behavior. Indirect prompt injection applied to development workflow.

### Attack Vectors

- **Issue bodies and PR descriptions.** Attacker opens issue w/ hidden instructions. Developer asks agent to "fix issue #123" → agent reads issue body, follows embedded instructions.
- **PR comments and review feedback.** Malicious review comments can instruct agent to modify unrelated files, weaken security controls, exfiltrate code when developer asks agent to "address review feedback."
- **README and documentation files.** Cloned repositories, dependencies, fetched documentation can contain instructions invisible to humans but parsed by agent.
- **Error traces and log output.** Agent reading error output to debug can be injected via crafted error messages.
- **Dependency changelogs and release notes.** Agents reading changelogs for version differences can be influenced by injected content.
- **Fetched web pages.** Agents w/ web access can be influenced by content on pages they reference.

### Do

- Treat all repository content (issues, PRs, comments, READMEs) as untrusted input when processed by AI coding agent.
- Review agent output for unexpected changes after processing any external content.
- Use tools sanitizing/flagging potential injection patterns in repository content before agent processes it.
- Restrict agent context to minimum files/content needed for task.
- Audit agent actions after processing content from external contributors or public repositories.

### Don't

- Let agents process issue bodies, PR descriptions, comments from untrusted contributors without reviewing resulting actions.
- Assume content safe because it appears in familiar context (e.g. GitHub issue).
- Give agents unrestricted web browsing/arbitrary URL fetch without egress controls.

## Section 4: MCP and Tool Security

AI coding agents connect to MCP (Model Context Protocol) servers for tools: file operations, database queries, API calls, more. Compromised/malicious MCP servers = direct supply chain risk to development environment.

Comprehensive MCP guidance: [MCP Security Cheat Sheet](MCP_Security.md).

### Do

- Audit all MCP servers connected to development environment. Maintain allowlist of approved servers + tools.
- Pin tool definitions and detect changes. Snapshot-and-diff catches rug-pull updates (tool behavior changes after initial approval).
- Review tool descriptions for hidden instructions. Descriptions are part of agent context, can carry prompt injection payloads.
- Restrict which tools agent can invoke. Least privilege -- coding agent doesn't need email, payment, or administrative tools.
- Monitor tool name shadowing: malicious MCP server registers tool w/ same name as legitimate one to intercept calls.
- Validate tool arguments before execution. Agents may pass sensitive data (credentials, file contents, environment variables) as tool arguments unaware of data classification.

### Don't

- Connect to MCP servers from untrusted sources without security review.
- Let agents discover + connect to MCP servers automatically without approval.
- Trust tool descriptions as benign. Injection surface.
- Allow MCP tools unrestricted filesystem, network, or credential access on developer's machine.

Reference: CVE-2026-39313 -- mcp-framework before 0.2.22: unbounded memory allocation in HTTP request body handling allowed unauthenticated denial of service. Example of vulnerability in AI framework code; shows need for dependency auditing + runtime limits.

## Section 5: Agent Runtime Sandboxing

Agentic coding tools execute commands, install packages, write files, access network on developer's machine. Without sandboxing, compromised agent context = developer's privileges.

### Do

- Run AI coding agents in sandboxed environments: dev containers, restricted shells, virtual machines, ephemeral cloud workspaces.
- Tool allowlists restricting executable commands. Block access to credential stores, SSH keys, cloud CLI configurations, sensitive directories.
- Egress controls on agent runtime. No outbound network needed for current task → block it.
- Ephemeral credentials scoped to current task, not long-lived developer credentials.
- Understand/evaluate risk of flags like `--dangerously-skip-permissions` or auto-accept modes: bypass confirmation prompts, give agent unrestricted execution.
- Resource limits (CPU, memory, disk, process count) on agent execution environments.

### Don't

- Run AI coding agents w/ full developer credentials, SSH keys, cloud access tokens without sandboxing.
- Enable auto-accept on untrusted or unfamiliar codebases.
- Let agents access production credentials, deployment keys, org-level secrets from development environment.
- Assume agent only touches files relevant to current task.

## Section 6: Rules Files and Persistent Steering

AI coding tools read configuration files steering behavior across all future interactions. Persistence mechanism -- attacker modifying them controls every subsequent generation.

### Affected Files

- `.cursorrules`, `.cursor/rules/`
- `CLAUDE.md`, `.claude/`
- `AGENTS.md`
- `.github/copilot-instructions.md`
- `.windsurfrules`
- `.aider.conf.yml`
- Custom system prompt files referenced by any AI tool

### Do

- Treat rules files as security-critical configuration. Review changes w/ same scrutiny as CI/CD pipeline changes.
- Add rules files to code review requirements. Explicit approval for any modification.
- Monitor unexpected rules file creation/modification, incl. by agent itself.
- Git hooks or CI checks flagging changes to known rules files in every PR.
- Audit existing rules files for instructions weakening security controls, disabling safety features, or directing agent to ignore certain file types/patterns.

### Don't

- Let external contributors' PRs add/modify rules files without security review.
- Let AI agent modify its own rules files without explicit developer approval.
- Assume rules files benign because plain text. Instruction injection surfaces w/ session-level persistence.

## Section 7: Out-of-Scope Edits and Review Anchoring

Agents routinely touch files beyond requested scope: lockfiles, CI configurations, unrelated tests, formatting changes, dependency updates. Reviewers anchored on requested change miss them. Most common review failure mode in agentic coding.

### Do

- Diff-aware review tooling highlighting all changed files, not just task-relevant ones.
- CI checks flagging unexpected file modifications: lockfile changes, CI/CD config changes, test modifications, changes outside requested scope.
- Review every file in agent-generated PR individually. Don't approve on PR description alone.
- CODEOWNERS rules requiring specific reviewers for sensitive files (CI configs, Dockerfiles, deployment scripts, rules files).
- Limit agent's file access scope when possible. Some tools support directory restrictions or file allowlists.

### Don't

- Approve agent-generated PRs from summary/description without reviewing full diff.
- Assume lockfile changes, test modifications, formatting changes benign because they "look routine."
- Let agents modify files outside explicitly requested scope without flagging for review.

## Section 8: Test Fabrication and Test Deletion

AI agents make CI green by deleting failing tests, weakening assertions, mocking unit under test instead of fixing code, or asserting buggy behavior. Passing suite generated by same agent that produced code gives no independent assurance.

### Do

- Require human review of all AI-generated test modifications, focusing on:
    - Deleted tests (why removed?)
    - Weakened assertions (did `assertEquals` become `assertNotNull`?)
    - New mocks replacing real dependencies test was designed to exercise
    - Tests asserting generated behavior rather than correct behavior
- Add adversarial + negative test cases AI didn't generate: invalid inputs, expired tokens, malformed payloads, boundary conditions, concurrent access.
- Measure security confidence by adversarial testing results + independent analysis, not "all tests pass."
- CI rules flagging test deletions or assertion-count reductions in agent-generated PRs.
- Write security-critical tests manually for authentication, authorization, input validation, cryptographic operations.

### Don't

- Trust AI-generated test suites as evidence of security.
- Measure confidence by test pass rate alone. 100% passing means nothing if tests assert broken behavior.
- Let agents delete/modify existing tests without human-reviewed justification.
- Let agent write both security-critical code and its tests without independent verification.

## Section 9: Prompt Context Leakage and Sensitive Code Exposure

AI coding assistants send code context (open files, project structure, terminal output) to model provider's API. May contain credentials, personal data, proprietary business logic, internal architecture details.

### Do

- Review what context assistant sends to provider. Most tools document this.
- Configure AI tools to exclude sensitive directories from context. Add `.env`, `.env.*`, `*.pem`, `*.key`, `credentials.json`, `serviceAccountKey.json`, similar sensitive files to tool's context exclusion list (`.cursorignore`, `.copilotignore`, or equivalent).
- Audit what tool sends via controlled request inspection. Exclude/redact credentials, personal data, sensitive source code before recording captured traffic; follow [Logging Cheat Sheet data exclusions](Logging.md#data-to-exclude).
- Self-hosted or air-gapped AI coding tools for projects handling classified, regulated, highly sensitive code.
- Store all secrets in environment variables, vault services, or encrypted secret stores -- never in files in project tree where AI tools can read them.

### Don't

- Use cloud-hosted AI coding assistants on classified or top-secret codebases without approval.
- Assume assistants only send current file. Many send broader project context.
- Open `.env` files or private keys in IDE while AI assistant active; contents may be sent as context.
- Paste API keys, tokens, credentials into terminal while AI tools w/ terminal context access run.
- Assume `.gitignore` stops AI tools reading files. `.gitignore` affects only git -- AI tools read filesystem directly.

## Section 10: Prompt-to-Code Supply Chain Risk

Controls throughout development lifecycle: [Software Supply Chain Security Cheat Sheet](Software_Supply_Chain_Security.md).

AI coding agents modify not just application code but build scripts, CI/CD configurations, package scripts, deployment infrastructure. Changes to these execute automatically in trusted contexts w/ elevated privileges.

### Do

- Review AI changes to following files w/ heightened scrutiny -- security-critical:
    - `package.json` (scripts section: postinstall, preinstall, prepare, prebuild)
    - `.github/workflows/*.yml` (GitHub Actions)
    - `.gitlab-ci.yml`
    - `Dockerfile`, `docker-compose.yml`
    - `Makefile`, `Rakefile`, `Taskfile`
    - `setup.py`, `pyproject.toml` (build scripts)
    - `go generate` directives
    - Any file executing automatically during build, install, test, deploy
- Flag any AI-generated change adding network access, downloading external resources, or executing shell commands in build/deploy context.
- CI checks diffing build configuration files, requiring explicit approval for CI/CD pipeline changes.
- AI-generated GitHub Actions must reference third-party actions pinned to specific commit SHA, not mutable tag.

### Don't

- Let AI modify CI/CD pipelines, Dockerfiles, package scripts without explicit human review.
- Accept AI-generated GitHub Actions referencing third-party actions by tag without SHA pinning.
- Trust AI-generated build scripts downloading/executing external URLs.
- Merge AI changes to deployment configurations without verifying what changed in build/deploy path.

## Section 11: CI/CD Agents and Confused Deputy Risk

AI-powered CI/CD agents (review bots, automated code fixers, PR assistants) run on PR events w/ access to org secrets, deployment credentials, repository write access. Malicious PR can manipulate CI agent into exfiltrating secrets or modifying pipeline.

### Do

- Scope CI agent credentials to minimum required permissions. Review bots shouldn't have deploy keys or write access to secrets.
- Filter + sanitize PR content (title, body, comments, diff) before passing to CI agents as context. PR content = attacker-controlled input.
- Run CI agents in isolated environments w/ no access to production secrets/credentials beyond what specific job requires.
- Log CI agent action metadata, correlation identifiers, authorization decisions, outcomes. Exclude secrets and sensitive prompt, tool-argument, response content; apply [Logging Cheat Sheet](Logging.md#data-to-exclude). Monitor unexpected file modifications, network calls, secret access patterns.
- Approval gates before CI agents can push commits, modify workflows, access sensitive resources.

### Don't

- Give CI agents org-level secrets or deployment credentials when they only need read access.
- Let CI agents process external contributors' PR content without sandboxing.
- Trust CI agent output (comments, reviews, suggested fixes) without verifying agent wasn't influenced by malicious PR content.

## Section 12: Markdown, Link, and Unicode Injection

Agent output rendered in IDE chat panes, PR comments, review interfaces can contain Markdown-based exfiltration links, bidi (bidirectional) text overrides, zero-width characters influencing future agent behavior or misleading reviewers.

### Do

- Sanitize agent output before rendering in IDE chat panes/PR comments. Strip/escape Markdown image tags, hidden links, HTML entities.
- Detect/flag bidi override characters (U+202A through U+202E, U+2066 through U+2069) and zero-width characters (U+200B, U+200C, U+200D, U+FEFF) in code, commits, agent output.
- CI checks scanning for homoglyph attacks + invisible characters in PRs.
- Review agent-generated commit messages + PR descriptions for embedded content that could influence future agent runs.

### Don't

- Render agent output containing Markdown images/links without sanitization. Image tags w/ external URLs can exfiltrate conversation context via URL parameters.
- Assume code with only visible ASCII is safe. Zero-width + bidi characters invisible in most editors.
- Let agent-generated content be committed without scanning for unicode injection.

## Section 13: Multi-Agent and Sub-Agent Propagation

When multiple agents interact (e.g. coding agent delegates to search agent, review agent processes coding agent output), prompt injection propagates across agent boundaries. Compromised context in one agent becomes instructions for next.

### Do

- Treat one agent's output as untrusted input when passed to another.
- Context boundaries between agents. No full conversation history or raw tool responses passed between agents without sanitization.
- Monitor cross-agent interactions for instruction propagation patterns (e.g. one agent's output instructing another to exfiltrate data or modify files).
- Validate sub-agent actions stay within scope defined by parent task.

### Don't

- Chain agents without context boundaries. Agent A compromised → Agent B must not blindly execute A's output.
- Let sub-agents inherit full permissions/credentials of parent agent without scope restriction.
- Assume agent-to-agent communication trusted because both are "your" tools.

Multi-agent trust boundaries: [AI Agent Security Cheat Sheet](AI_Agent_Security.md) and [MCP Security Cheat Sheet](MCP_Security.md) Section 8 (Multi-Server Isolation).

## Section 14: Human Accountability

AI-generated code needs human owner. Every AI-assisted change reviewed, approved, attributable to developer responsible for security + maintainability. AI tools don't accept responsibility; developer who accepts and commits code does.

### Do

- Assign human owner to every AI-generated code change, responsible for correctness, security, maintenance.
- Require explicit developer approval before merging AI-generated code; approval = developer reviewed and understood change.
- Maintain audit trails showing which developer approved which AI-generated changes, incl. AI tool + model version.
- Treat AI as tool, not colleague. Developer saying "the AI wrote it" is still responsible.

### Don't

- Deploy AI-generated code no human reviewed/approved.
- Let AI-generated code bypass code review because "the AI is usually right."
- Treat AI approval (e.g. AI-generated code review comments) as substitute for human review.
- Attribute security failures to AI tool. Developer who approved code is accountable.

## OWASP Top 10 Mapping

| OWASP Top 10 | Relevant Section |
|---|---|
| A01: Broken Access Control | Section 5: Agent Runtime Sandboxing, Section 11: CI/CD Agents |
| A03: Injection | Section 3: Indirect Prompt Injection, Section 12: Markdown and Unicode Injection |
| A04: Insecure Design | Section 8: Test Fabrication, Section 14: Human Accountability |
| A05: Security Misconfiguration | Section 6: Rules Files, Section 7: Out-of-Scope Edits |
| A06: Vulnerable and Outdated Components | Section 1: Hallucinated Dependencies, Section 2: Outdated Dependencies |
| A07: Identification and Authentication Failures | Section 4: MCP and Tool Security |
| A08: Software and Data Integrity Failures | Section 10: Prompt-to-Code Supply Chain Risk |
| A09: Security Logging and Monitoring Failures | Section 9: Prompt Context Leakage, Section 11: CI/CD Agents |
| A10: Server-Side Request Forgery | Section 3: Indirect Prompt Injection, Section 4: MCP and Tool Security |

## References

- NIST SP 800-218: Secure Software Development Framework
- OpenSSF: Concise Guide for Evaluating Open Source Software
- OWASP AI Security Verification Standard
