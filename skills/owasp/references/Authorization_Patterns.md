# Authorization Patterns Cheat Sheet

## Introduction

Authorization patterns decide where app decides and enforces access. **Policy Enforcement Point (PEP)** protects operation; **Policy Decision Point (PDP)** evaluates applicable policy. OpenID AuthZEN defines interface between them. Use [Authorization Cheat Sheet](Authorization.md) for baseline controls, [Identity Propagation Patterns](Identity_Propagation_Patterns.md) for trustworthy caller context.

In diagrams, **Policy Administration Point (PAP)** manages rules; **Policy Information Point (PIP)** supplies attributes for evaluation.

## Service-Level Authorization

Keep enforcement close to protected resource → can check requested action, object, tenant. Deny by default; [validate permissions on every request](Authorization.md#validate-the-permissions-on-every-request). Separating policy evaluation from enforcement doesn't transfer PEP's responsibility to enforce result; AuthZEN trust model explicitly relies on it.

### Policies in Application Code

Service implements decision and enforcement logic, using framework authorization facilities where possible.

![Decentralized service-level authorization](../assets/Decentralized_Service_Level_Authorization.png)

Can suit small app w/ limited policy surface. Centralize checks in app's authorization layer; test every protected entry point. Scattered conditional checks make omissions and inconsistent policies harder to detect; changing rules requires deploying app code. Code-based policies not inherently fail-open.

### Separately Managed Policies

Service stays PEP but asks PDP to evaluate policies managed independently of business code. PDP may be embedded, local, or remote; central policy ownership ≠ single central runtime.

![Centralized service-level authorization](../assets/Centralized_Service_Level_Authorization.png)

Use when several services need consistent rules and shared review process. Supply authenticated subject context and authoritative resource attributes, enforce returned decision before accessing resource, deny if no valid decision available. See [Policy and Data Distribution](Authorization_Policy_And_Data_Distribution.md) for keeping inputs current, [Decisions and Output Handling](Authorization_Decisions_And_Output_Handling.md) for enforcing results.

## Gateway and Proxy Enforcement

Gateway can enforce coarse access rules before forwarding request. Service-local proxy can do similar checks on calls to one service. Envoy external authorization filter illustrates delegation to PDP and documents how routing changes after authorization can invalidate earlier check.

![Edge-level authorization](../assets/Edge_Level_Authorization_Classic.png)

Complete traffic coverage = deployment requirement, not automatic gateway property. Authenticate permitted callers, restrict direct access to services, cover internal calls and alternate endpoints. Keep object-level and business-specific checks in service when proxy lacks context. Reevaluate authorization if effective resource or action changes after check.

### Propagating an Authorization Context

Gateway may attach signed context describing authenticated subject or authorization decision for downstream use.

![Gateway authorization with propagated context](../assets/Edge_Level_Authorization_Modern.png)

Downstream services must validate trusted issuer, integrity, audience, expiry, and context's applicability to actual request. Reject direct calls lacking required context. Strip client-supplied copies of trusted headers before populating them. Signature alone neither prevents bypass nor authorizes different resource, tenant, or action; follow JWT validation guidance (RFC 8725 section 3) and retain service-level enforcement.

## PDP Deployment and Failure Behavior

Choose deployment independently of access control model. E.g. OPA supports HTTP, library, WebAssembly integration; product name ≠ one deployment mode or particular access control standard.

| Deployment | Security benefit | Required control |
|------------|------------------|------------------|
| Embedded library | Evaluation continues w/o remote PDP connection | Keep policy and data current; verify enforcement on every entry point |
| Local sidecar or daemon | Shared decision implementation near service | Restrict its API, handle process failure; locality alone ≠ trust |
| Remote service | Shared evaluation, centralized policy administration | Authenticate and authorize PEPs, protect responses, deny when valid decision unavailable |

All modes depend on policy and data used. Local PDP w/ stale revocation data can still wrongly permit. Log decision and its enforcement, w/ enough policy/version context to investigate discrepancies, w/o exposing sensitive attributes.

Configure PDP errors and timeouts to deny protected operations. Envoy failure-mode setting makes this explicit: allowing requests when authorization fails bypasses control. Previously loaded policy may continue to be evaluated only within freshness requirements in [Policy and Data Distribution](Authorization_Policy_And_Data_Distribution.md#freshness-and-outages).

Prefer service-level enforcement w/ shared, separately reviewed policies as system grows. Add gateway checks for early rejection and traffic control; verify protected operations stay covered when gateway, policy source, or PDP unavailable.

## References

- OpenID AuthZEN Authorization API 1.0
- OPA integration documentation
- Envoy external authorization security considerations
