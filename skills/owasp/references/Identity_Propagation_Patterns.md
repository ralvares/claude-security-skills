# Identity Propagation Patterns Cheat Sheet

## Introduction

Identity propagation carries authenticated user context between services. Choose representation each recipient can validate that limits where credentials usable; OAuth security guidance (RFC 9700 section 2.3) recommends restricting access tokens to intended resources and actions. See [Authentication Patterns](Authentication_Patterns.md) for authenticating original request, [Authorization Patterns](Authorization_Patterns.md) for enforcing access decisions.

## Validation at Each Boundary

Separate calling service identity from user it acts for. Authenticate service connections w/ controls in [Microservices Security](Microservices_Security.md#service-to-service-authentication); user context alone ≠ caller service identity.

- Accept identity assertions only from configured issuers authorized to make them. JSON Web Tokens (JWTs): validate signature, allowed algorithm, issuer, audience, token type, validity period per applicable token profile. RFC 8725 section 3: signature verification alone insufficient.
- Opaque access tokens: use issuer's supported validation mechanism. Token representation does not determine whether it grants access to a given operation.
- OpenID Connect ID token ≠ API access token. Forwarding certificate does not preserve proof of private-key possession on TLS connection (RFC 8705). Preserve each protocol's validation and proof requirements.
- Reject missing/invalid context. Each receiving service must still authorize requested action and resource. Valid signature = issuer + integrity of assertion, not permission for every request.

Diagrams below show identity data flow. Verification steps include these checks; component labeled "Verifier" need not be separate online service.

## Propagation Patterns

### External Identity Propagation

Edge passes external access token to service that is intended recipient. Each recipient validates before use.

![External identity propagation](../assets/External_Identity_Propagation.png)

Reasonable when services share token's validation profile and token intended for them. Do not widen token audiences just to make forwarding work. Audience restriction (RFC 9700 section 4.10.2) limits leaked-token impact; forwarding bearer token to more services adds leak points. Forwarding not inherently incompatible w/ Zero Trust, but gives no isolation between recipients accepting same credential.

### Simple Service-Level Identity Forwarding

Service extracts user attributes, forwards JSON object, header, or assertion it signs itself.

![Simple service-level identity forwarding](../assets/Simple_Service_Level_Identity_Forwarding.png)

Avoid making arbitrary app services identity issuers. Authenticated channel or forwarding-service signature identifies sender and protects transit integrity; neither proves sender entitled to assert user's identity or privileges. Every service trusted to supply attributes can misrepresent them. Trusted proxy header: remove client-supplied copies, authenticate proxy, prevent requests bypassing it. Prefer assertion from designated issuer when context crosses multiple service boundaries.

### Token Exchange

Service presents incoming token to Security Token Service (STS), requests token for downstream recipient. RFC 8693 section 2 defines exchange: subject and actor tokens, requested audiences, scopes. Authenticate requesting service to STS. STS must authorize exchange and constrain issued privileges; requesting narrower token ≠ substitute for issuer-side enforcement.

![Token exchange](../assets/Token_Exchange_Based_Identity_Issuance.png)

Use exchange when downstream call needs different audience or explicit delegation. Preserve user vs acting-service distinction where policy depends on it. Exchange adds issuance dependency; plan for STS outages w/o accepting invalid credentials. RFC 8693 does not require all input credentials be OAuth access tokens or all issued tokens be signed JWTs.

### Protocol-Agnostic Identity Propagation

Edge validates external credential, obtains normalized internal assertion from trusted issuer. Internal services validate that assertion instead of implementing each external auth protocol.

![Protocol-agnostic identity propagation](../assets/Protocol_Agnostic_Identity_Propagation.png)

Prefer when several external auth mechanisms feed same internal services. Keep issuance privileges separate from verification privileges; limit assertion recipients and lifetime. Signing protects integrity; does not hide claims, prevent bearer-token replay, or compensate for compromised issuer.

Transaction Tokens draft (draft-ietf-oauth-transaction-tokens-11, section 12.2) = developing example: ingress/initiating workload obtains transaction token; workloads normally propagate it unmodified within trust domain. Recipients validate signature, trust-domain audience, expiry, then authorize own operation. Draft also permits constrained replacement by token service (section 13.15). Tokens not replay resistant; not fresh audience-specific exchange at every service hop.

## Privacy and Recommendation

Send only identity attributes recipient needs. Use pseudonymous identifiers where appropriate; protect tokens in transit (RFC 8693 section 6 privacy considerations). Mapping external → internal identifier alone does not prevent correlation; signing gives no confidentiality. Keep internal assertions out of client responses; follow [Logging Cheat Sheet](Logging.md#data-to-exclude) when recording identity events.

Start with token each intended recipient can validate. Use exchange for recipient-specific delegation, or trusted internal issuer to normalize external credentials. Every pattern: validate context at each receiving service, enforce least privilege there.

## References

- RFC 9700: OAuth 2.0 Security Best Current Practice
- RFC 8725: JSON Web Token Best Current Practices
- RFC 8693: OAuth 2.0 Token Exchange
