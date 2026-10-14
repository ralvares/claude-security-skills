# Micro-Frontend Security Cheat Sheet

## Introduction

Micro-frontends combine independently deployed features in host app (shell). Separate repos/deploy teams ≠ browser security boundaries: same-origin policy separates origins, not features within a page.

Covers security decisions composing these apps:

- Choose which features may share host's browser privileges.
- Limit communication + data sharing between apps.
- Enforce authorization on server for every request.
- Control which remote code each host release loads.

General browser controls: [Web Frontend Security Cheat Sheet](Web_Frontend_Security.md).

## Choose and Enforce Runtime Boundaries

Document origin, deployment owner, required data access of each micro-frontend before choosing composition mechanism.

| Composition | Security decision |
| --- | --- |
| Remote JavaScript loaded into host, incl. Module Federation | Trust remote w/ host page's privileges. Different download origin does not sandbox executing code. |
| Web Components in host page | Part of same app. Shadow DOM (Document Object Model) + scoped styles do not isolate scripts from host. |
| Cross-origin iframe | Use when feature must be separated from host's DOM + origin storage. Restrict capabilities; explicitly control messages crossing boundary. |
| HTML fragments assembled on server or edge | Review fragments + scripts as host content. Assembly before delivery ≠ browser isolation boundary. |

### Isolate Features with Different Trust Levels

Serve less-trusted feature from dedicated origin in iframe. Apply iframe sandbox, grant only required capabilities. Leave top-level navigation + popup permissions disabled unless necessary.

Never combine `allow-scripts` + `allow-same-origin` for content on host's own origin: embedded app can remove its sandbox. `allow-same-origin` preserves frame's original origin; does not make cross-origin frame same-origin w/ host.

Without `allow-same-origin`, sandboxed document has opaque origin, reported as `"null"` in messages. Never trust `"null"` as sender identity. If sensitive messaging needs identifiable origin, use dedicated cross-origin frame w/ sandbox policy preserving that origin.

Origin separation limits direct access to host DOM + storage. Does not authorize backend requests; data deliberately sent to frame stays readable by it.

### Control Remote Code and Deployments

Remotes executing in host page: permission to publish remote = permission to change host's running app:

- Load only approved HTTPS remote URLs from host-controlled config. Never let query params/untrusted input choose executable code.
- Select immutable, reviewed releases, incl. entry scripts + dependent chunks. Keep known-good release for rollback.
- Separate deployment credentials for shell + each remote. Limits direct changes to other deployments; does not contain compromised remote already trusted to execute in shell. See [CI/CD Security Cheat Sheet](CI_CD_Security.md).
- Use [Subresource Integrity](Third_Party_Javascript_Management.md#subresource-integrity) where loader supports it. Verify coverage of dynamically loaded chunks; checking entry script alone does not verify what it later loads. Integrity checks detect changed bytes, not malicious behavior in approved release.
- Apply host's [Content Security Policy (CSP)](Content_Security_Policy.md) to remote loading. Permitted script source = still trusted code; CSP does not isolate one allowed micro-frontend from another.

## Restrict Cross-Application Communication

Apply general [web messaging guidance](HTML5_Security.md#web-messaging) to every host/frame pair: exact `targetOrigin`, exact `event.origin` match, validate message data. Plus, per postMessage security guidance:

- Define small message contract per pair. Accept only message types + payload fields receiving feature needs.
- Check `event.source` against expected frame's `contentWindow` or expected parent window, not only origin. Several frames can share one origin.
- Pass minimum data needed. Avoid broadcasting credentials/sensitive state to every feature.

Checks identify sending origin + window, not current user's permissions. Message requesting privileged operation still needs server-side authorization. Also no protection against compromised code in expected sender.

Shared in-page event bus: no browser-enforced identity boundary between participants. Never use event names/app identifiers as proof of authority.

## Enforce Backend Authorization and Limit Shared Data

### Authorize Every Request on the Server

Neither shell nor remote can enforce authorization client-side. Route guards, hidden controls, client-side role checks = presentation only; bypassable.

Enforce permissions for requested operation, resource, tenant on every backend request, whichever frontend initiated it. Never trust role, tenant identifier, permission flag supplied by shell or remote. Use shared server-side policy where appropriate so independent features apply consistent checks. See [Authorization Cheat Sheet](Authorization.md#validate-the-permissions-on-every-request).

### Keep Sensitive State Out of Shared Runtimes

Browser storage separated by origin. Storage key prefixes, separate state stores, component boundaries give no security isolation between scripts in same page. Data exposed in page or origin storage = available to every remote executing there.

Keep session identifiers out of `localStorage` and `sessionStorage`. With backend-for-frontend: keep upstream access tokens on server; use session cookie configured per [Session Management Cheat Sheet](Session_Management.md#cookies). `HttpOnly` cookie stops JavaScript reading it, but compromised host code can still make authenticated requests. Apply [cross-site request forgery protection](Cross-Site_Request_Forgery_Prevention.md) to cookie-authenticated operations.

Return only data authenticated user is authorized to access. Clear shared state + cached responses on logout/tenant change to avoid stale data display. Cleanup does not replace backend tenant checks or protect info already exposed to compromised remote.

## References

- MDN: Same-Origin Policy
- MDN: postMessage Security Concerns
- MDN: iframe Sandbox
