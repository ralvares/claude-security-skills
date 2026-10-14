# Pinning Cheat Sheet

## Introduction

Technical guide to implementing certificate and public key pinning, as discussed by Jeffrey Walton (Virginia chapter presentation "Securing Wireless Channels in the Mobile Space"). Clear, actionable guidance for securing channel in hostile environment where actors may be malicious and conference of trust a liability.

## What's the problem

Baseline TLS configuration: [Transport Layer Security Cheat Sheet](Transport_Layer_Security.md).

Users, developers, apps expect secure channels; some are not. SSL/TLS channels vulnerable to Man-in-the-Middle (MITM) if certificate-based trust misused. Two attack forms:

1. Attacker acquires rogue digital certificate from trusted certificate authority (CA) in victim site's name;
2. Attacker injects dangerous CA into client's trust store.

Latter: attacker able to update trust store can change mobile app workings, potentially defeating pinning.

Per Certificate and Public Key Pinning (OWASP community control), problem is very small thanks to years of CA and browser community security advances.

## What Is Pinning

Pinning = associating host with its *expected* X509 certificate or public key. Once certificate/public key known or seen for host, it is 'pinned' to host. Multiple acceptable certificates/keys → program holds *pinset* (from Jon Larimer and Kenny Root Google I/O talk). Advertised credential must match one pinset element.

### When to Add a Pin

Add host/service certificate or public key: at development time; on first encounter ("Trust On First Use", TOFU); or in real time via unpinned channel, updated likewise. Development time preferred: *preloading* certificate/public key *out-of-band* usually means attacker cannot taint pin.

"When" = point in time to pin. First question: "Should I Pin?" Answer: probably never.

### When Do You Perform Pinning

Almost no situation warrants pinning. Outage risk almost always outweighs security risks given advances. If considering pinning, read Certificate and Public Key Pinning (OWASP community control), fully understand threat model.

### When Do You Not Pin?

- Don't control client and server side of connection → don't pin.
- Can't update pinset securely → don't pin.
- Pinset update disruptive, e.g. requires app redeployment → probably don't pin. (Possible exception: you control redeployment, e.g. forced updates within corporation.)
- Certificate key pair cannot be predicted before entering service → don't pin.
- Not native mobile application → do not pin.

### When to Apply Exceptions

Organization practicing "egress filtering" as part of Data Loss Prevention (DLP) strategy likely has *Interception Proxies*. **"good" bad actors** (vs **"bad" bad actors**): both break end-to-end security, indistinguishable. **Do not** allow-list interception proxy: defeats security goals. Add interception proxy's public key to pinset only after being **instructed** by Risk Acceptance.

### How Do You Pin

Reuse existing protocols + infrastructure, hardened. Program keeps doing what it did to establish secure connection.

To harden: use `OnConnect` callback of library, framework or platform. In callback, verify remote host identity by validating its certificate or public key. See [some examples](#examples-of-pinning).

### What Should Be Pinned

Steps:

1. Decide: pin root CA, intermediate CA or leaf certificate:

- **Root CA**: generally not recommended; greatly increases risk, implies trusting all its intermediate CAs.
- **Issuing/intermediate CA**: reduces risk, but app also trusts any other certificates issued by that CA or sub-CAs, not only ones meant for your app.
- **Leaf certificate**: recommended but must include backup (e.g. intermediate CA or pinset w/ alternates). Provides 100% certainty app exclusively trusts remote hosts it was designed for, plus resiliency for failover/certificate rotation.

E.g. app pins remote endpoint leaf certificate plus backup pin for intermediate CA: trusts more CAs (more risk) but lowers chance of bricking app. Leaf issue → app falls back to intermediate CA until app update released.

2. Choose pin **whole certificate** or just its **public key**.

3. Public key: two further choices:

- Pin `subjectPublicKeyInfo`.
- Pin one of concrete types such as `RSAPublicKey` or `DSAPublicKey`.

Three choices explained below. Pin `subjectPublicKeyInfo` (encouraged): has public parameters (e.g. `{e,n}` for RSA public key) **and** contextual info such as algorithm and OID. Context helps keep bearings.

#### Certificate

Easiest to pin. Fetch certificate out of band from website, have IT email company certificate, use `openssl s_client`, etc. At runtime retrieve website/server certificate in callback; compare with certificate embedded in program. Comparison fails → fail method/function, log client-side, alert end user. If threat model warrants pinning, users click past warnings → do not give user option to proceed and bypass pin.

**Benefits:**

- May be easier to implement than other methods, esp. in Cocoa/CocoaTouch and OpenSSL.

**Downsides:**

- Site rotates certificate regularly → app must be updated regularly. Don't control when certificate enters service → pinning causes outage.

#### Public Key

More flexible but trickier: extra steps to extract public key from certificate. Program compares extracted public key with embedded copy. Most certificates today good for only 90 days; public key pinning lengthens pinset update timeline: can pin key whose certificate not yet issued.

**Benefits:**

- Access to public key parameters (e.g. `{e,n}` for RSA public key) and contextual info such as algorithm and OID.
- More flexible than certificate pinning. Pin calculable long before certificate issued; if policy allows, certificate renewed with same key avoids breaking pinning. Latter = bad key management practice, emergency use only.

**Downsides:**

- Harder to work with keys than certificates: must extract key from certificate. Minor in Java and .Net; uncomfortable in iOS Cocoa/CocoaTouch and OpenSSL.
- Some providers generate new keys on renewal → pre-caching impossible.

#### Hash

Three choices above used DER encoding; hash of the information also acceptable. Original sample programs used digested certificates/public keys; changed so programmers can inspect objects with `dumpasn1` and other ASN.1 decoders.

**Benefits:**

- Convenient. Digested certificate fingerprint often native API in many libraries.
- Hash small, fixed length.

**Downsides:**

- No access to public key parameters or contextual info such as algorithm and OID, possibly needed in some use cases.
- Site rotates certificate regularly → app must be updated regularly. Don't control when certificate enters service → pinning causes outage.

## Examples of Pinning

Certificate and public key pinning in Android Java, iOS, .Net, OpenSSL. Code omitted; key platform points highlighted.

### Android

Since Android N, preferred: Android Network Security Configuration feature, lets apps customize network security settings in safe declarative config file, no app code change.

Enable pinning: `<pin-set>` configuration setting.

Alternative: programmatic pins, e.g. OkHTTP pinning, per OWASP Mobile Security Testing Guide (MSTG) and OKHttp documentation.

Android docs show customizing SSL validation in app code (Unknown CA implementation document) to implement pinning. Avoid implementing pinning validation from scratch: mistakes extremely likely, usually cause severe vulnerabilities.

Validate pinning success: follow OWASP MSTG "introduction into testing network communication" and Android-specific network testing chapters.

### iOS

Apple suggests pinning CA public key by specifying it in `Info.plist` under App Transport Security Settings. Details: article "Identity Pinning: How to configure server certificates for your app".

TrustKit: open-source SSL pinning library for iOS and macOS; easy-to-use API, deployed in many apps.

Otherwise, customizing SSL validation on iOS for pinning: HTTPS Server Trust Evaluation technical note. Avoid implementing pinning validation from scratch: mistakes extremely likely, usually cause severe vulnerabilities.

Validate pinning success: follow OWASP MSTG "introduction into testing network communication" and iOS-specific network testing chapters.

### .Net

.Net pinning via `ServicePointManager`. Example: OWASP MSTG (Xamarin applications).

.Net sample program download available (OWASP assets).

### OpenSSL

Pinning at one of two places. First: user-supplied `verify_callback`. Second: after connection established via `SSL_get_peer_certificate`. Either accesses peer's certificate.

OpenSSL performs X509 checks, but you must fail connection and tear down socket on error. By design, server supplying no certificate yields `X509_V_OK` with **NULL** certificate. To check customary verification:

1. You must call `SSL_get_verify_result` and verify return code is `X509_V_OK`;
2. You must call `SSL_get_peer_certificate` and verify certificate is **non-NULL**.

OpenSSL sample program download available (OWASP assets).

### Electron

electron-ssl-pinning: open-source SSL pinning library for Electron apps; easy-to-use API, tool to fetch configuration for needed hosts.

Otherwise validate certificates yourself via `ses.setCertificateVerifyProc(proc)`.

## References

- Android: Network security configuration
- RFC 5280: Internet X.509 Public Key Infrastructure Certificate and CRL Profile
