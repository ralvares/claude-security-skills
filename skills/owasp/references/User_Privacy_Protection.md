# User Privacy Protection Cheat Sheet

## Introduction

Mitigations for web developers protecting users' privacy and anonymity from threats, esp. in social networking and communication platforms.

## Guidelines

### Strong Cryptography

Platforms handling user identities, private info or communications must use strong cryptography. Encrypt user communications in transit and storage. Protect user secrets (e.g., passwords) w/ strong, collision-resistant hashing w/ increasing work factors → mitigates exposed credentials, gives integrity control.

In transit: follow TLS/SSL best practices: verified certificates, adequately protected private keys, strong ciphers only, informative clear user warnings, sufficient key lengths. At rest: encrypt private data w/ sufficient key lengths under strict technical and procedural access conditions. Hash user credentials regardless of whether encrypted in storage.

Detailed guides:

1. [Cryptographic Storage Cheat Sheet](Cryptographic_Storage.md).
2. [Authentication Cheat Sheet](Authentication.md).
3. [Transport Layer Security Cheat Sheet](Transport_Layer_Security.md).
4. Guide to Cryptography.
5. Testing for TLS/SSL.

### Support HTTP Strict Transport Security

HSTS: server HTTP header telling user agent only HTTPS accepted → user agent upgrades insecure HTTP links to HTTPS, fails safe by refusing any TLS/SSL connection not trusted by user.

Average support in popular user agents (Firefox, Chrome). Still useful for users fearing spying and Man in the Middle Attacks.

If forcing HSTS on all users impractical, at least let users opt in.

More:

1. HTTP Strict Transport Security in Wikipedia.
2. IETF for HSTS RFC.
3. OWASP Appsec Tutorial Series - Episode 4: Strict Transport Security.

### Digital Certificate Pinning

Certificate Pinning: hardcode/store predefined info (usually hashes) of certificates/public keys in user agent (browser, mobile app, plugin) so only those are used for secure communication; all others fail even if user trusted them (implicitly or explicitly).

Advantages:

- CA compromise: compromised CA trusted by user can issue certificates for any domain, enabling eavesdropping.
- Environments forcing users to accept potentially malicious root CA, e.g., corporate, national PKI schemes.
- Apps whose target demographic doesn't understand certificate warnings, likely to allow any invalid certificate.

Details:

1. [OWASP Certificate Pinning Cheat Sheet](Pinning.md).
2. Public Key Pinning Extension for HTTP RFC.
3. Securing the SSL channel against man-in-the-middle attacks: Future technologies - HTTP Strict Transport Security and Pinning of Certs, by Tobias Gondrom.

### Panic Modes

Panic mode: mode threatened users switch to when forced to disclose account credentials.

Helps users survive such threats, esp. in tumultuous regions; many users face threats most developers don't consider.

Examples: distressed users delete data upon threat, log into fake inboxes/accounts/systems, invoke triggers to backup/upload/hide sensitive data.

Right panic mode depends on app type. Disk encryption software like VeraCrypt: distress password boots fake system partition.

Email providers: hide predefined sensitive emails/contacts, show only innocent messages (usually user-defined), while preventing panic mode from taking over actual account.

Panic modes must not be easily discoverable, if at all. Adversary inside victim's panic mode must have no, or minimal, ways to learn truth. So inside panic mode, most non-sensitive normal operations must continue (e.g., sending/receiving email), and further panic modes must be creatable from inside original one (adversary trying to create one inside a panic mode and failing would know they're inside, may hurt victim).

Alternative: forbid creating panic modes from user account; make spoofing harder, e.g., create only Out Of Band; adversaries must have no way to know a panic mode exists for that account.

Implementation must always confuse adversaries, keep them from actual accounts/sensitive data, prevent discovery of existing panic modes for an account.

VeraCrypt hidden operating system mode:

- VeraCrypt Hidden Operating System.

### Remote Session Invalidation

Equipment lost, stolen, confiscated, or cookie theft suspected → users should be able to view current online sessions and disconnect/invalidate suspicious lingering ones, esp. on stolen/confiscated devices. Also helps if session details suspected stolen in Man-in-the-Middle attack.

Session management:

- [OWASP Session Management Cheat Sheet](Session_Management.md).

### Allow Connections from Anonymity Networks

Anonymity networks (e.g., Tor) let users in tumultuous regions escape surveillance, access information, break censorship. Activists often use them to report injustice or send uncensored info, esp. via social networks, media streaming sites, email providers.

Developers and network admins must pursue every avenue to enable access from behind such networks; re-evaluate carefully any policy against them for global impact.

If possible, integrate or enable easy coupling w/ anonymity networks, e.g., SOCKS proxies or integration libraries (e.g., OnionKit for Android).

More:

1. The Tor Project.
2. I2P Network.
3. OnionKit: Boost Network Security and Encryption in your Android Apps.

### Prevent IP Address Leakage

Preventing IP leakage matters when user protection in scope. Apps hosting external third-party content (avatars, signatures, photo attachments) should let users block third-party content loading.

If external-domain images can be embedded (e.g., in feed/timeline), adversary hosts image on own domain, watches HTTP requests → discovers victim's real IP.

Apps needing user content is acceptable business process; still advise option to block external content as precaution. Applies mainly to social networks, forums, also web email (images in HTML emails).

HTML emails w/ third-party images: same issue, but most email clients/providers block third-party content by default → better privacy/anonymity.

### Honesty & Transparency

If app can't provide enough legal/political protections, or can't prevent misuse/disclosure of sensitive info such as logs, tell users clearly and understandably so they make informed choice whether to use service.

If law permits, inform users when their info is requested for removal or investigation by external entities.

Honesty builds trust, lets users worldwide weigh options, prevents harm.

Secure logging:

- [OWASP Logging Cheat Sheet](Logging.md)

## References

- RFC 6973: Privacy Considerations for Internet Protocols
- RFC 6797: HTTP Strict Transport Security (HSTS)
