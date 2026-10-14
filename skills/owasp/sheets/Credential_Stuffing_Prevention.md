# Credential Stuffing Prevention Cheat Sheet

## Introduction

Defenses vs two common authentication attacks: credential stuffing and password spraying. Distinct attacks, but defenses often same, also effective vs brute-force. Summary:

| Attack Type | Description |
|-------------|-------------|
| Brute Force | Testing multiple passwords from dictionary or other source against a single account. |
| Credential Stuffing | Testing username/password pairs obtained from the breach of another site. |
| Password Spraying | Testing a single weak password against a large number of different accounts.|

## Multi-Factor Authentication

[Multi-factor authentication (MFA)](Multifactor_Authentication.md) = by far best defense vs majority of password attacks, incl. credential stuffing and password spraying; Microsoft analysis suggests would have stopped 99.9% of account compromises. Implement wherever possible. Historically, enforcing MFA sometimes impractical depending on audience, but modern browsers and mobile devices support FIDO2 Passkeys and other MFA forms → attainable for most use cases.

Balance security and usability: require 2nd factor only where reason to suspect illegitimate login, e.g. login from:

- New browser/device or IP address.
- Unusual country or location.
- Specific countries considered untrusted or typically w/o users of service.
- IP address on known denylists or associated w/ anonymization services, e.g. proxy or VPN.
- IP address that tried logging into multiple accounts.
- Login attempt appearing scripted or bot rather than human (i.e. large login volume from single IP or subnet).

Or "step-up" authentication for above scenarios during session combined w/ high risk activity request such as:

- Large currency transactions
- Privileged or Administrative configuration changes

Enterprise applications: known trusted IP ranges can be allowlisted so MFA not required from these ranges.

## Alternative Defenses

Where MFA impossible, many alternative defenses protect vs credential stuffing and password spraying. None alone as effective as MFA, but multiple layered defenses give reasonable protection. Often also protect vs brute-force or password spraying.

Multiple user roles: may implement different defenses per role. E.g., MFA may not be feasible for all users, but should be required for all administrators.

## Defense in Depth & Metrics

Implement defenses considering impact of individual defenses being defeated or failing. E.g., client-side defenses (device fingerprinting, JavaScript challenges) may be spoofed or bypassed; other layers must account for this.

Each defense should generate volume metrics as detective mechanism. Ideally include detected and mitigated attack volume, filterable by fields such as IP address. Monitoring and reporting metrics may identify defense failures, unidentified attacks, impact of new or improved defenses.

When multiple teams administer different defenses, ensure communication and coordination during maintenance, deployment, or modification of individual defenses.

### Secondary Passwords, PINs and Security Questions

Don't use security questions as additional authentication challenge. OWASP ASVS 5.0 requirement 6.4.2 excludes knowledge-based security questions. [Security Questions Cheat Sheet](Choosing_and_Using_Security_Questions.md) covers limitations in legacy systems.

Secondary password, PIN, or memorable word: request and verify entire secret, not selected characters, as required by NIST SP 800-63B-4. Another knowledge factor ≠ [MFA](Multifactor_Authentication.md); prefer independent factor.

### CAPTCHA

Requiring "Completely Automated Public Turing test to tell Computers and Humans Apart" (CAPTCHA) or similar puzzle per login attempt can identify automated/bot attacks, prevent automated logins, may slow credential stuffing or password spraying. CAPTCHAs imperfect: tools or services often break them w/ reasonably high success rate. Monitor CAPTCHA solve rates: may show impact on good users, and automated CAPTCHA breaking (abnormally high solve rates).

Usability: require CAPTCHA only when login request suspicious or high risk, using same criteria as MFA section.

### IP Mitigation and Intelligence

Blocking IP addresses may stop less sophisticated attacks, but not sole or primary defense: easily circumvented. Better: graduated response using multiple defensive measures depending on attack factors.

Any decision to mitigate (incl. blocking and CAPTCHA) credential stuffing traffic from IP address should consider multitude of abuse scenarios, not single predictable volume limit. Consider short (i.e. burst) and long time periods, high request volume, and one IP address, likely w/ _many_ other IPs, generating low but consistent traffic. Consider IP address classification (ex: residential vs hosting) and geolocation. Use these to raise or lower mitigation thresholds: reduce impact on legitimate users or mitigate abnormal sources more aggressively. Mitigations, esp. IP blocking, should be temporary; processes should remove IP from mitigated state as abuse declines or stops.

Many credential stuffing toolkits, e.g. Sentry MBA, have built-in proxy networks distributing requests across large volume of unique IPs. May defeat IP block-lists and rate limiting: per-IP volume stays low even in high volume attacks. Correlating authentication traffic w/ proxy and similar IP intelligence, and hosting provider IP ranges, helps identify highly distributed attacks, serves as mitigation trigger. E.g., require CAPTCHA on every request from hosting provider.

Public and commercial IP intelligence/classification sources exist. Some hosting providers publish own IP space, such as AWS.

Separate from blocking: consider storing account's IP authentication history. Recent IP added to block or mitigation list → may lock account and notify user.

### Device Fingerprinting

Beyond IP, many factors fingerprint device. Some passive from HTTP headers (esp. "User-Agent"):

- Operating system & version
- Browser & version
- Language

JavaScript accesses far more:

- Screen resolution
- Installed fonts
- Installed browser plugins

Create device fingerprint; match against any browser attempting login; mismatch → prompt additional authentication. Users have multiple devices/browsers, so don't simply block non-matching attempts; common to let users/customers view device history and manage remembered devices. Attributes also detect anomalous activity, e.g. device running older OS or Browser version.

fingerprintjs2 JavaScript library does client-side fingerprinting.

All info client-provided → attacker can spoof. Spoofing trivial for some (such as "User-Agent" header), harder for others.

### Connection Fingerprinting

Like device fingerprinting, numerous techniques for network connections: JA3, HTTP/2 fingerprinting, HTTP header order. Focus on how connection made → may be more accurate than defenses relying on indicator (e.g. IP address) or request data (e.g. user agent string).

Combine w/ other defenses to ascertain authentication request truthfulness. E.g., user agent header and device fingerprint indicate mobile device but connection fingerprint indicates Python script → likely suspect.

### Require Unpredictable Usernames

Credential stuffing relies on re-use of passwords and usernames across sites. Many sites use email as username; users mostly have single email for all accounts → email+password combination very effective.

Requiring user-created username at registration makes obtaining valid pairs harder: many credential lists only include email addresses. Generated username gives higher protection (users likely choose same username across sites) but user unfriendly. Generated username must not be predictable (e.g. based on full name, or sequential numeric IDs): makes enumerating valid usernames for password spraying easier.

### Multi-Step Login Processes

Most off-the-shelf tools target single step login: credentials POSTed, response indicates success. Additional steps (sequential username then password entry, or first obtaining random [CSRF Token](Cross-Site_Request_Forgery_Prevention.md)) make attack slightly harder, double attacker's request count.

Multi-step login must not facilitate [user enumeration](Authentication.md). Enumerating users before credential stuffing may yield harder to identify, lower request volume attack.

### Require JavaScript and Block Headless Browsers

Most tools POST directly and read responses, don't download or execute JavaScript. Requiring JavaScript evaluation in response (e.g. generate valid token submitted with request) forces attacker to use real browser w/ automation framework like Selenium or Headless Chrome, or implement JavaScript parsing w/ another tool such as PhantomJS. Techniques exist to identify Headless Chrome or PhantomJS.

Blocking visitors w/ JavaScript disabled reduces accessibility, esp. for screen reader users. In certain jurisdictions may breach equalities legislation.

### Degradation

More aggressive defense: increase time attack takes. May include incrementally increasing complexity of JavaScript to evaluate, requiring cryptographic or Proof-of-Work computational puzzle, long wait periods before responding, overly large HTML assets, randomized error messages.

Some security w/o user tracking or profiling. Typically no human in loop; constrain minimum latency and/or maximum request rate of client implementation and attacker's budget and sophistication. Needs context-dependent risk assessment for efficacy, resistance to countermeasures, user experience impact.

### Identifying Leaked Passwords

Implement ASVS v4.0 Password Security Requirements provision (2.1.7): verify new passwords' presence in breached password datasets.

Commercial and free services validate passwords vs prior breaches. Well known free: Pwned Passwords. Host own copy, or use the API.

### Notify users about unusual security events

Suspicious or unusual activity detected → may notify or warn user. Avoid overwhelming with unimportant notifications, or they ignore/delete them. Frequent password reuse across sites → consider user's email account may also be compromised.

E.g., generally don't notify of failed login attempt with incorrect password. But login w/ correct password that then failed subsequent MFA check → notify user to change password. Then if user requests multiple password resets from different devices or IPs, may prevent further access pending further user verification.

Show user details of current or recent logins. E.g., at login display date, time, location of previous login attempt. If app supports concurrent sessions, user should view list of all active sessions and terminate illegitimate ones.

## References

- OWASP: Credential Stuffing
- NIST SP 800-63B-4: Password Verifiers
