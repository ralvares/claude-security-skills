# Transport Layer Security Cheat Sheet

## Introduction

Guidance on transport layer protection using Transport Layer Security (TLS). Focus: protecting clients connecting to web app over HTTPS; much applies to other TLS uses. Correct TLS gives:

- **Confidentiality**: protects against attackers reading traffic contents.
- **Integrity**: protects against traffic modification, e.g., attacker replaying requests against server.
- **[Authentication](Authentication.md)**: client confirms connection to legitimate server. Client identity not verified unless [client certificates](#client-certificates-and-mutual-tls) used.

### SSL vs TLS

Secure Socket Layer (SSL): original protocol encrypting HTTP traffic (HTTPS). Two public versions - 2 and 3. Both have serious cryptographic weaknesses, no longer use.

Next version (effectively SSL 3.1) named Transport Layer Security (TLS) version 1.0 for various reasons. Later: TLS 1.1, 1.2, 1.3.

"SSL", "SSL/TLS", "TLS" used interchangeably; "SSL" often means modern TLS. Sheet uses "TLS" except for legacy protocols.

## Server Configuration

### Only Support Strong Protocols

Web apps must default to **TLS 1.3**, may support TLS 1.2 for compatibility. **TLS 1.0 and TLS 1.1 formally deprecated by RFC 8996 (March 2021), must be disabled.** Also forbidden by PCI DSS, disallowed by NIST SP 800-52 Rev. 2, removed from all mainstream browsers. SSLv2 and SSLv3 must always be disabled.

If interoperability with end-of-life clients is hard business requirement: isolate them on dedicated endpoint w/o access to sensitive data; don't weaken primary endpoint. Enable "TLS_FALLBACK_SCSV" extension (RFC 7507) to prevent protocol downgrade attacks.

### Only Support Strong Ciphers

Many TLS ciphers (cipher suites) w/ varying security.

TLS 1.3: use standard AEAD cipher suites (AES‑GCM or ChaCha20‑Poly1305).

TLS 1.2 if still required: prefer AEAD‑based suites, avoid CBC‑mode ciphers. At minimum always disable these ciphersuite types:

- Null ciphers;
- Anonymous ciphers (`TLS_*_anon_*`);
- EXPORT ciphers (`TLS_*_EXPORT_*`);
- RSA key transport (`TLS_RSA_*`) and static Diffie-Hellman key agreement (`TLS_DH_*`, `TLS_ECDH_*`), which [do not provide forward secrecy](https://www.rfc-editor.org/rfc/rfc9325.html#section-4.1).

TLS 1.2: prefer ECDHE cipher suites with authenticated encryption (RFC 9325 Section 4.2). Ephemeral Diffie-Hellman gives forward secrecy; finite-field DHE suites (`TLS_DHE_*`) nevertheless discouraged in TLS 1.2 due to construction and parameter-negotiation weaknesses, per RFC 9325 Section 4.1.

Mozilla Foundation offers easy-to-use secure configuration generator for web, database, mail servers: admins select software, get config file balancing security and compatibility for wide range of browser versions and server software.

### Set the appropriate Diffie-Hellman groups

Pre-TLS 1.3 Diffie-Hellman parameter generation for ephemeral DH key exchange (cipher suite names w/ "DHE" or "EDH") had practical issues: client had no say in server parameter selection (could only accept or drop), random parameter generation often caused denial of service attacks (CVE-2022-40735, CVE-2002-20001).

`supported_groups` extension negotiates supported Diffie-Hellman groups:

- Finite Field Diffie-Hellman groups: `ffdhe2048`, `ffdhe3072`, `ffdhe4096`, `ffdhe6144`, `ffdhe8192` per RFC7919;
- Elliptic Curve Diffie-Hellman groups include `x25519`, `prime256v1`, `x448`, `secp384r1`;
- post-quantum cryptography: `X25519MLKEM768` currently used (not strictly a group).

OpenSSL: configure enabled groups in `openssl.cnf`. E.g.

```text
openssl_conf = openssl_init
[openssl_init]
ssl_conf = ssl_module
[ssl_module]
system_default = tls_system_default
[tls_system_default]
Groups = X25519MLKEM768:x25519:prime256v1:x448:ffdhe2048:ffdhe3072
```

Apache:

```text
SSLOpenSSLConfCmd Curves X25519MLKEM768:X25519:prime256v1:secp384r1
```

NGINX:

```text
ssl_ecdh_curve X25519MLKEM768:X25519:prime256v1:secp384r1;
```

TLS 1.2 or earlier: recommended not to set Diffie-Hellman parameters.

### Disable Compression

Disable TLS compression; protects against vulnerability (CRIME) potentially letting attacker recover sensitive info such as session cookies.

### Patch Cryptographic Libraries

Besides protocol vulnerabilities, many historic SSL/TLS library vulnerabilities exist, Heartbleed best known. Keep libraries updated w/ latest security patches.

### Test the Server Configuration

Test configuration after hardening. OWASP Testing Guide chapter on SSL/TLS Testing has details.

Online tools to quickly validate server config:

- SSL Labs Server Test
- CryptCheck
- Hardenize
- ImmuniWeb
- Observatory by Mozilla
- Scanigma
- Stellastra
- OWASP PurpleTeam `cloud`

Offline tools:

- O-Saft - OWASP SSL advanced forensic tool
- CipherScan
- CryptoLyzer
- SSLScan - Fast SSL Scanner
- SSLyze
- testssl.sh - Testing any TLS/SSL encryption
- tls-scan
- OWASP PurpleTeam `local`

## Certificates

### Use Strong Keys and Protect Them

Private key must be strong enough for anticipated lifetime of key and certificate. Best practice: RSA keys at least 2048 bits. Key lifetimes and comparable strengths: keylength.com and NIST SP 800-57.

Protect private key from unauthorized access via filesystem permissions and other technical and administrative controls.

### Use Strong Cryptographic Hashing Algorithms

Certificates should use SHA-256, not older MD5 and SHA-1: cryptographic weaknesses, untrusted by modern browsers.

### Use Correct Domain Names

Certificate domain name (subject) must match fully qualified name of presenting server. Historically in `commonName` (CN) attribute; modern Chrome ignores CN, requires FQDN in `subjectAlternativeName` (SAN). For compatibility put primary FQDN in CN, full FQDN list in SAN.

When creating certificate:

- Consider whether "www" subdomain should be included.
- No non-qualified hostnames.
- No IP addresses.
- No internal domain names on externally facing certificates.
    - Server reachable via both internal and external FQDNs: configure multiple certificates.

### Carefully Consider the use of Wildcard Certificates

Wildcard certificates convenient but violate principle of least privilege: single certificate valid for all subdomains (such as *.example.org). Shared wildcard certificate across systems raises private key compromise likelihood (key on multiple systems) and key value, making it more attractive target.

Issues complicated; various discussions online.

Risk assessment considerations:

- Use wildcard certificates only for genuine need, not convenience.
    - Consider ACME so systems automatically request/update own certificates instead.
- Never use wildcard certificates for systems at different trust levels.
    - Two VPN gateways could share wildcard certificate.
    - Multiple instances of web app could share certificate.
    - VPN gateway and public web server **should not** share wildcard certificate.
    - Public web server and internal server **should not** share wildcard certificate.
- Consider reverse proxy doing TLS termination so wildcard private key is on one system only.
- Maintain list of all systems sharing certificate to update all if it expires or is compromised.
- Limit wildcard scope: issue for subdomain (such as `*.foo.example.org`) or separate domain.

### Use an Appropriate Certification Authority for the Application's User Base

Certificates must be signed by trusted certificate authority (CA). Internet facing apps: use well-known CA automatically trusted by OSes and browsers.

LetsEncrypt CA gives free domain validated SSL certificates, trusted by all major browsers; consider whether buying from a CA has any benefit.

Internal apps: internal CA possible. FQDN not exposed (to external CA or public certificate transparency lists). Certificate trusted only by users who imported and trust internal CA certificate.

### Use CAA Records to Restrict Which CAs can Issue Certificates

Certification Authority Authorization (CAA) DNS records define which CAs may issue certificates for domain. Record lists CAs; any CA not listed should refuse issuance. Helps prevent attacker obtaining unauthorized certificates via less-reputable CA. Applied to all subdomains, also administratively limits which CAs admins/developers can use, prevents unauthorized wildcard certificates.

### Consider the Certificate’s Validation Type

Validation = process CA uses to verify you may have the certificate (authorization). CA/Browser Forum (CAs, browser vendors, others interested in web security) sets rules CAs follow per validation type. Base validation: Domain Validated (DV). All publicly issued certificates must be domain validated: practical proof of control of name/endpoint requested; usually challenge-response in DNS, to official email address, or to endpoint receiving certificate.

Organization Validated (OV): includes requestor's organization info in certificate subject. E.g. C = GB, ST = Manchester, **O = Sectigo Limited**, CN = sectigo.com. Acquisition requires official contact with requesting company via method proving to CA they talk to right company.

Extended validation (EV): higher verification on top of DV and OV. Effectively "This site is really run by Example Company Inc." vs "This domain is really example.org". Latest Extended Validation Guidelines at CA/Browser Forum.

Historically displayed differently in browser (company name, green icon/background in address bar). As of 2019 no major browser shows EV status so; they don't believe EV gives additional protection. (Chromium covering Chrome, Edge, Brave, Opera; Firefox; Safari)

Browsers and TLS stacks don't distinguish DV, OV, EV → effectively same security. Attacker needs only practical domain control to get rogue certificate. Extra work for OV/EV in no way increases incident scope; likely means detection. Extra pain getting OV/EV may create availability risk; review their use with this in mind.

## Application

### Use TLS For All Pages

Use TLS for all pages, not just sensitive ones like login. Non-TLS pages let attacker sniff sensitive info (session tokens) or inject malicious JavaScript into responses for other attacks.

Public facing apps: web server may listen for unencrypted HTTP on port 80 and immediately permanent-redirect (HTTP 301) for users manually typing domain. Support with [HTTP Strict Transport Security (HSTS)](#use-http-strict-transport-security) header to prevent future HTTP access.

API-only endpoints: disable HTTP altogether, support encrypted connections only. If impossible, fail requests over unencrypted HTTP instead of redirecting.

### Do Not Mix TLS and Non-TLS Content

TLS page must not include resources (JavaScript, CSS) loaded over unencrypted HTTP: attacker could sniff session cookies or inject malicious code. Modern browsers also block loading active content over unencrypted HTTP into secure pages.

### Use the "Secure" Cookie Flag

Mark all cookies "Secure" attribute: browser sends only over HTTPS, prevents sniffing from unencrypted HTTP. Important even if site doesn't listen on HTTP (port 80): active man in the middle attacker could present spoofed web server on port 80 to steal cookie.

### Prevent Caching of Sensitive Data

TLS protects data in transit only, not once it reaches requesting system. Data may be stored in user's browser cache or by intercepting proxies configured for TLS decryption.

For responses with sensitive data, use HTTP headers telling browser and proxies not to cache, preventing storage or return to other users. Modern HTTP/1.1+ clients and intermediaries: single header sufficient:

```text
Cache-Control: no-store
```

`no-store` strongest cache directive: forbids shared and private caches storing any part of response. Legacy combination `Cache-Control: no-cache, no-store, must-revalidate` plus `Pragma: no-cache` and `Expires: 0` needed only for pre-HTTP/1.1 caches (effectively obsolete in 2024+); adds no protection beyond `no-store` on modern stack. `Cache-Control` governs HTTP cache, not browser cookie jar storage; that's controlled by cookie attributes (`Max-Age`, `Expires`, `Session`).

To also clear data already cached on client at sign-out, additionally send [`Clear-Site-Data`](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Clear-Site-Data) (e.g. `Clear-Site-Data: "cache", "cookies", "storage"`).

### Use HTTP Strict Transport Security

HSTS makes browser always request site over HTTPS, prevents user bypassing certificate warnings. See [HTTP Strict Transport Security Cheat Sheet](HTTP_Strict_Transport_Security.md).

### Client Certificates and Mutual TLS

Typical TLS authenticates server; mutual TLS (mTLS) also authenticates client via client certificate and proof of its private key. TLS 1.3: proof bound to handshake transcript by CertificateVerify (RFC 8446 Section 4.4.3). This channel binding prevents intermediary relaying client's authentication onto separate TLS connection to legitimate server.

TLS gives confidentiality between its endpoints (RFC 8446 Section 1); mTLS doesn't make data confidential from TLS endpoint whose server certificate client accepts. If client accepts attacker's certificate for target domain, attacker reads application data sent to that endpoint, even when client uses certificate. Validate server identity and trust configuration independently; see [Public Key Pinning](#public-key-pinning) for restricting server trust further.

Challenges and Considerations

Client certificates rarely used in public systems:

- Issuing/managing client certificates has significant admin overhead.
- Non-technical users may find installing client certificates difficult.
- Organizations' TLS decryption practices can break client certificate authentication, key mTLS component.

Still consider client certificates and mTLS for high-value apps or APIs, esp. with technically sophisticated users or users in same organization.

### Public Key Pinning

Public key pinning assures server's certificate is not only valid and trusted but matches expected certificate. Protects against attacker obtaining valid certificate via validation process weakness, compromised trusted CA, or administrative access to client.

Added to browsers as HTTP Public Key Pinning (HPKP) standard; due to issues deprecated, no longer recommended or supported by modern browsers.

Still beneficial for mobile apps, thick clients, server-to-server communication. See [Pinning Cheat Sheet](Pinning.md).

## References

- TLS Reference: Server-Side TLS
- SP 800-52 Rev. 2 Guidelines for the Selection, Configuration, and Use of Transport Layer Security (TLS) Implementations
