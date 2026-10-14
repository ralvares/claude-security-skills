# Webhook Security Cheat Sheet

## Introduction

Webhooks = HTTP callbacks: **publisher** pushes event notifications to URL **subscriber** registered; both run HTTP servers (Standard Webhooks specification). Webhook endpoint = public, unauthenticated `POST` handler unless you add authentication. Publisher delivering to user-supplied URLs = outbound request engine; attackers aim it at internal network.

Covers both sides: prove delivery genuine, stop replays/duplicate processing, protect signing secrets, prevent publisher being used as proxy.

## Threat Model Summary

Use [Threat Modeling Cheat Sheet](Threat_Modeling.md) to assess integration trust boundaries.

Forged deliveries = headline threat: w/o verification, attacker posts fake events triggering order fulfillment, account access, record changes (Stripe's webhook documentation). Signature verification first control; others close remaining gaps.

| Threat | Primary control |
|---|---|
| Forged events | Hash-based message authentication code using SHA-256 (HMAC-SHA256), verified every delivery |
| Replay of captured delivery | Authenticated timestamp w/ tolerance window + authenticated event-ID deduplication, where publisher protocol supports |
| Signing secret leakage | Secrets manager, one secret per webhook, log redaction, immediate revocation + replacement |
| Server-side request forgery (SSRF) via subscriber-supplied callback URL | `https://`-only scheme allowlist + deny-list of every non-public address range, enforced on resolved IP at connect time |
| Denial of service | Rate limiting, payload size limit, asynchronous processing |
| Duplicate processing | Idempotent handlers keyed on event ID |
| Eavesdropping or tampering in transit | Transport Layer Security (TLS) 1.2 or higher w/ certificate from trusted certificate authority (CA) |
| Malicious payload content | Schema validation, then parameterized queries + output encoding downstream |

## Authenticating Deliveries

### Transport Security

- Require HTTPS on every webhook endpoint; reject plain HTTP. Signature proves authenticity, doesn't encrypt; anyone on network path reads unencrypted delivery (Standard Webhooks: Enforcing HTTPS).
- Enforce TLS 1.2 or higher w/ trusted CA certificate. Large publishers refuse weaker: Stripe validates subscriber certificate, negotiates only TLS 1.2 and 1.3.
- Publisher: verify subscriber certificate every delivery. GitHub lets users disable check but recommends leaving SSL verification enabled.
- Protocol version + cipher suite config: [Transport Layer Security Cheat Sheet](Transport_Layer_Security.md).

### Signature Verification

Signing lets subscriber confirm delivery from legitimate publisher + body unmodified in transit.

Publisher:

- Generate cryptographically random signing secret per registered webhook. 32 bytes sound default; Standard Webhooks signature scheme specifies 24 to 64 bytes.
- New protocol → use documented signature scheme authenticating event ID, delivery timestamp, raw request body together, e.g. Standard Webhooks. Existing providers differ: GitHub signs raw body only; Stripe signs timestamp + body (event ID inside body).
- Planned secret rotation: sign with every active secret, send one signature per secret (see Secret Rotation below).

Subscriber:

- Use publisher's maintained verification library when available; follow its exact signing format. Supply raw request body before framework parses it. Re-serializing JSON, reordering fields, changing whitespace/line endings, converting character encoding all invalidate signature (Stripe).
- Recompute HMAC, compare w/ constant-time function e.g. `hmac.compare_digest`, `crypto.timingSafeEqual`, `MessageDigest.isEqual`. NEVER `==`: leaks timing, can make endpoint a signing oracle (GitHub, Standard Webhooks).
- Header w/ several signatures → accept if any one matches. Publishers send one per active secret during rotation; this makes rotation safe in either order (Standard Webhooks: Webhook headers).
- Accept only expected signature scheme (e.g. Stripe's `v1`); ignore other schemes in header → prevents downgrade attacks (Stripe).
- Return `401` when signature missing or mismatched; don't say why.

### Secret Management

Leaked signing secret → attacker forges deliveries until revoked. Treat webhook secrets like DB credentials.

- Store signing secrets in secrets manager; never hard-code in source, config files, container images (GitHub: Securely storing the secret token). See [Secrets Management Cheat Sheet](Secrets_Management.md).
- Distinct secret per registered webhook → one leak exposes one integration; e.g. Stripe generates unique secret per endpoint.
- Redact secrets + signature header values from logs and error responses.

#### Secret Rotation

Suspected compromise → revoke old secret immediately, replace, per Secrets Management Cheat Sheet's [incident response guidance](Secrets_Management.md#92-remediation). Accepting compromised secret during overlap still permits forged deliveries.

Planned rotation: overlap window with both secrets valid avoids failed deliveries. Stripe supports immediate expiration or overlap of up to 24 hours, signing with every active secret meanwhile. To rotate:

- Generate new secret.
- Configure publisher to sign w/ both secrets, send both signatures.
- Load new secret on subscriber. Subscriber already accepts any matching signature → sides can switch in either order inside window.
- Once deliveries verify w/ new secret, revoke old.
- Return `401` for deliveries signed only w/ revoked secret.

### Additional Authentication (Defense in Depth)

HMAC signing authenticates payload, not connection. Layer one of these when leaked signing secret must not suffice to reach endpoint:

| Method | When to use |
|---|---|
| Mutual TLS (mTLS) | High-assurance machine-to-machine pipelines; see [Client Certificates and Mutual TLS](Transport_Layer_Security.md#client-certificates-and-mutual-tls) |
| Static bearer token or API key | Simple integrations; store in secrets manager, rotate like signing secret |
| OAuth 2.0 client credentials | Both parties support OAuth → use client credentials grant to get access token. Validate via authorization server's supported mechanism; require permission to deliver to this webhook. For JSON Web Token (JWT) access tokens using RFC 9068 profile, apply its complete validation rules incl. token type; see [OAuth2 Cheat Sheet](OAuth2.md) |
| IP allowlisting | Extra layer only. Publishers e.g. Stripe and GitHub publish delivery addresses, but ranges change; shared egress IP ≠ proof of identity |

## Replay, Duplicates, and Abuse

### Replay Attack Protection

Captured delivery carries valid signature → signature verification alone doesn't stop repeated processing. For protocols w/ authenticated delivery timestamps + event IDs, e.g. Standard Webhooks:

- Publisher: include Unix timestamp in signed material, send next to signature, generate fresh timestamp + signature every retry (Stripe: Preventing replay attacks).
- Subscriber: reject deliveries whose authenticated timestamp differs from your clock by more than small tolerance. Five minutes = default in Stripe's libraries; keep clock synced via Network Time Protocol (NTP) so window meaningful.
- Subscriber: after signature + freshness validation, cache authenticated event IDs to prevent repeated processing inside window (Standard Webhooks: Verifying signatures). Keep each ID ≥ twice tolerance, 10 minutes for 5-minute window: delivery with timestamp 5 minutes ahead of your clock accepted now, stays acceptable another 10 minutes. Short replay cache doesn't replace persisted processing record below.

GitHub's body-only signature doesn't authenticate delivery timestamp or `X-GitHub-Delivery` header. Header helps identify ordinary redeliveries, gives no authenticated replay guarantee. Follow provider's documented protocol; make downstream effects idempotent.

### Idempotency and Duplicate Events

Publishers retry on failure (Stripe: up to three days w/ exponential backoff) → every endpoint gets some events more than once. Double-processing payment or notification causes real harm.

- After verifying delivery, persist processed event IDs, skip repeats (Stripe: Handle duplicate events). Retain record across publisher's retry period. GitHub's `X-GitHub-Delivery` identifies ordinary redeliveries but ≠ signed event ID.
- Return `200` for authenticated duplicate already durably queued or processed; don't repeat side effects.
- Make downstream side effects (DB writes, emails, payments) idempotent by default.
- Don't assume in-order delivery. Fetch object's current state from publisher API when event may be stale. Use sequence/version field only when publisher documents ordering guarantees; timestamps alone may not establish order (Stripe: Event ordering).

### Rate Limiting

Broader resource controls: [Denial of Service Cheat Sheet](Denial_of_Service.md).

W/o limits, misconfigured publisher or attacker floods endpoint. Protect both sides.

- Publisher: per-subscriber delivery limits, exponential backoff w/ jitter, max retry count; disable endpoints failing for days (Standard Webhooks: Deliverability and reliability).
- Subscriber: rate limit at API gateway or app layer; answer excess w/ `429 Too Many Requests` + `Retry-After` header (RFC 6585 section 4).
- Subscriber: ack fast, process via asynchronous queue. GitHub expects `2xx` within 10 seconds; Stripe recommends asynchronous queue to absorb delivery spikes.
- Subscribe only to event types you handle; listening to everything multiplies load + hands you unneeded data (GitHub: Subscribe to the minimum number of events).

### SSRF Prevention (Publisher Side)

Subscribers register own callback URLs → attacker registers internal address or cloud metadata endpoint, uses your delivery workers as proxy into your network. Webhook senders especially exposed (Standard Webhooks) since accepting arbitrary URLs is the feature.

- Allowlist scheme: `https://` only.
- Block every non-public destination: resolve hostname, reject any address not globally reachable; at minimum deny-list in [Server-Side Request Forgery Prevention Cheat Sheet](Server_Side_Request_Forgery_Prevention.md#deny-list-last-resort) incl. IPv6 equivalents, plus internal hostnames e.g. `metadata.google.internal`. IANA IPv4 and IPv6 special-purpose address registries include both globally reachable and non-globally-reachable ranges; consult each entry's Globally Reachable field.
- Validate address you actually connect to. Re-resolving name just before request doesn't close DNS rebinding gap: HTTP client resolves again at connect, may get different answer. Either resolve once, validate IP, connect to that exact IP while sending original hostname in `Host` header and Server Name Indication (SNI); or validate inside client's connect hook, same lookup for validation + connection. [DNS pinning guidance in the SSRF cheat sheet](Server_Side_Request_Forgery_Prevention.md#case-2---application-can-send-requests-to-any-external-ip-address-or-domain-name) covers this.
- Disable redirects, or apply same checks to every redirect target. Stripe treats redirect responses as failed deliveries.
- Isolate delivery workers or egress proxy in network segment unable to reach internal services (Standard Webhooks). Egress proxy e.g. Smokescreen can enforce destination checks.

## Endpoint Hardening

### Input Validation

See [Input Validation Cheat Sheet](Input_Validation.md) + [Injection Prevention Cheat Sheet](Injection_Prevention.md) for validation and downstream interpretation controls.

- Valid signature proves sender, not content safety. Enforce max body size, reject unexpected `Content-Type`, validate against strict schema before processing, per REST Security Cheat Sheet's [Input validation](REST_Security.md#input-validation) + [Validate content types](REST_Security.md#validate-content-types). Publishers keep payloads small; Standard Webhooks spec recommends under 20 KB.
- Downstream: parameterized queries for SQL ([Query Parameterization Cheat Sheet](Query_Parameterization.md)); context-appropriate output encoding wherever payload fields render as HTML ([Cross Site Scripting Prevention Cheat Sheet](Cross_Site_Scripting_Prevention.md)).

### HTTP Method Restriction

- Accept `POST` only; answer every other method `405 Method Not Allowed`, per [Restrict HTTP methods](REST_Security.md#restrict-http-methods) in REST Security Cheat Sheet.

### Cross-Site Request Forgery (CSRF) Considerations

- Exempt webhook route, only that route, from framework CSRF token checks: publisher is server, can't obtain token; check only blocks legitimate deliveries (Stripe: Exempt webhook route from CSRF protection).
- Put signature verification in place before granting exemption; it's the replacement control. See [Cross-Site Request Forgery Prevention Cheat Sheet](Cross-Site_Request_Forgery_Prevention.md).

### Fail Securely

- Return `200` only after event durably queued or processed, `400` for malformed payloads, `401` for signature failures; generic body, no stack traces or internal detail, per REST Security Cheat Sheet's [Error handling](REST_Security.md#error-handling).
- Route events repeatedly failing processing to dead-letter queue; alert on it, don't drop.

### Logging and Monitoring

Logs detect probing + diagnose integration failures; keep full payloads + secrets out.

- Log timestamp, source IP, HTTP method, response status, event ID, event type, processing latency.
- Don't log full request bodies (often personal data), signing secrets, `Authorization` and signature header values; see [Data to exclude](Logging.md#data-to-exclude) in Logging Cheat Sheet.
- Alert on: spikes in signature failures (endpoint probing), sustained `4xx` or `5xx` (processing failure/misconfiguration), deliveries from unexpected source addresses.

## Quick Reference Checklist

Stripe and GitHub best-practice pages cover subscriber side of own platforms; use table to check both sides of any integration.

| Control | Publisher | Subscriber |
|---|---|---|
| TLS 1.2 or higher w/ trusted CA certificate | Yes | Yes |
| HMAC-SHA256 signature on every delivery | Sign | Verify w/ constant-time comparison |
| One secret per webhook, stored in secrets manager | Yes | Yes |
| Planned rotation w/ overlap window | Sign w/ every active secret | Accept any matching signature |
| Compromised secret | Revoke + replace immediately | Stop accepting revoked secret |
| Authenticated timestamp + event ID | Include when designing protocol | Enforce freshness + deduplication where provider supports |
| Replay cache retention | n/a | ≥ twice timestamp tolerance; keep separate processing record across retries |
| Idempotent, order-independent processing | n/a | Yes |
| SSRF checks on callback URLs at connect time | Yes | n/a |
| Rate limiting | Throttle, back off, cap retries | `429` + asynchronous queue |
| Payload size limit + schema validation | Keep payloads small | Yes |
| `POST` only, `405` for other methods | n/a | Yes |
| Generic errors: `400` malformed, `401` bad signature | n/a | Yes |
| Structured logs w/o secrets or full bodies | Yes | Yes |

## Security Testing

Run before production + after any webhook handling code change:

- Missing/invalid signature: endpoint returns `401`, not `200`.
- Replay protection: protocols w/ authenticated timestamps + event IDs → stale deliveries fail freshness checks; already accepted event can't trigger side effects twice. Valid duplicate already durably queued/processed gets `200`.
- Duplicate event ID: deliver same event twice; confirm processed once. GitHub redelivery reuses original `X-GitHub-Delivery` value → convenient duplicate test.
- Oversized payload: exceed size limit; expect `400` or `413`.
- SSRF (publisher side): register `http://` URL, `https://169.254.169.254/`, `https://127.0.0.1/`, internal hostname, public hostname resolving to private address; each must be rejected at registration or blocked at delivery. WSTG-INPV-19 describes test cases + filter bypasses to try, e.g. alternative IP encodings.
- Secret rotation: both secrets accepted during planned overlap; revoked/compromised secret no longer accepted.
- Use publisher's own test tooling where exists, e.g. `stripe trigger`, to exercise handler w/ genuine signed deliveries.

## References

- Standard Webhooks Specification
- Stripe: Receive Stripe Events in Your Webhook Endpoint
- GitHub: Validating Webhook Deliveries
