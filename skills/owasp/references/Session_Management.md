# Session Management Cheat Sheet

## Introduction

**Web Authentication, Session Management, and Access Control**:

Web session = sequence of HTTP request/response transactions associated with same user. Modern web apps must retain per-user info/status across multiple requests. Sessions establish variables (access rights, localization settings) applying to every user interaction for session duration.

Apps can create sessions to track anonymous users from first request (e.g. language preference). Apps also use sessions post-authentication: identify user on subsequent requests, apply security access controls, authorize access to user private data, improve usability. Sessions exist pre and post authentication.

Once authenticated session established, session ID (or token) is temporarily equivalent to strongest authentication method used by app: username/password, passphrases, one-time passwords (OTP), client-based digital certificates, smartcards, biometrics (fingerprint, eye retina). See [Authentication Cheat Sheet](Authentication.md).

HTTP stateless (RFC2616 section 5): each request/response pair independent. Sessions need session management linking authentication and access control (authorization) modules:

![SessionDiagram](../assets/Session_Management_Cheat_Sheet_Diagram.png)

Session ID/token binds user authentication credentials (as user session) to user HTTP traffic and appropriate access controls. Complexity of these three components (authentication, session management, access control) plus implementation/binding left to web developer (frameworks don't enforce strict relationships between modules) makes secure session management very challenging.

Session ID disclosure, capture, prediction, brute force, or fixation → session hijacking (sidejacking): attacker fully impersonates victim. Two types: targeted (impersonate specific/privileged victim) and generic (impersonate/access as any valid user).

## Session ID Properties

To keep authenticated state and track user progress, apps give users **session identifier** (session ID/token) assigned at session creation, exchanged by user and app for session duration (sent on every HTTP request). Session ID = `name=value` pair.

Secure session ID generation must meet these properties.

### Session ID Name Fingerprinting

Session ID name should not be extremely descriptive or offer unnecessary details on ID purpose/meaning.

Common framework session ID names easily fingerprinted: `PHPSESSID` (PHP), `JSESSIONID` (J2EE), `CFID` & `CFTOKEN` (ColdFusion), `ASP.NET_SessionId` (ASP .NET), etc. → name can disclose technologies/languages used.

Recommended: change framework default session ID name to generic name, e.g. `id`.

### Session ID Entropy

Session IDs must have at least `64 bits` of entropy to prevent brute-force guessing. Entropy = randomness/unpredictability. Each "bit" doubles possible outcomes; 64 bits → `2^64` possible values.

Must use strong CSPRNG (Cryptographically Secure Pseudorandom Number Generator) for session IDs → values evenly distributed over all possible values. Otherwise attackers may use statistical analysis to find patterns, reducing effective entropy, making guessing/prediction easier.

**NOTE**:

- Expected brute-force time depends on bits of entropy, number of active sessions, session expiration times, attacker guessing rate.
- 64 bits entropy: attacker expects ~585 years to guess valid session ID, assuming 10,000 guesses per second with 100,000 valid simultaneous sessions.
- Further analysis of expected brute-force time: Insufficient Session-ID Length (OWASP community).

### Session ID Length

Per *Session ID Entropy*, primary requirement: at least `64 bits` of entropy vs brute-force. Length matters but entropy ensures security. ID must be long enough to encode sufficient entropy.

Different encodings give different lengths for same entropy. Hexadecimal common: session ID must be at least 16 hexadecimal characters for 64 bits of entropy. Other encodings (e.g. Base64, Microsoft's encoding for ASP.NET session IDs) may need different character counts for minimum 64 bits.

Any fixed/predictable part reduces effective entropy; length may need increase to compensate. E.g., half of 16-character hex session ID fixed → only remaining 8 characters random = 32 bits, insufficient. Ensure entire session ID randomly generated and unpredictable, or increase overall length if parts not random.

**NOTE**:

- More on Session ID Length vs Entropy relationship: Insufficient Session-ID Length (OWASP community).

### Session ID Content (or Value)

Content/value must be meaningless to prevent information disclosure: attacker decoding ID to extract user, session, or app internals details.

Session ID must be only an identifier client-side; value must never include sensitive info or Personally Identifiable Information (PII).

Meaning and business/app logic associated with session ID must be stored server-side, in session objects or session management database/repository.

Stored info can include client IP address, User-Agent, email, username, user ID, role, privilege level, access rights, language preferences, account ID, current state, last login, session timeouts, other internal session details. Session objects/properties holding sensitive info (e.g. credit card numbers): encrypt and protect session management repository.

Recommended: use session ID created by language/framework. Own sessionID: use CSPRNG with size at least 128 bits, ensure each sessionID unique.

## Session Management Implementation

Defines exchange mechanism for sharing session ID between user and web app. HTTP mechanisms: cookies (standard HTTP header), URL parameters (URL rewriting, RFC2396), URL arguments on GET requests, body arguments on POST requests (e.g. hidden form fields), proprietary HTTP headers.

Preferred mechanism should allow advanced token properties: expiration date/time, granular usage constraints. Reason cookies (RFCs 2109 & 2965 & 6265) are among most used: offer advanced capabilities other methods lack.

Mechanisms with ID in URL might disclose session ID (web links, logs, browser history, bookmarks, Referer header, search engines) and facilitate other attacks: ID manipulation, session fixation attacks.

### Built-in Session Management Implementations

Frameworks (J2EE, ASP .NET, PHP, others) provide session management. Recommended: use built-in vs home-made from scratch; used worldwide, tested by security/development communities over time.

Frameworks have had vulnerabilities/weaknesses; always use latest version (fixes known vulnerabilities), and review/change default configuration to harden per this document.

Storage/repository temporarily saving session IDs must be secure, protecting session IDs vs local/remote accidental disclosure or unauthorized access.

### Server-Side Session Token Storage

Storing random session tokens verbatim can be acceptable in tightly controlled session store, but anyone reading it can reuse unexpired tokens. High entropy protects vs guessing, not vs exposed tokens. Read-only store disclosure in threat model → store one-way verifier instead. RFC 6819 recommends token hashes for corresponding OAuth access-token database threat.

One approach: identifier and secret verifier split. Cookie carries both values; server stores public lookup identifier + full SHA-256 hash of verifier. Each request: look up session by identifier, hash supplied verifier, compare with stored hash via constant-time comparison. Never accept identifier alone as proof of authentication. Use consistent verifier representation when creating/validating session. Fast hash sufficient for these random verifiers; password hashing algorithms unnecessary.

Generate token, or secret verifier in split design, with CSPRNG with at least 128 bits entropy; prefer 160 bits or more, per OAuth's guidance for generated credentials (RFC 6749 section 10.10). Generate verifier independently of identifier; public identifier doesn't count toward verifier entropy.

One-way storage protects vs read-only disclosure of session records and backups containing only verifier hashes. Doesn't protect vs stolen cookies, session record modification, app compromise. Don't persist raw verifier alongside its hash.

Either design: restrict session store access, encrypt backups/replicas at rest. Follow [session logging protections](#logging-sessions-life-cycle-monitoring-creation-usage-and-destruction-of-session-ids) and [session renewal guidance](#renew-the-session-id-after-any-privilege-level-change).

### Used vs. Accepted Session ID Exchange Mechanisms

Web apps should use cookies for session ID exchange. Session ID submitted via different mechanism (e.g. URL parameter): app should refuse it, defending vs session fixation.

**NOTE**:

- Even if cookies are default, app might accept other mechanisms too.
- Confirm via thorough testing all mechanisms currently accepted when processing/managing session IDs; limit accepted tracking mechanisms to just cookies.
- Past apps used URL parameters, or switched from cookies to URL parameters (automatic URL rewriting) under conditions (e.g. clients without cookie support or not accepting cookies for privacy).

### Transport Layer Security

Protect session ID exchange from active eavesdropping and passive disclosure in network traffic: use encrypted HTTPS (TLS) for entire web session, not only authentication where credentials exchanged. May be mitigated by [HTTP Strict Transport Security (HSTS)](HTTP_Strict_Transport_Security.md) for supporting clients.

`Secure` cookie attribute must be used so session ID only exchanged over encrypted channel. Encrypted channel also protects vs some session fixation attacks where attacker intercepts/manipulates traffic to inject (fix) session ID in victim browser.

Best practices protecting session ID (esp. with cookies) and integrating HTTPS:

- Don't switch session from HTTP to HTTPS or vice-versa: discloses session ID in clear.
    - Redirecting to HTTPS: set or regenerate cookie **after** redirect.
- Don't mix encrypted and unencrypted contents (HTML pages, images, CSS, JavaScript files, etc) in same page or from same domain.
- Where possible, avoid offering public unencrypted and private encrypted contents from same host. Insecure content required → consider separate insecure domain.
- Implement [HTTP Strict Transport Security (HSTS)](HTTP_Strict_Transport_Security.md) to enforce HTTPS.

General TLS guidance: [Transport Layer Security Cheat Sheet](Transport_Layer_Security.md).

TLS doesn't protect vs session ID prediction, brute force, client-side tampering, or fixation; does protect effectively vs interception/theft of session IDs via man in the middle.

## Cookies

Cookie-based session ID exchange offers multiple security features as cookie attributes protecting exchange:

### Secure Attribute

`Secure` cookie attribute tells browsers to send cookie only over encrypted HTTPS (SSL/TLS) connection. Mandatory to prevent session ID disclosure via MitM (Man-in-the-Middle) attacks; attacker can't simply capture session ID from browser traffic.

Forcing app to use only HTTPS (even with TCP/80, HTTP, closed on host) doesn't protect vs session ID disclosure if `Secure` cookie unset: browser can be deceived to disclose session ID over unencrypted HTTP. Attacker intercepts/manipulates victim traffic and injects unencrypted HTTP reference to app, forcing browser to submit session ID in clear.

See also: SecureFlag

### HttpOnly Attribute

`HttpOnly` cookie attribute tells browsers to deny scripts (e.g. JavaScript or VBscript) access to cookies via DOM document.cookie object. Mandatory to prevent session ID stealing through XSS. But XSS combined with CSRF: requests to app still include session cookie, as browser always includes cookies. `HttpOnly` protects only cookie confidentiality; attacker can't use it offline, outside XSS context.

See [XSS (Cross Site Scripting) Prevention Cheat Sheet](Cross_Site_Scripting_Prevention.md).

See also: HttpOnly

### SameSite Attribute

`SameSite` attribute controls whether browsers send cookie with cross-site requests. `SameSite=Strict` excludes cross-site requests; `SameSite=Lax` permits top-level cross-site navigations using safe HTTP methods. Treat `SameSite` as [defense in depth against CSRF](Cross-Site_Request_Forgery_Prevention.md#samesite-cookie-attribute), not replacement for CSRF token. Session cookies must explicitly set `SameSite=Strict` (preferred) or `SameSite=Lax`. Never use `SameSite=None` without `Secure`; don't rely on browser-default value, which varies across browsers/versions.

See also: SameSite

### Cookie Name Prefixes

Cookie name prefixes bind cookies to security properties at browser level (RFC 6265bis §4.1.3):

- `__Host-` — cookie must be set with `Secure`, must not have `Domain` attribute, must use `Path=/`. Prevents subdomain forgery and HTTPS downgrade attacks. **Recommended for session IDs.**
- `__Secure-` — cookie must be set with `Secure`. Use only when subdomain sharing required.

Example:

```http
Set-Cookie: __Host-SessionID=<value>; Secure; HttpOnly; SameSite=Strict; Path=/
```

### Domain and Path Attributes

`Domain` cookie attribute tells browsers to send cookie only to specified domain and all subdomains. Unset: cookie sent only to origin server. `Path` cookie attribute tells browsers to send cookie only to specified directory or subdirectories (paths/resources) in web app. Unset: cookie sent only for directory (path) of requested resource that set cookie.

Recommended: narrow/restricted scope for both. `Domain` should not be set (restricts cookie to origin server); `Path` set as restrictive as possible to web app path using session ID.

Too permissive `Domain` (e.g. `example.com`) lets attacker attack session IDs between different hosts/web apps in same domain (cross-subdomain cookies). E.g., vulnerabilities in `www.example.com` might give attacker access to session IDs from `secure.example.com`.

Also don't mix web apps of different security levels on same domain. Vulnerability in one app lets attacker set session ID for different app on same domain via permissive `Domain` attribute (such as `example.com`); technique used in session fixation attacks.

`Path` attribute isolates session IDs between apps on different paths of same host, but highly recommended not to run different web apps (esp. different security levels/scopes) on same host. Other methods let these apps access session IDs, e.g. `document.cookie` object. Also any web app can set cookies for any path on that host.

Cookies vulnerable to DNS spoofing/hijacking/poisoning: attacker manipulates DNS resolution to force browser to disclose session ID for host/domain.

### Expire and Max-Age Attributes

Cookie-based session management uses non-persistent (session) cookies and persistent cookies. Cookie with `Max-Age` (preferred over `Expires`) or `Expires` attributes = persistent; stored on disk by browser until expiration time.

Use non-persistent cookies when authentication needn't persist across browser sessions, but don't rely on browser closure to end authenticated session. Browsers with session restore can retain session cookies after close. Enforce [session expiration](#session-expiration) server-side and invalidate session on logout; deleting cookie alone doesn't invalidate stolen copy of session ID.

- Ensure sensitive info not compromised: not persistent, encrypted, stored only for duration of need
- Ensure unauthorized activities can't occur via cookie manipulation
- Ensure secure flag set to prevent accidental non-secure transmission
- Determine if all state transitions in application code properly check for cookies and enforce their use
- Ensure entire cookie encrypted if sensitive data persisted in cookie
- Define all cookies used by application, their name, why needed

## HTML5 Web Storage API

WHATWG describes HTML5 Web Storage APIs, `localStorage` and `sessionStorage`, as mechanisms storing name-value pairs client-side.
Unlike HTTP cookies, `localStorage`/`sessionStorage` contents aren't automatically shared in requests/responses by browser; used for client-side storage.

### The localStorage API

> [!WARNING]
> Never store authentication tokens, session IDs, JWTs, refresh tokens, or any credential in `localStorage` or `sessionStorage`. APIs accessible to any JavaScript executing in origin → single XSS vulnerability discloses every token. Use `HttpOnly; Secure; SameSite=Strict` cookies (preferred) or Backend-for-Frontend (BFF) pattern. See OAuth 2.0 for Browser-Based Apps.

#### Scope

`localStorage` data accessible by pages loaded from same origin: scheme (`https://`), host (`example.com`), port (`443`), domain/realm (`example.com`).
Similar access to cookie `secure` flag: data stored from `https` not retrievable via `http`. Potential concurrent access from separate windows/threads → `localStorage` data may suffer shared access issues (e.g. race-conditions); consider non-locking (Web Storage API Spec).

#### Duration

`localStorage` data persists across browsing sessions, extending timeframe accessible to other system users.

#### Offline Access

Standards don't require `localStorage` data encrypted-at-rest → may be directly accessible from disk.

#### Use Case

WHATWG suggests `localStorage` for data needed across windows/tabs, across multiple sessions, and where large (multi-megabyte) volumes stored for performance.

### The sessionStorage API

#### Scope

`sessionStorage` stores data within calling window context: Tab 1 can't access data stored from Tab 2.
Like `localStorage`, accessible by pages loaded from same origin: scheme (`https://`), host (`example.com`), port (`443`), domain/realm (`example.com`).
Similar access to cookie `secure` flag: data stored from `https` not retrievable via `http`.

#### Duration

`sessionStorage` stores data only for current browsing session. Tab closed → data not retrievable. Doesn't necessarily prevent access if browser tab reused or left open. Data may persist in memory until garbage collection event.

#### Offline Access

Standards don't require `sessionStorage` data encrypted-at-rest → may be directly accessible from disk.

#### Use Case

WHATWG suggests `sessionStorage` for data relevant to one-instance of workflow (e.g. ticket booking details) while multiple workflows run concurrently in other tabs. Window/tab-bound nature keeps data from leaking between workflows in separate tabs.

### References

- Web Storage APIs
- LocalStorage API
- SessionStorage API
- WHATWG Web Storage Spec

## Web Workers

Web Workers run JavaScript in separate global context. Main window and worker communicate via messages using `postMessage()`.

### Use Case

Worker can keep secret in memory when persistence across page refresh not required. To isolate secret from main window: obtain it within worker, keep secret-dependent operations there, never return secret to main window.

Isolation can reduce direct access to existing secret, but doesn't make app safe vs XSS. Malicious page code can still request secret-dependent operations and read results. OAuth browser-apps guidance (RFC 10017 section 8.3) also explains isolating existing refresh token doesn't stop malicious code obtaining new tokens via another authorization flow.

Use worker only when browser-side code needs secret-dependent operations. Expose narrow message interface; enforce authorization on server. Worker isolation doesn't replace XSS prevention or server-side session controls; prefer HttpOnly cookie or backend holding tokens when browser needn't handle them.

## Session ID Life Cycle

### Session ID Generation and Verification: Permissive and Strict Session Management

Two session management mechanisms re session fixation vulnerabilities: permissive and strict. Permissive: web app initially accepts any user-set session ID value as valid, creating new session for it. Strict: web app accepts only session ID values previously generated by it.

Session tokens should be handled by web server if possible, or generated via cryptographically secure random number generator.

Strict most common today (more secure), but PHP defaults to permissive. Developers must ensure app doesn't use permissive mechanism. Web apps must never accept session ID they never generated; on receipt, generate and offer user new valid session ID. Also detect as suspicious activity and generate alert.

### Manage Session ID as Any Other User Input

Session IDs = untrusted, like any user input; thoroughly validate/verify. Depending on mechanism, session ID arrives in GET or POST parameter, URL, or HTTP header (e.g. cookies). Not validating/filtering invalid session ID values before processing can enable other web vulnerabilities: SQL injection if session IDs stored in relational database, persistent XSS if stored and reflected back.

### Renew the Session ID After Any Privilege Level Change

Web app must renew/regenerate session ID after any privilege level change within user session. Mandatory most commonly during authentication: privilege level changes from unauthenticated (anonymous) to authenticated, though sometimes not yet authorized. Other scenarios: password changes, permission changes, switching from regular user role to administrator role. For all sensitive pages: ignore any previous session IDs, assign only current session ID to every new request for protected resource, destroy old/previous session ID.

Common frameworks provide session functions to renew session ID: `request.getSession(true)` & `HttpSession.invalidate()` (J2EE), `Session.Abandon()` & `Response.Cookies.Add(new...)` (ASP .NET), `session_start()` & `session_regenerate_id(true)` (PHP).

Regeneration mandatory to prevent session fixation attacks, where attacker sets session ID in victim browser instead of gathering victim's session ID as in most other session-based attacks, independent of HTTP or HTTPS. Mitigates impact of other web vulnerabilities that can launch session fixation, such as HTTP response splitting or XSS (see Raul Siles BlackHat EU 2011 slides and whitepaper).

Complementary recommendation: different session ID or token name (or set of session IDs) pre and post authentication → app tracks anonymous and authenticated users without exposing/binding user session between states.

### Reauthentication After Risk Events

Require reauthentication after high-risk events such as:

- Changes to critical user information (e.g., password, email address)
- Login attempts from new or suspicious IP addresses or devices
- Account recovery flows (e.g., password reset or compromised-account detection)

Best practices: [Reauthentication After Risk Events](Authentication.md#re-authentication-after-risk-events) section in Authentication Cheat Sheet

### Additional Resources

- Why Frequent Reauthentication Can Be a UX Pitfall (Tailscale)

### Considerations When Using Multiple Cookies

App uses cookies for session ID exchange and multiple cookies set for session: verify all cookies (and enforce relationships between them) before allowing access to user session.

Common: app sets user cookie pre-authentication over HTTP to track unauthenticated (anonymous) users. After authentication, new post-authentication secure cookie set over HTTPS, binding both cookies and user session. App not verifying both cookies for authenticated sessions → attacker uses pre-authentication unprotected cookie to access authenticated session (see Raul Siles BlackHat EU 2011 slides and whitepaper).

Avoid same cookie name for different paths/domain scopes within same app: adds complexity, potential scoping issues.

## Session Expiration

Set expiration timeouts for every session (mandatory), defining how long session stays active; minimizes attacker window to hijack active sessions. Insufficient expiration increases exposure to other session-based attacks: attacker reusing valid session ID needs session still active.

Shorter interval → less time attacker can use valid session ID. Set timeouts per purpose/nature of app, balancing security and usability so users complete operations without frequent expiry.

Idle and absolute timeouts depend on app/data criticality. Common idle timeouts: 2-5 minutes for high-value apps, 15-30 minutes for low risk apps. Absolute timeouts depend on typical usage length; app used by office worker full day: 4 to 8 hours.

On expiry, app must actively invalidate session on both client and server. Server side most relevant, mandatory for security.

Client-side invalidation for most exchange mechanisms: clear token value. E.g. invalidate cookie: provide empty (or invalid) session ID value and set `Expires` (or `Max-Age`) to past date (persistent cookie): `Set-Cookie: id=; Expires=Friday, 17-May-03 18:45:00 GMT`

Server-side close/invalidate is mandatory when session expires or user logs out: use session management mechanism functions/methods, e.g. `HttpSession.invalidate()` (J2EE), `Session.Abandon()` (ASP .NET), `session_destroy()/unset()` (PHP).

### Automatic Session Expiration

#### Idle Timeout

All sessions should implement idle/inactivity timeout: session closed and invalidated after defined idle period since last HTTP request for that session ID.

Limits chance attacker guesses and uses another user's valid session ID. If attacker hijacks session, idle timeout doesn't limit actions: attacker can periodically generate activity to keep session active.

Enforce session timeout management/expiration server-side. Client-enforced timeout (e.g. session token or client parameters tracking time, like minutes since login) can be manipulated by attacker to extend session.

#### Absolute Timeout

All sessions should implement absolute timeout regardless of activity: maximum active time, closing and invalidating session after defined period since creation. Then user must (re)authenticate and establish new session.

Limits time attacker can use hijacked session to impersonate victim.

#### Renewal Timeout

Alternatively, additional renewal timeout automatically renews session ID mid-session, independent of activity (thus idle timeout).

After specific time since creation, app regenerates new ID for session and sets/renews it on client. Previous session ID stays valid for a safety interval until client learns new ID and uses it; then app invalidates previous ID.

Minimizes time a session ID value, possibly obtained by attacker, can be reused to hijack session even while victim session active. Session stays alive on legitimate client; ID transparently renewed periodically each time renewal timeout expires. Complements idle and absolute timeouts, esp. when absolute timeout extends significantly (e.g. requirement to keep sessions open long).

Depending on implementation, potential race condition: attacker with still-valid previous session ID sends request before victim, right after renewal timeout expires, and gets renewed session ID first. At least then victim may notice attack: session suddenly terminated as associated session ID no longer valid.

### Manual Session Expiration

Provide mechanisms letting security-aware users actively close session when finished.

#### Logout Button

Provide visible, easily accessible logout (logoff, exit, close session) button in app header or menu, reachable from every resource and page, so user can manually close session anytime. Per *Session_Expiration* section, app must invalidate session at least server-side.

**NOTE**: Not all apps let users close current session. Client-side enhancements let conscientious users protect sessions by helping close them diligently.

### Web Content Caching and Clear-Site-Data

After session ends, private/sensitive session data may remain accessible via browser cache. Set cache policy in HTTP response headers on sensitive pages. Don't treat HTML `<meta http-equiv>` tags as equivalent cache-control mechanism: browsers support only specific processing instructions; unsupported values can be ignored.

Use `Cache-Control: no-store` on responses with session identifiers or sensitive session data. Unlike `no-cache` (allows storage, requires revalidation before reuse), `no-store` directs private and shared HTTP caches not to store request or response (RFC 9111 section 5.2.2.5). Not a privacy guarantee: malicious/compromised caches might ignore directive.

Also ensure previously stored sensitive data removed when session ends: return Clear-Site-Data response header (e.g., `Clear-Site-Data: "cache", "cookies", "storage"`) at logout/session termination. Instructs browser to delete cached resources, cookies, other client-side storage for origin → complete session cleanup.

> **Note:** Directive `Cache-Control: no-cache="Set-Cookie, Set-Cookie2"` sometimes suggested to prevent session ID caching, but syntax not widely supported, may cause unintended behavior. Use `Cache-Control: no-store` for stronger protection. `Clear-Site-Data: "cache"` clears every stored response for site in browser cache; use with care. Doesn't affect shared/intermediate caches.
> **Reference:** MDN - Cache-Control and MDN - Clear-Site-Data header

## Reauthentication After Risk Events

For session integrity and account protection, require reauthentication on detected high-risk events, e.g.:

- Attempted or completed password changes
- Login from new or suspicious IP address or device
- Completion of account recovery or challenge flows (e.g., hacked-lock scenarios)

Mitigates session hijacking and unauthorized access, esp. with long-lived sessions or external identity providers.

**Recommended Practices:**

- Prompt for primary credentials (e.g., password) or enforce MFA
- Clear messaging explaining need to reauthenticate

## Additional Client-Side Defenses for Session Management

Client-side countermeasures (typically JavaScript checks) complement session management defenses. Not bullet proof, easily defeated by skilled attacker, but add another layer intruders must bypass.

### Initial Login Timeout

JavaScript in login page measures time since page load/session ID grant. Login attempted after specific time: client code notifies user max login time passed, reloads login page, retrieving new session ID.

Forces pre-authentication session ID renewal, avoiding reuse of previously used (or manually set) session ID by next victim on same computer, e.g. in session fixation attacks.

### Limits of Logout on Browser Close

Browser close events can't reliably enforce logout. E.g., `beforeunload` may not fire when mobile browser closed from app manager. Use [server-side idle and absolute timeouts](#automatic-session-expiration) and explicit [logout action](#logout-button) to invalidate sessions. Client-side close handlers can supplement but must not replace them.

### Disable Web Browser Cross-Tab Sessions

After login and session establishment, JavaScript can force re-authentication if new browser tab/window opens against same app. App doesn't allow multiple tabs/windows sharing same session; tries to force browser not to share same session ID simultaneously between them.

**NOTE**: Can't be implemented if session ID exchanged via cookies; cookies shared by all tabs/windows.

### Automatic Client Logout

JavaScript in all (or critical) pages can automatically log out client sessions after idle timeout, e.g. redirecting to logout page (same resource as logout button).

Benefit of client-side code enhancing server-side idle timeout: user sees session finished due to inactivity, or is notified in advance via countdown timer/warnings that session about to expire. Avoids work loss on pages with extensive input data from silently expired server-side sessions.

## Session Attacks Detection

### Session ID Guessing and Brute Force Detection

Guessing/brute forcing valid session ID needs multiple sequential requests using different session IDs from single (or set of) IP address(es). Analyzing session ID predictability (e.g. statistical analysis) also needs multiple sequential requests from single (or set of) IP address(es) to gather new valid session IDs.

Apps must detect both scenarios by number of attempts to gather (or use) different session IDs, and alert and/or block offending IP address(es).

### Detecting Session ID Anomalies

Detect anomalies tied to session ID, such as manipulation. OWASP AppSensor Project provides framework/methodology for built-in intrusion detection in web apps focused on anomalies/unexpected behaviors, as detection points and response actions. Business logic details and advanced intelligence sometimes available only inside app (not external protection layers), enabling multiple session-related detection points: existing cookie modified/deleted, new cookie added, session ID from another user reused, user location or User-Agent changes mid-session.

### Binding the Session ID to Other User Properties

To detect (and sometimes protect vs) user misbehavior and session hijacking, highly recommended: bind session ID to other user/client properties, e.g. client IP address, User-Agent, client-based digital certificate. Change/anomaly between these properties mid-session = very good indicator of session manipulation/hijacking attempts; can alert and/or terminate suspicious session.

Properties can't be trusted to defend vs session attacks but significantly increase detection (and protection). Skilled attacker can bypass: reuse victim's IP address by sharing same network (very common in NAT environments, like Wi-Fi hotspots) or same outbound web proxy (very common in corporate environments), or manually modify User-Agent to match victim's.

### Logging Sessions Life Cycle: Monitoring Creation, Usage, and Destruction of Session IDs

Increase logging to cover full session life cycle. Record session events: creation, renewal, destruction of session IDs; usage details in login/logout operations; privilege level changes within session; timeout expiration; invalid session activities (when detected); critical business operations during session.

Log timestamp, source IP address, requested resource, event type, result/error code, user ID when needed for session monitoring. Record only selected header and parameter fields after excluding credentials and sensitive values, per [Logging Cheat Sheet](Logging.md#data-to-exclude). Don't log raw session IDs; use session correlation approach below.

Sensitive data like session ID must not be in logs, protecting logs vs local/remote session ID disclosure or unauthorized access. Still need session-specific info to correlate log entries to sessions. Recommended: log salted-hash of session ID instead of session ID itself → session-specific correlation without exposing session ID.

Thoroughly protect administrative interfaces managing all current active sessions. Frequently used by support personnel to solve session-related or general issues by impersonating user and viewing app as user does.

Session logs become a main intrusion detection data source; intrusion protection systems can use them to automatically terminate sessions and/or disable user accounts when attacks detected. Active protections implemented: log those defensive actions too.

### Simultaneous Session Logons

App design decides whether multiple simultaneous logons from same user allowed, from same or different client IP addresses. Not allowing them: take effective action after each new authentication, implicitly terminating previously available session, or asking user (through old, new, or both sessions) which session remains active.

Recommended: user capabilities to check active session details anytime, monitor/alert user about concurrent logons, remotely terminate sessions manually, and track account activity history (logbook) recording client details such as IP address, User-Agent, login date and time, idle time, etc.

## Session Management WAF Protections

Cases: app source code unavailable or unmodifiable, or changes for above recommendations/best practices imply full architecture redesign, not easily done short term.

In these scenarios, or to complement app defenses, use external protections such as Web Application Firewalls (WAFs) mitigating described session management threats.

WAFs offer detection/protection vs session-based attacks. Trivial: enforce cookie security attributes (`Secure`, `HttpOnly` flags) via basic rewriting rules on `Set-Cookie` header for all app responses setting new cookie.

More advanced: WAF tracks sessions and session IDs, and applies protections vs session fixation (renewing session ID client-side when privilege changes detected), enforcing sticky sessions (verifying relationship between session ID and other client properties like IP address or User-Agent), or managing session expiration (forcing both client and app to finalize session).

Open-source ModSecurity WAF plus OWASP Core Rule Set provides capabilities to detect/apply security cookie attributes, countermeasures vs session fixation attacks, session tracking features to enforce sticky sessions.

## References

- NIST SP 800-63B-4: Session Management
- MDN: Set-Cookie
