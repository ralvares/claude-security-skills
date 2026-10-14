# Forgot Password Cheat Sheet

## Introduction

Proper user management → **Forgot Password** service letting user request password reset.

Looks easy but common vulnerability source, e.g. renowned user enumeration attack.

Quick reference:

- **Return consistent message for existent and non-existent accounts.**
- **Ensure uniform response time for user message.**
- **Use side-channel to communicate reset method.**
- **Use [URL tokens](#url-tokens) for simplest, fastest implementation.**
- **Ensure generated tokens/codes are:**
    - **Randomly generated w/ cryptographically safe algorithm.**
    - **Long enough against brute-force attacks.**
    - **Stored securely.**
    - **Single use, expire after appropriate period.**
- **No account change (e.g. lockout) until valid token presented.**

Sheet covers resetting passwords. MFA reset: see [Multifactor Authentication Cheat Sheet](Multifactor_Authentication.md#resetting-mfa).

## Forgot Password Service

Reset process = two main steps below.

### Forgot Password Request

User inputs username/email in forgot password service; for secure process:

- Return consistent message for existent and non-existent accounts.
- Return responses in consistent time to prevent account enumeration. Use async calls or same logic path instead of quick exit.
- Protect against excessive automated submissions: per-account rate-limiting, CAPTCHA, or other controls. Otherwise attacker can send thousands of reset requests/hour for an account, flooding user's intake (e.g., email inbox, SMS) w/ useless requests.
- Normal security measures: [SQL Injection Prevention methods](SQL_Injection_Prevention.md), [Input Validation](Input_Validation.md).

### User Resets Password

After user proves identity via token (emailed) or code (SMS/other), they reset to new secure password. Measures:

- User confirms password by typing twice.
- Secure password policy in place, consistent w/ rest of app.
- Update/store password per [secure practices](Password_Storage.md).
- Email user that password was reset (never send password in email!).
- After setting new password, user logs in via usual mechanism. Don't auto-login: adds complexity to authentication/session code, raises vulnerability likelihood.
- Ask user whether to invalidate all existing sessions, or invalidate automatically.

### Account Recovery After Suspected Compromise

Password reset alone may not restore control of compromised account. Attacker may still hold active session or have changed recovery info or MFA methods.

Recovering potentially compromised account:

- Don't rely solely on recently added/changed recovery info. Use independent, previously established recovery evidence (e.g. saved recovery codes), in combination meeting account's assurance requirements. See NIST account recovery guidance.
- Don't auto-restore superseded recovery addresses/phone numbers; may have been replaced because lost or compromised.
- Promptly suspend/invalidate authenticators identified as compromised, per NIST guidance for compromised authenticators.
- Review recovery addresses, phone numbers, MFA methods w/ verified account owner; remove unauthorized changes. Google's compromised-account guidance identifies these settings.
- After successful recovery, invalidate existing sessions and outstanding password reset/recovery links/codes so they can't restore attacker access. See [session invalidation guidance](Session_Management.md#session-expiration).
- Notify user via all applicable registered notification addresses, incl. established channels still safe. Include instructions and contact info for reporting unauthorized recovery (NIST account notification guidance).

Related controls: [reauthentication after risk events](Authentication.md#re-authentication-after-risk-events), [MFA recovery](Multifactor_Authentication.md#resetting-mfa).

## Methods

Need way to identify user or reach them via side-channel.

Methods:

- [URL tokens](#url-tokens).
- [PINs](#pins)
- [Offline methods](#offline-methods)
- [Security questions](#security-questions).

Combine for greater assurance of identity. Always ensure user has recovery path, even if via support team and proving identity to staff.

### General Security Practices

Good practices essential for reset identifiers (tokens, codes, PINs, etc.). Some points (e.g. lifetime restriction) don't apply to [offline methods](#offline-methods). All tokens/codes should be:

- Generated w/ [cryptographically secure random number generator](Cryptographic_Storage.md#secure-random-number-generation).
    - JSON Web Tokens (JWTs) possible instead of random tokens, but may add vulnerabilities, see [JSON Web Token Cheat Sheet](JSON_Web_Token.md).
- Long enough against brute-force attacks.
- Linked to individual user in database.
- Invalidated after use.
- Stored securely, per [Password Storage Cheat Sheet](Password_Storage.md).

### URL Tokens

Passed in URL query string, typically emailed. Process:

1. Generate token for user, attach in URL query string.
2. Email token to user.
   - Don't rely on Host header when creating reset URLs → avoids Host Header Injection. URL hard-coded or validated against list of trusted domains.
   - Ensure URL uses HTTPS.
3. User opens email, browses to URL w/ token.
   - Reset password page adds Referrer Policy tag w/ `no-referrer` value to avoid referrer leakage.
   - Protect against brute-forcing tokens in URL, e.g. rate limiting.
4. If required, add validation steps e.g. [security questions](#security-questions).
5. User creates new password and confirms. Apply same password policy as elsewhere in app.

*Note:* URL tokens can follow [PINs](#pins) behavior by creating restricted session from token. Decide per needs and developer expertise.

### PINs

PINs = numbers (between 6 and 12 digits) sent to user via side-channel e.g. SMS.

1. Generate PIN.
2. Send via SMS or other mechanism.
   - Splitting PIN with spaces eases reading/entering.
3. User enters PIN + username on reset page.
4. Create limited session from PIN permitting only password reset.
5. User creates new password and confirms. Apply same password policy as elsewhere in app.

### Offline Methods

Differ from others: user resets password w/o requesting special identifier (token/PIN) from backend. Backend must still authenticate to ensure request legit. Identifier provided on registration or when user configures it.

Store identifiers offline, securely (*e.g.* password managers); backend follows [general security practices](#general-security-practices). Some implementations built on [hardware OTP tokens](Multifactor_Authentication.md#hardware-otp-tokens), [certificates](Multifactor_Authentication.md#certificates), or other enterprise implementations; out of scope here.

Account w/ MFA needing MFA recovery: methods in [Multifactor Authentication cheat sheet](Multifactor_Authentication.md#resetting-mfa).

### Security Questions

Not sole mechanism for password reset: answers often guessable/obtainable by attackers. Can add extra layer combined w/ other methods here. If used, choose secure questions per [Security Questions cheat sheet](Choosing_and_Using_Security_Questions.md).

## Account Lockout

Don't lock accounts in response to forgotten password attack: enables denying access to users w/ known usernames. See [Authentication Cheat Sheet](Authentication.md).

## References

- NIST SP 800-63B-4: Account Recovery
- OWASP Application Security Verification Standard (ASVS): V6.4 Authentication Factor Lifecycle and Recovery
