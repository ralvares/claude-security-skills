# OAuth 2.0 Protocol Cheatsheet

Best current security practices for OAuth 2.0 (RFC 6749). OAuth = standard for API protection, basis for federated login via OpenID Connect. OpenID Connect 1.0 = simple identity layer on OAuth 2.0: clients verify end-user identity from authorization server authentication, get basic profile info interoperably, REST-like.

**Note:** OAuth 2.0 supports different token types. **Bearer tokens** (RFC 6750): simple, widely adopted. **Proof of Possession (PoP) tokens**: advanced security via cryptographic token-client binding. Choose per security requirements, threat model, implementation constraints.

## Terminology

- **Client**: app making protected resource requests on behalf of resource owner, w/ its authorization. No implied implementation (server, desktop, other devices).
- **Authorization Server (AS)**: issues access tokens to client after authenticating resource owner and obtaining consent.
- **Resource Owner (RO)**: entity able to grant access to protected resource. Person = end user; can also be organization or system.
- **Resource Server (RS)**: hosts protected resources; accepts/responds to protected resource requests using access tokens.

- **Access Tokens**: abstraction replacing authorization constructs (e.g., username + password, assertion) w/ single token RS understands. Enables short-lived tokens; RS needs no wide range of authentication schemes. Most common: **bearer token** (RFC 6750), easy to implement/integrate, only token value needed for API access. Anyone holding bearer token can use it → audience-restrict, preferably to single Resource Server, to limit leakage impact.
- **Refresh Tokens**: credentials issued to client by AS to get new access token when current one invalid/expired, or additional access tokens w/ identical or narrower scope (access tokens may have shorter lifetime, fewer permissions than RO authorized). Protect refresh tokens w/ sender-constraining (DPoP or mTLS) or refresh token rotation.

- **Proof of Possession (PoP) tokens**: access/refresh tokens cryptographically bound to clients via DPoP (RFC 9449) or mTLS-bound access tokens (RFC 8705). Bound to client-owned private key; client must demonstrate possession to use token. Extra protection where token interception is concern; needs key management + proof generation.

## OAuth 2.0 Essential Basics

1. Clients and Authorization Server must not expose URLs forwarding user's browser to arbitrary URIs from query parameter ("open redirectors"): enables exfiltration of authorization codes + access tokens.
2. Clients ensuring AS supports PKCE may rely on PKCE CSRF protection. OpenID Connect flows: "nonce" parameter gives CSRF protection. Otherwise must use one-time user CSRF tokens in "state" parameter, securely bound to user agent.
3. Client interacting with more than one AS: use issuer "iss" parameter as countermeasure, or "iss" value in authorization response (e.g., "iss" Claim in OpenID ID Token).
4. Absent other mix-up countermeasure options for clients interacting with more than one AS, clients may use distinct redirect URIs to identify authorization endpoints and token endpoints.
5. AS avoids forwarding/redirecting request possibly containing user credentials accidentally.

## PKCE - Proof Key for Code Exchange Mechanism

OAuth 2.0 public clients using Authorization Code Grant are susceptible to authorization code interception attack. Proof Key for Code Exchange (PKCE, pronounced "pixy") mitigates it.

Originally intended only for native apps; now deployed OAuth feature. Protects against authorization code injection and codes created for public clients: attacker cannot redeem stolen authorization code at AS token endpoint w/o knowing code_verifier.

6. Clients prevent injection (replay) of authorization codes into authorization response using PKCE flow. Clients may instead use OpenID Connect "nonce" parameter + respective ID Token Claim. PKCE challenge or OpenID Connect "nonce" must be transaction-specific, securely bound to client and user agent where transaction started. **Note:** PKCE protects authorization codes; use sender-constrained tokens to protect access + refresh tokens.
7. With PKCE, clients should use code challenge methods not exposing PKCE verifier in authorization request. Otherwise attackers reading authorization request break PKCE security. Authorization servers must support PKCE.
8. Client sends valid PKCE "code_challenge" in authorization request → AS enforces correct "code_verifier" usage at token endpoint.
9. AS mitigates PKCE Downgrade Attacks: token request containing "code_verifier" accepted only if "code_challenge" present in authorization request.

## Implicit Grant (DEPRECATED — DO NOT USE)

Implicit Grant (`response_type=token`) **deprecated** by RFC 9700 §2.1.2, removed from OAuth 2.1. Exposes access tokens in URL fragment: retained in browser history, accessible to scripts on response page; tokens cannot be sender-constrained. Major identity providers disabled it or marked for removal.

10. Clients **must** use Authorization Code Grant w/ PKCE (`response_type=code`) for all client types, incl. SPAs + native apps. Existing Implicit Grant apps must migrate. Hybrid `code id_token` response type only when OpenID Connect ID Token required at authorization endpoint; access tokens must still come from token endpoint, never front channel.

## Token Replay Prevention

Token security critical. Sender-constrained tokens bind token to client. Proof of Possession (PoP) tokens = sender-constrained type using cryptographic binding via client-owned private key. Client must demonstrate private key possession on token use → client authentication at token usage level.

### PoP Mechanisms Comparison

**DPoP (Demonstration of Proof of Possession - RFC 9449):**

- Client generates public-private key pair. AS binds each DPoP access token to public key. JWT access tokens: AS represents binding w/ `cnf` (confirmation) claim holding JWK thumbprint (`jkt`), per RFC 9449 Section 6.1. Opaque tokens: RS gets same binding via token introspection. Each API request: client includes proof of private-key possession as JWT signed w/ private key, including hash of access token. RS validates access token + DPoP proof (incl. token hash) → request comes from legitimate token holder.
- No mutual TLS needed; proof via DPoP HTTP headers; suits browsers, mobile apps, other client types; extra cryptographic operations per request.

**Mutual TLS Certificate-Bound Access Tokens (RFC 8705):**

- Client authenticates w/ TLS client certificate during TLS handshake (mutual TLS, mTLS). AS binds access token to client certificate thumbprint via `cnf` claim. RS validates certificate presented in TLS handshake matches certificate bound to access token.
- Transport layer; uses existing TLS infrastructure; PKI or self-signed certificates; authentication at connection establishment; no per-request proof generation.

### When to Use PoP Tokens

Valuable where enhanced token security needed. Consider for:

- APIs where sender-constraining limits replay of leaked access token. Bearer and PoP tokens both should be audience-restricted, preferably to single RS
- APIs handling sensitive data (financial, healthcare, personal info, etc.) needing extra security layers
- High-value transactions (payments, critical operations, etc.) where cryptographic client binding adds assurance
- Long-lived tokens needing extra protection for extended validity
- Cross-organizational access (B2B integrations) spanning multiple security domains
- Mobile + native apps w/ extra client-environment security concerns
- Distributed architectures where tokens cross multiple network boundaries

Choose token security approach per application security requirements, existing infrastructure, client capabilities, operational resources.

11. For advanced protection against token replay, AS and RS may implement sender-constraining of access tokens, e.g. Mutual TLS for OAuth 2.0 (mTLS - RFC 8705) or Demonstration of Proof of Possession (DPoP - RFC 9449). Cryptographically bind tokens to specific clients via private-key possession proof.
12. Refresh tokens sender-constrained (DPoP or mTLS) or use refresh token rotation (issue new refresh tokens, invalidate old ones immediately → detect replay). **Note:** PoP-constrained refresh tokens + rotation = defense-in-depth.

## Access Token Privilege Restriction

13. Restrict access token privileges to minimum needed for application/use case. Prevents clients exceeding privileges RO authorized; prevents users exceeding privileges per security policy; reduces leakage impact. **Combine with sender-constrained tokens for defense-in-depth.**
14. Restrict access tokens to certain Resource Servers (audience restriction), preferably single RS. AS should associate access token with certain RSs; every RS obliged to verify, per request, token meant for that RS. If not, RS must refuse request. Clients and AS may use parameters "scope" and "resource" to determine target RS.
15. Restrict access tokens to certain resources + actions on RSs or resources. AS should associate access token with respective resource + actions; every RS obliged to verify, per request, token meant for that action on that resource. If not, RS must refuse request. Clients and AS may use parameters "scope" and "authorization_details" to determine resources/actions.

## Resource Owner Password Credentials Grant

16. Do not use Resource Owner password credentials grant. Insecurely exposes RO credentials to client → larger attack surface.

## Client Authentication

17. AS uses client authentication if possible. Recommend asymmetric (public-key) methods, e.g. mTLS or "private_key_jwt" (OpenID Connect). AS need not store sensitive symmetric keys → more robust against several attacks.

## Other Recommendations

18. AS does not allow clients to influence their "client_id" or "sub" value or any other Claim confusable with genuine Resource Owner. Recommend end-to-end TLS.
19. Authorization responses not transmitted over unencrypted network connections. AS must not allow redirect URIs using "http" scheme, except native clients using Loopback Interface Redirection.

## References

- RFC 9700: Best Current Practice for OAuth 2.0 Security
- RFC 9449: OAuth 2.0 Demonstrating Proof of Possession (DPoP)
- RFC 8705: OAuth 2.0 Mutual-TLS Client Authentication and Certificate-Bound Access Tokens
