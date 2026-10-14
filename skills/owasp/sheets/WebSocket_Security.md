# WebSocket Security Cheat Sheet

## Introduction

WebSockets = real-time bidirectional client-server communication (chat, live trading, collaboration). Connections stay open, continuous data exchange.

Security challenges differ from standard web apps:

- **Cross-Site WebSocket Hijacking (CSWSH)**: attackers hijack authenticated connections from malicious sites
- **Authentication bypass**: no built-in authentication; access control easy to forget
- **Injection attacks**: messages carry XSS, SQL injection, other payloads
- **Denial-of-service**: persistent connections enable new DoS vectors like connection exhaustion
- **Monitoring gaps**: HTTP logs capture only initial upgrade request, miss all message traffic

**Real-world vulnerabilities:**

- **Gitpod CSWSH (2023)**: insufficient origin validation → full account takeover via hijacked WebSocket connections
- **Spring RCE vulnerability**: CVE-2018-1270 let attackers execute code via crafted STOMP messages

## Primary Defenses

### Transport Security

#### Always Use WSS (WebSocket Secure)

Never use unencrypted `ws://` in production; allows eavesdropping + tampering.

```javascript
// Secure - always use this
const socket = new WebSocket('wss://app.example.com/socket');

// Insecure - never use in production
// const socket = new WebSocket('ws://app.example.com/socket');
```

See [Transport Layer Security Cheat Sheet](Transport_Layer_Security.md).

#### WebSocket Protocol Configuration

**Use modern protocol versions:**

Support only RFC 6455 (current WebSocket standard). Drop backward compatibility for outdated Hixie-76 and hybi-00 (known vulnerabilities).

**Compression security:**

Disable `permessage-deflate` unless needed. Compression + secret data can leak info, like CRIME/BREACH.

```javascript
// Node.js - disable compression for security
const wss = new WebSocket.Server({
  perMessageDeflate: false
});
```

#### Infrastructure Configuration

**Proxy and load balancer support:**

Configure reverse proxies, load balancers, CDNs to handle WebSocket upgrades:

- Support HTTP/1.1 upgrade mechanism
- Pass `Upgrade` and `Connection: upgrade` headers correctly
- Set proper read timeouts for long-lived connections
- Ensure security policies don't block WebSocket traffic

**WAF support:**

Check WAF inspects WebSocket traffic beyond initial handshake. If not, rely on server-side validation + application logging.

### Authentication and Authorization

General identity/session controls: [Authentication Cheat Sheet](Authentication.md), [Session Management Cheat Sheet](Session_Management.md).

No built-in WebSocket authentication. Browsers include cookies in handshake requests → apps vulnerable to Cross-Site WebSocket Hijacking (CSWSH).

CSWSH flow:

1. User logs into app (session cookie established)
2. User later visits malicious website
3. Malicious site opens WebSocket to app, browser sends cookies automatically
4. Server accepts connection → attacker gets live authenticated WebSocket access

#### Origin Header Validation

Validate `Origin` header on every handshake. Always use explicit allowlist of trusted origins. Browsers send this header; malicious JavaScript cannot override it.

Node.js `ws`: validate `Origin` in HTTP server's `upgrade` event before calling `handleUpgrade`; library discourages `verifyClient` (`ws` documentation).

**Important:** Allowlist, not denylist. Avoid wildcards or substring matching (error-prone).

#### Additional CSWSH Protections

Apps already using CSRF protection: include **CSRF tokens** in WebSocket handshakes.

#### Session Management

WebSocket connections often outlive normal sessions; need special handling.

**Use SameSite cookies** (`SameSite=Lax` or `Strict`) to block cross-site cookie transmission, strengthen CSWSH defenses.

**Handle session expiration**: server-side validation for long-running connections. Close connections when sessions expire. Re-validate sessions periodically (every 30 minutes common).

```javascript
// Example: Close WebSocket on session expiry
function validateSession(ws, sessionId) {
  if (!isSessionValid(sessionId)) {
    ws.close(1008, 'Session expired');
    return false;
  }
  return true;
}
```

**On logout**, close all user's WebSocket connections immediately. Keep session → active connections mapping to invalidate access at logout.

**Token-based authentication:**

Browser clients using tokens: prefer sending token in first message over WSS. Avoid tokens in URL query strings (leak into access logs); see `websockets` authentication guidance.

Until token validation succeeds, accept only authentication message, send no protected data. Close connection on auth failure or timeout, and [limit unauthenticated connections](#denial-of-service-protection). Message-based auth keeps tokens out of handshake URL, but tokens must also be excluded from message logs.

**Token refresh:**

Rotate tokens in long-lived connections so hijacked sessions don't persist.

#### Message-Level Authorization

Connection ≠ unlimited access. Check authorization per action:

```javascript
ws.on('message', (data) => {
  const message = JSON.parse(data);
  
  // Check authorization for each action
  if (message.action === 'delete_user' && !user.hasRole('admin')) {
    ws.send(JSON.stringify({type: 'error', message: 'Access denied'}));
    return;
  }
  
  handleAuthorizedMessage(ws, user, message);
});
```

### Input Validation

Treat all WebSocket messages as untrusted. Can carry SQLi, XSS, command injection.

**Validate message structure + content** w/ JSON schemas and allow-lists. Set size limits (typically 64KB or less), rate limiting against flooding.

**Binary data**: verify file types via magic numbers, not content-type headers. Scan uploads for malware when appropriate; safe deserialization for protobuf, MessagePack.

```javascript
ws.on('message', (data, isBinary) => {
  if (isBinary) {
    // Validate binary data
    if (data.length > MAX_BINARY_SIZE) {
      ws.close(1009, 'Message too large');
      return;
    }
    
    // Check file type by magic numbers
    if (!isValidFileType(data)) {
      ws.close(1008, 'Invalid file type');
      return;
    }
  }
  
  processBinaryData(data);
});
```

**Prevent replay**: include timestamps or nonces in messages, reject duplicates so old messages cannot be resent.

```javascript
ws.on('message', (data) => {
  const message = JSON.parse(data);
  
  // Check timestamp or nonce to prevent replay
  if (!isValidNonce(message.nonce)) {
    ws.close(1008, 'Replay detected');
    return;
  }

  processMessage(message);
});
```

**Always use `JSON.parse()` instead of `eval()`** for JSON; `eval()` enables code execution from untrusted input.

```javascript
// Safe
const message = JSON.parse(data);

// Dangerous - enables code execution
// const message = eval('(' + data + ')');
```

See [Input Validation Cheat Sheet](Input_Validation.md), [Cross Site Scripting Prevention Cheat Sheet](Cross_Site_Scripting_Prevention.md), [SQL Injection Prevention Cheat Sheet](SQL_Injection_Prevention.md).

### Service Tunneling Risks

WebSockets can tunnel TCP services (VNC, FTP, SSH) → risk: app XSS lets attackers reach these services directly from victims' browsers. If tunneling necessary, add authentication + access controls beyond WebSocket layer.

### Denial-of-Service Protection

Persistent connections raise DoS risk.

**Limit connections/resources**: restrict total connections; per-user limits (preferred) or per-IP where user identification unavailable. Set **message size limits** (typically 64KB or less) and **rate limiting** against flooding; 100 messages per minute common starting point.

**Idle/dead connections**: idle timeouts close inactive connections. **Heartbeat monitoring** w/ ping/pong frames detects and cleans dead connections.

**Backpressure controls** prevent memory exhaustion from fast producers. Many implementations lack flow control; attackers overwhelm server memory by sending faster than processing.

```javascript
const wss = new WebSocket.Server({
  maxPayload: 64 * 1024
});
```

### Security Monitoring and Logging

HTTP access logs capture only initial upgrade request, not message traffic → miss auth failures, injection attempts, rate-limit violations, abuse.

**Log WebSocket events**: connection establishment/termination (user identity, IP, origin); authentication/authorization events during handshake and message processing; security violations (rate limiting triggers, message validation failures); abnormal disconnections, protocol errors.

**Avoid logging sensitive data**: never log complete message contents, authentication tokens, session IDs, personal info (privacy regulation violations).

See [Logging Cheat Sheet](Logging.md).

### Testing WebSocket Security

**Key security tests:**

- **Origin validation**: connect from unauthorized domains
- **Authentication bypass**: connect without proper credentials
- **Message injection**: send XSS, SQL injection, command injection payloads
- **DoS resistance**: test connection limits, message flooding, oversized messages
- **Session management**: test session expiration, logout handling

**Testing tools:**

- Browser developer tools for manual testing
- wscat for command-line WebSocket connections
- Custom scripts for automated vulnerability testing
- OWASP ZAP (WebSocket security testing features)

### Framework-Specific Best Practices

**Node.js:** `ws`: origin + authentication checks in HTTP server's `upgrade` event; set `maxPayload` limits, disable `perMessageDeflate` unless needed.

**Python:** Django Channels: implement authentication middleware + origin validation. Async exception handling prevents crashes from malformed messages.

**Java Spring:** Configure allowed origins explicitly, integrate Spring Security for authorization. Set message size limits in WebSocket container config against resource exhaustion.

**Go:** Gorilla WebSocket: implement validation in `CheckOrigin`; don't just return `true`. Set read limits, timeouts, context cancellation for graceful cleanup.

#### Keep Dependencies Updated

Update WebSocket libraries regularly, monitor advisories. Past versions of popular libraries (`ws`, Spring STOMP, Python `websockets`) had critical vulnerabilities incl. DoS and RCE.

## References

- RFC 6455: The WebSocket Protocol
- CWE-1385: Missing Origin Validation in WebSockets
