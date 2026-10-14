# Multifactor Authentication Cheat Sheet

## Introduction

Multifactor Authentication (MFA) requires evidence from ≥2 distinct factors: something you know, something you have, something you are. Location + other risk signals can inform authentication decisions; not substitutes for a factor (NIST SP 800-63B-4).

| Factor | Examples |
|--------|----------|
| [Something You Know](#something-you-know) | [Passwords and PINs](#passwords-and-pins) |
| [Something You Have](#something-you-have) | [OTP Tokens](#one-time-password-tokens), [U2F Tokens](#universal-second-factor), [Certificates](#certificates), [Smart Cards](#smart-cards), [SMS and Phone Calls (restricted)](#sms-messages-and-phone-calls) |
| [Something You Are](#something-you-are) | [Fingerprints, Facial Recognition, Iris Scans](#biometrics), [Behavioral Biometrics](#something-you-do) |

Multiple instances of same factor (e.g., password + PIN) **≠ MFA**; minimal extra security. Factors must be independent, not compromisable by same attack. Weaknesses below mostly matter only against targeted attacks. **Any MFA is better than no MFA**.

## Advantages

Most common account compromise: weak, re-used, stolen passwords. Users choose weak passwords / reuse across apps despite technical controls. Assume user passwords will be compromised; design to defend.

MFA = best defense vs most password attacks incl. brute-force, [credential stuffing](Credential_Stuffing_Prevention.md), password spraying; Microsoft analysis: would have stopped 99.9% of account compromises.

## Disadvantages

Biggest: added management complexity for admins + end users; less technical users may struggle to configure/use. Other issues:

- MFA types needing specific hardware: significant cost + admin overhead.
- Users locked out if they lose/cannot use other factors.
- Added application complexity.
- Many MFA solutions add external dependencies → vulnerabilities or single points of failure.
- Processes to bypass/reset MFA may be exploitable.
- Requiring MFA may block some users from app.

## Quick Recommendations

When/how to implement MFA varies by app threat model, user technical level, admin control over users; consider per app.

Generally appropriate starting point:

- Require some form of MFA for all users.
- Let users enable MFA using [TOTP](#software-otp-tokens).
- Require MFA for administrative / other high-privileged users.
- Implement secure procedure for users to reset MFA.
- Consider [MFA as a service](#consider-using-a-third-party-service).

## Implementing MFA

MFA = critical security control, recommended for all apps.

### Regulatory and Compliance Requirements

Many industries/countries mandate MFA, esp. finance + healthcare; often required for General Data Protection Regulation (GDPR) compliance in EU. Consider when implementing.

### When to Require MFA

Most important: login. Depending on functionality, also require for sensitive actions, e.g.:

- Changing passwords or security questions.
- Changing account email address.
- Disabling MFA.
- Elevating user session to administrative session.

If app offers multiple ways to authenticate, all should require MFA or have other protections. Commonly missed: separate login API, associated mobile app.

### One-Time Password (OTP) Handling and Storage

OTPs = authentication secrets; handle w/ password-like hygiene. Security traits differ from long-lived passwords, but improper handling still leads to account compromise.

OTP implementations SHOULD:

- Enforce short time-to-live (TTL)
- Ensure single use
- Apply strict attempt limits
- Invalidate OTP on successful verification

OTP implementations SHOULD NOT:

- Log OTP values
- Store OTPs in long-term plaintext form

RECOMMENDED to further reduce risk:

- Generate OTPs w/ cryptographically secure random number generator
- Consider 8-digit or longer codes where usability allows
- On "resend", generate new OTP, overwrite old record

#### Hashing OTPs

Hashing OTPs still recommended, for different reasons than password hashing. OTPs have tiny keyspace (e.g., ~1 million possibilities for 6-digit code) → database attacker brute-forces any OTP hash quickly. So hashing gives no strong offline attack resistance like password hashing.

Hashing still useful to:

- Prevent accidental disclosure via logs, metrics, debugging tools
- Reduce blast radius if database briefly exposed during OTP validity window
- Enforce good secret-handling discipline; avoid plaintext storage by default

Goal: short-term exposure protection, not long-term cryptographic secrecy.

### Improving User Experience

#### Risk Based Authentication

Frequent MFA login burdens users; may cause them to disable MFA. Risk based authentication reduces MFA prompt frequency by requiring MFA only for high-risk actions. Examples:

- Require MFA when user logs in from new device or location.
- Require MFA when login from high-risk location.
- Use corporate IP ranges or [geolocation](#geolocation) as risk signals deciding whether to require additional authentication.

#### Passkeys

Passkeys give phishing-resistant MFA: possession of credential private key + local [PIN](#passwords-and-pins) or [biometric](#biometrics) verification. When using passkeys as MFA, require user verification and validate returned user-verification flag on server; touch confirming user presence alone ≠ second factor. Credential key pair created during registration; authentication uses existing private key to sign challenge. Registration, verification, recovery guidance: [Passkey Security Cheat Sheet](Passkey_Security.md).

### Failed Login Attempts

User enters password but fails second factor → either:

- User lost second factor / unavailable (e.g., no phone, no signal).
- User's password compromised.

Steps:

- Prompt user to try another form of MFA.
- Allow user to attempt to [reset their MFA](#resetting-mfa).
- Notify user of failed login attempt; encourage password change if unrecognized.
    - Notification should include time, browser, geographic location of attempt.
    - Display at next login; optionally email too.

### Resetting MFA

Biggest challenge: users who forget/lose additional factors. E.g.:

- Re-installing workstation without backing up digital certificates.
- Wiping/losing phone without backing up OTP codes.
- Changing mobile numbers.

Need mechanism to regain access if existing MFA unusable, without giving attacker way to bypass MFA + hijack account.

No definitive "best way"; varies by app security + control over users. Corporate-app solutions (staff know each other) unlikely feasible for public app w/ thousands of global users. Every recovery method has trade-offs; evaluate in app context.

Possible methods:

- Give user several single-use recovery codes when first setting up MFA.
- Require user to set up multiple MFA types (e.g., digital certificate, OTP core, phone number for SMS), so unlikely to lose all at once.
- Mail one-use recovery code (or new hardware token) to registered address.
- Require user contact support team; rigorous identity verification process.
- Require another trusted user to vouch.

### Changing MFA Factors

Users may update factors (change phone number, migrate authenticator app, replace lost hardware token). Attackers exploit this for takeover → strictly secure it.

Best practices:

- Require reauthentication w/ existing enrolled factor before allowing changes.
- Never rely solely on active session; may be hijacked.
- Treat factor replacement as high-risk action; apply risk-based checks (e.g., new device, unusual location).
- Notify user via out-of-band channels (email, push notification) whenever MFA factor changed.
- Consider delays or step-up verification for high-value accounts.

Ensures even compromised session cannot silently replace user's MFA factors + lock out legitimate user.

### Consider Using a Third Party Service

Third-party MFA-as-a-service suits apps lacking resources to implement MFA, or needing high assurance. Consider service security + implications: if third party compromised, attacker could bypass MFA on all apps using it.

## Something You Know

Knowledge-based; most common: password. Biggest advantage: very low requirements for devs + users; no special hardware or service integration.

### Passwords and PINs

Most common authentication form, simple to implement. [Authentication Cheat Sheet](Authentication.md#implement-proper-password-strength-controls): strong password policy. [Password Storage Cheat Sheet](Password_Storage.md): secure storage. Most MFA systems use password + ≥1 other factor.

#### Pros

- Simple, well understood.
- Native support in every authentication framework.
- Easy to implement.

#### Cons

- Users prone to weak passwords.
- Commonly re-used between systems.
- Susceptible to phishing.

### Security Questions

**Security questions no longer recognized as acceptable authentication factor** per NIST SP 800-63. Account recovery = alternate way to authenticate → no weaker than regular authentication.

#### Pros

- None not also present in passwords.

#### Cons

- No longer recognized as acceptable authentication factor.
- Answers often easily guessable.
- Answers often obtainable from social media/other sources.
- Questions must be chosen so users remember answers years later.
- Susceptible to phishing.

## Something You Have

Possession-based: user has physical/digital item required to authenticate. Most common MFA form, often used with passwords. Common types: hardware + software tokens, digital certificates. Properly implemented: significantly harder for remote attacker; but adds admin burden on user (must keep factor with them).

### One-Time Password Tokens

OTP tokens: user submits constantly changing numeric code. Most common: Time-based One-Time Password (TOTP) tokens, hardware or software.

#### Hardware OTP Tokens

Generate constantly changing numeric codes submitted at authentication. Best known: RSA SecureID, six digit number changing every 60 seconds.

##### Pros

- Separate physical devices → almost impossible to compromise remotely.
- Usable without mobile phone/other device.

##### Cons

- Deploying physical tokens expensive + complicated.
- Lost token: significant time to buy + ship new one.
- Some implementations need backend server → new vulnerabilities + single point of failure.
- Stolen tokens usable without PIN or device unlock code.
- Susceptible to phishing (although short-lived).

#### Software OTP Tokens

Cheaper, easier than hardware: software generates TOTP codes. Typically user installs TOTP app on phone, scans QR code from web app providing initial seed. Authenticator app generates numeric code using configured time step; RFC 6238 recommends default of 30 seconds. App + server must use same time-step value.

Most sites use standardized TOTP → user can use any TOTP-supporting app. A few apps use own variants (e.g., Symantec), requiring specific app. Avoid; prefer standards-based approach.

##### Pros

- No physical tokens → greatly reduced cost + admin overhead.
- Lost TOTP app access: configure new one without shipping physical token.
- TOTP widely used; many users already have ≥1 TOTP app.
- Screen lock reduces theft risk but no guarantee if phone stolen unlocked. Enable authenticator-app access protection where available; e.g., Google Authenticator's Privacy Screen requires device verification before app use.

##### Cons

- TOTP apps usually on mobile devices, vulnerable to compromise.
- TOTP app may be on same mobile device (or workstation) used to authenticate.
- Users may store backup seeds insecurely.
- Not all users have mobile devices.
- Lost, stolen, or out-of-battery device → cannot authenticate.
- Susceptible to phishing (although short-lived).

### Universal Second Factor

Hardware U2F tokens

Universal Second Factor (U2F): standard for USB/NFC hardware tokens implementing challenge-response authentication; no manual code entry. User presses token button or taps NFC reader. Most common: YubiKey.

#### Pros

- Phishing-resistant: private key never leaves token.
- User just presses button, no code typing.
- Separate physical devices → almost impossible to compromise remotely.
- Natively supported by several major browsers.
- Usable without mobile phone/other device.

#### Cons

- As with hardware OTP tokens: significant costs + admin overhead.
- Stolen tokens usable without PIN or device unlock code.
- Usually connected via USB → users more likely to forget them.

### Certificates

Digital certificates: files on user's device, automatically provided alongside password when authenticating. Most common: X.509, aka [client certificates](Transport_Layer_Security.md#client-certificates-and-mutual-tls). Supported by all major browsers; once installed need no user interaction. Link certificates to individual user account to prevent authenticating against other accounts.

#### Pros

- No hardware tokens to buy/manage.
- Very simple for users once installed.
- Centrally managed + revocable.
- Resistant to phishing.

#### Cons

- Needs backend Private Key Infrastructure (PKI).
- Installation can be hard for users, esp. in highly restricted environments.
- Enterprise proxy servers doing SSL decryption prevent certificate use.
- Stored on user's workstation → stealable if system compromised.

### Smart Cards

Credit-card size cards w/ chip holding user's digital certificate, unlocked w/ PIN. Common for OS authentication, rare in web apps.

#### Pros

- Stolen smartcards unusable without PIN.
- Usable across multiple apps/systems.
- Resistant to phishing.

#### Cons

- Managing/distributing: same costs/overheads as hardware tokens.
- Not natively supported by modern browsers → third-party software.
- Most business-class laptops have built-in readers; home systems often do not.
- Requires backend PKIs.

### SMS Messages and Phone Calls

> [!WARNING]
> NIST SP 800-63B-4 designates SMS and PSTN-delivered codes as a *restricted* authenticator because of SS7 interception, SIM-swap, and number-porting attacks. Do not use SMS for high-value or PII-handling applications. Where it is the only available factor, document the risk acceptance, enforce per-account rate limits, monitor for SIM-swap signals, and plan migration to TOTP, push notifications, or WebAuthn/FIDO2.

SMS/phone calls deliver single-use code as additional factor. Due to risks, do not use to protect apps holding Personally Identifiable Information (PII) or w/ financial risk, e.g., healthcare, banking. NIST SP 800-63B classifies as restricted authenticators; discourages use for apps containing PII.

#### Pros

- Relatively simple to implement.
- Requires user to link account to mobile number.

#### Cons

- Requires user to have mobile device or landline.
- Requires signal/internet access to receive call/message.
- Calls/SMS cost money; protect against attackers requesting large numbers of messages to exhaust funds.
- Susceptible to SIM swapping.
- SMS may arrive on same device user authenticates from.
- Susceptible to phishing.
- SMS may be previewed when device locked.
- SMS may be read by malicious/insecure apps.

### Email

Email verification: user enters code or clicks link sent to email. Debated whether MFA: if email account lacks MFA, needs only email password (often same as app password). Included for completeness.

#### Pros

- Very easy to implement.
- No separate hardware or mobile device.

#### Cons

- Relies entirely on email account security, which often lacks MFA.
- Email passwords commonly same as app passwords.
- No protection if user's email compromised first.
- Email may arrive on same device user authenticates from.
- Susceptible to phishing.

## Something You Are

Inherence-based: physical attributes of user. Less common in web apps (needs specific hardware; most privacy-invasive). Common for OS authentication + some mobile apps.

### Biometrics

Common types:

- Fingerprint scans
- Facial recognition
- Iris scans
- Voice recognition

#### Pros

- Well-implemented biometrics hard to spoof; need targeted attack.
- Fast, convenient.

#### Cons

- Manual enrollment required.
- Custom (sometimes expensive) hardware often required.
- Privacy: sensitive physical info stored about users.
- Compromised biometric data hard to change.
- Hardware may have additional attack vectors.

## Somewhere You Are

Location can inform access restrictions + risk-based authentication decisions. Not independent authentication factor: password + trusted IP/location ≠ MFA. NIST SP 800-63B-4 explicitly distinguishes these risk signals from factors.

### Source IP Address

Source IP usable as risk signal or access restriction, typically allow-list. Static list (e.g., corporate office ranges) or dynamic list (e.g., IPs user previously authenticated from).

#### Pros

- Very easy for users.
- Minimal config/management by admins.

#### Cons

- No protection if user's system compromised.
- No protection against rogue insiders.
- Trusted IPs must be carefully restricted (e.g., open guest Wi-Fi using main corporate IP range).

### Geolocation

Use geographic location the IP is registered to rather than exact IP. Less precise, but more feasible where IPs not static. Common: require additional factors when attempt from outside user's normal country.

#### Pros

- Very easy for users.

#### Cons

- No protection if user's system compromised.
- No protection against rogue insiders.
- Easy to bypass: attacker obtains IPs in trusted country/location.
- Privacy features such as Apple's iCloud Private Relay and VPNs reduce accuracy.

### Geofencing

More precise geolocation: user defines specific area where authentication allowed. Often in mobile apps, location determined accurately via geopositioning hardware like GPS.

#### Pros

- Very easy for users.
- High protection against remote attackers.

#### Cons

- No protection if user's system compromised.
- No protection against rogue insiders.
- No protection against attackers physically close to trusted location.

## Something You Do

Behavioral biometrics (e.g., keystroke patterns, gait) = form of "something you are", not separate factor. Under NIST biometric requirements, biometric comparison must be combined with authenticated physical authenticator. General activity signals (login times, navigation patterns) can inform risk decisions but alone ≠ MFA.

### Behavioral Profiling

Based on how user interacts with app: time of day of login, devices used, navigation. Increasingly common in web apps combined with [Risk Based Authentication](#risk-based-authentication) and User and Entity Behavior Analytics (UEBA) systems.

#### Pros

- No user interaction needed.
- Can continuously authenticate user.
- Combines well with other factors to raise identity assurance.

#### Cons

- Early implementations often inaccurate; many false positives.
- Needs large data + processing power.
- Hard where user behavior changes frequently.

### Keystroke & Mouse Dynamics

Based on how user types + moves mouse: time between key presses, between presses and releases, mouse speed + acceleration. Largely theoretical; not widely used.

#### Pros

- No additional hardware.
- No additional user interaction.
- Can continuously authenticate user.
- Can detect when user is not the one using system.
- Can detect user under duress.
- Can detect user not in fit state to use system.

#### Cons

- Unlikely accurate enough as standalone factor.
- May be spoofed by AI or other advanced attacks.

### Gait Analysis

Based on how user walks, via cameras + sensors. Used in physical security systems, rare in web apps. Mobile apps may use accelerometer to detect gait as additional factor; still largely theoretical.

#### Pros

- Very hard to spoof.
- No additional user interaction.

#### Cons

- Needs specific hardware.
- Use outside physical security systems not widely tested.

## Adaptive or Risk-Based Authentication

Adjusts authentication requirements dynamically by login attempt context. Improves UX + security: extra verification only when risk elevated.

Common risk signals:

- Geolocation and IP reputation
- Device fingerprinting
- Time of access (e.g., 3 AM login)
- Behavioral biometrics (e.g., typing speed or mouse movements)
- Known compromised credentials

If risk detected, system may:

- Prompt for additional factor (e.g., OTP)
- Enforce re-authentication
- Deny access, trigger alerting or account protection flows

When to trigger reauthentication after high-risk events (account recovery, suspicious activity): [Reauthentication After Risk Events](Authentication.md#re-authentication-after-risk-events) in Authentication Cheat Sheet

Widely used to balance usability + security. Devs must ensure risk signals cannot be spoofed + fallback mechanisms not weaker than primary MFA methods.

**Example Use Case**: User logs in from trusted device in usual location: no extra prompt. Login from new country via Tor exit node: system requires SMS verification or triggers account lock until further verification.

## MFA Attack Patterns and Mitigations

Attackers increasingly target weaknesses in MFA deployments + authentication workflows rather than MFA itself. Patterns + mitigations below based on NIST SP 800-63B, CISA's Implementing Phishing-Resistant MFA, FIDO Alliance Specifications, OAuth 2.0 Security Best Current Practice (RFC 9700).

### General Mitigation: Primary Phishing-Resistant Control

Prefer phishing-resistant authenticators (FIDO2/WebAuthn): bind authentication to legitimate origin; resist credential theft, MFA fatigue, reverse-proxy phishing. See Passkeys section.

### MFA Fatigue (Push Notification Bombing)

Attackers repeatedly send MFA push notifications, often w/ social engineering, hoping user eventually approves one.

#### Mitigations

- Require challenge-response push authentication (e.g., number matching) to prevent blind approval.
- Rate-limit or cap push notifications to prevent repeated prompt abuse.
- Monitor anomalous authentication activity, e.g., multiple push prompts in short period or new-device token reuse.

### Real-Time Phishing Using Reverse Proxies

Attackers use reverse-proxy phishing frameworks (e.g., Evilginx, Modlishka, Muraena) to present convincing copies of legitimate login pages; relay authentication traffic between user + legitimate service → capture credentials + session tokens in real time.

#### Mitigations

- Monitor anomalous authentication + session activity indicating credential/session compromise (e.g., impossible travel, new ASN, sudden MFA method changes).
- Use phishing-resistant authenticators (see Passkeys section): bind authentication to legitimate origin; resist real-time phishing.

### SIM Swap and Phone Number Takeover

Attackers convince telecom provider to transfer victim's number → intercept SMS/voice OTPs.

#### Mitigations

- Encourage carrier account PINs or port-out protection where available.
- Monitor unexpected phone-number changes or SIM replacement events.
- Prefer phishing-resistant authenticators or TOTP over SMS/voice OTP.
- See also: [SMS Messages and Phone Calls](#sms-messages-and-phone-calls).
  
### Device Binding Bypass

Attackers bypass device-based authentication by extracting exportable cryptographic keys or replaying cloned device attributes when authenticators not hardware-protected.

#### Mitigations

- Prefer hardware-backed, non-exportable cryptographic keys (e.g., platform authenticators backed by TPM, Secure Enclave, Android StrongBox).
- Validate authenticator attestation where required by organizational policy.

### MFA Downgrade Attacks

Attackers force authentication through legacy protocols/flows not enforcing same MFA requirements as modern methods. Weak fallbacks or legacy endpoints let users authenticate with lower-assurance factors than intended.

#### Mitigations

- Disable legacy authentication protocols/endpoints that cannot enforce MFA consistently.
- Prevent fallback from phishing-resistant authenticators to lower-assurance methods unless required by documented security policy.
- Follow OAuth 2.0 Security Best Current Practice (RFC 9700) to prevent OAuth protocol-level downgrade + mix-up attacks.

## References

- NIST SP 800-63B-4: Authentication and Authenticator Management
- W3C Web Authentication Level 3
- RFC 6238: Time-Based One-Time Password Algorithm
