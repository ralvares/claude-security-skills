# MCP (Model Context Protocol) Security Cheat Sheet

## Introduction

Model Context Protocol (MCP), introduced by Anthropic in November 2024, standardizes how AI applications (LLM clients) connect to external tools, data sources, services. Universal interface layer, "USB-C port for AI", replacing fragmented custom integrations with single protocol.

MCP introduces fundamentally new attack surface: AI agents dynamically executing tools based on natural language, with access to sensitive systems. Unlike traditional APIs where developers control every call, MCP lets LLMs decide which tools to invoke, when, with what parameters. Creates unique risks combining prompt injection, supply chain attacks, confused deputy problems.

Best practices to secure MCP deployments, minimize attack surfaces across clients, servers, connections between them.

## Architecture Overview

```
User ↔ MCP Host (AI App) ↔ MCP Client ↔ MCP Server(s) ↔ Tools / Data / APIs
```

- **MCP Host**: AI application (e.g., Claude Desktop, Cursor, IDE plugins).
- **MCP Client**: Connects to one or more MCP servers, passes tool definitions to LLM.
- **MCP Server**: Lightweight program exposing tools, resources, prompts via protocol.
- **Transports**: `stdio` (local) or Streamable HTTP (remote). Older HTTP+SSE transport deprecated. See Streamable HTTP specification.

LLM sees all tool descriptions from all connected servers in its context — critical for understanding cross-server attacks.

## Key Risks

- **Tool Poisoning**: Malicious instructions hidden in tool descriptions, parameter schemas, return values manipulate LLM behavior.
- **Rug Pull Attacks**: Server changes tool definitions after initial user approval, turning trusted tool malicious.
- **Tool Shadowing / Cross-Origin Escalation**: Malicious server's tool description manipulates agent behavior with tools from *other* trusted servers.
- **Confused Deputy Problem**: MCP server executes actions with own (often broad) privileges, not requesting user's permissions.
- **Data Exfiltration via Legitimate Channels**: Attackers use prompt injection to encode sensitive data into seemingly normal tool calls (e.g., search queries, email subjects).
- **Excessive Permissions / Over-Scoped Tokens**: MCP servers request broad OAuth scopes (full Gmail access vs. read-only) → aggregation risk.
- **Supply Chain Attacks**: Untrusted/compromised MCP server packages installed from public registries without review.
- **Message Tampering and Replay**: JSON-RPC payloads modified after TLS termination by compromised proxies/middleware, or captured and re-sent to duplicate actions.
- **Sandbox Escapes**: Local MCP servers with full host access enable file system traversal, credential theft, arbitrary code execution.

## Best Practices

### 1. Principle of Least Privilege

- Grant each MCP server minimum permissions needed for its function.
- Scoped, per-server credentials — never share tokens across servers.
- Request narrow OAuth scopes (e.g., `mail.readonly` instead of `mail.modify` or `mail.full_access`).
- Prefer ephemeral, short-lived tokens over long-lived PATs.

### 2. Tool Description & Schema Integrity

- Inspect all tool descriptions, parameter names, types, return schemas before approval.
- Treat *entire* tool schema as potential injection surface — not just `description` field.
- Pin reviewed tool definitions using cryptographic hashes; require review when they change. Detects metadata changes, not changes to server code/behavior behind unchanged definition; tool annotations are hints, not enforcement.
- Use tools like `mcp-scan` to automatically detect poisoned descriptions and cross-server shadowing.
- Strict JSON Schema for tool parameters: set `additionalProperties: false`, use `pattern` (or similar) on string fields so only declared parameters and valid formats accepted.

### 3. Sandbox and Isolate MCP Servers

- Run local MCP servers in sandbox enforcing minimal privileges and host resource access, following MCP local-server guidance. Bare `chroot` is not a process sandbox.
- Restrict file system access to required directories only.
- Disable network access unless explicitly needed.
- Use `stdio` for local MCP communication through launched process's standard streams. Avoids listening MCP endpoint; doesn't restrict server process's file system, network, or credential access.
- Separate sensitive servers (payment, auth, PII) from general-purpose ones.

### 4. Human-in-the-Loop for Sensitive Actions

- Require explicit user confirmation for destructive, financial, data-sharing operations.
- Display full tool call parameters to user — not just summary name.
- Never auto-approve tool calls, esp. in multi-server setups.
- Ensure confirmation UI can't be bypassed by LLM-crafted responses.

### 5. Input and Output Validation

- Validate all inputs to MCP server tools — untrusted (originate from LLM output influenced by potentially malicious context).
- Sanitize inputs against injection attacks (SQL, OS command, path traversal).
- Validate + sanitize tool outputs before returning to LLM context — output often used as input by other tools; unsanitized can cause downstream SSRF or command injection.
- Never pass raw shell commands or unsanitized file paths.
- Protect against SSRF: MCP tools fetching URLs from LLM-generated parameters can be manipulated via prompt injection to access internal services (e.g., cloud metadata endpoints). Never fetch arbitrary LLM-provided URLs without strict allowlist validation.

### 6. Authentication, Authorization & Transport Security

- Require authentication when remote endpoints expose non-public tools/data. Authorization optional in protocol; see MCP authorization specification.
- OAuth over HTTP: follow MCP OAuth 2.1 profile. Clients MUST identify intended MCP server with `resource` parameter. See resource indicators.
- Validate each access token issued for this MCP server as intended audience. Reject invalid tokens; never pass MCP access token to upstream API. See token handling.
- Validate authorization on every protected request. Current Streamable HTTP transport has no protocol-level sessions. Supporting older session-based revisions: random session IDs, bind to authenticated user, never treat ID as authentication; see legacy session guidance.
- TLS for remote Streamable HTTP connections.
- Verify server identity via certificate pinning or cryptographic server verification for remote servers.
- Apply resource controls (rate limits, quotas, timeouts) per session or tenant to resist DoS, limit abuse impact; combine with sandboxing to contain local escape impact.
- Use OS-native secure credential storage (macOS Keychain, Windows Credential Manager, Linux Secret Service) for OAuth access + refresh tokens.
- Never store OAuth tokens in plaintext in MCP config files or application settings.
- Bind local Streamable HTTP servers to localhost unless network access explicitly needed. See transport security rules.
- Validate `Origin` header on incoming Streamable HTTP requests. Reject present-but-invalid Origin with HTTP 403. Don't reject non-browser clients solely for sending no Origin header. See transport security rules.
- Validate Host header on incoming requests; reject unexpected hostnames.

### 7. Optional Message-Level Integrity

TLS protects messages in transit, but component changing data after TLS termination is separate threat. Core MCP transport specification doesn't require signing every JSON-RPC message. MCPS Internet-Draft proposes separate signing + replay-protection layer; individual work in progress, not adopted MCP standard.

Threat model calls for integrity after TLS termination → choose reviewed mechanism supported by both endpoints. Define how keys trusted, what signed, how replay rejected, what happens when verification fails. Don't present optional signing as requirement for ordinary MCP deployments.

### 8. Multi-Server Isolation & Cross-Origin Protection

- Treat each MCP server as untrusted, independent security domain.
- Prevent tool descriptions from one server referencing/modifying behavior of tools from another.
- Monitor cross-server data flows (e.g., credentials from server A appearing in calls to server B).
- Use MCP proxy/gateway to enforce isolation policies between servers.

### 9. Supply Chain Security

- Install MCP servers only from trusted, verified sources.
- Review server source code + tool definitions before installation.
- Verify package integrity with checksums or code signing.
- Scan MCP server dependencies for known vulnerabilities.
- Monitor changes to tool descriptions post-installation (rug pull detection).
- Carefully verify package names before installation — typosquatting (e.g., mcp-server-filesystem vs mcp-server-filesytem) common attack vector.
- Use tools like `mcp-scan` to automatically analyze/monitor installed servers for malicious behavior or changes.

### 10. Monitoring, Logging & Auditing

- Log all MCP tool invocations with full parameters, user context, timestamps.
- Feed MCP logs into SIEM for anomaly detection.
- Alert on unusual patterns: new tools called, admin-level queries, abnormal call frequency.
- Redact secrets + PII from logs.
- Regular security audits + simulated attacks against MCP setups.
- Logs from component you didn't build: see [Verifying Third-Party Agent Execution Evidence Cheat Sheet](Verifying_Third_Party_Agent_Execution_Evidence.md) for judging what such record establishes.

### 11. Consent & Installation Security

- Clear consent dialog before connecting any new MCP server.
- Show exact command to be executed (local servers), without truncation.
- Clearly identify source + publisher of MCP server.
- Re-prompt for consent when tool definitions change.
- Never allow web content or untrusted data to trigger MCP server installation.

### 12. Prompt Injection via Tool Return Values

- Treat every tool response as **untrusted data**, incl. responses from approved servers.
- Separate and clearly label tool data in model context; instruct model to treat as data not instructions.
- Tag stripping + instruction-pattern detection only as additional filtering/alerting. Can't establish remaining text safe; OWASP describes encoded and multilingual prompt injections evading filters.
- Enforce authorization and validate subsequent tool calls in trusted application code, independent of model's interpretation. Apply [least privilege](#1-principle-of-least-privilege) and [human approval for sensitive actions](#4-human-in-the-loop-for-sensitive-actions).
- Web-scraping/retrieval tools: extract required structured data instead of passing raw HTML. Text inside structured fields remains untrusted.

## Do's and Don'ts

**Do**:

- Enforce least privilege per MCP server and per tool.
- Inspect and pin all tool descriptions + schemas.
- Sandbox local MCP servers in containers or restricted environments.
- Require human approval for sensitive/destructive tool calls.
- Validate all inputs + outputs at MCP server layer.
- Use `mcp-scan` or equivalent tooling to detect poisoned tools.
- Log + monitor all tool invocations centrally.
- Verify MCP server sources, scan dependencies.
- Validate Origin of Streamable HTTP requests and audience of OAuth access tokens.
- Pin tool definitions with cryptographic hashes; verify before each execution.

**Don't**:

- Auto-approve tool calls without showing full parameters to user.
- Trust tool descriptions blindly — prompt injection vector.
- Share OAuth tokens/credentials across MCP servers.
- Run MCP servers with full host access or `*` permissions.
- Install MCP servers from unverified public registries without review.
- Assume tool approved yesterday is same tool today (rug pulls).
- Ignore cross-server interactions — shadowing attacks are real.
- Store secrets in source code, plaintext config files, logs.
- Treat optional message signing as core MCP requirement.
- Accept server public keys from unverified first-contact responses (TOFU without pinning).

## References

- MCP: Security Best Practices
- MCP: Authorization
- MCP: Streamable HTTP
