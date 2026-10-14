# Authentication Cheat Sheet

## Introduction

**Authentication** (**AuthN**) = verifying individual, entity, or website is who/what it claims, by determining validity of one or more authenticators (passwords, fingerprints, security tokens) backing the claim.

**Digital Identity** = unique representation of subject in online transaction. Unique within a digital service; needn't be traceable to specific real-life subject.

**Identity Proofing** establishes subject actually is who they claim. Related to KYC; binds digital identity to real person.

**Session Management** = server maintaining state of interacting entity; needed so server knows how to react to subsequent requests during transaction. Sessions kept on server by session identifier passed between client and server. Sessions should be unique per user and computationally very hard to predict. See [Session Management Cheat Sheet](Session_Management.md).

## Authentication General Guidelines

### User IDs

User ID primary function: uniquely identify user in system. Ideally randomly generated → prevents predictable or sequential IDs, a risk esp. where User IDs exposed or inferable from external sources.

### Usernames

Usernames = easy-to-remember identifiers chosen by user for login. User ID and username may be interchangeable if chosen username also serves as unique identifier in system.

Permit email address as username, provided email verified at sign-up. Also offer option of non-email username. Email validation: [input validation cheat sheet email discussion](Input_Validation.md#email-address-validation).

### Authentication Solution and Sensitive Accounts

- Do **NOT** allow login w/ sensitive accounts (accounts usable internally e.g. backend / middleware / database) to any front-end UI
- Do **NOT** use same authentication solution (e.g. IDP / AD) used internally for unsecured access (e.g., public access / DMZ)

### Implement Proper Password Strength Controls

Key concern: password strength. "Strong" policy makes guessing (manual or automated) difficult or improbable. Strong password characteristics:

- Password Length
    - **Minimum** length enforced by application.
        - MFA enabled: passwords **shorter than 8 characters** weak (NIST SP800-63B).
        - MFA not enabled: passwords **shorter than 15 characters** weak (NIST SP800-63B).
    - **Maximum** length **at least 64 characters** to allow passphrases (NIST SP800-63B). Some hashing algorithm implementations may cause [long password denial of service](https://www.acunetix.com/vulnerabilities/web/long-password-denial-of-service/).
    - Longer passphrases effective because they raise number of guesses attacker's dictionary/wordlist must cover, not due to precise entropy value: NIST notes "estimating entropy for user-chosen passwords is challenging", recommends length and blocklist checks (below) over composition or entropy math (NIST SP800-63B, Strength of Passwords). Entropy estimates rely on search-space assumptions; treat as illustrative, not absolute measures.
    - Attackers commonly use password guessing w/ common-password dictionaries and lists, and may use previously compromised credentials (credential stuffing). See MITRE ATT&CK T1110 – Brute Force, incl. Password Guessing, Password Spraying, Credential Stuffing. Screening passwords against blocklists prevents users picking commonly used or attacker-known passwords, per NIST SP 800-63B – Passwords.
- Don't silently truncate passwords. See [Password Storage Cheat Sheet](Password_Storage.md#input-limits-of-bcrypt) for handling passwords longer than maximum.
- Allow **all** characters incl. unicode and whitespace. No composition rules limiting character types. No requirement for upper/lower case, numbers, special characters.
- Rotate credentials when password leak occurs, at compromise identification, or when authenticator technology changes. Avoid periodic password changes; encourage strong passwords and [MFA](Multifactor_Authentication.md). NIST: verifiers should not mandate arbitrary (e.g., periodic) password changes.
- Include password strength meter to help users create more complex password
    - zxcvbn-ts library usable.
    - Other language zxcvbn implementations exist; check age and maturity before use.
- Block common and previously breached passwords
    - Pwned Passwords: check passwords against previously breached ones; has API.
    - Or download Pwned Passwords database via HaveIBeenPwned downloader to self-host.
    - Other top password lists exist, no guarantee how updated:
        - Various password lists hosted by SecLists (Daniel Miessler).

#### For more detailed information check

- ASVS v5.0 Password Security Requirements
- Passwords Evolved: Authentication Guidance for the Modern Era

### Implement Secure Password Recovery Mechanism

Apps commonly give users way to regain access after forgetting password. See [Forgot Password Cheat Sheet](Forgot_Password.md).

### Store Passwords in a Secure Fashion

Store password using right cryptographic technique. See [Password Storage Cheat Sheet](Password_Storage.md).

### Compare Password Hashes Using Safe Functions

Where possible compare user-supplied password to stored hash with secure comparison function from language/framework, e.g. PHP `password_verify()`. Otherwise ensure comparison function:

- Has maximum input length → protects against DoS w/ very long inputs.
- Explicitly sets type of both variables → protects against type confusion attacks e.g. Magic Hashes in PHP.
- Returns in constant time → protects against timing attacks.

### Change Password Feature

Change password feature needs:

- User authenticated w/ active session.
- Current password verification → ensures legitimate user changes password. Abuse case: user logs in on public computer, forgets to log out; another person uses active session. W/o current password verification, that person may change password.

### Transmit Passwords Only Over TLS or Other Strong Transport

See: [Transport Layer Security Cheat Sheet](Transport_Layer_Security.md)

Login page and all subsequent authenticated pages must be accessed exclusively over TLS or other strong transport. No TLS on login page → attacker modifies login form action, posting credentials to arbitrary location. No TLS on authenticated pages after login → attacker views unencrypted session ID, compromises authenticated session.

### Require Re-authentication for Sensitive Features

Mitigate CSRF and session hijacking: require current credentials before updating sensitive account info (password, email) or sensitive transactions (e.g., shipping purchase to new address). W/o it, attacker may execute sensitive transactions via CSRF or XSS w/o knowing current credentials. Attacker may also get temporary physical access to browser or steal session ID to take over session.

### Re-authentication After Risk Events

**Overview:**
Re-authentication critical after high-risk activity: account recovery, password resets, suspicious behavior patterns. When/how to trigger it; details: [Require Re-authentication for Sensitive Features](#require-re-authentication-for-sensitive-features).

#### When to Trigger Re-authentication

- **Suspicious Account Activity**: unusual login patterns, IP address changes, device enrollments
- **Account Recovery**: after users reset passwords or change sensitive account details
- **Critical Actions**: high-risk actions e.g. changing payment details, adding new trusted devices

#### Re-authentication Mechanisms

- **Adaptive Authentication**: risk-based models adapting to user behavior and context
- **Multi-Factor Authentication (MFA)**: extra verification layer for sensitive actions/events
- **Bound Authenticators**: require authenticator already bound to account, e.g. current password or passkey. Don't substitute security questions; excluded by ASVS 6.4.2.

#### Implementation Recommendations

- **Minimize User Friction**: no unnecessary UX disruption
- **Context-Aware Decisions**: decide by context (e.g., geolocation, device type, prior patterns)
- **Secure Session Management**: invalidate sessions after re-authentication, rotate tokens; see [Session Management Cheat Sheet](Session_Management.md)

### Consider Strong Transaction Authentication

Some apps should use second factor to check whether user may perform sensitive operations. See [Transaction Authorization Cheat Sheet](Transaction_Authorization.md).

#### TLS Client Authentication

TLS Client Authentication (two-way TLS): browser and server both send TLS certificates during handshake. As client can validate server certificate via verifiably-valid Certificate Authority (CA), server authenticates user by receiving client certificate and validating against third-party CA or own CA. Server must give user certificate generated specifically for them, w/ subject values identifying which user certificate validates. User installs certificate in browser and uses it for site.

Appropriate when:

- Acceptable (or preferred) that user accesses site only from single computer/browser.
- User not scared by installing TLS certificates in browser, or someone (probably IT support) does it for them.
- Site requires extra step of security.
- Good for company/organization intranet.

Generally bad idea for widely/publicly available sites with average users (e.g. wouldn't suit Facebook). Can spare user typing password (protects against average keylogger) but still consider combining password and TLS client authentication.

Client behind enterprise proxy performing SSL/TLS decryption breaks certificate authentication unless site allowed on proxy.

More: Client-authenticated TLS handshake

### Authentication and Error Messages

Incorrectly implemented authentication error messages enable user ID and password enumeration. App should respond (HTTP and HTML) generically.

#### Authentication Responses

For any authentication mechanism (login, password reset, password recovery), respond w/ generic error message regardless of whether:

- User ID or password incorrect.
- Account doesn't exist.
- Account locked or disabled.

Account registration should also use same generic-message approach when user exists.

Goal: prevent [discrepancy factor](https://cwe.mitre.org/data/definitions/204.html) enabling user enumeration.

Business logic can itself create discrepancy factor in processing time: success vs failure can differ significantly, enabling [time-based attack](https://en.wikipedia.org/wiki/Timing_attack) (delta of some seconds for example).

Pseudo-code login example:

- First implementation, "quick exit" approach

```text
IF USER_EXISTS(username) THEN
    password_hash=HASH(password)
    IS_VALID=LOOKUP_CREDENTIALS_IN_STORE(username, password_hash)
    IF NOT IS_VALID THEN
        RETURN Error("Invalid Username or Password!")
    ENDIF
ELSE
   RETURN Error("Invalid Username or Password!")
ENDIF
```

If user doesn't exist, app errors directly. If user exists but password wrong, more processing before error. Response time differs for same error → attacker distinguishes wrong username from wrong password.

- Second implementation, no "quick exit":

```text
password_hash=HASH(password)
IS_VALID=LOOKUP_CREDENTIALS_IN_STORE(username, password_hash)
IF NOT IS_VALID THEN
   RETURN Error("Invalid Username or Password!")
ENDIF
```

Same process regardless of user or password → approx. same response time.

Generic error message is User Experience (UX) matter: legitimate user may be confused, struggle to use app, abandon after retries. Decide on *generic error message* by criticality of app and data. E.g., critical apps: on failure always redirect user to support page and return *generic error message*.

Protection against [brute-force attacks](#protect-against-automated-attacks) also helps against enumeration by preventing it at scale. [CAPTCHA](https://en.wikipedia.org/wiki/CAPTCHA) usable for features where *generic error message* can't be returned because *user experience* must be preserved.

##### Incorrect and correct response examples

###### Login

Incorrect response examples:

- "Login for User foo: invalid password."
- "Login failed, invalid user ID."
- "Login failed; account disabled."
- "Login failed; this user is not active."

Correct response example:

- "Login failed; Invalid user ID or password."

###### Password recovery

Incorrect response examples:

- "We just sent you a password reset link."
- "This email address doesn't exist in our database."

Correct response example:

- "If that email address is in our database, we will send you an email to reset your password."

###### Account creation

Incorrect response examples:

- "This user ID is already in use."
- "Welcome! You have signed up successfully."

Correct response example:

- "A link to activate your account has been emailed to the address provided."

##### Error Codes and URLs

App may return different [HTTP Error code](https://developer.mozilla.org/en-US/docs/Web/HTTP/Status) by authentication attempt response, e.g. 200 positive, 403 negative. Even w/ generic error page, differing HTTP response code can leak whether account valid.

Error disclosure can also be discrepancy factor; see [error handling cheat sheet](Error_Handling.md) for global error handling.

### Protect Against Automated Attacks

Automated attack types used to compromise accounts:

| Attack Type         | Description                                                                                      |
|---------------------|--------------------------------------------------------------------------------------------------|
| Brute Force         | Testing multiple passwords from dictionary or other source against single account.               |
| Credential Stuffing | Testing username/password pairs obtained from breach of another site.                            |
| Password Spraying   | Testing single weak password against many accounts.                                              |

Defenses often incomplete individually; layered defense-in-depth gives reasonable protection.

Following sections focus on brute-force prevention, though controls also help against other attacks. Credential stuffing and password spraying: see [Credential Stuffing Cheat Sheet](Credential_Stuffing_Prevention.md).

#### Multi-Factor Authentication

MFA = by far best defense against most password-related attacks incl. brute force; Microsoft analysis suggests it would have stopped 99.9% of account compromises. Implement wherever possible; depending on audience, enforcing may be impractical.

Further guidance: [Multifactor Authentication Cheat Sheet](Multifactor_Authentication.md).

#### Login Throttling

Login Throttling prevents attacker making too many password guesses via normal interactive means; includes controls:

- Maximum number of attempts.

##### Account Lockout

Most common protection: account lockout, preventing further login attempts for a period after certain number of failed logins.

Associate failed-login counter with account itself, not source IP → prevents attacker attempting from many IPs. Balance security and usability in lockout policy via:

- Number of failed attempts before lockout (lockout threshold).
- Time period attempts must occur within (observation window).
- Lockout duration.

Instead of fixed lockout duration (e.g., ten minutes), some apps use exponential lockout: starts very short (e.g., one second), doubles after each failed login attempt.

- Time to delay after each account lockout (max 2-3, after that permanent account lockout).

Design lockout so it can't cause denial of service by locking out other users' accounts. One way: allow forgotten password functionality to log in even if account locked.

#### CAPTCHA

Effective CAPTCHA helps prevent automated login attempts. Many implementations have weaknesses allowing automated solving or outsourcing to solving services. View CAPTCHA as defense-in-depth making brute force more time-consuming and expensive, not preventative.

More user-friendly: require CAPTCHA only after small number of failed logins, not from first login.

#### Security Questions and Memorable Words

Don't use security questions for authentication or re-authentication; ASVS 6.4.2 excludes knowledge-based authentication. When verifying password or memorable word, request and verify full secret, not selected characters, per NIST SP 800-63B-4. See [Choosing and Using Security Questions Cheat Sheet](Choosing_and_Using_Security_Questions.md) for legacy-system-only guidance.

## Logging and Monitoring

Enable logging and monitoring of authentication functions → detect attacks/failures in real time

- Log and review all failures
- Log and review all password failures
- Log and review all account lockouts

## Use of authentication protocols that require no password

Username + password + MFA generally secure, but some use cases aren't best or safe: third-party apps connecting to web app from mobile device, other website, desktop, etc. NOT safe to let third-party app store user/password combo; extends attack surface into uncontrolled hands. Several password-less authentication protocols avoid exposing user data.

### OAuth 2.0 and 2.1

OAuth = **authorization** framework for delegated API access. See [OAuth 2.0 Cheat Sheet](OAuth2.md).

> **Note:** OAuth 2.1 = active IETF Working Group draft consolidating OAuth 2.0 and widely adopted best practices; intended to replace RFC 6749/6750; guidance here applies to both OAuth 2.0 and OAuth 2.1. Internet-Drafts are revisioned → use unversioned OAuth 2.1 Datatracker page for current draft. See also oauth.net/2.1.

### OpenID Connect (OIDC)

**OpenID Connect 1.0 (OIDC)** = identity layer **on top of OAuth**. Defines how client (**relying party**) verifies **end user's** identity using **ID Token** (signed JWT) and obtains user claims interoperably. **OIDC for authentication/SSO**; **OAuth for authorization** to APIs.

#### OIDC implementation guidance

- **Validate ID Tokens** on relying party: issuer (`iss`), audience (`aud`), signature (per provider JWKs), expiration (`exp`).
- Prefer **well-maintained libraries/SDKs** and provider discovery/JWKS endpoints.
- Use **UserInfo** endpoint when claims beyond ID Token needed.

> **Avoid confusion:** **OpenID 2.0 ("OpenID")** = separate legacy authentication protocol, **superseded by OpenID Connect**, obsolete. New systems must not implement OpenID 2.0. References: OpenID Foundation obsolete OpenID 2.0 libraries, OpenID 2.0 → OIDC migration

#### Secure Federated Account Linking

Linking OIDC identity to existing app account:

- Identify federated identity by combination of `iss` (issuer) and `sub` (subject), not `sub` alone. See OIDC claim stability and uniqueness.
- Don't auto-link accounts solely because `email`, `preferred_username`, or other profile attributes match; claims not guaranteed unique or stable (OIDC Core Section 5.7).
- Require authenticated session with existing app account before adding/removing linked identities (NIST SP 800-63C-4, Section 3.8.1). Apply [Require Re-authentication for Sensitive Features](#require-re-authentication-for-sensitive-features) before changing links.
- Authenticate identity being added and validate resulting ID Token before saving link. Bind authentication response to user's linking session using protections in [OAuth 2.0 Cheat Sheet](OAuth2.md).
- After unlinking, disallow app account access via removed identity (NIST SP 800-63C-4, Section 3.8.1).
- Notify user when identity added, or removed without terminating app account (NIST SP 800-63C-4, Section 3.8).

### SAML

Security Assertion Markup Language (SAML) often seen competing with OpenId. Recommended version 2.0: very feature-complete, strong security. Like OpenId uses identity providers; unlike OpenId, XML-based, more flexible. Based on browser redirects sending XML data. Can be initiated by service provider or identity provider → user navigates portals while staying authenticated, transparently.

OpenId took most of consumer market; SAML often chosen for enterprise apps because few OpenId identity providers are enterprise-class (user identity validation lacks enterprise standards). SAML more common in intranet sites, sometimes w/ intranet server as identity provider.

Recent years: SAP ERP and SharePoint (via Active Directory Federation Services 2.0) adopted SAML 2.0 as often preferred SSO method where enterprise federation needed for web services/apps.

**See also: [SAML Security Cheat Sheet](SAML_Security.md)**

### FIDO

Fast Identity Online (FIDO) Alliance created two protocols: Universal Authentication Framework (UAF) and Universal Second Factor (U2F). UAF = passwordless authentication; U2F adds second factor to password-based authentication. Both use public key cryptography challenge-response.

UAF uses existing device security tech: fingerprint sensors, cameras (face biometrics), microphones (voice biometrics), Trusted Execution Environments (TEEs), Secure Elements (SEs), others; plugs device capabilities into common authentication framework. Works with native and web apps.

U2F augments password authentication with hardware token (typically USB) storing cryptographic authentication keys and signing. Same token usable as second factor across applications. Works with web apps. **Protects against phishing** by using website URL to look up stored authentication key.

**FIDO2**: FIDO2 combines WebAuthn with Client-to-Authenticator Protocols (CTAP). U2F now named CTAP1; UAF separate protocol. WebAuthn credentials = foundation of modern **Passkeys**. Passkeys let users log in securely via local user verification (biometrics or device PINs), often with credential synchronization across devices.

#### Hardware-backed Key Storage

Many authenticators, incl. common platform passkeys: private key generated and stored by OS secure key manager. Depending on platform/authenticator, keys may be protected by hardware-backed components e.g. Trusted Platform Module (TPM) on Windows, Secure Enclave on Apple devices, Android Keystore/StrongBox on Android, or by other software-based mechanisms.

Typically private key intended non-exportable and bound to authenticator; platform security module signs server challenge with it. Some authenticators support credential synchronization or backup that may involve export or server-side storage; not all implementations hardware-backed. Relying parties must not assume keys hardware-backed and non-exportable unless verified (e.g., via authenticator properties or attestation).

## Password Managers

Programs, browser plugins, or web services automating management of many credentials. Most let users use them on websites either:
(a) pasting passwords into login form
-- or --
(b) simulating user typing.

Don't make password managers' job harder than necessary:

- Standard HTML forms for username and password input w/ appropriate `type` attributes.
- Avoid plugin-based login pages (Flash, Silverlight).
- Reasonable maximum password length, at least 64 characters, per [Implement Proper Password Strength Controls section](#implement-proper-password-strength-controls).
- Allow any printable characters in passwords.
- Allow pasting into username, password, MFA fields.
- Allow navigating between username and password field with single `Tab` press.

## Changing A User's Registered Email Address

User emails often change. Recommended process:

*Note: Process less stringent with [Multifactor Authentication](Multifactor_Authentication.md); proof-of-identity stronger than password alone.*

### Recommended Process If the User HAS [Multifactor Authentication](https://cheatsheetseries.owasp.org/cheatsheets/Multifactor_Authentication_Cheat_Sheet.html) Enabled

1. Confirm validity of user's authentication cookie/token. Invalid → show login screen.
2. Describe email change process to user.
3. Ask user for proposed new email address, ensure complies w/ system rules.
4. Request [Multifactor Authentication](Multifactor_Authentication.md) for identity verification.
5. Store proposed new email as pending change.
6. Create and store **two** time-limited nonces for (a) system administrators' notification, (b) user confirmation.
7. Send two email messages w/ links including those nonces:

    - **Notification-only email** to current address: alerts user to impending change, link to report unexpected activity.

    - **Confirmation-required email** to proposed new address: instructs user to confirm change, link for unexpected situations.

8. Handle link responses accordingly.

### Recommended Process If the User DOES NOT HAVE Multifactor Authentication Enabled

1. Confirm validity of user's authentication cookie/token. Invalid → show login screen.
2. Describe email change process to user.
3. Ask user for proposed new email address, ensure complies w/ system rules.
4. Request user's current password for identity verification.
5. Store proposed new email as pending change.
6. Create and store three time-limited nonces for system administrators' notification, user confirmation, additional step for password reliance.
7. Send two email messages w/ links to those nonces:

    - **Confirmation-required email** to current address: instructs user to confirm change, link for unexpected situation.

    - **Separate confirmation-required email** to proposed new address: instructs user to confirm change, link for unexpected situations.

8. Handle link responses accordingly.

### Notes on the Above Processes

- Google takes different approach for password-only accounts: current email address receives notification-only email. Carries risks, requires user vigilance.

- Regular social engineering training crucial. Train sysadmins and help desk to follow prescribed process and recognize/respond to social engineering attacks. See CISA's "Avoiding Social Engineering and Phishing Attacks".

## Adaptive or Risk Based Authentication

More advanced apps can require different authentication stages by environmental and contextual attributes (incl. data sensitivity, time of day, user location, IP address, device fingerprint).

E.g., MFA for first login from a device but not subsequent logins from it. Or SSO authenticates user and keeps them logged in for a day but requires reauthentication on profile page access.

Use device fingerprints, IP addresses, remembered-device cookies as risk signals, not substitutes for authentication. NIST session guidance distinguishes authenticated session secret from device/browser characteristics used for monitoring. Require authentication or valid authenticated session before exposing private account data. E.g., banking app may allow balance viewing within authenticated session, requiring stronger or fresher authentication for transaction details or money movement.

Questions when implementing:

- Are policies in line with corporate and especially regulatory policies?
- Which user‑ or device‑attributes (IP, geolocation, device fingerprint, time‑of‑day, behavioral biometrics, etc.) monitored at session start?
- Which signals need refresh during active session, at what cadence?
- How ensure each signal’s accuracy and handle missing or low‑confidence data?
- What scoring model (weights, thresholds, ML, rule‑based, hybrid) converts raw signals to risk tier?
- Where does model run (edge, API gateway, central service); latency budget?
- What action per risk tier (allow, CAPTCHA, step‑up MFA, block, revoke session)?
- What user-facing messages and error codes per action?
- At which exact code/platform layers invoke risk engine (login controller, middleware, API gateway, service mesh)?
- How propagate decisions consistently across web, mobile, API clients?
- How mutate, extend, revoke tokens/cookies when mid‑session risk check escalates?
- How synchronize state across concurrent devices or browser tabs?
- What monitoring and alerting for suspicious activity, incl. user notification.

## References

- NIST SP 800-63B-4: Password Verifiers
- OWASP Application Security Verification Standard (ASVS): V6 Authentication
- OpenID Connect Core 1.0: ID Token Validation
