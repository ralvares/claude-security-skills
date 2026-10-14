# Security Terminology Cheat Sheet

## Introduction

Definitions/distinctions for often-confused security terms. Critical for correct controls + standards like OWASP ASVS.

## Table of Contents

- [Data Handling: Encoding, Escaping, Sanitization, and Serialization](#data-handling-encoding-escaping-sanitization-and-serialization)
- [Cryptography: Encryption, Hashing, and Signatures](#cryptography-encryption-hashing-and-signatures)
- [Identity: Authentication and Authorization](#identity-authentication-and-authorization)
- [Federated Identity Terms](#federated-identity-terms)
- [References](#references)

## Data Handling: Encoding, Escaping, Sanitization, and Serialization

How data is transformed for transport, storage, display. Validation: [Input Validation Cheat Sheet](Input_Validation.md).

### Encoding

**Definition:** Transform data to different format via public scheme, so another system can safely consume it.

- **Purpose:** Represent data for transport, storage, or output context.
- **Reversibility:** Always reversible.
- **Examples:** Base64, URL Encoding, HTML Entity Encoding.
- **Security Context:** Base64 gives no confidentiality. Context-appropriate output encoding = XSS defense; wrong encoding for destination context can leave injection vulnerability.

### Escaping

**Definition:** Represent characters w/ parser-specific escape sequences so they're interpreted literally in a context.

- **Purpose:** Interpreter treats data as text, not code/commands.
- **Examples:** `\"` inside a JSON string, `&lt;` in HTML text.
- **Security Context:** Rules depend on parser + context. SQL values: use [parameterized queries](SQL_Injection_Prevention.md#primary-defenses), not escaped-string SQL.

### Sanitization

**Definition:** Clean/filter input by removing, replacing, modifying potentially dangerous characters/content.

- **Purpose:** Make "dirty" input "clean" per security policy.
- **Examples:** Maintained HTML sanitizer allowing approved elements + attributes in user-authored HTML.
- **Security Context:** Use [HTML sanitization](Cross_Site_Scripting_Prevention.md#html-sanitization) when untrusted input must render as HTML. Removing `<script>` tags alone insufficient; other elements/attributes can execute scripts. Use output encoding when value displays as text.

### Serialization

**Definition:** Convert object/data structure to storable/transmittable format (e.g., byte stream), later reconstructable.

- **Purpose:** Data persistence + communication.
- **Security Context:** **Insecure Deserialization** = untrusted data reconstructs object → potential Remote Code Execution (RCE).

---

## Cryptography: Encryption, Hashing, and Signatures

Protect confidentiality, integrity, authenticity. Implementation: [Key Management Cheat Sheet](Key_Management.md), [Password Storage Cheat Sheet](Password_Storage.md).

### Encryption

**Definition:** Transform data (plaintext) → unreadable format (ciphertext) using secret key.

- **Purpose:** **Confidentiality**. Only authorized key holders read data.
- **Reversibility:** Reversible (Decryption) w/ correct key.
- **Types:** Symmetric (same key), Asymmetric (public/private keys).

### Hashing

**Definition:** Transform data → fixed-size string ("hash"/"digest") via math function.

- **Purpose:** **Integrity**. Small input change → completely different hash.
- **Reversibility:** One-way (non-reversible).
- **Security Context:** Password storage (w/ salt), file integrity verification.
- **Examples:** SHA-256, Argon2, bcrypt.

### Signatures (Digital Signatures)

**Definition:** Asymmetric cryptography proving origin + integrity of message.

- **Purpose:** **Authenticity** + **Non-repudiation**. Proves who sent message, not altered.
- **Mechanism:** Signing uses signer's private key; verification uses trusted public key bound to signer. Follow algorithm's message-processing rules (FIPS 186-5); no separate prehash unless chosen algorithm/API requires it.
- **Examples:** Asymmetrically signed JWTs, GPG signatures. JWTs can also use shared-key message authentication codes or encryption (RFC 7519); JWT format ≠ digital signature.

---

## Identity: Authentication and Authorization

### Authentication (AuthN)

**Definition:** Verify who user is.

- **Question:** "Who are you?"
- **Factors:** Something you know (password), have (token), are (biometrics).

### Authorization (AuthZ)

**Definition:** Verify what user may do.

- **Question:** "Are you allowed to do this?"
- **Security Context:** Occurs *after* successful authentication.
- **Examples:** Role-Based Access Control (RBAC), Attribute-Based Access Control (ABAC).

---

## Federated Identity Terms

Common in OAuth2, SAML, OIDC:

| Term | Definition | Context |
| :--- | :--- | :--- |
| **Identity Provider (IdP)** | System creating, maintaining, managing identity info + providing authentication services. | Google, Okta, Azure AD |
| **Relying Party (RP)** | App/service relying on IdP to authenticate users. | Your web app using "Login with Google" |
| **Service Provider (SP)** | In SAML, equivalent of Relying Party. | Your enterprise app using SAML |
| **Principal** | Entity (user, service, device) being authenticated. | The user logging in |

---

## References

- RFC 4949: Internet Security Glossary, Version 2
- OpenID Connect Core 1.0: Terminology
