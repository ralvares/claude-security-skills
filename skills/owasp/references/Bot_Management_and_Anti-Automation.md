# Bot Management and Anti-Automation Cheat Sheet

## Introduction

Automated traffic, not DDoS but abusive: credential stuffing, content scraping, inventory hoarding (scalping), fake account creation, gift-card enumeration, card testing, fake reviews, click fraud, skewed analytics. OWASP **Automated Threats to Web Applications** project (OAT-001 through OAT-021) catalogs these.

Goes beyond [Credential Stuffing Prevention Cheat Sheet](Credential_Stuffing_Prevention.md); covers full automated abuse spectrum: architecture, signals, response strategy, CAPTCHA alternatives.

Goal **not to block all bots** (search crawlers, monitoring agents, accessibility tools legitimate) but raise cost of abusive automation, leave legitimate users and bots unaffected.

## Common Threats and Risks

- **OAT-008 Credential Stuffing**: replaying breached username/password pairs.
- **OAT-011 Scraping**: large-scale content, price, PII extraction.
- **OAT-005 Scalping / Inventory Hoarding**: buying limited stock for resale.
- **OAT-019 Account Creation**: fake accounts at signup endpoints.
- **OAT-012 Cashing Out**: stolen accounts used to extract value.
- **OAT-001 Carding**: testing stolen card numbers via low-value purchases.
- **OAT-003 Ad Fraud**: fake clicks and impressions.
- **OAT-002 Token Cracking**: brute-forcing gift cards, vouchers, coupons.
- **OAT-015 Denial of Inventory**: adding items to cart to deplete stock.
- **OAT-014 Vulnerability Scanning**: automated probing for weaknesses.
- **Skewed business metrics**: bots polluting A/B tests, recommendations, fraud models.
- **Privacy violations**: over-collecting fingerprinting data to defend against bots.

## Threat Modeling Before Controls

Before tooling, identify which OAT categories apply and which endpoints at risk. Login form, search page, checkout, public API: very different threat profiles and defenses.

| Endpoint type | Primary OAT risk | Suggested first control |
|---|---|---|
| Login | OAT-008 Credential Stuffing | Rate limit + breached-password check + MFA |
| Signup | OAT-019 Account Creation | Email/phone verification + velocity limits |
| Search / catalog | OAT-011 Scraping | Rate limit per identity + behavioral signal |
| Checkout / cart | OAT-005 Scalping, OAT-001 Carding | Queue + purchase limits + 3D Secure |
| Public API | OAT-011, OAT-014 | API keys + per-key quotas + signed requests |
| Comments / reviews | OAT-020 Account Aggregation, spam | Reputation + delayed publishing |

## Layered Defense Architecture

Single control brittle. Combine three layers:

1. **Edge layer**: CDN, WAF, anti-bot service: IP reputation, ASN filtering, TLS fingerprint (JA3/JA4), HTTP/2 fingerprint, basic rate limits.
2. **Application layer**: session-aware rate limits, identity-bound quotas, behavioral signals, honeypots, CAPTCHA challenges.
3. **Backend / business layer**: transaction anomaly detection, account-velocity rules, fraud scoring, async review queues.

Request human-looking at one layer (good IP, valid CAPTCHA) may fail another (10 checkouts in 30 seconds w/ different cards).

## Rate Limiting and Quotas

Foundational control. Apply at multiple keys, not just IP.

- **Per IP**: coarse, defeated by residential proxy networks, still useful as floor.
- **Per session / cookie**: defeated by cookie clearing, useful vs unsophisticated bots.
- **Per authenticated identity**: most reliable; applies after login.
- **Per endpoint**: login deserves tighter limit than home page.
- **Per ASN or geo**: useful when datacenter-ASN traffic unexpected.

Use token-bucket or sliding-window. Avoid fixed-window counters: allow bursts at boundary times.

Correct login-endpoint rate limit = **two independent buckets**, both under threshold for request to pass:

- **Per-username bucket**: limits attempts vs any single account regardless of source IP. Defends targeted account from distributed attack.
- **Per-IP (or per-IP+ASN) bucket**: limits attempt volume from one source vs any account. Defends vs credential-stuffing sweeps trying one password per account.

Common mistake: single bucket keyed on IP+username *combination* (e.g., `login:<ip>:<user>`). One bucket per pair → single IP attempts threshold vs unlimited usernames before any limit fires, exactly the credential-stuffing pattern to stop. Always check two buckets separately.

On limit hit return generic `429 Too Many Requests`. Avoid `Retry-After` values precise enough to schedule retries against. No diagnostic detail (which bucket fired, remaining attempts): useful only to attackers tuning tooling.

## Device and Network Fingerprinting (Privacy-Aware)

Fingerprinting detects bots rotating IPs but reusing client environments. Use **passive, network-level** signals first; client-side fingerprinting only when necessary.

Network signals (no client cooperation):

- **JA3 / JA4**: TLS ClientHello fingerprint. Headless tooling often yields uncommon JA3 values.
- **HTTP/2 fingerprint (Akamai)**: frame ordering, settings, priorities.
- **Client Hints (`Sec-CH-UA-*`)**: declared but verifiable vs TLS fingerprint.

Browser-side signals (last resort, w/ consent where required):

- WebGL renderer string, canvas hash, font list, audio context: strong but invasive.
- Page-level behavioral telemetry (mouse paths, scroll, focus): collect only on sensitive flows.

**Privacy guidance:**

- Document fingerprinting in privacy notice; some jurisdictions (EU/UK ePrivacy, CCPA) require disclosure or opt-out.
- Hash or truncate fingerprints before storage; no raw values enabling re-identification.
- Short retention (hours to days) for anti-bot signals: long enough to detect, short enough to limit surveillance risk.
- Avoid fingerprinting authenticated, low-risk traffic (logged-in user reading own profile needs no repeat fingerprint).

## CAPTCHA and Its Modern Alternatives

Visible CAPTCHAs (image grids, distorted text): accessibility-hostile, ML-solvable, outsourced to human solver farms for fractions of a cent per solve. Treat as **last-resort step-up**, not primary defense.

Prefer alternatives or layer them:

- **Cryptographic attestation tokens**: Privacy Pass (RFC 9576) lets origin verify client satisfied issuer's attestation policy, e.g. CAPTCHA, device check, account validation. Select trusted issuers w/ policies matching use case; valid token ≠ general proof requester human. Privacy guarantees depend on deployment and trust assumptions.
- **Managed challenges**: Cloudflare Turnstile returns validation result, not risk score. Validate each token server-side w/ Siteverify, require `success: true`, check expected hostname and configured action. Tokens expire after five minutes, single-use.
- **Invisible risk scoring**: reCAPTCHA v3 and hCaptcha Enterprise return scores for app-defined thresholds.
- **Proof of work (PoW)**: require computation before serving selected expensive requests. Raises automation cost, does not establish client human. Benchmark supported clients: overly hard puzzles (RFC 8019) can deny service to legitimate users.
- **WebAuthn / Passkeys**: for high-value flows, possession of registered authenticator = far stronger bot signal than any CAPTCHA.

Use maintained challenge implementation, not standalone hash check. Keep challenge, difficulty, expiry under server control; reject unknown, expired, spent challenges; prevent concurrent reuse. Bind accepted work to intended policy. Anubis challenge lifecycle illustrates validation and reuse checks beyond hash itself. Keep rate limits after challenge passed.

## Honeypots and Tarpits

Cheap, effective, zero impact on legitimate users.

- **Hidden form fields**: `<input type="text" name="website" />` styled `display:none`, labeled "leave blank." Bots fill, humans don't. Reject submission.
- **Robots.txt traps**: disallow bait path in `robots.txt`; treat any traffic to it as malicious (well-behaved crawlers obey, abusive ones don't).
- **Tarpitting**: for detected bots don't return `403`. Slow responses progressively (e.g., `setTimeout(send, 5000 + jitter)`). Bot throughput collapses w/o telegraphing detection.
- **Canary content**: embed unique watermarked records on listing pages. Appearing elsewhere = proof of scraping + scraper fingerprint.

```html
<!-- Honeypot field. Real users never see or fill this. -->
<div aria-hidden="true" style="position:absolute;left:-10000px;top:auto;width:1px;height:1px;overflow:hidden;">
  <label for="company_url">Leave this field empty</label>
  <input type="text" id="company_url" name="company_url" tabindex="-1" autocomplete="off" />
</div>
```

Server side: if `company_url` non-empty, silently drop request or route to tarpit.

## Defending Specific Flows

### Account creation (OAT-019)

- Verify email **before** account usable; gate features behind it, don't just send confirmation.
- Check email vs disposable-domain lists (refresh weekly).
- Phone verification: check carrier type; VoIP numbers abundant and cheap.
- Per-IP, per-ASN, per-device-fingerprint signup velocity limit (e.g., 3 per hour).
- Reject signup if email local-part high entropy and recently-created domain.

### Login (OAT-008)

- Per-username **and** per-IP limits w/ separate windows.
- Check submitted password vs breach corpora (e.g., HaveIBeenPwned k-Anonymity API); don't block, require step-up.
- On suspicious patterns require MFA even for low-risk users. See [Authentication](Authentication.md) and [Multifactor Authentication](Multifactor_Authentication.md) cheat sheets.
- See [Credential Stuffing Prevention Cheat Sheet](Credential_Stuffing_Prevention.md).

### Inventory / scalping (OAT-005, OAT-015)

- **Waiting room / virtual queue** for limited drops: randomized admission, tokens bound to session and identity.
- **Per-account purchase limits** enforced server side, incl. identity proxies (same payment method, shipping address, device).
- **Hold time**: cart inventory paid within N seconds or released; prevents cart-camping.
- **Address and payment dedup** at order time via normalized hashes (street + zip, BIN + last4 + holder hash).

### Public APIs

- API keys w/ rotating secrets, **not** static bearer tokens checked in to client code.
- Per-key quotas advertised in `X-RateLimit-*` headers so well-behaved clients self-throttle.
- Request signing (e.g., HMAC of method + path + timestamp + body) prevents replay, requires stable secret.
- Tier APIs explicitly: public catalog endpoint may serve cached, slightly-delayed data; partner APIs serve realtime data w/ authenticated key.

## Response Strategy: Don't Always Block

Hard blocks teach attackers what worked. Graduated response more durable.

| Confidence | Response |
|---|---|
| Low (suspicious) | Log; serve normally; flag the session |
| Medium | Step-up: CAPTCHA, MFA, or PoW challenge |
| High | Tarpit (slow responses), serve stale or randomized data |
| Very high | Soft-block specific actions (e.g., disable checkout, allow browsing) |
| Confirmed abuse | Account hold + manual review; do not delete to allow forensics |

Scrapers: returning **plausible but slightly wrong data** (price ±1%, fake stock counts) poisons dataset, often more damaging to scraping business case than 403.

## Logging and Monitoring

Bot incidents detected post-hoc almost as often as real time. Log enough to investigate.

Per request to sensitive endpoint capture:

- Timestamp, request ID, route, status code.
- Client IP, ASN, country.
- TLS fingerprint (JA3/JA4) and HTTP/2 fingerprint.
- User-Agent (raw + parsed family/version).
- Authenticated identity (or session ID hash).
- Decision and signals (e.g., `bot_score=0.87`, `rule=login_velocity`).

Mask credentials and PII in logs (see [Logging Cheat Sheet](Logging.md)).

Dashboards: requests-per-second by endpoint, 4xx/5xx rate, fail rate by route, signup-to-purchase funnel, login success rate. Sudden shifts (more than 3-sigma) = bot signals.

```python
# Minimal structured log record for an anti-bot decision.
import json, hashlib, time

def log_decision(req, score, decision, rule):
    record = {
        "ts": int(time.time() * 1000),
        "route": req.path,
        "ip": req.remote_addr,
        "asn": req.headers.get("X-ASN"),  # set by your edge
        "ja4": req.headers.get("X-TLS-JA4"),
        "ua": req.headers.get("User-Agent"),
        "session": hashlib.sha256(
            (req.cookies.get("sid") or "").encode()
        ).hexdigest()[:16],
        "score": score,
        "decision": decision,   # allow | challenge | tarpit | block
        "rule": rule,
    }
    print(json.dumps(record))
```

## Privacy and Compliance

Anti-bot defenses collect data; treat as any data-processing activity.

- Document lawful basis and data categories collected. Assess consent requirements or exemptions for device storage and access, incl. fingerprinting; UK ICO guidance: legitimate interests cannot replace consent when consent required.
- **Data minimization**: collect what's needed to score request, discard rest.
- Short retention for raw signals; aggregate for longer-term analytics.
- Third-party anti-bot vendor: list as sub-processor, review their DPIA.
- Don't block users solely for hardened browser (privacy-respecting users often look "bot-like"). Prefer challenge to block.
- Provide accessible alternative when challenging w/ CAPTCHAs (audio CAPTCHA, support contact).

## Anti-Patterns to Avoid

- Blocking all non-standard User-Agents: breaks legitimate research, accessibility, integration tools.
- Relying solely on single edge vendor "magic box": mis-tuned → whole site down or open.
- Storing raw fingerprints indefinitely.
- CAPTCHAs at every login attempt: destroys conversion, trains users to solve mechanically.
- "Hidden" anti-bot rules w/o logging: can't tune what can't see.
- Hard-blocking on first signal, no graduated response: gives attackers clean signal to iterate against.

## Checklist

- [ ] Map app endpoints to OWASP Automated Threats (OAT) catalog.
- [ ] Rate limits at IP, identity, endpoint levels, sliding window.
- [ ] Layer defenses across edge, application, business logic.
- [ ] TLS/HTTP-level fingerprints before browser fingerprinting.
- [ ] Replace visible CAPTCHAs w/ attestation tokens, invisible scoring, or PoW where possible.
- [ ] Honeypot fields + tarpit responses for high-confidence detections.
- [ ] Verify email and phone at signup; track signup velocity.
- [ ] Per-account purchase, address, payment-method limits on scarce inventory.
- [ ] Sign API requests; advertise quotas via `X-RateLimit-*` headers.
- [ ] Log decisions w/ signals; build anomaly dashboards.
- [ ] Mask PII; rotate raw signal storage on short schedule.
- [ ] Document anti-bot processing in privacy notice.
- [ ] Accessibility alternatives to any user-facing challenge.

## References

- Pwned Passwords API
- OWASP Automated Threat Handbook
