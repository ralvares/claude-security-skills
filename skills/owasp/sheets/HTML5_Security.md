# HTML5 Security Cheat Sheet

## Introduction

Guide for implementing HTML 5 securely.

## Communication APIs

### Web Messaging

Web Messaging (aka Cross Domain Messaging): messaging between documents of different origins, generally safer than past hacks. Still:

- Posting message: state expected origin explicitly as second argument to `postMessage`, not `*`, to prevent sending to unknown origin after redirect or other change of target window's origin.
- Receiving page **always**:
    - Checks sender's `origin` attribute to verify data comes from expected location.
    - Validates input on event's `data` attribute for desired format.
- Don't assume control over `data` attribute. Single [Cross Site Scripting](Cross_Site_Scripting_Prevention.md) flaw in sending page lets attacker send messages of any format.
- Both pages interpret exchanged messages only as **data**. Never evaluate as code (e.g. `eval()`) or insert into page DOM (e.g. `innerHTML`): creates DOM-based XSS. See [DOM based XSS Prevention Cheat Sheet](DOM_based_XSS_Prevention.md).
- Assign data to element with safer `element.textContent=data;`, not insecure `element.innerHTML=data;`
- Match origin exactly to expected FQDN(s). Code `if(message.origin.indexOf(".owasp.org")!=-1) { /* ... */ }` very insecure, wrong behavior: `owasp.org.attacker.com` matches.
- Embedding external content/untrusted gadgets and allowing user-controlled scripts (highly discouraged): see [sandboxed frames](HTML5_Security.md#sandboxed-frames).

### Cross Origin Resource Sharing

- Validate URLs passed to `XMLHttpRequest.open`. Current browsers allow cross domain URLs; can lead to code injection by remote attacker. Extra attention to absolute URLs.
- URLs responding with `Access-Control-Allow-Origin: *` must not include sensitive content or info aiding further attacks. Use `Access-Control-Allow-Origin` header only on chosen URLs needing cross-domain access; not whole domain.
- Allow only selected, trusted domains in `Access-Control-Allow-Origin`. Prefer allowing specific domains over blocking or allowing any (no `*` wildcard, no blindly returning `Origin` header content without checks).
- CORS does not prevent requested data going to unauthorized location. Server still performs usual [CSRF](Cross-Site_Request_Forgery_Prevention.md) prevention.
- Fetch Standard recommends pre-flight request with `OPTIONS` verb, but current implementations might not perform it; "ordinary" (`GET` and `POST`) requests must perform any necessary access control.
- Discard requests received over plain HTTP with HTTPS origins to prevent mixed content bugs.
- Don't rely only on Origin header for Access Control. Browser always sends it in CORS requests, but may be spoofed outside browser. Use application-level protocols to protect sensitive data.

### WebSockets

- See [WebSocket Security Cheat Sheet](WebSocket_Security.md) for WebSocket specific protections.

### Server-Sent Events

- Validate URLs passed to `EventSource` constructor. Cross-origin connections use CORS, require permission from event-stream server.
- Process messages (`event.data`) as data; never evaluate content as HTML or script code.
- Always check message origin attribute (`event.origin`) for trusted domain. Allow-list approach.

## Storage APIs

### Local Storage

- Aka Offline Storage, Web Storage. Underlying storage mechanism varies by user agent → any authentication your app requires can be bypassed by user with local privileges on machine storing data. Avoid storing sensitive info in local storage where authentication would be assumed.
- Browser security guarantees make local storage appropriate where data access assumes no authentication/authorization.
- Use sessionStorage instead of localStorage if persistence not needed. sessionStorage available only to that window/tab until closed.
- Single [Cross Site Scripting](https://owasp.org/www-community/attacks/xss/) can steal all data in these objects → don't store sensitive info in local storage.
- Single [Cross Site Scripting](https://owasp.org/www-community/attacks/xss/) can also load malicious data into these objects → don't trust their contents.
- Pay extra attention to "localStorage.getItem" and "setItem" calls in HTML5 page: detects solutions putting sensitive info in local storage; severe risk if authentication/authorization to data wrongly assumed.
- No session identifiers in local storage: always accessible by JavaScript. Cookies mitigate with `httpOnly` flag.
- Can't restrict object visibility to specific path like HTTP Cookie attribute path; every object shared within origin, protected by Same Origin Policy. Avoid hosting multiple apps on same origin (all share same localStorage object); use different subdomains.

### Client-side databases

- Web SQL Database deprecated by W3C in 2010, **removed from all major browsers**: Chromium dropped support in version 119 (October 2023); Safari/Firefox never shipped it for third-party origins. Do not use Web SQL. Need SQL interface in browser: prefer embedded engine such as official SQLite WebAssembly build (`sqlite-wasm`), backed by IndexedDB or Origin Private File System (OPFS) for persistence.
- Current standard for client-side structured storage: **IndexedDB**, transactional key-value store, W3C Recommendation since 2015, supported in all evergreen browsers.
- Storage mechanisms vary across user agents and OSes. User/process with browser profile access can read/modify stored data; don't assume IndexedDB gives confidentiality. Avoid storing session tokens, credentials, other secrets. If sensitive data must be stored locally, design encryption and key management for device-access threat. Non-extractable `CryptoKey` restricts Web Crypto export operations, but does not guarantee protection of persisted keys from device access or prevent hostile scripts using the key.
- Single [Cross-Site Scripting](https://owasp.org/www-community/attacks/xss/) vulnerability can read/write any IndexedDB data; treat contents as untrusted input on read.
- Apply same input validation and output encoding to IndexedDB data as to network data.

## Geolocation

- Geolocation API requires user agents to ask user permission before calculating location. Whether/how decision is remembered varies by browser. Some user agents require revisiting page to turn off location access without asking; for privacy, require user input before calling `getCurrentPosition` or `watchPosition`.

## Web Workers

- Web Workers may use `XMLHttpRequest` for in-domain and Cross Origin Resource Sharing requests. See CORS section of this sheet.
- Workers lack DOM access of calling page, but malicious Web Workers can use excessive CPU → Denial of Service, or abuse CORS for further exploitation. Ensure all Web Worker scripts not malevolent. Don't allow creating Web Worker scripts from user supplied input.
- Validate messages exchanged with Web Worker. Don't exchange JavaScript snippets for evaluation e.g. via `eval()`: could introduce [DOM Based XSS](DOM_based_XSS_Prevention.md).

## Tabnabbing

Attack detailed in Reverse Tabnabbing article.

Summary: newly opened page can act on parent page's content or location via back link exposed by **opener** JavaScript object instance.

Applies to HTML link or JavaScript `window.open` using attribute/instruction `target` to specify target loading location that doesn't replace current location and then makes current window/tab available.

Prevention:

Cut back link between parent and child pages:

- HTML links:
    - Add attribute `rel="noopener"` on tag creating link from parent to child. Cuts link, but depending on browser, referrer info may be present in request to child page.
    - To also remove referrer info use: `rel="noopener noreferrer"`.
- JavaScript `window.open`: add values `noopener,noreferrer` in windowFeatures parameter of `window.open`.

Behavior differs between browsers; for either HTML link or JavaScript window (or tab) opening, use this configuration for max cross support:

- HTML links: add attribute `rel="noopener noreferrer"` to every link.
- JavaScript: use this function to open window (or tab):

```javascript
function openPopup(url, name, windowFeatures = "") {
  const features = ["noopener", "noreferrer", windowFeatures]
    .filter(Boolean)
    .join(",");
  window.open(url, name, features);
}
```

- Add HTTP response header `Referrer-Policy: no-referrer` to every HTTP response of app (OWASP Secure Headers project has Referrer-Policy info). Ensures no referrer info sent with requests from page.

Compatibility matrix:

- noopener
- noreferrer
- referrer-policy

## Sandboxed frames

- Use `sandbox` attribute of `iframe` for untrusted content.
- `sandbox` attribute enables restrictions on `iframe` content. Active restrictions when set:
    1. All markup treated as from unique origin.
    2. All forms and scripts disabled.
    3. All links prevented from targeting other browsing contexts.
    4. All automatically triggering features blocked.
    5. All plugins disabled.

Fine-grained control over `iframe` capabilities via `sandbox` attribute value.

- Old user agents without support ignore attribute. Use as additional protection layer, or check browser support and show untrusted content only if supported.
- Against Clickjacking and unsolicited framing, also use header `X-Frame-Options`, supports `deny` and `same-origin` values. Framebusting e.g. `if(window!==window.top) { window.top.location=location;}` not recommended.

## Credential and Personally Identifiable Information (PII) Input hints

Form attributes give input/autofill hints; no guarantee browser avoids storing sensitive values.

Sensitive fields where autofill inappropriate: `autocomplete="off"` requests browser not remember/prefill value. But browsers may still offer to save and autofill login credentials. Don't treat attribute as protection against credential reuse on shared computer.

```html
<input type="text" spellcheck="false" autocomplete="off" autocorrect="off" autocapitalize="off">
```

Attributes adjust input assistance; do not enforce no-storage policy:

- `spellcheck="false"`
- `autocomplete="off"`
- `autocorrect="off"`
- `autocapitalize="off"`

## Offline Applications

- HTML5 Application Cache (`<html manifest="...">` and `.appcache` files) **removed from all major browsers** (Firefox 85, Chrome 93). Don't use for new apps; migrate remaining usage to **Service Workers** with Cache API.
- Service Workers run on separate scriptable thread, intercept network requests for registered scope. Can transparently serve cached responses → significant security impact:
    - Register Service Workers only from own origin; **serve worker script only over HTTPS** with long-cache-busting filename (e.g. `sw.<hash>.js`).
    - Restrict Service Worker scope (`scope` option or `Service-Worker-Allowed` response header) so compromised worker can't intercept unrelated paths.
    - Malicious/compromised Service Worker can intercept requests from pages it controls. Have documented recovery process that updates or unregisters worker and removes affected caches. Expiring cached data does not unregister worker.
    - No responses with sensitive data in Cache API. `Cache` does not honor HTTP caching headers, entries don't expire automatically; service-worker code must explicitly exclude such responses and delete sensitive entries already stored. Keep sending `Cache-Control: no-store` to control HTTP caches.

## Progressive Enhancements and Graceful Degradation Risks

- Best practice: determine browser-supported capabilities; augment with substitutes only for unsupported ones. Don't fall back to obsolete browser plugins — Adobe Flash Player end-of-life 31 December 2020, removed from all browsers; Java applets, Silverlight, ActiveX likewise unsupported. Native HTML5 (`<video>`, `<audio>`, `<canvas>`, WebAssembly) covers these legacy use cases.

## HTTP Headers to enhance security

OWASP Secure Headers project lists HTTP security headers an app should use for browser-level defenses.

## References

- MDN: Window.postMessage() security concerns
- MDN: IndexedDB API
