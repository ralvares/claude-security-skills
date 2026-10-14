# JSON Web Token Cheat Sheet

## Introduction

Tips to prevent common security issues when using JSON Web Tokens (JWT).

**JSON Web Tokens** (JWT, RFC 7519) = security tokens carrying information (**claims**), often about user, application, etc. (**subject**). JWTs provide authenticity of claims (**signed JWT**) and/or confidentiality (**encrypted JWT**). JWT also defines standard claims (IANA registry).

Uses:

- OpenID Connect: ID token = JWT representing identity + attributes of connected user.
- OAuth 2: access token for protected resource can be a JWT (RFC 9068).
- "Stateless" user sessions: often suggested, but frowned upon.
- DPoP Proof JWT: prove possession of private key.
- SPIFFE: JWT-SVID authenticates a workload.

Most common form (signed JWT): generating application (**issuer**) protects info w/ signature against tampering. Signature prevents attackers (e.g. malicious client/user) forging token or modifying claims in existing token, e.g. changing role from user to admin or altering client's login. JWT = protected identity card/certificate about user, application, etc. Application (**presenter**) presents token to consuming application (**audience**), which verifies authenticity + validity, decides/acts based on claims.

JWT can also provide claim confidentiality (encrypted JWT). Encryption only briefly introduced in [Token Confidentiality and JWE](#token-confidentiality-and-jwe); much of this sheet also applies to encrypted JWTs.

## Token Structure

Signed JWT structure:

```
{base64url(json(header))}.{base64url(json(claims))}.{base64url(signature)}
```

Elements:

- **Protected Header:** info about token such as token type (IANA media type), cryptographic algorithms protecting token.
- **Claims:** content = list of claims (usually about subject). Standard claims: JWT IANA Registry.
- **Signature:** public-key digital signature (public/private key pair) or MAC (shared secret). Protects both protected headers and claims.

### Example

Example (taken from JWT.IO):

```text
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiYWRtaW4iOnRydWUsImlhdCI6MTUxNjIzOTAyMn0.KMUFsIDTnFmyG3nMiGM6H9FNFUROf3wh7SmqJp-QV30
```

First part (**protected header**, RFC 7515 section 4) decodes to:

```json
{
  "alg": "HS256",
  "typ": "JWT"
}
```

Second part (**claims**, RFC 7519 section 4) decodes to:

```json
{
  "sub": "1234567890",
  "name": "John Doe",
  "admin": true,
  "iat": 1516239022
}
```

Last part (**signature**) guarantees authenticity of header + claims, via public/private key pair (digital signature) or shared secret (MAC), depending on `alg` header value. Example computed as:

```javascript
base64url(
    HMACSHA256(
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
        + "."
        + "eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiYWRtaW4iOnRydWUsImlhdCI6MTUxNjIzOTAyMn0",
        key
    )
)
```

## Considerations about using JWTs

### Not using JWTs

Consider whether JWTs are really necessary for use case.

JWTs often suggested for "stateless" user sessions. But JWT sessions need session invalidation solution, e.g. deny list of revoked sessions/tokens. Deny list → sessions no longer fully stateless, may defeat benefits. Consider plain session system following [session management cheat sheet](Session_Management.md).

### Public-key Signatures vs. MAC

Signed JWT authenticated via digital signature or MAC:

- **Digital signature:** issuer signs w/ private key; audience verifies w/ associated public key. Private key known only to issuer; public key can be public.
- **MAC:** shared secret between issuer and audience. *Same* secret used by issuer to generate token and audience to verify.

Credential management differs.

Digital signature:

- Issuer can reuse same public key for many audiences.
- Audience needs only public information to validate → no risk of secret leakage by audience.
- Public key needn't be secret → easily distributed (e.g. publish at public HTTPS URI).
- Simpler key rotation.
- Traditional digital signature schemes might be broken by post quantum computers in future (RFC 9958); would need replacement w/ post-quantum schemes, which are heavier than traditional ones.

MAC:

- Different secret MUST be used for each (issuer, audience) pair. E.g. same secret reused for different audiences → one audience can forge token (impersonating issuer).
- Secret keys obviously never published at public HTTPS URI. Need solution for secret distribution + rotation.
- MAC much faster than digital signatures (usually negligible in practice).

MAC may suit:

- Issuer is sole audience. Even then, digital signature may be easier for secret rotation/distribution.
- Issuer is the audience. No secret rotation/distribution problem.

### Public-key Signatures

| Signature scheme      | Identifier                      | Type         | Status
|-----------------------|---------------------------------|--------------|---------
| EdDSA                 | EdDSA, Ed448, Ed25519           | Traditional  | Recommended, limited support
| ECDSA                 | ES256, ES384, ES512             | Traditional  | Recommended
| RSASSA-PSS            | PS256, PS384, PS512             | Traditional  | Recommended
| RSASSA-PKCS1-v1_5     | RS256, RS384, RS512             | Traditional  | Not recommended
| Hybrid ML-DSA / EdDSA | ML-DSA-44-Ed25519, etc.         | PQ/T hybrid  | Draft
| Hybrid ML-DSA / ECDSA | ML-DSA-44-ES256, etc.           | PQ/T hybrid  | Draft
| ML-DSA                | ML-DSA-44, ML-DSA-65, ML-DSA-87 | Post-quantum | Very limited support at best

Notes:

- EdDSA support in JWT implementations currently limited.
- ECDSA signature generation may be dangerous on embedded systems w/ problematic randomness quality. Then implementation must use deterministic ECDA per RFC 6979.
- Post-quantum signatures (ML-DSA, RFC 9964) or hybrid post quantum signatures resist quantum computers but produce very large signatures → very large JWTs. Probably not justified now unless signatures need long validity.

Key management:

- Don't reuse key pair for another purpose (e.g. encryption).
- Same key for authenticating different JWT types fine if no risk of token type confusion.
- Don't publish private key!

#### MAC

| Signature scheme      | Identifier                      | Status
|-----------------------|---------------------------------|---------------
| HMAC with SHA-2       | HS256, HS384, HS512             | Recommended

Secret management:

- Don't reuse same secret for another purpose (e.g. encryption).
- Same key for authenticating different JWT types fine if no risk of token type confusion.
- Don't reuse same secret with another audience.
- Don't reuse same secret with another issuer.
- Don't use password as MAC secret.
- Secret MUST be generated by local, cryptographically secure secret generator.
- Secret MUST be at least same size as output (e.g. 256, 384 and 512 bits respectively for HS256, HS384 and HS512).
- Don't publish secret key!
- Secret MUST have at least 160 bits of entropy.
- HMAC: secret should be at least as long as output size (RFC 2104 section 3).

Valid HMAC secret generation example:

```python
import secrets
secret_for_hs256 = secrets.token_bytes(256//8)
secret_for_hs512 = secrets.token_bytes(512//8)
```

Invalid HMAC secret generation:

```python
import random
import secrets

# Using a password/passphrase is not OK:
bad_secret = b"MyProject2026"

# Using a hardcoded secret is not OK:
bad_secret = urlsafe_b64decode(b'KYkbbclxtjJMiHzoPvuahOfarej0VV-nQZPFxK0hyro=')

# Not a secure randomness source:
bad_secret = random.randbytes(256//8)

# Not enough entropy:
bad_secret = secrets.token_bytes(128//8)

# Not enough entropy for HS512
meh_secret_for_hs512 = secrets.token_bytes(256//8)
```

### Header fields

Important JWT (JOSE) header parameters for security:

| Parameter       | Semantic                               | Security impact
|-----------------|----------------------------------------|----------------
| `alg`           | Signature algorithm                    | Signature algorithm used, risk of key type confusion
| `typ`           | Media type                             | Protection against token type confusion
| `jku`           | Verification key (URL to the JWK)      | Risk of untrusted key usage, risk or SSRF
| `x5u`           | Verification key (URL to certificate)  | Risk of untrusted key usage, risk or SSRF
| `jwk`           | Verification key (JWK)                 | Risk of untrusted key usage
| `kid`           | Verification key (key ID)              | Risk of untrusted key usage
| `x5c`           | Verification key (certificate chain)   | Risk of untrusted key usage
| `x5t`           | Verification key (certificate hash)    | Risk of untrusted key usage
| `x5t#S256`      | Verification key (certificate hash)    | Risk of untrusted key usage

Standard JWT (JOSE) header parameters: header parameters subregistry.

### Claims

Important JWT claims for security:

| Parameter       | Semantic                               | Security impact
|-----------------|----------------------------------------|----------------
| `exp`           | Expiration                             | Token validity
| `nbf`           | Not valid before                       | Token validity
| `status`        | Reference to token status list         | Token revocation, risk of SSRF
| `iss`           | Issuer                                 | Scoping of claims (eg. `iss`), risk of untrusted issuer, risk of SSRF
| `aud`           | Audience                               | Protection against audience confusion
| `sub`, `sub_id` | Subject identifier                     | Subject/user identification, risk of cross-issuer user impersonation
| `jti`           | Token identifier                       | Audit (logs)
| `iat`           | Issuance timestamp                     | Audit (logs)
| `azp`           | Authorized Party (OIDC)                | Audit (logs), authorization
| `client_id`     | Client (OAuth 2)                       | Audit (logs), authorization
| `auth_time`     | Authentication timestamp (OIDC)        | Enforcing authentication freshness
| `acr`           | Authentication class                   | Enforcing authentication strength (eg. MFA)
| `amr`           | Authentication method reference        | Enforcing authentication strength (eg. MFA)
| `cnf`           | Token holder (public) key              | Sender constrained token
| `may_act`       | Authorized Actor (impersonation/delegation) | Risk of cross-issuer user impersonation
| `act`           | Actor (delegation, "on behalf of")     | Audit (logs), risk of invalid actor imputation
| `scope`         | Token restriction (OAuth 2)            | Authorization
| `roles`         | User roles                             | Authorization, risk of spoofed cross-issuer authorization
| `groups`        | User groups                            | Authorization, risk of spoofed cross-issuer authorization
| `entitlements`  | User entitlements                      | Authorization, risk of spoofed cross-issuer authorization
| `authorization_details` | Fine grained authorizations    | Authorization, risk of spoofed cross-issuer authorization

Standard JWT claims: JSON Web Token Claims subregistry.

Many implementations have built-in validation of core claims `nbf`, `exp`, `iss`, `aud`.

## Threats on JWTs

Threats/vulnerabilities discussion: RFC 8725.

### Unsecured JWTs

Some JWT libraries used to accept unsecured JWTs by default (`"alg":"none"`). Attacker forges own JWTs: may impersonate arbitrary users, obtain arbitrary authorizations, etc. Should now be fixed in libraries.

Mitigation:

- Ensure JWT parser doesn't accept `"alg":"none"`. Recent implementations disable by default.

### Key type confusion

Some JWT implementations accept public key meant for digital signature as secret key for MAC verification → attacker forges MAC-based JWT using real issuer's public key as secret key.

Also called "key confusion" or "algorithm confusion".

Legitimate token issuance:

```python
token = jwt.encode(claims, private_key_bytes, algorithm="ES256")
```

Attacker forging token via key type confusion:

```python
token = jwt.encode(claims, public_key_bytes, algorithm="HS256")
```

Validation potentially vulnerable to key type confusion:

```python
# If the token is using a MAC, the library might interpret the public key bytes as a MAC secret:
decoded = jwt.decode(token, public_key_bytes, algorithms=jwt.algorithms.get_default_algorithms())
```

Note: mitigated in recent PyJWT versions by detecting whether MAC key appears to be public key (PEM or SSH format).

Mitigations (at validation):

- use library not vulnerable (e.g. strong-typing of key type);
- choose key per requested signature algorithm, or validate key consistent w/ signature algorithm;
- if possible, hardcode accepted algorithms; don't mix public-key signature algorithms and MAC algorithms.

Not vulnerable because MAC algorithms not accepted:

```python
decoded = jwt.decode(token, public_key_bytes, algorithms=["ES256"])
```

Illustrative signature verification using joserfc typed key import and trusted EC public key. Claim validation still required before accepting token. Replace example key w/ issuer's trusted public key; `encoded` = received token string.

```python
from joserfc import jwt, jwk

public_jwk = {
    "kty": "EC",
    "crv": "P-256",
    "x": "f83OJ3D2xF1Bg8vub9tLe1gHMzV76e8Tus9uPHvRVEU",
    "y": "x_FEzRu9m36HLN_tue659LNpXW6pCyStikYjKIWI5a0",
}
public_key = jwk.import_key(public_jwk)
decoded = jwt.decode(encoded, public_key, algorithms=["ES256"])
```

References:

- Algorithm confusion attacks;
- CVE-2022-29217, Key confusion through non-blocklisted public key formats (PyJWT);
- CVE-2023-48223, JWT Algorithm Confusion in fast-jwt.

### Trusting key material named in the token header

JWS header can carry verification key or pointer: `jwk` (embedded key), `jku` (URL to JWK Set), `x5u` (URL to X.509 certificate), `x5c` (embedded certificate chain), plus key selection hints `kid`, `x5t`, `x5t#S256`. Application resolving/selecting verification key from these, w/o tying result to something already trusted, can be steered into trusting attacker-controlled key: header = unauthenticated attacker input.

Attacker forges token, includes own public key in `jwk`, or points `jku`/`x5u` at attacker-hosted JWK Set/certificate, signs w/ matching private key. Verifier trusting key just read from token accepts forgery. Attacker may also smuggle symmetric key via same parameters hoping implementation uses it for MAC verification.

Parameters have legitimate uses → distinction is anchoring, not avoidance. `x5c`, `x5u` usable where certificate chain validates up to anchor already trusted for that issuer; `kid`, `x5t`, `x5t#S256` = normal way to choose which key from already configured JWKS verifies a token. Must not treat any as source of trust rather than pointer within it.

Mitigations:

- Don't take verification key from token unless key tied, via chain of trust, to root trust anchor associated w/ issuer.
- Prefer out-of-band trust material, e.g. pinned key or `jwks_uri` published in issuer's metadata.
- Validate/sanitize `kid` before lookup: also reaches databases/directories as injection vector.
- Keys fetched by URL: see [Server Side Request Forgery Prevention Cheat Sheet](Server_Side_Request_Forgery_Prevention.md).

References:

- RFC 8725, Do Not Trust Received Claims;
- CVE-2018-0114, key embedded in JWS header trusted for verification.

### Issuer and audience confusion

JWT typically carries `iss` (issuer) = who created it, `aud` (audience) = which party should consume/validate it. Neither mandatory; some designs omit one deliberately: token app issues and consumes itself under key used for nothing else, or SD-JWT whose audience established by accompanying key binding JWT rather than `aud`. But where a key speaks for more than one issuer or recipient, verifier checking only signature + expiration accepts any token that key signed, whatever `iss`/`aud`. Attacker holding such token (legitimately issued to them or obtained from service they control) may replay against different recipient. RFC 8725 calls this substitution attack.

Two variants, defeated by different checks.

**Audience confusion.** Attacker presents token issued for one service to second service trusting same issuer. Second service not requiring own identifier in `aud` → token accepted. E.g. token minted for low-privilege service replayed against internal API → access never granted. Another axis: third-party app legitimately receiving tokens for own use replays one against another application (first- or third-party), reaching data/operations never granted.

**Issuer confusion.** Attacker presents token from different issuer verifier also trusts, e.g. partner tenant or self-service account at public identity provider. Comparing `iss` string alone doesn't stop this if verifier resolves verification key independently of `iss`. Verifier looking up key by `kid` across union of several trusted issuers' JWK Sets accepts token whose `iss` names one issuer and `kid` names another's key: signature verifies against key `kid` selected; `iss` and `aud` comparisons pass because attacker set both to expected values. No key theft needed; deployment needn't be multi-tenant.

Mitigations:

- Validate `iss` against what deployment trusts: case-sensitive comparison of whole string incl. scheme and path. Single expected issuer → equality check. Dynamically provisioned issuers (e.g. discovery protocol) → membership of explicit allowlist of issuer identifiers, not acceptance of whatever `iss` token presents.
- Select verification key from set bound to validated `iss`, e.g. that issuer's `jwks_uri`; never verify against union of keys from several issuers. Multi-tenant: resolve key set from allowlist keyed by issuer, not by searching every tenant's keys.
- Validate recipient's own identifier present in `aud`, whether `aud` is single string or array of strings.
- Where deployment relies on these claims, reject tokens missing `iss` or `aud`. RFC 7519 makes both optional → deployment decision, not spec requirement: verifier w/o `iss` has nothing to bind key to; w/o `aud` can't tell if token meant for it; but profile establishing either by other means doesn't need the claim.

Related case, key material taken from token rather than merely selected by it: [Trusting key material named in the token header](#trusting-key-material-named-in-the-token-header). Where verification uses MAC, see also secret reuse points under [MAC](#mac).

Strict validation in Python w/ PyJWT, resolving key from expected issuer's JWK Set rather than accepting independently supplied one:

```python
import jwt

ISSUER = "https://auth.example.com/"
AUDIENCE = "https://api.example.com/v1/payments"

# Keys come from this issuer's JWK Set only (its published jwks_uri),
# so a `kid` naming a key of some other trusted issuer cannot verify
# this token.
jwks_client = jwt.PyJWKClient("https://auth.example.com/.well-known/jwks.json")
signing_key = jwks_client.get_signing_key_from_jwt(token)

decoded_payload = jwt.decode(
    token,
    signing_key,
    algorithms=["ES256"],
    issuer=ISSUER,
    audience=AUDIENCE,
    options={"require": ["exp", "iss", "aud"]},
)
```

Note: PyJWT `issuer`/`audience` arguments perform validation. `verify_iss`/`verify_aud` options enabled by default but gate checks that do nothing alone → token checked against expected issuer/audience only when those arguments passed.

References:

- RFC 8725, Substitution Attacks;
- RFC 8725, Validate Issuer and Subject;
- RFC 8725, Use and Validate Audience;
- RFC 7519, "iss" (Issuer) Claim;
- RFC 7519, "aud" (Audience) Claim.

### Cross-JWT and token type confusion

Cross-JWT (token type) confusion: validation rules fail to distinguish token kinds, so token issued for one purpose (e.g. ID or password-reset token) accepted as another (e.g. access token). Overlapping claims or shared signing keys common enablers (RFC 8725 section 2.8).

Mitigations:

- **Use explicit typing (`typ`):** set `typ` header to specific media type distinguishing token purpose, e.g. `"at+jwt"` for OAuth 2.0 access tokens (RFC 9068), `"logout+jwt"` for logout tokens (OpenID Connect Back-Channel Logout 1.0 section 2.4), or custom types (e.g., `example-reset+jwt`) for internal tokens.
- **Validate `typ` at verifier:** for token profiles requiring/reliably providing explicit typing, reject tokens w/ missing or unexpected `typ` at that endpoint. `typ` is case-insensitive; `application/` prefix may be omitted (RFC 7515 section 4.1.9).
- **Use mutually exclusive validation rules:** where explicit typing can't be enforced interoperably (e.g., standard OIDC ID tokens omitting `typ`), distinguish token kinds via separate signing keys, required claims, or strict **`iss` and `aud` isolation** (RFC 8725 section 3.12).

Validation enforcing explicit token type:

```python
import jwt

# Verify signature and standard claims first
decoded = jwt.decode_complete(
    token,
    public_key,
    algorithms=["ES256"],
    audience="https://api.example.com",
    issuer="https://auth.example.com",
    options={"require": ["exp", "iss", "aud"]},
)

# Enforce explicit token type from the verified header
typ = str(decoded["header"].get("typ", "")).lower()
if typ not in ["at+jwt", "application/at+jwt"]:
    raise jwt.InvalidTokenError("Invalid token type: expected at+jwt")
```

References:

- RFC 8725 §3.11, Use Explicit Typing;
- RFC 8725 §3.12, Use Mutually Exclusive Validation Rules for Different Kinds of JWTs;
- RFC 9068, JSON Web Token (JWT) Profile for OAuth 2.0 Access Tokens.

## JWT revocation

### Token Status List

Issuer-side JWT revocation needed → use Token Status Lists (TSL):

- JWT contains URI of a TSL;
- TSL aggregates revocation status of several tokens in compressed form;
- token consumer fetches TSL to get JWT's revocation status.

Issuer includes `status` claim in JWT: URI of associated TSL + index of JWT's status within list:

```json
{
    "iss": "https://issuer.example/",
    "sub": "NsxuACbpJ9N7Ix96aWrYxHX-EZ4",
    "iat": 1783635268,
    "nbf": 1783635268,
    "exp": 1783653268,
    "status": {
        "status_list": {
            "idx": 6,
            "uri": "https://issuer.example/tsl/JAffke55FR5gtJQ_rtktWkSaTlI"
        }
    }
}
```

## Replay protection

### JWT denylist

Token consumer might maintain JWT denylist, e.g. as simple JWT replay protection or workaround for "stateless session" invalidation problem.

Deny list typically based on `jti` and `iss` claims:

```python
def revoke_token(claims):
    jti = claims.get("jti")
    iss = claims.get("iss")
    exp = claims.get("exp")
    deny_list.insert((jti, iss), exp)

def is_token_revoked(claims) -> bool:
    jti = claims.get("jti")
    iss = claims.get("iss")
    return deny_list.contains((jti, iss))
```

Other claims might suit better depending on application and JWT type.

**Warning:** Raw JWT or secure hash of JWT (`SHA-256(token)`) as denylist key is *not safe*; may expose application to **denylist bypass through JWT malleability**. Attacker holding revoked JWT might modify an alternative representation that still passes signature verification:

- because of non-strict JWT parsing by implementation;
- for ECDSA JWTs, because of ECDSA signature malleability.

```python
# Not secure. Might be vulnerable to JWT malleability:
def unsafe_revoke_token(claims):
    exp = claims.get("exp")
    token_hash = hashlib.sha256(token.encode("utf-8")).digest()
    deny_list.insert(token_hash, exp)
```

Before implementing denylist, consider better solutions:

- Token Status List: scalable issuer-side revocation.
- Freshness/replay protection often via `nonce` bound to session in JWT claims (used in OpenID Connect).
- Token reuse mitigated by short JWT expiration time.
- Sender-constrained access tokens, e.g. DPoP-bound tokens or mutual-TLS certificate-bound tokens (RFC 8705 section 3), limit attacker's ability to use stolen token w/o associated private key. Don't prevent token disclosure. Protect tokens and keys, use HTTPS, prevent untrusted code from using client's signing key.

## Token Confidentiality and JWE

### Signed JWTs are not confidential

Signed JWT (JSON Web Signature, JWS) gives integrity + authenticity, not confidentiality. Payload only base64url encoded, not encrypted → anyone obtaining token reads every claim. With MAC (`HS*`), valid signature only proves token produced by some holder of shared secret, see [Public-key Signatures vs. MAC](#public-key-signatures-vs-mac).

TLS prevents reading in transit, but claims remain exposed elsewhere: application logs, browser storage, referrer headers, any intermediary terminating TLS.

Omitting privacy-sensitive info from JWT = simplest way to minimize privacy issues (RFC 7519 section 12). Prefer keeping sensitive data server-side behind opaque reference token. Use JWE only when claims must travel with token to party that can't resolve them with issuer.

### Using JWE

Claims must stay confidential → use JSON Web Encryption (JWE, RFC 7516). JWE uses two algorithms:

- **`alg`:** key management algorithm; encrypts or agrees upon (RFC 7518 section 4.1) Content Encryption Key (CEK) for intended recipient (e.g. `RSA-OAEP-256` or `ECDH-ES+A256KW`).
- **`enc`:** content encryption algorithm; encrypts payload using authenticated encryption (e.g. `A256GCM`).

JWE gives confidentiality + ciphertext integrity, **not** issuer authentication. With public-key `alg`, anyone holding recipient's public key can produce token that decrypts successfully → never make authorization decisions on claims from unsigned JWE.

Need both authenticity and confidentiality → **nested JWT**: sign claims first (JWS), then encrypt result (JWE). Prevents attacks where signature stripped leaving just encrypted message, and provides privacy for signer (RFC 7519 section 11.2). In outer JWE, `cty` header MUST be set to `JWT` to signal nesting (RFC 7519 section 5.2).

Consuming nested JWT: decrypt outer JWE **and** verify inner JWS signature; reject token if either fails. Both outer and inner operations MUST be validated (RFC 8725 section 3.3): successful decryption alone proves nothing about who issued claims.

Two further JWE requirements:

- Accept only allowlisted `alg`/`enc` pair; bind each key to single algorithm. Never let token header select algorithm: enables downgrade attack that can recover CEK (RFC 7516 section 11.4).
- Don't compress claims before encryption (`zip` header): compressed data often reveals info about plaintext (RFC 8725 section 3.6).

**Note:**

Full JWE implementation guidance out of scope; to be addressed in dedicated JWE cheat sheet.

## References

- RFC 7519: JSON Web Token
- RFC 8725: JSON Web Token Best Current Practices
- RFC 7516: JSON Web Encryption
- RFC 7517: JSON Web Key
