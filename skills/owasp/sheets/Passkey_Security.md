# Passkey Security Cheat Sheet

## Introduction

Passkeys = discoverable WebAuthn public key credentials for passwordless authentication, no shared secret sent to app. Web apps use passkeys via WebAuthn. Authenticator keeps private key; relying party stores public key. Passkey scoped to relying party identifier (RP ID) → phishing resistance when ceremony + server-side verification implemented correctly.

For developers building WebAuthn relying-party side: passkey registration, authentication, credential management, account recovery. Scope: platform and roaming authenticators, incl. security keys supporting discoverable credentials; synced and device-bound passkeys. Legacy FIDO U2F/CTAP1 second-factor credentials out of scope. Main recommendations:

- Use maintained WebAuthn server library; validate every required ceremony field on server.
- Bind registration to intended account; require recent authentication before changing passkeys.
- User presence (UP) and user verification (UV) = different security properties.
- Design credential management + recovery as carefully as authentication.
- Support more than one authenticator so losing one device does not force weak recovery path.

## Understand the Security Model

### Components and Terms

- **Relying party (RP)**: app registering/authenticating users.
- **Client**: browser or other software calling WebAuthn API.
- **Authenticator**: creates credentials, signs authentication assertions. Built into device or separate roaming authenticator.
- **WebAuthn/FIDO2 protocol**: spans RP, client, authenticator. WebAuthn = web-facing API used by RPs; CTAP = communication between clients and roaming authenticators.
- **Passkey**: discoverable WebAuthn credential for passwordless authentication. Held by platform or roaming authenticator; device-bound or synced between devices by credential provider.
- **Credential ID**: identifies credential to RP. Private key stays under authenticator control.
- **User handle**: opaque RP-generated account identifier. Not username or email address.
- **User presence (UP)**: person interacted with authenticator.
- **User verification (UV)**: authenticator locally verified user, e.g. PIN or biometric.

UP ≠ UV. Require UV when passkey must satisfy multi-factor or other high-assurance policy. Passkey not automatically multi-factor just because authenticator supports UV; RP must request UV and verify returned UV flag.

### Security Properties and Limits

WebAuthn credentials scoped to RP; signed response includes hash of RP ID. Client data also binds response to web origin + ceremony challenge. Correct verification → RP gets phishing resistance, verifier-name binding, replay resistance.

Not protected by passkeys alone:

- Compromised authenticated session adding attacker-controlled passkey.
- Insecure recovery process bypassing passkey authentication.
- Server-side credential records associated with wrong account.
- Application code, authorization, session-management vulnerabilities.
- Compromise of device, authenticator, or account used to sync passkeys.

Apply controls from [Authentication Cheat Sheet](Authentication.md), [Session Management Cheat Sheet](Session_Management.md), [Transaction Authorization Cheat Sheet](Transaction_Authorization.md) to surrounding app.

### Choose the RP ID Carefully

RP ID determines where credential usable. Use narrowest stable domain covering intended app. Do not use registrable parent domain merely to share credentials with unrelated subdomains. WebAuthn spec discusses security implications of RP ID/origin relationship; compromise of an origin within RP ID scope may affect that RP deployment's security.

Server must use same expected RP ID in registration and authentication. Maintain explicit allowlist of permitted origins, incl. scheme, host, port where applicable. Never construct expected origin from untrusted request header.

Native app origins differ by platform. Apple native passkey API reports HTTPS origin formed from `https://` + RP ID, validated against app's Associated Domains. Android app origin = string like `android:apk-key-hash:<hash>`, derived from app signing certificate. Both platforms decide whether app may use your RP ID from association file you host: `/.well-known/assetlinks.json` on Android; `webcredentials` entries in `/.well-known/apple-app-site-association` on Apple platforms. Server must match each expected origin against allowlist as explicit entry, never pattern. Treat both association files as RP attack surface, same change control as origin allowlist. Overly broad association can authorize unintended apps to use RP-scoped credentials. Permissive server origin allowlist weakens response verification; it does not by itself bypass platform app-association checks or give app access to user's passkey.

WebAuthn restricted to secure contexts. Serve registration, authentication, credential-management pages over HTTPS; protect against script injection. Avoid cross-origin WebAuthn in embedded frames unless intentional, reviewed design using required Permissions Policy and origin validation.

### Use a Maintained Library

Never implement CBOR parsing, COSE key handling, attestation validation, or assertion verification yourself. Use maintained server-side WebAuthn library implementing W3C relying-party verification steps. Keep updated; include successful and failing registration + authentication ceremonies in automated tests.

Library does not make account workflows safe automatically. App remains responsible for: issuing/consuming challenges, choosing expected RP ID + origins, binding ceremonies to correct session + account, enforcing UV policy, managing credential lifecycle events.

## Secure Passkey Registration

### Establish an Authorized Account Context

Registration attaches new authenticator to account; treat as sensitive account change.

- Existing account: require recently authenticated session and reauthenticate user before adding passkey. Do not rely only on long-lived session cookie.
- New account: bind ceremony to verified account-creation transaction. Do not let client-supplied account identifier select different account.
- Protect registration initiation + completion endpoints against CSRF per [Cross-Site Request Forgery Prevention Cheat Sheet](Cross-Site_Request_Forgery_Prevention.md).
- Rate-limit; log failed and successful enrollment attempts.

### Generate and Bind Registration Options

Generate registration challenge w/ cryptographically secure RNG. WebAuthn security considerations require at least 16 random bytes; expire promptly, accept only once. Store server-side state binding challenge to:

- Registration ceremony type.
- Authenticated session + intended account.
- Expected RP ID + origin policy.
- Intended user-verification + attestation policy.
- Expiration time.

Never accept authentication challenge as registration challenge, or challenge issued for one account in ceremony for another. Invalidate challenge whether ceremony succeeds or fails terminally.

Generate stable, opaque user handle w/ no username, email, or other PII, per WebAuthn user-handle privacy guidance. User handle identifies one account within RP; never reassign to another account.

Include account's existing credential IDs in `excludeCredentials` when possible: discourages duplicate registration (UX), but server must still enforce credential uniqueness.

### Verify the Registration Response

Diagram (registration ceremony sequence) summarizes key checks and which party performs them.

Follow WebAuthn registration verification procedure via selected library. Server verifies at minimum:

- Client data type is `webauthn.create`.
- Returned challenge exactly matches issued challenge.
- Origin is exact member of RP allowlist.
- RP ID hash matches expected RP ID.
- UP flag set; UV flag set when UV required.
- Public-key algorithm is one RP offered and permits.
- Credential public key + credential ID structurally valid.
- Requested extensions processed per RP policy.
- Attestation verified when RP policy requires it.

Store credential only after all checks succeed. Associate with account from server-side ceremony state, never account identifier returned by client. Enforce credential ID uniqueness across RP; make account association change auditable.

Store credential ID, public key, user handle association, algorithm, relevant transports, creation time, user-visible name, authenticator data needed by library. Store backup eligibility + backup state when returned; do not expose them as proof a provider/device is trustworthy.

### Minimize Attestation

Most public-facing apps: no attestation, no restriction to authenticator model list. WebAuthn documents attestation limitations and privacy considerations; attestation does not prove authenticator stays uncompromised.

Use attestation only when documented enterprise/regulatory requirement justifies enforcing authenticator provenance/properties. If required:

- Define acceptable formats, trust anchors, metadata, failure behavior.
- Validate complete attestation chain + relevant status info.
- Plan metadata + trust-anchor updates.
- Provide reviewed exception/recovery process that does not silently remove policy.

## Secure Passkey Authentication

### Generate and Bind Authentication Options

Fresh, unpredictable challenge for every authentication ceremony. Bind to ceremony type, expected RP ID, origin policy, UV requirement, session/transaction context, expiration time. Consume once.

Account-first authentication: send only credential IDs registered to selected account in `allowCredentials`. Generic responses + consistent behavior so account selection step does not disclose whether account exists.

Username-less authentication: omit `allowCredentials`, use discoverable credentials. After verification, use returned user handle + credential ID to locate server-side credential record. Both must resolve to same account; never trust display name or other client-provided identity claim.

Conditional mediation improves passkey discovery, coexists with password fields. Treat as another way to start same authentication ceremony, not different verification policy.

### Verify the Authentication Response

Diagram (authentication ceremony sequence) summarizes key checks and which party performs them.

Follow WebAuthn assertion verification procedure via selected library. Server verifies at minimum:

- Client data type is `webauthn.get`.
- Challenge exactly matches unexpired, unused authentication challenge.
- Origin is exact member of RP allowlist.
- RP ID hash matches expected RP ID.
- Credential ID exists, belongs to account selected by verified ceremony context.
- Assertion signature valid under stored public key.
- UP flag set; UV flag set when policy requires.
- Returned user handle, when present, matches credential's account.
- Extension outputs + cross-origin indicators comply with RP policy.

Create authenticated app session only after every required check succeeds. Rotate session identifier at authentication; apply [Session Management Cheat Sheet](Session_Management.md) controls.

### Handle Signature Counters Conservatively

Non-increasing signature counter can signal cloned, malfunctioning authenticator, or out-of-order assertion processing. WebAuthn signature counter considerations: not universal clone detection. Some authenticators implement no counter; synced credential may be used from multiple authenticator instances w/ non-strictly-monotonic counters.

Nonzero counter not increasing as expected: record event, evaluate w/ other account-risk signals. Do not auto-lock out every user solely for counter anomaly. Follow library guidance; document RP response policy.

### Use Safe Failure Behavior

Return generic authentication errors not distinguishing unknown account, unknown credential, failed signature, policy rejection. Keep externally visible response timing as consistent as practical. Rate-limit attempts by account + relevant network/device signals, w/o creating trivial account-lockout DoS.

Failed passkey ceremony must not silently fall back to weaker method. Adversary-in-the-middle phishing does not defeat correctly verified passkey ceremony; it steers user to whatever fallback remains enabled. NIST SP 800-63B-4 Section 3.2.5: authenticators involving manual entry of authenticator output (OTP, out-of-band codes) are not phishing-resistant. If fallback exists, make it deliberate, logged, policy-documented path, not default error handling; follow [MFA Downgrade Attacks](Multifactor_Authentication.md#mfa-downgrade-attacks) guidance.

Log enough structured info to investigate failures; never log challenges, full credential responses, session identifiers, unnecessary user-identifying data. General guidance: [Logging Cheat Sheet](Logging.md).

## Protect the Credential Lifecycle and Recovery

### Credential Management

Provide authenticated credential-management page to view/manage passkeys. Show user-chosen name, creation date, last-used date; not raw credential IDs.

- Require recent reauthentication before adding/removing passkey, changing recovery methods, disabling last strong authenticator.
- Allow registering more than one authenticator.
- Notify user via existing trusted channel when passkey added/removed.
- Record enrollment, use, renaming, revocation as security events.
- Revoke credential immediately on server when user removes it or reports compromise.
- Confirm at least one usable authentication/recovery method remains before removing final passkey.

Never silently reassign credential record to different account. DB migrations + admin changes to credential-to-account mappings need integrity controls, authorization checks, audit logs. Unexpected duplicate credential ID = error requiring investigation.

Where supported, WebAuthn signal methods help credential provider reconcile local state after RP deletes credentials or updates user details. Improve consistency; do not replace server-side revocation.

### Account Recovery and Bootstrap

Passkey account security limited by weakest recovery route. Prefer recovery via another already-registered passkey, separately secured recovery code, or high-assurance identity process matching app risk.

- Encourage registering multiple authenticators before one is lost.
- Protect recovery codes as authentication secrets: store securely, single-use, user-regenerable.
- Rate limits, risk checks, notifications, additional review for recovery attempts.
- Email/SMS recovery must not silently bypass stronger authentication policy for high-risk accounts.
- After recovery: rotate sessions, review/revoke existing credentials as appropriate, notify user.
- Delay or add verification before high-impact actions when recovery indicates elevated takeover risk.

More: [Forgot Password Cheat Sheet](Forgot_Password.md); recovery guidance in [Multifactor Authentication Cheat Sheet](Multifactor_Authentication.md).

### Synced and Device-Bound Credentials

Synced passkeys (NIST syncable authenticators) improve availability: credential usable on multiple devices. Security also depends on credential provider's account protection, device enrollment, synchronization, recovery controls. Device-bound credentials support policies requiring key to stay on particular authenticator; need availability + replacement plan.

Choose policy per threat model:

- Public-facing apps: generally support synced passkeys; give users secure options for additional authenticators + recovery.
- Enterprise/high-assurance apps: may require managed, device-bound authenticators + attestation when operational controls justify reduced interoperability.
- Use backup eligibility + backup state as risk/policy inputs where appropriate. Not user-verification results; not proof of specific sync provider.
- Do not assume synced passkey meets every assurance level. E.g. NIST does not allow syncable authenticators at Authentication Assurance Level 3 (AAL3).

## Deployment and Review Checklist

Use with W3C registration and authentication verification procedures.

### Server and Protocol

- Maintained WebAuthn server library, kept updated.
- Cryptographically random, single-use, expiring challenges of at least 16 bytes.
- Bind each challenge to ceremony, account/session context, RP ID, origin, policy.
- Exact origin allowlist + documented RP ID.
- List native app origins explicitly; change-control `assetlinks.json` and `apple-app-site-association` files together with allowlist.
- Verify type, challenge, origin, RP ID hash, UP, required UV, credential ownership, signature.
- Store public keys + credential metadata safely; enforce credential ID uniqueness.
- Counters = risk signals, not universal clone detection.
- Test registration + authentication on supported browsers + authenticators.

### Account Workflows

- Recent authentication for passkey enrollment, removal, recovery changes.
- Bind new credentials to server-selected account.
- Support multiple authenticators + immediate server-side revocation.
- Notify users of credential lifecycle changes; retain useful audit events.
- Recovery commensurate with passkey authentication security.
- Generic error messages; protect account-first flows from enumeration.
- Never let failed passkey ceremony silently fall back to non-phishing-resistant method.

### Privacy and Operations

- User handles opaque, free of PII.
- Avoid attestation unless documented requirement justifies it.
- No raw credential IDs in UIs, URLs, logs.
- Minimize stored authenticator metadata; restrict access.
- Monitor registration, authentication, recovery, admin mapping changes.
- Document incident procedures for compromised authenticator, sync account, RP origin, WebAuthn library.

## References

- W3C Web Authentication Level 3
- NIST SP 800-63B-4
- NIST SP 800-63B-4: Syncable Authenticators
