# REST Security Cheat Sheet

## Introduction

REST (**RE**presentational **S**tate **T**ransfer): architectural style from Roy Fielding's Ph.D. dissertation "Architectural Styles and the Design of Network-based Software Architectures".

Evolved as Fielding wrote HTTP/1.1 and URI specs; proven suited to distributed hypermedia apps. Widely applicable; most commonly used for communicating with services via HTTP.

Key abstraction = resource, identified by URI, usually HTTP URL. REST components use connectors to act on resource, using representation to capture current/intended resource state and transferring that representation.

Primary connectors: client, server; secondary: cache, resolver, tunnel.

REST APIs are stateless. Stateful APIs do not follow REST. State in REST = state of resource API accesses, not session state. Session management complex, hard to do securely.

Stateful services out of scope: *Passing state from client to backend, while making service technically stateless, is an anti-pattern to avoid; prone to replay and impersonation attacks.*

REST flows: resources typically created, read, updated, deleted. E.g. ecommerce: create empty shopping cart, add items, check out. Each REST call stateless; endpoint should check caller authorized for requested operation.

Another key feature: standard HTTP verbs + error codes → remove unnecessary variation among services.

Another: HATEOAS (Hypermedia As The Engine of Application State) → self-documenting; developers interact without prior knowledge.

FastAPI apps: also see [FastAPI Security Cheat Sheet](FastAPI_Security.md) (dependency-based access control, request/response models, deployment settings).

## HTTPS

Secure REST services must provide only HTTPS endpoints. Protects authentication credentials in transit (passwords, API keys, JSON Web Tokens); lets clients authenticate service; guarantees transmitted data integrity.

See [Transport Layer Security Cheat Sheet](Transport_Layer_Security.md).

Consider mutually authenticated client-side certificates for extra protection of highly privileged web services.

## Access Control

Non-public REST services must perform access control at each API endpoint. Monolithic app web services use user authentication, authorization logic, session management; drawbacks for modern architectures composing multiple RESTful microservices.

- minimize latency, reduce coupling between services: REST endpoints take access control decision locally
- centralise user authentication in Identity Provider (IdP) issuing access tokens

## JWT

Convergence toward JSON Web Tokens (JWT) (RFC 7519) as security token format. JWT = JSON data structure with claims usable for access control decisions. Cryptographic signature or message authentication code (MAC) can protect integrity.

- Ensure JWTs integrity protected by signature or MAC. Do not allow unsecured JWTs: `{"alg":"none"}`.
    - See RFC 7519 section 6.1
- Generally prefer signatures over MACs for JWT integrity protection.

MACs: every service able to validate JWTs can also create new JWTs with same key → all services sharing key must mutually trust each other; compromise of any service compromises all others sharing key. See RFC 7515 section 10.5.

Relying party / token consumer validates JWT by verifying integrity + contained claims.

- Relying party must verify JWT integrity based on own configuration or hard-coded logic. Must not rely on JWT header info to select verification algorithm (JWT algorithm confusion).

JWTs for API access control: require and validate `iss`, `aud`, `exp` by default; mandatory for tokens conforming to RFC 9068, Section 2.2. Require and validate any additional claims token profile makes mandatory. Check:

- `iss` or issuer: trusted issuer? Expected owner of signing key?
- `aud` or audience: relying party in target audience?
- `exp` or expiration time: current time before end of validity period?
- `nbf` or not before time: if present, current time at or after start of validity period? Optional in RFC 7519, Section 4.1.5; require if token profile requires.

JWTs contain authenticated entity details → disconnect possible between JWT and current session state, e.g. session ended earlier than expiration by explicit logout or idle timeout. On explicit session termination, submit unique server-issued identifier (`jti` claim, optionally combined with `aud`) to API denylist → invalidates JWT for any request until token expiration. See [JSON_Web_Token_Cheat_Sheet](JSON_Web_Token.md#jwt-denylist).

## API Keys

Public REST services without access control risk being farmed → excessive bandwidth/compute bills. API keys mitigate. Also used to monetize APIs: instead of blocking high-frequency calls, grant access per purchased plan.

API keys can reduce DoS impact. Issued to third-party clients, relatively easy to compromise.

- Require API keys for every request to protected endpoint.
- Return `429 Too Many Requests` if requests come too quickly.
- Revoke API key if client violates usage agreement.
- Do not rely exclusively on API keys to protect sensitive, critical, high-value resources.

## Restrict HTTP methods

- Allowlist permitted HTTP Methods e.g. `GET`, `POST`, `PUT`.
- Reject all non-matching requests with `405 Method not allowed`.
- Ensure caller authorized for incoming HTTP method on resource collection, action, record

Java EE esp. hard to implement properly. See "Bypassing Web Authentication and Authorization with HTTP Verb Tampering" (OWASP assets PDF) for this common misconfiguration.

## Preventing Out-of-Order API Execution

Modern REST APIs implement business workflows via endpoint sequences (e.g. create → validate → approve → finalize). Backend not explicitly validating workflow state transitions → attackers invoke endpoints out of sequence, bypass intended controls.

### Problem

Attacker:

- Skips required steps by directly calling later-stage endpoints
- Replays/reuses tokens across workflow boundaries
- Exploits assumption frontend enforces correct sequencing

Each endpoint may be individually authenticated + authorized → traditional access control checks often miss this.

### Example

Checkout workflow expects:

```http
POST /checkout/create
POST /checkout/pay
POST /checkout/confirm
```

Backend not validating state transitions: attacker directly invokes:

```http
POST /checkout/confirm
```

without completing payment.

### Prevention Guidance

- Enforce workflow state validation server-side for every request
- Model workflows explicitly w/ finite states or state machines
- Bind tokens/identifiers to specific workflow stages
- Do not rely on frontend logic for sequencing
- Reject invalid/out-of-order transitions w/ clear error responses

### Testing Checklist

- Endpoints invokable out of sequence?
- Each endpoint validates current workflow state?
- Tokens reusable across workflow steps?
- Invalid state transitions consistently rejected?

## Input validation

- Do not trust input parameters/objects.
- Validate input: length / range / format and type.
- Implicit validation via strong types (numbers, booleans, dates, times, fixed data ranges) in API parameters.
- Constrain string inputs with regexps.
- Reject unexpected/illegal content.
- Use validation/sanitation libraries or frameworks for your language.
- Define request size limit; reject requests exceeding it with HTTP 413 Request Entity Too Large.
- Consider logging input validation failures. Hundreds of failed validations per second = someone up to no good.
- See input validation cheat sheet for comprehensive explanation.
- Use secure parser for incoming messages. XML: parser not vulnerable to XXE and similar attacks.

## Validate content types

REST request/response body should match intended content type in header. Otherwise misinterpretation at consumer/producer → code injection/execution.

- Document all supported content types in API.

### Validate request content types

- Requests with body: require supported `Content-Type` per endpoint contract; reject unsupported media types with `415 Unsupported Media Type` (RFC 9110 section 15.5.16). Do not require `Content-Type` solely for bodyless requests. Reserve `406 Not Acceptable` for response content negotiation.
- XML content types: appropriate XML parser hardening, see [XXE cheat sheet](XML_External_Entity_Prevention.md).
- Avoid accidentally exposing unintended content types by explicitly defining them, e.g. Jersey (Java) `@consumes("application/json"); @produces("application/json")`. Avoids XXE-attack vectors, for example.

### Send safe response content types

REST services commonly allow multiple response types (e.g. `application/xml` or `application/json`); client specifies preferred order via Accept header.

- **Do NOT** copy `Accept` header to response `Content-type` header.
- Select supported response type matching client's `Accept` preferences, incl. media ranges + quality values. None acceptable and no default response supplied → `406 Not Acceptable` (RFC 9110 section 15.5.7).

Services including script code (e.g. JavaScript) in responses must especially defend against header injection.

- Send intended content type headers matching body content, e.g. `application/json` not `application/javascript`.

## Management endpoints

- Avoid exposing management endpoints via Internet.
- If Internet-accessible, require strong authentication, e.g. multi-factor.
- Expose via different HTTP ports or hosts, preferably different NIC + restricted subnet.
- Restrict access via firewall rules or ACLs.

## Error handling

- Generic error messages; avoid unnecessary failure details.
- No technical details (call stacks, internal hints) to client.

## Audit logs

- Write audit logs before and after security related events.
- Consider logging token validation errors → detect attacks.
- Sanitize log data beforehand → prevent log injection.

## Security Headers

Several security related headers (OWASP Secure Headers Project) instruct browsers to act in specific ways. Some target HTML responses; little/no benefit on APIs not returning HTML. API consumed only by non-browser clients (mobile apps, server-to-server, CLI tools): most headers have no effect (browser directives).

Include in all API responses possibly consumed by browser clients:

| Header | Rationale |
|--------|-----------|
| `Cache-Control: no-store` | Compliant private + shared HTTP caches must not store response or reuse it for another request (RFC 9111). Does not prevent storage by application code: Cache API ignores HTTP caching headers. Keep sensitive responses out of app-managed caches; see [offline application guidance](HTML5_Security.md#offline-applications). |
| `Content-Security-Policy: frame-ancestors 'none'` | Specifies whether response can be framed in `<frame>`, `<iframe>`, `<embed>`, `<object>`. API responses need no framing. `frame-ancestors 'none'` prevents any domain framing API response. Protects against drag-and-drop style clickjacking. |
| `Content-Type` | Specifies response content type. Must match content returned. If unspecified/incorrect, browser may guess type → MIME sniffing attacks. Common value `application/json` for JSON responses. |
| `Strict-Transport-Security` | Hosts under active HSTS policy: browsers use HTTPS and terminate connections with TLS errors (RFC 6797 section 8.4). Initial HTTP access stays exposed unless policy already known, e.g. preloading. HSTS does not protect against attacker certificate client trusts (RFC 6797 section 14.8). |
| `X-Content-Type-Options: nosniff` | Browser always uses MIME type declared in `Content-Type`, no guessing from file content. `nosniff` prevents MIME sniffing and inappropriately interpreting responses as HTML. |
| `X-Frame-Options: DENY` | Legacy; superseded by `Content-Security-Policy: frame-ancestors 'none'` (above). Still recommended for older browsers lacking CSP Level 2. `DENY` prevents any domain framing response. |

Headers below add security only when responses rendered as HTML. API **never** returning HTML → may be unnecessary. Any uncertainty about header function or types of information API returns (or may return later) → include as defense-in-depth.

| Header | Example | Rationale |
|--------|-----------|-----------|
| Content-Security-Policy | `Content-Security-Policy: default-src 'none'` | Majority of CSP functionality affects only HTML-rendered pages. |
| Permissions-Policy | `Permissions-Policy: accelerometer=(), ambient-light-sensor=(), autoplay=(), battery=(), camera=(), cross-origin-isolated=(), display-capture=(), document-domain=(), encrypted-media=(), execution-while-not-rendered=(), execution-while-out-of-viewport=(), fullscreen=(), geolocation=(), gyroscope=(), keyboard-map=(), magnetometer=(), microphone=(), midi=(), navigation-override=(), payment=(), picture-in-picture=(), publickey-credentials-get=(), screen-wake-lock=(), sync-xhr=(), usb=(), web-share=(), xr-spatial-tracking=()` | Formerly Feature-Policy. Browsers heeding it control browser features via directives. Example disables features with empty allowlist for several permitted directive names (MDN). When applying, verify directives up-to-date and fit needs. See Chrome permissions-policy article for detail. |
| Referrer-Policy | `Referrer-Policy: no-referrer` | Non-HTML responses should not trigger additional requests. |

## CORS

Cross-Origin Resource Sharing (CORS): W3C standard to flexibly specify permitted cross-domain requests. Appropriate CORS Headers signal to browser which domains (AKA origins) may make JavaScript calls to REST service.

- Disable CORS headers if cross-domain calls unsupported/unexpected.
- Origins for cross-domain calls: as specific as possible, as general as necessary.

## Sensitive information in HTTP requests

Prevent leaking credentials. Passwords, security tokens, API keys must not appear in URL: captured in web server logs, intrinsically valuable.

- `POST`/`PUT` requests: sensitive data in request body or request headers.
- `GET` requests: sensitive data in HTTP Header.

**OK:**

`https://example.com/resourceCollection/[ID]/action`

`https://twitter.com/vanderaj/lists`

**NOT OK:**

`https://example.com/controller/123/action?apiKey=a53f435643de32` because apiKey in URL.

## HTTP Return Code

HTTP defines status codes. Designing REST API: don't just use `200` for success or `404` for error. Always use semantically appropriate status code.

Non-exhaustive selection of security related REST API **status codes**:

| Code | Message                | Description |
|-------------|------------------------|-------------|
| 200         | OK                     | Response to successful REST API action. HTTP method can be GET, POST, PUT, PATCH or DELETE. |
| 201         | Created                | Request fulfilled, resource created. URI of created resource returned in Location header. |
| 202         | Accepted               | Request accepted for processing; processing not yet complete. |
| 301         | Moved Permanently       | Permanent redirection. |
| 304         | Not Modified           | Caching related; returned when client has same copy of resource as server. |
| 307         | Temporary Redirect     | Temporary redirection of resource. |
| 400         | Bad Request            | Request malformed, e.g. message body format error. |
| 401         | Unauthorized           | Wrong or no authentication ID/password provided. |
| 403         | Forbidden              | Authentication succeeded but authenticated user lacks permission for requested resource. |
| 404         | Not Found              | Non-existent resource requested. |
| 405         | Method Not Allowed     | Unexpected HTTP method. E.g. API expects HTTP GET, HTTP PUT used. |
| 406         | Not Acceptable         | No supported response representation satisfies client's content negotiation preferences; server will not send default representation. |
| 413         | Payload too large      | Request size exceeded given limit e.g. file uploads. |
| 415         | Unsupported Media Type | Request content has format target method does not support. |
| 429         | Too Many Requests      | Possible DOS attack detected, or request rejected due to rate limiting. |
| 500         | Internal Server Error  | Unexpected condition prevented fulfilling request. Response must not reveal internal info helping attacker, e.g. detailed error messages or stack traces. |
| 501         | Not Implemented        | REST service does not implement requested operation yet. |
| 503         | Service Unavailable    | REST service temporarily unable to process request. Tells client to retry later. |

More on HTTP return code usage in REST APIs: restapitutorial.com, restfulapi.net.

## References

- RFC 8725: JSON Web Token Best Current Practices
- RFC 9110: HTTP Semantics
