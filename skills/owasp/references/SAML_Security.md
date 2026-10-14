# SAML Security Cheat Sheet

## Introduction

**S**ecurity **A**ssertion **M**arkup **L**anguage (SAML): open standard for exchanging authorization + authentication info. *Web Browser SAML/SSO Profile with Redirect/POST bindings* = one of most common SSO implementations; this sheet focuses on it.

## Validate Message Confidentiality and Integrity

[TLS 1.2](Transport_Layer_Security.md) = most common solution for transport-layer message confidentiality + integrity. See SAML Security (section 4.2.1). Counters:

- Eavesdropping 7.1.1.1
- Theft of User Authentication Information 7.1.1.2
- Theft of the Bearer Token 7.1.1.3
- Message Deletion 7.1.1.6
- Message Modification 7.1.1.7
- Man-in-the-middle 7.1.1.8

Digitally signed message w/ certified key = most common solution for message integrity + authentication. See SAML Security (section 4.3). Counters:

- Man-in-the-middle 6.4.2
- Forged Assertion 6.4.3
- Message Modification 7.1.1.7

Assertions may be encrypted via XMLEnc to prevent disclosure of sensitive attributes post transportation. See SAML Security (section 4.2.2). Counters:

- Theft of User Authentication Information 7.1.1.2

## Validate Protocol Usage

Common security-gap area; real example: Google SSO vulnerability (SSO profile vulnerable to Man-in-the-middle from malicious SP (Service Provider)).

SSO Web Browser Profile most susceptible to attacks from trusted partners. Flaw exposed because SAML Response lacked all required data elements for secure exchange. Follow SAML Profile usage requirements for AuthnRequest (4.1.4.1) and Response (4.1.4.2) to counter.

*AVANTSSAR* team suggests requiring these data elements:

- **AuthnRequest(ID, SP):** `AuthnRequest` must contain `ID` and `SP`. `ID` = string uniquely identifying request; `SP` identifies `Service Provider` that initiated it. Request `ID` must be returned in response (`InResponseTo="<requestId>"`); `InResponseTo` helps guarantee authenticity of response from trusted IdP. One of missing attributes that left Google's SSO vulnerable.
- **Response(ID, SP, IdP, {AA} K -1/IdP):** Response must contain all elements. `ID` = string uniquely identifying response. `SP` identifies recipient. `IdP` identifies identity provider authorizing response. `{AA} K -1/IdP` = assertion digitally signed w/ `IdP` private key.
- **AuthAssert(ID, C, IdP, SP):** authentication assertion must exist within Response; must contain `ID`, client `(C)`, identity provider `(IdP)`, service provider `(SP)` identifier.

### Validate Signatures

XML Signature Wrapping vulnerabilities in SAML implementations described in 2012, On Breaking SAML: Be Whoever You Want to Be.

Recommendations in response (Secure SAML validation to prevent XML signature wrapping attacks):

- Without exception, always schema-validate XML document before any security-related use::
    - Always use local, trusted copies of schemas.
    - Never allow automatic schema download from third-party locations.
    - If possible, inspect schemas + harden them, disabling possible wildcard type or relaxed processing statements.
- Securely validate digital signature:
    - One expected signing key: use `StaticKeySelector`. Obtain key directly from identity provider, store in local file, ignore any `KeyInfo` elements in document.
    - More than one expected signing key: use `X509KeySelector` (JKS variant). Obtain keys directly from identity providers, store in local JKS, ignore any `KeyInfo` elements in document.
- Avoid signature-wrapping attacks.
    - Never use `getElementsByTagName` to select security related elements in XML document w/o prior validation.
    - Always use absolute XPath expressions to select elements, unless hardened schema used for validation.

## Validate Protocol Processing Rules

Another common security-gap area due to vast number of steps to assert.

Processing SAML response is expensive, but all steps must be validated:

- Validate AuthnRequest processing rules: SAML Core (3.4.1.4). Counters:
    - Man-in-the-middle (6.4.2)
- Validate Response processing rules: SAML Profiles (4.1.4.3). Counters:
    - Stolen Assertion (6.4.1)
    - Man-in-the-middle (6.4.2)
    - Forged Assertion (6.4.3)
    - Browser State Exposure (6.4.4)

## Validate Binding Implementation

- HTTP Redirect Binding: SAML Binding (3.4). Encoding example: RequestUtil.java in Google's reference implementation.
- HTTP POST Binding: SAML Binding (3.5). Caching considerations very important: cached SAML protocol message can later be used as Stolen Assertion (6.4.1) or Replay (6.4.5) attack.

## Validate Security Countermeasures

Revisit each threat in SAML Security document; assert appropriate countermeasures applied for threats relevant to your implementation.

Additional countermeasures:

- Prefer IP Filtering when appropriate. E.g., could have prevented Google's initial flaw if Google gave each trusted partner separate endpoint w/ IP filter per endpoint. Counters:
    - Stolen Assertion (6.4.1)
    - Man-in-the-middle (6.4.2)
- Prefer short lifetimes on SAML Response. Counters:
    - Stolen Assertion (6.4.1)
    - Browser State Exposure (6.4.4)
- Prefer OneTimeUse on SAML Response. Counters:
    - Browser State Exposure (6.4.4)
    - Replay (6.4.5)

Architectural diagram: SAML technical overview has most complete diagrams; Web Browser SSO Profile with Redirect/POST bindings: section 4.1.3. Of all SAML documentation, technical overview most valuable at high level.

## Unsolicited Response (ie. IdP Initiated SSO) Considerations for Service Providers

Unsolicited Response inherently less secure by design: no **login [CSRF](Cross-Site_Request_Forgery_Prevention.md#possible-csrf-vulnerabilities-in-login-forms)** protection. SP has no chance to create pre-login session or verify authentication request intentionally initiated by user.

Doesn't make IdP-initiated SSO uniquely vulnerable to Man-in-the-Middle (MITM); those risks apply equally to SP-initiated flows if transport security compromised. But removes important layer of login intent validation.

IdP-initiated SSO remains supported for backward compatibility (notably SAML 1.1). If must be enabled, these steps (in addition to above) should help:

- Follow validation process in SAML Profiles (section 4.1.5). Counters:
    - Replay (6.1.2)
    - Message Insertion (6.1.3)
- `RelayState` parameter contract is URL → validate URL, explicitly on allowlist. Counters:
    - Open Redirect
- Implement proper replay detection at response or assertion level. Counters:
    - Replay (6.1.2)

## Identity Provider and Service Provider Considerations

SAML protocol rarely attack vector of choice, but sheets needed to keep it robust. Endpoints more targeted; how SAML token is generated + consumed both matter in practice.

### X.509 Certificate Considerations

Security association between Identity Provider (IdP) and Service Provider (SP) typically created when SP explicitly trusts IdP's X.509 signing certificate. How this occurs strongly affects security posture, as do how certificate is generated, its contents, how its private key is protected. E.g., attacker able to use IdP's signing key can mint SAML responses containing any assertion.

Manual association often akin to Certificate Pinning; not ideal, but may be unavoidable depending on IdP/SP software or design.

Certificate's signature type can differ from XML document signing type. Certificate's private key = only key that can sign XML document, but signing algorithm chosen at IdP's discretion. Most commonly supported signing algorithm: rsa-sha256.

#### SAML Parties vs Organizations

Most common SAML use cases are business-to-business (B2B): two parties w/ different security policies, practices, risk tolerances. Guidance focuses mainly on B2B. SAML federation/SSO also common inside one organization; there "third-party CA" doesn't apply: CA likely built/run to company standards, poses no more/less risk to SAML systems. "Third-party CA" = private CA run by a third-party.

#### Certificate Use Cases

5 separate certificate use cases in SAML system. Document mainly covers IdP's SAML signing certificate; considerations apply to all four SAML-related certificates. Fifth, IdP's TLS server certificate, no more/less special than any other server certificate.

##### IdP SAML Signing

SP uses it to validate IdP's SAML response; IdP signs response w/ corresponding private key. Often most important certificate + private key: protects identity assertions sent to SP.

##### IdP SAML Encryption

Less common: used when SP wants to protect SAML request to IdP from information disclosure, not just tampering. SAML request should hold no sensitive info, hence rare. If used, certificate + private key must differ from SAML signing certificate's.

##### SP Signing

Best practice (not required): SPs and IdPs don't allow IdP Initiated SSO. Caller starts SAML flow at SP, producing signed SAML request for IdP.

##### SP Encryption

Best practice: avoid sensitive data in IdP's SAML response; sometimes unavoidable (usernames, other PII). When information disclosure matters, SP has SAML encryption certificate; IdP uses it + embedded public key to encrypt SAML response. SP must use separate certificate + key pair for SAML signing and encryption.

#### Certificate Contents

For SAML signing/encryption, X.509 certificates mostly treated as wrapper holding public key to verify signature or wrap symmetric key for SAML encryption. Certificates can still carry attributes enhancing security.

OWASP recommends IdPs and SPs adopt EKU, KU, key lifetimes below. Legitimately enhance security, let verifying party protect itself further, help show PKI-norm compliance.

##### Keys and Signing Algorithms

Key pair size/type and signing algorithm strongly affect security + interoperability. Not all IdP/SP software supports all combinations. One IdP often has many SPs → pick least secure option still considered secure. Most supported, currently secure combination: RSA 2048 bit keys + SHA-256 hashing/signing. Refers to certificate's signing algorithm, not SAML XML signature.

Post-quantum algorithms becoming prevalent, ultimately required → more complex. SAML SP/IdP software authors should begin looking at supporting more key + signing algorithms.

###### Keys

ECC keys much smaller yet more secure than RSA, faster math. Preferred when all parties can use them. ECC keys as low as 256 bit still secure. RSA more interoperable. Minimum RSA key size: 2048 bit.
At least one major vendor, Microsoft Entra, doesn't support ECC keys.

###### Signing Algorithms

Public key signing: data hashed w/ chosen algorithm, hash signed w/ private key.

No IdP should use SHA-1 as certificate signing hash. SHA-256 = minimum. If possible move to larger hashes like SHA-384 or SHA-512 for future-proofing. Refers to certificate's signing algorithm, not SAML response XML signature.

##### Certificate Lifetime

X.509 certificates contain `notBefore` and `notAfter` validity dates (RFC 5280, section 4.1.2.5). Plan certificate replacement before expiry; don't ignore validity period. Choose signing key's usage period by its protection, use, threat model; see [Cryptoperiods and Rotation](Key_Management.md#cryptoperiods-and-rotation). NIST SP 800-57 Part 1 Rev. 5, Section 5.3.4 distinguishes certificate validity from key usage periods: renewing certificate w/ same public key doesn't rotate private key or restart its usage period.

##### Extended Key Usage (EKU) and Key Usage (KU)

EKU (RFC 5280 section 4.2.1.12) describes specific intended use case: server authentication, client authentication, code signing; not appropriate for SAML signing. No widely accepted EKU for SAML signing, but RFC 9336 defines ideal one, id-kp-documentSigning (1.3.6.1.5.5.7.3.36). IdPs and SPs may consider standardizing on it.

KU (RFC 5280 section 4.2.1.3) describes underlying cryptographic operations private key is meant for: digitalSignature, nonRepudiation, keyEncipherment, etc. IdPs and SPs may consider requiring digitalSignature and disallowing certificates w/ other KUs; certificates should serve one use case only. E.g. IdP's TLS server certificate must never be SAML signing certificate.

##### CRL Distribution Point (CDP)

Certificate Revocation List (CRL) Distribution Point (RFC 5280 section 4.2.1.13): list of certificates CA says should no longer be trusted. Mostly delivered over HTTP; CRL URLs generally embedded in each CA-issued certificate. CRL (RFC 5280 appendix C.4) signed by CA → MITM against HTTP can't harm list integrity beyond tampering (thus invalidating it); attacker can't alter it. Only CA-signed certificates can have CRL. If SAML certificate lists CRL, it should be reachable by validating party, which should validate it (RFC 5280 section 6.3).

Given risk if private key compromised and smaller scale of IdP-SP relationships, SAML parties should establish plan w/ contact lists to notify + rotate certificates rapidly in incident. Many SAML products/libraries don't support revocation checking; simply revoking certificate w/o coordinated replacement = outage.

##### Online Certificate Status Protocol (OCSP)

OCSP (RFC 6960): another revocation check. OCSP URL embedded in certificate like CRL, should be reachable over HTTP. Response signed → MITM not integrity concern. OCSP increasingly disfavored: privacy concerns, caller's IP address and used certificate disclosed. Less concern for SAML (no destination website disclosed); overall use has declined. If OCSP URL present on any certificate in chain, use it to check revocation.

#### Certificate Hierarchy

SAML signing certificate can be self-signed, public CA signed, or private CA signed. Each has pros/cons; given current WebPKI (public) and private PKI state, self-signed SAML certificates are clear winner when proper precautions taken for exchanging certificates.

##### Certificate Issuer

All X.509 certificates signed, using private key, by authority known as Issuer (RFC 5280 section 4.1.2.4). May be CA or, for self-signed certificate, certificate's own private key. CA-signed: signer may also have certificate w/ Issuer, etc. This chain/path (RFC 5280 section 3.2) should terminate in Root CA (self-signed by definition). Inspect issuer. If issuer is CA, validate its attributes (EKU, KU, CRLs). Do this for each certificate in path to root.

##### Public Certificate Authority (CA) Signed

Public CA issues certificate per its rules + CA Browser Forum (CABF) rules. Public root CAs bundled in trust stores maintained by major browser vendors. Most of web trusts these.

IdP rotates SAML Signing certificate → each SP must simultaneously update explicit trust. Challenging with few SPs, nearly impossible with many. This pain led to SAML signing certificates with longest possible lifetimes: once two years with public CAs, then 398 days. WebPKI standards/CABF focus on TLS server certificates. Ongoing lifetime reductions make Public CA certificates less appealing: CABF has path to public CA certificates lasting only 47 days (ballot SC-081v3). IdP must get certificate, announce change for reasonable time, execute change → IdPs and SPs perpetually updating certificates.

CABF doesn't govern use/acquisition of SAML certificates; certificates from its member CAs are what's widely considered Public CAs: widely trusted by browsers, operating systems, development frameworks.

Public CA signed certificates allow revocation checking, can increase security, but if certificate exchange not secured, false sense of security.

##### Private CA Signed

Most IdPs and SPs treat X.509 certificates as explicit trust → private CAs/PKI usable. Private CA design, build, operation vary wildly; running CAs well very costly. Trusting third-party CAs requires clear understanding of CA lifecycle. Two audit types cover this, both very costly on top of building/running CAs. Third-party CAs relied on should be WebTrust, ETSI, or SOC 2 Type II audited.

Improperly trusting third-party CAs can cause unintended over-trust (TLS, code signing). If trusted, trust only for IdP signature validation.

Private CA-issued signing certificates must not extend beyond signing key's approved usage period. Apply [same lifetime and rotation policy](#certificate-lifetime) to CA-issued and self-signed signing certificates.

##### Self-Signed

SAML security associations mostly explicit → self-signed certificates ideal. Contents and lifetime unconstrained by issuing CA policy/process, public or private. SAML certificate rotation painful, labor intensive → set certificate lifetime as long as safely possible. Few CAs allow long enough lifetimes (TLS threat model focus).

###### Creating a Self-Signed SAML Certificate

Using Hardware Security Module (HSM): follow vendor instructions. Process below uses openssl. Example distinguished name overly generic; Common Name (CN) should be meaningful + specific.

1. Generate a Private Key:
openssl genrsa -out private.key 2048
or
openssl ecparam -genkey -name prime256v1 -out private.pem

2. Create a Configuration File (e.g., cert.cnf):

\[req\]
distinguished_name = req_distinguished_name
x509_extensions = v3_ca
prompt = no

\[req_distinguished_name\]
C = US
ST = California
L = San Francisco
O = MyOrganization
OU = MyUnit
CN = SAML Signing

\[v3_ca\]
basicConstraints = CA:FALSE
keyUsage = digitalSignature
extendedKeyUsage = 1.3.6.1.5.5.7.3.36

3. Generate the Self-Signed Certificate:
openssl req -x509 -new -nodes -key private.key -sha256 -days 365 -out certificate.crt -config cert.cnf -extensions v3_ca

#### Certificate Metadata URLs

Many IdPs publish metadata URL w/ basic configuration incl. SAML signing certificate. Many SPs consume it, updating Signing certificate info near real-time. Ideal; matches intent of Certificate and Public Key Pinning when pinning must be used.

Protect metadata URL w/ TLS; server certificate from widely trusted WebPKI CA, matching guidance in [Transport Layer Security Cheat Sheet](Transport_Layer_Security.md#certificates).

Ideal IdP-SP relationship uses metadata URLs regardless of certificate type. Without them, take great care an attacker can't convince SP to trust wrong certificate. Avoid emailing certificates; present over properly configured TLS, like metadata URL.

#### Signing Key Protection

SAML Signing keys = top security asset and target of attackers (Storm-0558). Take great care creating keys and copying to IdP cluster nodes. File-based keys trivial for attacker with access to exfiltrate. IdP operators should strongly consider protecting private keys with Hardware Security Module (HSM): application uses key w/o it being exportable/copyable; keys safely replicate into failover HSM, never exposed outside HSMs. Quality HSMs rated FIPS 140-2 or FIPS 140-3.

### Identity Provider (IdP) Considerations

- Validate X.509 Certificate for algorithm compatibility, encryption strength, export restrictions, content above
- Validate Strong Authentication options for generating SAML token
- IDP validation (which IDP mints token)
- Synchronize to common Internet timesource
- Define levels of assurance for identity verification
- Prefer asymmetric identifiers for identity assertions over personally identifiable information (e.g. SSNs, etc)
- Sign each individual Assertion or entire Response element

### Service Provider (SP) Considerations

- Validating session state for user
- Level of granularity setting authorization context when consuming SAML token (groups, roles, attributes?)
- Ensure each Assertion or entire Response element signed
- [Validate Signatures](#validate-signatures)
- Validate signed by authorized IdP
- Validate IDP certificates for revocation against CRL/OCSP if present
- Validate `Destination` attribute on `<samlp:Response>` exactly matches SP's expected Assertion Consumer Service (ACS) URL (SAML Core 2.0 §3.2.2.1). Reject responses missing `Destination` or mismatching; prevents cross-SP assertion replay.
- Validate `<saml:Audience>` matches SP's EntityID
- Validate NotBefore and NotOnorAfter
- Validate Recipient attribute, `InResponseTo`, `<saml:SubjectConfirmationData>` (`Recipient`, `NotOnOrAfter`, `InResponseTo`)
- Explicitly verify signature algorithm at least RSA-SHA-256 (or stronger). Reject SHA-1-based algorithms (`http://www.w3.org/2000/09/xmldsig#rsa-sha1`, `...#hmac-sha1`) and `<ds:DigestMethod Algorithm="...sha1">`. NIST SP 800-131A Rev. 2 disallows SHA-1 in digital signatures.
- Verify XML signature's `<ds:Reference URI>` resolves to signed Assertion or Response, and exact assertion used for authentication is protected by that validated signature. SAML Core sections 5.3 and 5.4 define signature inheritance/references; approved errata E93 permits Response signatures in browser SSO profile. Reject assertions outside validated signed content; follow [signature-wrapping defenses](#validate-signatures).
- Define criteria for SAML logout
- Exchange assertions only over secure transports like TLS
- Define criteria for session management
- Verify user identities obtained from SAML ticket assertions whenever possible.

## Input Validation

SAML being security protocol doesn't remove need for input validation.

- Ensure all SAML providers/consumers do proper [input validation](Input_Validation.md).

## Cryptography

Cryptographic algorithm reliance must follow latest cryptoanalysis developments.

- Ensure all SAML elements in chain use [strong encryption](Cryptographic_Storage.md#algorithms)
- Consider deprecating support for insecure XMLEnc algorithms

## References

- OASIS: Security and Privacy Considerations for SAML 2.0
- OASIS: Assertions and Protocols for SAML 2.0
- OASIS: Profiles for SAML 2.0
