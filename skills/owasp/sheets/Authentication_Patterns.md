# Authentication Patterns Cheat Sheet

## Introduction

Authentication can be enforced at different system architecture layers. Compares main patterns, where verification happens, trust-boundary implications:

- **Service-Level:** each service verifies identity itself, or delegates to tightly coupled proxy.
- **Edge-Level:** authentication centralized in shared component at system boundary.
- **Network-Layer (Node-Level):** peers authenticated cryptographically at network layer, transparent to apps.

Patterns apply to **external** actors (end users, client apps outside system) and **internal** actors (services, other workloads, nodes they run on), though mechanisms and trust assumptions differ. Most systems authenticate in two phases:

- **Primary authentication** verifies credential, links it to known identity: password, signed challenge e.g. WebAuthn assertion, or for internal actors machine certificate or workload identity e.g. SPIFFE ID.
- **Authentication proof verification** checks reusable artifact issued after primary authentication (session cookie, token, assertion at app layer; TLS session key or IPsec Security Association at lower layers) → primary authentication not repeated per request. NIST SP 800-63B describes this as session management based on session secret.

Where distinction doesn't matter, **authentication data** covers both. Patterns differ in **what** verified (credentials or proofs), **where** verification happens, **which** implications for system design and trust boundaries.

Authorization and propagating authenticated identity between services: see [Microservices Security Cheat Sheet](Microservices_Security.md), esp. [edge-level](Microservices_Security.md#edge-level-authorization), [identity propagation](Microservices_Security.md#external-entity-identity-propagation), [service-to-service authentication](Microservices_Security.md#service-to-service-authentication) sections.

## Service-Level Embedded Authentication

Each service handles primary authentication itself: manages identities and credentials, verifies them, implements authentication workflows, typically username/password or API keys. All authentication logic and subject data storage inside service, in custom code or built-in libraries. Maintaining such service: credential handling must follow [Authentication Cheat Sheet](Authentication.md) and [Password Storage Cheat Sheet](Password_Storage.md).

![Service-Level Embedded Authentication](../assets/Service_Level_Embedded_Authentication.png)

### Pros

- **Simplicity:** each service self-contained, needs no external authentication infrastructure.
- **Customization freedom:** adapt authentication to service-specific requirements w/o external constraints.
- **Support for external and internal actors:** service controls all authentication functionality → can orchestrate different contexts (internal services and external users), at price of significant complexity (see authentication orchestration con below).

### Cons

- **Inconsistency:** authentication behavior, credential storage, flows differ across services → fragments system, degrades UX, rules out Single Sign-On (SSO).
- **Security risk:** authentication code duplicated across services → more vulnerabilities, harder audits.
- **Maintenance burden:** changing authentication methods (e.g., adding multi-factor authentication (MFA)) needs updates across all affected services.
- **Limited scalability:** each service manages own identities; doesn't scale to service-to-service authentication across large system.
- **Limited observability and governance:** w/o centralized monitoring, credential reuse, account compromise, brute-force against one service invisible to others → hinders coordinated detection and response.
- **Authentication orchestration:** multi-principal subjects (multiple authentication configurations, protocol chaining, subject-specific variations for contexts e.g. first- and third-party access, external clients next to service-to-service calls) add significant complexity.
- **Coupling of external authentication data with internal trust assumptions:** same authentication data for external clients and internal services raises leakage and unauthorized access risk. Internal service exposed by misconfiguration, or attacker gains internal access → leaked authentication data grants access to sensitive resources.

## Service-Level Code-Mediated Authentication

Addresses key limits of [Service-Level Embedded Authentication](#service-level-embedded-authentication): fragmented identity management, duplicated credential stores, no SSO. Service no longer verifies credentials directly. External Identity Provider (IdP) authenticates subject, issues authentication proofs; service verifies these itself, extracts identity attributes for request processing.

![Service-Level Code-Mediated Authentication](../assets/Service_Level_Code_Mediated_Authentication.png)

### Pros

- **SSO support:** identity and credential lifecycle consolidated in IdP → SSO, less duplication.
- **Lower security risks:** centralized authentication shrinks credential-handling attack surface.
- **Improved user experience:** consistent authentication flows and session handling across services.
- **Interoperability:** widely adopted protocols e.g. OpenID Connect (OIDC) and SAML → flexibility, broad IdP integration.
- **Customization freedom:** services can still tailor authentication to needs, e.g. where standards like OIDC not applicable.
- **Support for external and internal actors:** as in [embedded pattern](#service-level-embedded-authentication), same orchestration complexity.

### Cons

- **Protocol handling overhead:** each service must implement and maintain authentication proof verification and protocol-specific logic.
- **Misconfiguration risks:** incorrect verification logic, e.g. missing expiration checks or improper cryptography, → severe vulnerabilities.
- **Authentication orchestration:** same complexity as [embedded pattern](#service-level-embedded-authentication).
- **Coupling of external authentication data with internal trust assumptions:** same risk as [embedded pattern](#service-level-embedded-authentication).

## Service-Level Proxy-Mediated Authentication

Builds on [previous pattern](#service-level-code-mediated-authentication) but moves authentication logic from service into dedicated proxy deployed as sidecar. Proxy sits in front of app, verifies authentication proofs with Identity Provider (IdP), injects identity context into request (typically headers), forwards locally to service.

![Service-Level Proxy-Mediated Authentication](../assets/Service_Level_Proxy_Mediated_Authentication.png)

### Pros

- **All benefits of code-mediated pattern:** SSO, centralized credential handling, consistent UX, standards-based interoperability (see [above](#service-level-code-mediated-authentication)).
- **Separation of concerns:** removes authentication logic from app code → simpler development, less maintenance.
- **Consistent behavior:** identity verification and protocol handling in proxy → uniform across services.
- **Improved security posture:** authentication logic in dedicated hardened component → fewer implementation flaws.
- **Authentication orchestration:** some proxies support multiple authentication configurations incl. protocol chaining and subject-specific variations → covers first- and third-party access or mix of external clients and internal services.
- **Strong foundation for service-to-service trust:** enables Zero Trust networking with workload identity, typically via SPIFFE/SPIRE, which issues workload identities as X.509 certificates used for mutual TLS (mTLS) between services.

### Cons

- **Operational complexity:** extra component per microservice to deploy and maintain; higher resource usage and cost.
- **Header spoofing risk:** app trusts identity headers set by sidecar, so any path letting caller set them yields forged identity: client reaching app port directly, or proxy forwarding identity headers received from caller. Countermeasures: sidecar must strip or overwrite every inbound identity header before injecting own (Envoy, for example, sanitizes `x-forwarded-client-cert` by default); app must accept traffic only from its sidecar (bind to loopback, or network policy allowing only sidecar to reach app port); or, where isolation can't be guaranteed, sidecar must sign injected headers with HTTP Message Signatures (RFC 9421) so app can verify origin. Define signature profile binding identity to intended service and relevant request components. App must verify trusted signer's signature and enforce freshness and replay checks. NIST SP 800-204 (MS-SS-13) recommends layer 3 network segmentation for sensitive apps precisely to counter callers bypassing sidecar proxy.
- **Configuration consistency:** all proxies across service landscape must be configured uniformly; inconsistencies → confusing user flows or vulnerabilities.
- **Coupling of external authentication data with internal trust assumptions:** same risk as [embedded pattern](#service-level-embedded-authentication), since external authentication data still travels to every service's sidecar for verification.

## Edge-Level Authentication

Authentication at system boundary by shared component e.g. API gateway or ingress proxy. Authenticates incoming external requests before they reach internal services. Uses OIDC or SAML with identity provider for user authentication, validates OAuth 2.0 access tokens (RFC 6749) for API access, or uses mTLS (RFC 8446) for certificate-based client authentication. Propagates verified identity info, typically via headers, to downstream services.

![Edge-Level Authentication](../assets/Edge_Level_Authentication.png)

Consolidates authentication into single enforcement point; removes per-service authentication handling. Corresponds to gateway or portal placement of policy enforcement point in NIST SP 800-207 (Zero Trust Architecture).

### Pros

- **Improved consistency:** uniform authentication at single entry point → less fragmentation and configuration drift, better auditability.
- **Simplified service logic:** internal services skip authentication; focus on authorization and business functionality.
- **Faster service onboarding:** new services rely on existing authentication infrastructure; minimal setup.
- **Protocol-agnostic identity propagation:** edge verifies external authentication data once, propagates identity to internal services in trusted, implementation-independent format: newly issued JSON Web Token (JWT) (RFC 7519), headers protected with HTTP Message Signatures (RFC 9421), or signed proprietary structure. Unlike service-level patterns, where every service or sidecar must receive and verify external authentication data, internal services only see internal representation.

### Cons

- **Limited granularity:** fine-grained or per-endpoint authentication policies (e.g., step-up authentication) harder to implement; may need coordination with downstream services, depending on edge proxy capabilities.
- **Identity propagation challenges:** secure, reliable propagation of identity context (e.g., via headers) needs strict validation and explicit trust model between edge and internal services. Use one of protected formats above; internal services verify signature and reject requests whose identity context missing or unsigned.
- **Single point of failure:** ingress proxy/gateway already central in most architectures, but edge authentication makes it critical part of security infrastructure. Misconfiguration or compromise affects authentication decision integrity system-wide.
- **Not suitable for service-to-service authentication:** covers only incoming external requests. Internal service-to-service calls need own mechanism; any component reaching a service directly bypasses gateway entirely; NIST SP 800-204 (MS-SS-2) recommends mutual authentication to prevent such direct anonymous connections. Routing internal traffic through edge technically possible but severe performance bottlenecks.

## Network-Layer (Node-Level) Authentication

Authenticates peers at network layer (layer 3), inside OS kernel, using cryptographic identities attached to node/host, not app. Built on IPsec (RFC 6071) or WireGuard: peer identity bound to keys configured on each node; every packet cryptographically authenticated. Enforcement transparent to apps → good complement for securing workload traffic, not replacement for application-layer authentication.

![Network-Layer (Node-Level) Authentication](../assets/Network_Layer_Authentication.png)

### Pros

- **Transparent to applications:** services need no authentication logic; kernel enforces peer identity for all traffic.
- **Protocol-agnostic:** all traffic types, not just HTTP.
- **Low overhead:** kernel implementation and lightweight handshakes → low latency, strong node isolation.
- **Provides node (host) identity:** each node holds own key material, every packet authenticated → resists spoofing and replay at network layer; supports Zero Trust segmentation between nodes.

### Cons

- **Not suitable for application-level (layer 7) authentication:** identities belong to nodes/hosts, not individual users, external clients, or usually individual workloads. Every workload on node shares node identity; user-specific attributes can't be conveyed.
- **Limited observability:** monitoring limited to connection-level data (source and destination nodes); no insight into user-driven actions in app.
- **Infrastructure complexity:** needs robust automation for key and identity management and OS/kernel-level policy enforcement (e.g., via eBPF).

## Operational and Security Considerations

Patterns differ mainly in *where* and *how* authentication performed, but also significantly affect operations and authorization. Choosing pattern = balancing development flexibility, operational effort, risk tolerance.

### Operational Considerations

| Pattern                          | Configuration & Implementation Burden | Operational Overhead    | Observability Scope        |
| -------------------------------- | ------------------------------------- | ----------------------- | -------------------------- |
| **Service-Level Embedded**       | High                                  | High                    | Application-specific       |
| **Service-Level Code-Mediated**  | Medium                                | Medium                  | IdP + Application-specific |
| **Service-Level Proxy-Mediated** | Medium                                | High (infra cost)       | Proxy + Application        |
| **Edge-Level**                   | Low                                   | Low                     | Centralized (Proxy)        |
| **Network-Layer (Node-Level)**   | Low-Medium                            | High (infra complexity) | Network-level only         |

Decentralized authentication (e.g. [Service-Level Embedded Authentication](#service-level-embedded-authentication)) typically costs more operationally: inconsistencies, duplicated configuration, monitoring complexity. Centralized patterns reduce duplication but add infrastructure dependencies, need resilient design.

### Security Considerations

Security risk rises significantly when authentication logic and credentials handled directly in app code. Centralized enforcement (IdP, edge, kernel) limits exposure, enforces stronger boundaries, cuts misconfiguration risk. But prevent trust leakage; directly undermines least privilege. Depends on where authentication occurs and on how identity info propagated and verified downstream. W/o trustworthy tamper-resistant propagation, even strong initial authentication undermined, weakening trust boundaries and reliable authorization decisions. [Identity Propagation Patterns Cheat Sheet](Identity_Propagation_Patterns.md) compares forwarding, token exchange, trusted internal assertions, incl. validation requirements and limits.

**Note:** Token theft, replay protection, session lifecycle, reauthentication critical in any pattern. Covered in [Authentication Cheat Sheet](Authentication.md) and [Session Management Cheat Sheet](Session_Management.md).

## Recommendations

- **Authenticate external actors at the edge.** Centralize external authentication in gateway or ingress proxy per NIST SP 800-207 and NIST SP 800-204 (MS-SS-2). Normalize different authentication mechanisms into signed internal assertion when needed. Forward external access token only to its intended recipients (RFC 9700 Section 2.3), with required validation and proof at each receiving service; else exchange it or issue suitable internal assertion. See [Identity Propagation Patterns](Identity_Propagation_Patterns.md).
- **Authenticate internal service calls with proxy-mediated mTLS and workload identity.** Every workload gets own cryptographic identity, e.g. X.509 SVID issued via SPIFFE; sidecar enforces mutual authentication w/ TLS (RFC 8446) client certificates on every service-to-service connection, as NIST SP 800-204 (MS-SS-4) recommends. See also [Client Certificates and Mutual TLS](Transport_Layer_Security.md#client-certificates-and-mutual-tls).
- **Do not embed authentication in new systems.** Service-level embedded authentication fragments identity, duplicates credential stores, rules out SSO. Reserve for legacy code you can't change; even then follow [Authentication Cheat Sheet](Authentication.md).
- **Treat network-layer (node-level) authentication as transport complement, never sole control.** Authenticates nodes, not users or workloads; NIST SP 800-207 explicit that network location alone doesn't imply trust. Combine with edge-level or proxy-mediated authentication; NIST SP 800-204 (MS-SS-13) likewise positions layer 3 segmentation as complement to service mesh controls.

## References

- NIST SP 800-204: Security Strategies for Microservices-Based Application Systems
- NIST SP 800-207: Zero Trust Architecture
