# Cookie Theft Mitigation Cheat Sheet

## Introduction

2FA and Passkey made login more robust; password-only theft makes spoofing difficult.

But attacker stealing valid session cookie can hijack session for session lifetime. Stealing session cookie = same impact as stealing credentials until expiry. Robust authentication ≠ sufficient countermeasure for Cookie Theft.

Cookie theft via malware, phishing, application vulnerabilities. Apply preventive controls in [Session Management Cheat Sheet](Session_Management.md); monitor for stolen-cookie misuse. Detection complements, doesn't replace, these controls.

## Cookie Theft Mitigation

Session Cookies issued at login. If stolen and used to hijack session from attacker's device, environment information of the connection changes.

E.g., stolen cookies used from another country → detect via significant IP address change.

Multiple vectors detect changed user environment:

- Access from different region (IP Address)
- Access from different device (User-Agent)
- Access from different language setting (Accept-Language)
- Access at different time of day (Date)

Save this info at session establishment, compare each request → detect changed user environment.

Simple comparison alone makes judgment hard. User changes Wi-Fi network → IP changes. User updates browser → User-Agent changes. Compare values and check whether meaning changed significantly.

### False negatives/positives

Session cookie granted access in one country used from another: could be attack, or user traveled.

IP-Geo change ≠ certain attack. Detection method has **False Positives** (seems attack, isn't).

Unchanged IP-Geo: attacker may attack from same country. Method has **False Negatives** (seems not attack, is).

### Cookie Theft Detection

Implementation case study: Slack's compromised-cookie detection design.

Store session info server-side at session establishment; detect hijacking when info changes significantly.

Core info to save:

- IP Address
- User-Agent
- Accept-Language
- Date

Headers varying by Device and OS also effective monitoring targets:

- Accept
- Accept-Encoding

`Sec-CH-*` Client Hint headers give info on browser, device, user preferences. Differ from `Sec-Fetch-*` Fetch Metadata headers (request context). Client Hints may be omitted depending on browser support, server requests, client permissions → optional signals only.

- sec-ch-prefers-color-scheme
- sec-ch-ua
- sec-ch-ua-arch
- sec-ch-ua-bitness
- sec-ch-ua-form-factors
- sec-ch-ua-full-version
- sec-ch-ua-full-version-list
- sec-ch-ua-mobile
- sec-ch-ua-model
- sec-ch-ua-platform
- sec-ch-ua-platform-version
- sec-ch-ua-wow64

Illustrative Express sketch assumes server-side session store and trusted middleware populating `req.clientIP` and `req.session`. Read request headers w/ Express's `req.get()`; server timestamp when establishing session:

```js
const session = SessionStorage.create()
session.save({
  ip: req.clientIP,
  user_agent: req.get("User-Agent"),
  date: Date.now(),
  accept_language: req.get("Accept-Language"),
  // ...
})
```

Large change detected comparing info on each request → session possibly hijacked.

### Session Validation

Possible hijack: most reliable verification = re-authenticate. Temporarily invalidate session, require authentication again, issue new session cookie → attacker's stolen cookie useless.

Monitoring yields false positives; too frequent re-authentication = poor user experience.

CAPTCHA may limit automated abuse but doesn't establish requester controls authenticator bound to account (basis of authentication). Don't treat solved CAPTCHA as validation of suspected stolen session. Use [reauthentication with an account-bound authenticator](Authentication.md#re-authentication-after-risk-events) before restoring access depending on trusting session.

Sketch: comparison helpers return `false` when signal requires reauthentication. Must handle missing headers and legitimate changes. Express middleware must end response or call `next()`. Error response below blocks this request; application must also restrict or invalidate suspect session and complete account-bound reauthentication before restoring access. Sketch implements no session storage, authorization, or CSRF protection.

```js
function cookieTheftDetectionMiddleware(req, res, next) {
  const currentIP = req.clientIP
  const expectedIP = req.session.ip
  if (checkGeoIPRange(currentIP, expectedIP) === false) {
    return res.status(403).send("Reauthentication required")
  }
  const currentUA = req.get("User-Agent")
  const expectedUA = req.session.user_agent
  if (checkUserAgent(currentUA, expectedUA) === false) {
    return res.status(403).send("Reauthentication required")
  }

  next()
}

app.post("/users/delete", cookieTheftDetectionMiddleware, (req, res) => {
 // ...
})
```

Usually such functions provided as middleware, or by WAF (Web Application Firewall) in front of web server.

If comparison hurts performance, tune: set priority per path, check intensively only endpoints viewing or modifying important information.

## Device Bound Session Credentials

Ordinary session cookies = bearer credentials: anyone possessing valid cookie can use it until expiry or server invalidation.

Device Bound Session Credentials (DBSC) uses device-bound signing key to prove possession when refreshing short-lived cookies (DBSC refresh design). Ordinary app requests still use those cookies as bearer credentials; DBSC doesn't bind every request to key.

Attacker can replay stolen cookie during remaining lifetime. Protecting key limits attacker's ability to refresh session from another device; doesn't make stolen cookie immediately unusable.

DBSC doesn't prevent abuse while attacker retains access to compromised browser or device: may obtain fresh cookies or use protected key through compromised environment. Account for documented threat-model limits when choosing session lifetimes and incident-response controls.

## References

- NIST SP 800-63B-4: Authentication and Authenticator Management
- Device Bound Session Credentials explainer
