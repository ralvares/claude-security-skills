# Web Frontend Security Cheat Sheet

## Introduction

Previously named AJAX Security Cheat Sheet.

Starting point for AJAX security; to be expanded w/ framework/technology specifics.

Apps composing independently deployed frontend features: see [Micro-Frontend Security Cheat Sheet](Micro_Frontend_Security.md) for runtime isolation, cross-application messaging, host-to-remote trust boundaries.

**Before any specific control, adopt security mindset:**
All data untrusted unless explicitly validated and safely handled.
Applies to:

- Client-side input
- API response
- Third-party integrations
- Internal services and microservices
- Cached responses
- Browser storage (localStorage, sessionStorage)
- Hidden form fields

### Client-Side (JavaScript)

#### Use `innerHTML` with extreme caution

DOM manipulation common in web apps, esp. monolithic server-side rendering (e.g., PHP, ASP.NET) and AJAX apps. `innerHTML` convenient for injecting HTML but significant risk w/ untrusted data, esp. cross-site scripting (XSS).

##### What is `innerHTML`?

Property sets/gets element HTML content incl. tags; browser parses and renders as DOM. E.g. `innerHTML = "<p>Hello</p>"` creates paragraph element.

##### Why does `innerHTML` require extreme caution?

`innerHTML` w/ untrusted data (e.g., AJAX API responses) lets malicious JavaScript execute in user's browser → XSS. Risks:

- Stealing session cookies.
- Defacing website.
- Redirecting users to malicious sites.
- Unauthorized actions (e.g., API calls on user's behalf).
- Keylogging user inputs.

###### Vulnerable Example

```javascript
    document.getElementById('content').innerHTML = data; 
    // DANGER! The server may have returned a payload that executes scripts, for example: <img src=abc onerror=alert('xss!')>.
```

##### When is `innerHTML` acceptable?

Fundamental rule: never use innerHTML w/ untrusted data. Limited cases (e.g., legacy monolithic apps w/o viable alternatives) allow cautious use:

- **Static, Hardcoded HTML**: small fixed snippets in app source code, no user input:

```javascript
document.getElementById('footer').innerHTML = '<p>© 2025 My Company. All rights reserved.</p>';
```

- **Sanitized HTML**: user-generated HTML (e.g., rich text editors): sanitize w/ library like [DOMPurify](DOM_Clobbering_Prevention.md#1-html-sanitization) before innerHTML:

```javascript
import DOMPurify from 'dompurify';
const userInput = '<img src=abc onerror=alert("xss")>';
document.getElementById('content').innerHTML = DOMPurify.sanitize(userInput); // Safe, removes malicious code
```

##### Alternatives

- Templating engines (auto-escaping) for reusable structured HTML snippets.
- Framework text bindings: generally escape text, not sanitize arbitrary markup (Vue documents this distinction). Raw-HTML APIs like React's `dangerouslySetInnerHTML` require trusted, sanitized HTML. URL and style bindings need context-appropriate controls; see [Framework Security](Cross_Site_Scripting_Prevention.md#framework-security).

#### Use of `textContent` or `innerText` for DOM updates (for text-only content)

AJAX and monolithic server-side rendering apps (e.g., PHP, ASP.NET) commonly update DOM dynamically w/ text-only content from APIs or user inputs.

##### What is `textContent`?

Sets/gets plain text content of element. Inserted HTML tags treated as literal text, not parsed. Ideal for most text-only updates, e.g. user comments.

```javascript
const userInput = '<script>alert("OWASP")</script>';
document.getElementById('content').textContent = userInput; // Displays plain text
```

##### What is `innerText`?

Sets/gets visible text content, respecting CSS styling (e.g., ignores text in `display: none` elements). Reflects rendered text formatting, e.g. line breaks, spacing.

```javascript
const userInput = 'OWASP'; 
document.getElementById('content').innerText = userInput;
```

##### When to Use `textContent` vs. `innerText`

- **`textContent`**: monolithic apps, safely insert plain text from APIs.
- **`innerText`**: only when CSS visibility or rendered text formatting (e.g. ignoring text in `display: none` elements) required.

> Note: `textContent` slightly faster, more predictable; use unless rendered text formatting needed (`innerText`).

##### Note

- `textContent`/`innerText` safe for plain text in DOM, but don't protect against XSS in other contexts: HTML attributes, JavaScript event handlers, URLs. Always validate and sanitize untrusted input.
- Modern frameworks (React, Vue, Angular, Svelte) update text-only content automatically; no manual `textContent`/`innerText` needed.

#### Don't use `eval()`, `new Function()` or other code evaluation tools

`eval()` dangerous, never use. Needing eval() usually signals design problem.

> Note: `eval()` or `new Function()` open doors to remote code execution and XSS. Avoid entirely.

#### Encode Data Before Use in an Output Context

Building HTML, script, CSS, XML, JSON, etc.: account for how data must be presented literally to keep logical meaning.

Encode data properly before such use, preventing injection issues and preserving logical meaning.

See OWASP Java Encoder Project.

#### Don't rely on client logic for security

User controls client-side logic. Browser plugins set breakpoints, skip code, change values. Never rely on client logic for security.

#### Don't rely on client business logic

As w/ security logic, duplicate important business rules server-side so users can't bypass them (unexpected or costly behavior).

#### Avoid writing serialization code

Hard; small mistake → large security issues. Use existing frameworks.

See JSON page for more info.

#### Avoid building XML or JSON dynamically

Like building HTML or SQL, may cause XML injection bugs. Avoid, or use encoding library or safe JSON/XML library for attributes and element data.

- [XSS (Cross Site Scripting) Prevention](Cross_Site_Scripting_Prevention.md)
- [SQL Injection Prevention](SQL_Injection_Prevention.md)

#### Never transmit secrets to the client

Anything sent to client can be read/modified by user; keep secrets on server.

#### Choose encryption for the threat model

TLS for transport. Client-side encryption can also fit end-to-end protection or encryption before upload (Web Cryptography use cases). Use reviewed protocols/implementations, don't design own cryptographic protocol. Browser cryptography doesn't protect plaintext or keys from malicious code in the app; account for XSS and key management (Web Cryptography security considerations).

#### Don't perform security impacting logic on client-side

Fail-safe: security decision ambiguous → perform on server.

### Server-Side

#### Use CSRF Protection

See [Cross-Site Request Forgery (CSRF) Prevention](Cross-Site_Request_Forgery_Prevention.md) cheat sheet.

#### Protect against JSON hijacking for older browsers

##### Review AngularJS JSON hijacking defense mechanism

See AngularJS documentation, JSON Vulnerability Protection section.

##### Always return JSON with an object on the outside

Outside primitive of JSON strings MUST be object:

**Exploitable:**

```json
[{"object": "inside an array"}]
```

**Not exploitable:**

```json
{"object": "not inside an array"}
```

**Also not exploitable:**

```json
{"result": [{"object": "inside an array"}]}
```

#### Avoid writing serialization code server-side

Mind reference vs. value types; use reviewed library.

#### Services can be called directly by users

Even if only AJAX client code expected to call services, malicious user can call directly.

Validate inputs, treat as user-controlled.

#### Avoid building XML or JSON by hand, use the framework

Serialize via framework; hand-built payloads can introduce security issues.

#### Use JSON and XML schema for web services

Use third-party library to validate web service inputs.

## References

- MDN: innerHTML Security Considerations
- DOMPurify: HTML Sanitization
