# Email Validation and Verification in Identity Systems Cheat Sheet

## Introduction

Email = primary identifier in authentication + account recovery. Improper validation, normalization, verification → account takeover, user enumeration, identity confusion.

Guidance for secure email handling in identity systems. Broader identity controls: [Authentication Cheat Sheet](Authentication.md).

## Goals

- Treat email safely as identifier
- Prevent account takeover via email-based flows
- Reduce user enumeration risk
- Define secure verification + change workflows

## Threat Model

Attackers may:

- Register equivalent/visually similar email addresses
- Exploit inconsistent normalization logic
- Abuse password reset
- Enumerate valid accounts
- Take over accounts via email change workflows

## Email Canonicalization

MUST define consistent normalization strategy before storing/comparing email addresses.

### Recommendations

- Normalize domain portion to lowercase
- Avoid provider-specific transformations (e.g., Gmail dot removal) unless fully controlled
- Store both:
    - Original input (display + communication)
    - Canonical form (comparison per your policy)
- Document comparison policy explicitly; apply consistently across registration, login, password reset, account recovery, account linking

## Email Format Validation

Strict regex validation often rejects valid addresses or adds inconsistencies.

### Recommendations

- Use well-tested libraries, not custom regex
- Accept broad range of valid formats
- Reject clearly malformed input only

## Unicode and IDN Considerations

Unicode → spoofing via visually similar characters.

### Recommendations

- Normalize Unicode input
- Convert internationalized domains to punycode for comparison
- Beware homoglyph attacks (e.g., Latin vs Cyrillic characters)
- Extra caution w/ internationalized local-parts: normalization/comparison behavior may differ across systems

## Case Sensitivity

- Domain part: always case-insensitive
- Local part: technically case-sensitive under SMTP, though many providers don't enforce in practice

### Recommendation

- Preserve original email as user entered
- Define explicit local-part comparison policy per identity architecture + interoperability requirements
- Fold/normalize local part only when system fully owns that behavior and decision won't create account-collision or mistaken-account risk

## Email Ownership Verification

Verify email ownership before enabling account use.

### Recommendations

- Use cryptographically secure, random tokens
- Tokens:
    - Single-use
    - Time-limited
- Don't activate accounts before verification completes

## Password Reset Flows

Password reset = high-risk operation. Recovery controls: [Forgot Password Cheat Sheet](Forgot_Password.md).

### Recommendations

- Single-use, time-limited tokens
- Don't disclose whether email exists
- Invalidate tokens after use or expiration
- Rate limit reset requests

## Email Change Workflows

Changing email = changing identity.

### Recommendations

- Require re-authentication
- Notify existing email of change
- Require confirmation of new email
- Consider confirmation from both addresses for high-risk systems

## Anti-Enumeration Controls

Attackers must not determine whether email is registered.

### Recommendations

- Consistent responses for login + reset flows
- Avoid timing discrepancies between valid/invalid cases
- Rate limiting + monitoring

## Temporary Email Abuse

Disposable email services can bypass controls.

### Recommendations

- Maintain list of known disposable domains if appropriate
- Prefer risk-based controls over strict blocking
- Monitor suspicious account-creation patterns

## Email as an Authentication Factor

Email ≠ strong authentication factor.

### Recommendations

- Treat email as weak factor
- Require multi-factor authentication (MFA) for sensitive operations
- Don't rely on email alone for account security

## Logging and Monitoring

Monitoring email flows detects abuse.

### Recommendations

- Log verification attempts + failures
- Monitor password reset activity
- Detect abnormal patterns (e.g., high-frequency requests)
- Avoid logging full email addresses; mask/pseudonymize where logging necessary (e.g., `j***@example.com`)
- Never log verification, reset, authentication tokens or full verification/reset URLs
- Treat email addresses + related identifiers in logs as personal/sensitive data; restrict access

## References

- RFC 5322: Internet Message Format
- RFC 5321: Simple Mail Transfer Protocol
- NIST SP 800-63B-4: Authentication and Authenticator Management
