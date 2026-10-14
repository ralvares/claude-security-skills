# JavaScript and TypeScript Security Cheat Sheet

## Introduction

Secure development practices for JavaScript/TypeScript, valid wherever language runs: browsers, hybrid apps, server-side Node.js, any runtime implementing it. Covers language-level pitfalls (dynamic code execution, prototype pollution, regular expressions), client-side sinks, TypeScript-specific false confidence. Rules valid on client and server stated once here; backend/runtime hardening in [Node.js Security Cheat Sheet](Nodejs_Security.md), linked not duplicated.

## Related Cheat Sheets (Top-Level Links)

- [Node.js Security Cheat Sheet](Nodejs_Security.md) - backend, runtime guidance.
- [Cross Site Scripting Prevention Cheat Sheet](Cross_Site_Scripting_Prevention.md) - output encoding rules per context.
- [DOM based XSS Prevention Cheat Sheet](DOM_based_XSS_Prevention.md) - client-side XSS sinks, sources.
- [Third Party JavaScript Management Cheat Sheet](Third_Party_Javascript_Management.md) - managing external scripts.
- [Transport Layer Security Cheat Sheet](Transport_Layer_Security.md) - TLS configuration.
- OWASP Cheat Sheet Series index - full catalog.

## Dangerous Language Surface

### `eval`, `Function`, and `with`

Never build code from strings (see MDN eval guidance). `eval`, `new Function` execute arbitrary code w/ current runtime's privileges → attacker-influenced input reaching them = code injection (CWE-94). Browsers: `setTimeout`/`setInterval` w/ string argument compile it same way via implied `eval`.

- Parse data w/ `JSON.parse`, never `eval`.
- Replace dynamic dispatch w/ static maps of functions, not calls constructed from names.
- Don't use `with`: unpredictable scope, forbidden in strict mode, blocks engine optimizations.
- Enforce statically w/ lint rules `no-eval`, `no-implied-eval`, `no-new-func`.
- Browsers: block string compilation w/ enforced Content Security Policy whose `script-src` directive, or `default-src` fallback, omits both `'unsafe-eval'` and `'trusted-types-eval'`. Report-only policy doesn't block execution (CSP `EnsureCSPDoesNotBlockStringCompilation`).
- CSP = browser-side only, n/a to server-side runtimes → lint rules remain primary enforcement everywhere.

### Evil Regex (ReDoS)

Nested quantifiers such as `(a+)+`, repeated ambiguous alternatives such as `^(a|aa)*$` can make matching take exponential time on crafted input, consuming CPU, potentially blocking executing thread/event loop (CWE-1333). Exploitability depends on surrounding expression + failing input, not just quantified group.

- Prefer well-tested validators over hand-written patterns for emails, URLs, similar inputs.
- Keep patterns linear: avoid nested quantifiers, ambiguous alternation over same characters.
- Cap untrusted input length before matching; reject rather than sanitize on non-match.
- Attack mechanics/detection tooling: OWASP ReDoS guidance; linear-time patterns = primary control, input-length caps = defense in depth.

### Strict Mode

Ship ES modules (strict by default) or declare `'use strict'` (MDN strict mode docs). Strict mode turns silent mistakes into errors: assignment to undeclared variables throws, `this` stays `undefined` in plain functions (not global object), `with` rejected. Doesn't fix injection, XSS, prototype pollution; hygiene, not security boundary.

## Object and Property Safety (Including Prototype Pollution)

Prototype pollution (CWE-1321): attacker-controlled keys such as `__proto__`, `constructor`, `prototype` reach recursive merge or path setter, modify object's prototype → alters behavior of objects inheriting from it. JS-specific essentials only; full guidance in [Prototype Pollution Prevention Cheat Sheet](Prototype_Pollution_Prevention.md).

- Never pass untrusted input to recursive merge or `set-by-path` helper; reject key segments `__proto__`, `constructor`, `prototype` before writing.
- Use `Map` w/ `set`, `get`, `has` for untrusted dictionary keys, keeping entries separate from object properties (MDN prototype pollution defenses). If object required, create w/ `Object.create(null)` (no prototype).
- Validate parsed/copied untrusted data against schema before use; drop `__proto__` keys first: `Object.assign` applies them via prototype setter, mutates target's prototype; spread creates silent own property.

## DOM Sinks and Output Context

Injecting attacker-controlled strings into HTML, script, URL contexts = cross-site scripting (CWE-79). Follow [Cross Site Scripting Prevention Cheat Sheet](Cross_Site_Scripting_Prevention.md) for per-context encoding, [DOM based XSS Prevention Cheat Sheet](DOM_based_XSS_Prevention.md) for client-side sources/sinks.

- Build DOM w/ `textContent`, `createElement`, not `innerHTML`/`insertAdjacentHTML`.
- HTML must be rendered → sanitize w/ maintained allowlist sanitizer; enforce Trusted Types w/ no permissive default policy.
- Framework auto-escaping has explicit bypasses; never give them untrusted input: React `dangerouslySetInnerHTML`, Vue `v-html`, Angular `bypassSecurityTrustHtml` + siblings.

## Async Error Handling, Messaging, and Origin Checks

Not every promise failure is a defect. *Expected* failure = part of function's contract (lookup returning `null` for missing key, parse throwing on malformed input): handle where caller decides, via `try`/`catch` around `await` or `.catch` on terminal link of chain; return typed result or documented error. *Unhandled* rejection = promise rejects w/ no handler; failure propagates past call site, usually a bug: browsers report in console + fire `unhandledrejection` event; Node.js behavior depends on unhandled-rejection mode, may terminate process (MDN promise rejection events). Keep chains flat w/ terminal error handler so unexpected rejections stay visible; don't silence w/ empty `catch`. Server-side specifics in [Node.js Security Cheat Sheet](Nodejs_Security.md).

`postMessage`: receiver MUST verify `event.origin` against explicit allowlist, check `event.source` when conversation partner expected, validate `event.data` against expected schema before acting. Sender MUST pass exact `targetOrigin`, never `"*"` for sensitive data. Prefer narrow `MessageChannel` ports over broadcast messaging where design allows.

## TypeScript-Specific Caveats

Types erased at runtime → TypeScript alone enforces nothing against malicious/malformed caller.

- `any` = hole in every check. `unknown` = safe default for values of unknown type: forces narrowing before use; `any` disables type checking for that value.
- Type assertions (`as`), non-null assertions (`!`) silence compiler w/o changing runtime values; don't use on untrusted data.
- Enable `strict` in `tsconfig.json` (plus `noUncheckedIndexedAccess` where affordable) to catch accidental unsafety in own code. Code-quality control, not trust boundary.
- Validate at every trust boundary (network responses, `postMessage` payloads, storage reads) w/ runtime schema validator. Validated type should flow from schema, not parallel hand-written interface.

## Linting and Dependency Tooling

- Lint w/ `typescript-eslint` recommended sets plus `no-eval`, `no-implied-eval`, `no-new-func`. Keep dependencies updated so new rules apply.
- Pin versions w/ lockfile, review dependency changes, monitor advisories. Frontend dependency-review specifics overlap [Node.js Security Cheat Sheet](Nodejs_Security.md).
- Third-party scripts from CDN: pin Subresource Integrity hash w/ `crossorigin` handling per [Third Party JavaScript Management Cheat Sheet](Third_Party_Javascript_Management.md).

## References

- MDN: Window.postMessage
- TypeScript Handbook: unknown
- W3C Trusted Types
