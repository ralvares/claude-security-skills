# Mobile Application Security Cheat Sheet

Mobile dev has security challenges unique vs web/other software. Starting point for devs, not comprehensive.

## Architecture & Design

### 1. Secure by Design

- Secure design from start of development, not afterthought.
- Apply least privilege, defense in depth, separation of concerns.
- Follow industry standards/best practices, e.g.:
    - National Institute of Standards and Technology (NIST)
    - Internet Engineering Task Force (IETF)

See [Secure Product Design Cheat Sheet](Secure_Product_Design.md).

### 2. Secure APIs

- App must communicate securely w/ backend services.
- Use OAuth2, JWT, or similar for authentication.
- Regularly update + rotate API keys/tokens.

### 3. Principle of Least Privilege

- Request only needed permissions.
- Applies to device permissions granted by user + permissions granted to app by backend services.
- Avoid storing app files w/ overly permissive permissions.
- Secure by default: most secure settings by default.

### 4. Supply Chain

Third-party libraries/components add security unknowns.

- Ensure app signing.
- Use only trusted, validated third-party libraries/components.
- Establish security controls for app updates, patches, releases.
- Monitor + detect security incidents of used third-party products.

See [Vulnerable Dependency Management Cheat Sheet](Vulnerable_Dependency_Management.md) for managing third-party deps when vulnerabilities found.

## Authentication & Authorization

Authentication complex, many pitfalls. Write + test auth logic w/ extreme care. Tips here barely scratch surface. See [Authentication Cheat Sheet](Authentication.md) and OWASP Mobile Top 10 M1: Insecure Authentication/Authorization.

### 1. Don't Trust the Client

- Authenticate/authorize server-side; load data on device only after successful authentication.
- Sensitive local data: encrypt, protect keys using platform key storage (MASWE-0003). If design needs password-derived keys, use dedicated password-based key derivation function (MASWE-0014) w/ unique random salt + appropriate work factor; password or fast hash of it = unsuitable encryption key.
- Never store user passwords on device; use device-specific revocable tokens.
- Avoid spoofable values (e.g., device identifiers) for authentication.
- Assume all client-side controls bypassable; also perform server-side.
- Include client-side code to detect code/binary tampering.

### 2. Credential Handling

- Never hardcode credentials in app.
- Encrypt credentials in transmission.
- Never store user credentials on device. Consider secure, revocable access tokens.

### 3. Passwords and PIN Policy

- Account passwords: allow long passphrases w/o character-composition requirements; block common/compromised passwords, per NIST password guidance (SP 800-63B). See [password strength controls](Authentication.md#implement-proper-password-strength-controls) for length + other policy.
- Never allow short PINs such as 4 digits.
- Use platform secure storage: Keychain (iOS) or Keystore (Android).

### 4. Biometric Authentication

- Use platform-supported biometric methods.
- Always provide fallback, e.g., PIN.

### 5. Session Management

- Session timeout after inactivity.
- Offer remote logout.
- Use randomly generated session tokens.
- Secure session data, client + server side.

### 6. Token Storage

- Store auth tokens securely.
- Handle token expiration gracefully.

### 7. Sensitive Operations

- Require re-authentication for sensitive operations (e.g., changing passwords, updating payment info).
- Consider re-authentication before displaying highly sensitive info.
- Require authorization checks on any backend functionality.

## Data Storage & Privacy

### 1. Data Encryption

- Encrypt sensitive data at rest + in transit.
- Store private data in device internal storage.
- Use platform APIs for encryption; never implement own algorithms.
- Use hardware-based security where available (e.g., Secure Enclave on iOS, Strongbox on Android) for key storage + crypto operations.

### 2. Data Leakage

- Beware caching, logging, background snapshots; ensure sensitive data not leaked via them.

See [Logging Cheat Sheet](Logging.md#data-to-exclude) for data not to log.

### 3. Use HTTPS

- Always HTTPS for network communications.

### 4. Third-Party Libraries

- Ensure all third-party libraries secure + up to date.

### 5. Personally Identifiable Information (PII)

- Minimize PII to necessity.
- Replace PII w/ less critical info if possible.
- Reduce PII, e.g., less frequent location updates.
- Implement automatic expiration + deletion of PII to minimize retention.
- Ask user consent before collecting/using PII.

## Network Communication

### 1. Don't Trust the Network

- Assume all network communication insecure + interceptable.

### 2. Use Secure Protocols

- HTTPS for all network communication.
- Never override SSL certificate validation to allow self-signed/invalid certificates.
- Avoid mixed version SSL sessions.
- Encrypt data even over SSL, in case of future SSL vulnerabilities.
- Use strong, industry-standard cipher suites w/ appropriate key lengths.
- Use certificates signed by trusted CA.
- Avoid sending sensitive data via SMS.

### 3. Certificate Pinning

- Consider certificate pinning. See [Pinning Cheat Sheet](Pinning.md) for pros/cons.

## User Interface

### 1. UI Data Masking

- Mask sensitive info in UI fields to prevent shoulder surfing.

### 2. User Notifications

- Inform user of security-related activities, e.g., logins from new devices.

### 3. Input Validation

- Validate + sanitize user input. See [Input Validation Cheat Sheet](Input_Validation.md).

### 4. Output Validation

- Validate + sanitize output to prevent injection/execution attacks.

## Code Quality

### 1. Static Analysis

- Use static analysis tools to find vulnerabilities.

### 2. Code Reviews

- Make security focal point of code reviews.

### 3. Update Libraries

- Keep all libraries updated to patch known vulnerabilities.

## Application Integrity

- Disable debugging.
- Include code to validate app code integrity.
- Obfuscate app binary.
- Implement runtime anti-tampering controls:
    - Check for debugging, hooking, code injection.
    - Detect emulator or rooted/jailbroken device.
    - Verify app signatures at runtime.
    - Apply appropriate responses to detected tampering (e.g., limit functionality).

## Testing

### 1. Penetration Testing

- Ethical hacking to find vulnerabilities.
- Example tests:
    - Cryptographic vulnerability assessment.
    - Attempt backend server functionality anonymously by removing session tokens from POST/GET requests.

### 2. Automated Tests

- Automated tests to ensure security features work + access controls enforced.

### 3. Usability Testing

- Security features must not harm usability; else users bypass them.

## Post-Deployment

### 1. Incident Response

- Have clear incident response plan.

### 2. Updates

- Plan regular updates/patches. Esp. important for mobile: delay between patch release + users receiving it (app store review, user update time).

- Mechanism to force users to update app version when necessary.

### 3. Monitoring and Analytics

- Real-time monitoring to detect + respond to threats.

## Platform-Specific Guidance

### Android

- Use Android's ProGuard for code obfuscation.
- Avoid storing sensitive data in SharedPreferences. See Android docs on working with data securely.
- Disable backup mode to prevent sensitive data in backups.

- Use Android Keystore w/ hardware backing (TEE or StrongBox) to store cryptographic keys.
    - **How**: Generate hardware-backed keys by specifying `.setIsStrongBoxBacked(true)` in `KeyGenParameterSpec.Builder` when available (Android 9+).
    - Verify hardware-backed storage via `KeyInfo.isInsideSecureHardware()`.
    - Fall back to regular hardware-backed keystore if Strongbox unavailable.
    - Configure key usage restrictions w/ `.setUserAuthenticationRequired(true)` for sensitive operations.
    - See Hardware-backed Keystore documentation.

- Implement Google's Play Integrity API for device + app integrity checks.
    - **How**: Obtain integrity verdict from device, validate server-side, act if integrity checks fail.
    - SafetyNet Attestation API fully turned down January 2025. All developers must migrate to Play Integrity API.
    - See Play Integrity API documentation.

### iOS and iPadOS

#### Shortcuts Permissions

- iOS/iPadOS Shortcuts automate app functions; may enable sensitive actions even when device locked.

- Scenarios where user can execute Shortcut while device locked:

  1. Shortcut added as widget to Today View.
  2. Shortcut assigned to Action Button (iPhone 15 Pro and iPhone 16 Pro models): press while locked.
  3. Shortcut assigned to Control Center (iOS/iPadOS 18+): pull up Control Center, press Shortcut button while locked.
  4. Shortcut invoked via Siri while locked.
  5. Shortcut added to Home Screen (iOS/iPadOS 18+): tap Shortcut button on lock screen while locked.
  6. Shortcut set to run at specific interval/time: executes even if locked.

- Sensitive app functionality triggered via Shortcuts must always require device unlock before execution.

- **How**: Sensitive App Intents (iOS/iPadOS 16+): set `authenticationPolicy` to `.requiresLocalDeviceAuthentication`. Requires unlocking device running intent if locked; does not require fresh authentication when device already unlocked. Keep enforcing app's session + authorization checks. `isProtectedDataAvailable` reports protected-file availability, can be true when content protection disabled; never use as authentication check.

#### Siri Permissions

- Siri accesses app functionality via voice or Type to Siri commands; by default available when device locked → potentially unauthorized actions.
- **How**: Apply App Intent authentication policy above to sensitive Siri actions. For explicit approval before destructive work, call `requestConfirmation()`, stop if user cancels; confirmation does not replace authentication/authorization. Legacy SiriKit intents handled by app: set supported intent's Authentication level to **Restricted While Locked** in Xcode, configures `INIntentsRestrictedWhileLocked`.

#### Deep Link Security

- Deep links give direct access to specific app screens; if unsecured can bypass authentication → unauthorized access to secure sections.
- Example: Microsoft Authenticator for iOS (remediated July 2024) let users bypass App Lock by navigating to `msauth://microsoft.aad.brokerplugin/?`, which opened Authenticator and dismissed Face ID/Touch ID/passcode prompt.
- **How**: Authentication checks on any view controllers/endpoints reached via deep links. Configure + validate Universal Links using apple-app-site-association files. Sanitize + validate all deep link params to prevent injection. Redirect unauthorized users to login screen; no direct access to sensitive parts w/o authentication. (See Apple Developer: Supporting universal links in your app.)

#### WidgetKit Security

- Lock screen widgets may display sensitive data, exposing it w/o device unlock.
- **How**: Mark sensitive views with `privacySensitive(_:)`, provide redacted placeholders so WidgetKit honors user privacy settings. If widget must hide content while locked, enable Data Protection capability for widget extension, select `NSFileProtectionComplete`. Follow Apple's widget privacy guidance.

#### Additional Security Considerations

- Configure background refresh policies to prevent sensitive data updates while device locked.
- Configure privacy-related entries in `Info.plist` for features needing user permissions.
- Use App Groups w/ appropriate security config when sharing data between app + widgets.
- Use ATS (App Transport Security) to enforce strong network security policies.
- Never store sensitive data in `plist` files.

- Use Apple's Secure Enclave for cryptographic key storage + sensitive operations.
    - **How**: Create keys using `SecKeyCreateRandomKey` w/ `kSecAttrTokenID` set to `kSecAttrTokenIDSecureEnclave`.
    - Secure Enclave keys never leave secure hardware; only operations using them run there.
    - Biometric operations: use `LAContext` w/ `evaluatePolicy` to authenticate directly via Secure Enclave w/o exposing biometric data to app.
    - Consider access control options like `kSecAccessControlBiometryAny` or `kSecAccessControlUserPresence` to require user authentication before key use.
    - See Secure Enclave documentation.

- Use Apple's App Attest API (iOS 14+) to validate app integrity.
    - **How**: Generate attestation keys + assertions w/ `DCAppAttestService`; verify assertions server-side.
    - Complement w/ Apple's DeviceCheck API for persistent device state tracking.
    - See App Attest documentation.

## Advanced Hardware Security & Monitoring

- Modern devices typically provide Trusted Execution Environments (TEE) or secure hardware modules. Use via standard OS APIs.
- Higher-risk scenarios: consider extra runtime security (behavioral anomaly detection, runtime monitoring) complementing built-in OS protections.

Further reading: OWASP Mobile Top 10 Project; OWASP Mobile Application Security Project (detailed framework).

## References

- OWASP MASVS-STORAGE-1: Secure Storage of Sensitive Data
- Android Keystore System
- Apple Platform Security: The Secure Enclave
