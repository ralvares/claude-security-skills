# Authorization Regression Testing Cheat Sheet

## Introduction

Authorization implementation rarely static. Apps evolve: new API endpoints, refactored data layers, decoupled microservices. Initial testing validates access controls at launch; "Day 2" problem: **how ensure new features or structural changes don't break existing authorization logic?**

Broken Access Control (BAC) ranked number-one risk in OWASP Top Ten 2021; Insecure Direct Object Reference (IDOR) among its most exploited sub-categories. Sheet gives architectural guidance for automated authorization regression testing in SDLC. Shift from manual point-in-time pentesting to continuous developer-centric regression suites → catch BAC, IDOR, tenant isolation failures before production.

Baseline controls: [Authorization Cheat Sheet](Authorization.md).

Topics:

- Designing automated authorization test matrix.
- Regression patterns for horizontal, vertical, tenant isolation tests.
- Validating authorization schemas via API contracts.
- Integrating authorization tests into CI/CD.

## Authorization Test Matrix Design

> **Relationship to the Authorization Testing Automation Cheat Sheet**
>
> [Authorization Testing Automation Cheat Sheet](Authorization_Testing_Automation.md) = foundational XML-driven approach to building/executing authorization matrix against REST services, incl. full Java/JUnit integration harness. **This sheet extends it** w/ *continuous regression*: matrices in YAML/JSON suited to modern test runners, failure patterns to prioritize (IDOR, vertical escalation, tenant boundary), coupling tests to OpenAPI contracts, automatic PR gating in CI/CD. New to authorization test matrices: read [Authorization Testing Automation Cheat Sheet](Authorization_Testing_Automation.md) first, then return for SDLC integration.

Foundation of continuous authorization testing = structured rule mapping consumable by automated frameworks. Design central matrix; no scattered one-off tests.

### Define the Access Policy Model

Before writing tests, define access model explicitly via **Actor-Resource-Action** pattern from OWASP WSTG - Testing for Authorization:

- **Actor (Who):** logical role or specific user attempting operation (e.g., `Tenant_Admin`, `Standard_User`, `Anonymous_User`).
- **Resource (What):** object or data accessed (e.g., `Invoice_123`, `/api/v2/users`, `System_Settings`).
- **Action (How):** operation performed (e.g., `READ`, `CREATE`, `DELETE`, `EXECUTE`).

### Machine-Readable Rules

Store matrix machine-readable (JSON, YAML, structured test fixtures), not spreadsheet. Frameworks generate test cases dynamically → less manual maintenance as policy evolves.

```yaml
# Example Test Fixture Definition
policies:
  - resource: "/api/invoices/{id}"
    method: "GET"
    owner_role: "tenant_user"
    allowed_roles: ["tenant_admin", "system_auditor"]
    denied_roles: ["anonymous", "different_tenant_user"]
    expected_denial_code: 403
```

## Regression Testing Patterns

Target ways authorization usually degrades over time. Implement these patterns in regression suite.

### Horizontal Escalation (IDOR) Validation

Horizontal privilege escalation = user accesses resource of another user w/ same privilege level. [IDOR Prevention Cheat Sheet](Insecure_Direct_Object_Reference_Prevention.md) describes root cause: missing server-side ownership checks on object identifiers.

- **Pattern:** "Multi-User Replay."
- **Implementation:** Authenticate as User A, create Resource X, capture identifier. Authenticate as User B (same role, different account); attempt read, update, delete of Resource X.
- **Assertion:** MUST return `403 Forbidden` or `404 Not Found` (avoids leaking resource existence), never `200 OK`.

### Vertical Escalation Validation

Vertical escalation = lower-privileged user accesses functions reserved for higher-privileged roles. Maps to CWE-269: Improper Privilege Management.

- **Pattern:** "Role Demotion Check."
- **Implementation:** Suite targeting administrative endpoints (e.g., `/api/admin/users/delete`). Iterate all non-admin roles (incl. unauthenticated); attempt to execute endpoints.
- **Assertion:** Endpoints explicitly reject requests. UI hiding insufficient; API layer must enforce check (OWASP Proactive Controls C7); client-side controls trivially bypassed.

### Tenant Isolation Breakage

Multi-tenant SaaS: logic changes (caching, query modifications) can leak data across tenant boundaries; see [Multi-Tenant Security Cheat Sheet](Multi_Tenant_Security.md).

- **Pattern:** "Cross-Tenant Boundary Test."
- **Implementation:** Provision two tenants (Tenant Alpha, Tenant Beta) in test env. Seed data into Tenant Alpha. Run broad read queries (e.g., `GET /api/all-records`) as Tenant Beta user.
- **Assertion:** Response payload contains no records of Tenant Alpha. Single leaked record identifier = critical failure.

## Contract-Driven Authorization Validation

Define authorization schema explicitly in API contract. OpenAPI Specification provides `securitySchemes` and `security` fields to declare requirements globally and per operation.

- **Schema-Aware Testing:** Use OpenAPI definition to identify declared authentication schemes and required scopes; test against access policy. Schemathesis `ignored_auth` check probes missing and invalid credentials. Add explicit tests w/ otherwise-valid tokens lacking required scopes; rejecting missing credentials ≠ scope enforcement works.
- **Middleware Enforcement:** Configure API gateways or web frameworks to auto-enforce security definitions in OpenAPI contract. Regression tests validate middleware not bypassed or disabled after refactor.

## Automated Testing Framework Integration

Authorization tests live alongside functional tests in developer's standard toolkit (OWASP SAMM: Security Testing).

- **Test Frameworks:** Standard runners (e.g., `pytest` Python, `Jest` JavaScript, `JUnit` Java). Low entry barrier; tests run in same CI pipeline as functional tests.
- **Generated and Custom Tests:** Schema-driven testing supplements authorization matrix. Create explicit expired-token and missing-scope fixtures w/ expected denial responses; don't assume OpenAPI contract generates these credentials. Dredd hooks let you modify requests and set custom expectations for these cases.
- **Session Switching:** Swap authentication context quickly and cheaply (e.g., swap JWTs in `Authorization` header per RFC 6750) w/o full login flow per test.

## CI/CD Gating and SDLC Integration

Suite's value realized only if it prevents vulnerable code merging. [CI/CD Security Cheat Sheet](CI_CD_Security.md) covers broader pipeline hardening; below = authorization gates.

- **Blocking PR Builds:** Authorization suite = required CI/CD check (e.g., GitHub Actions, GitLab CI). Failing test → PR can't merge.
- **Dedicated Test Suites:** Tag/group authorization tests distinctly (e.g., `@pytest.mark.authz` or dedicated `authz-tests` npm script) → quick independent local runs.
- **Monitoring in Lower Environments:** Configure CI environments to flag unusual volumes of `401 Unauthorized` or `403 Forbidden` during integration testing; may indicate developer's functional changes colliding w/ existing security controls.

## References

- OWASP WSTG: Testing for Insecure Direct Object References
- OWASP SAMM: Security Testing
- OpenAPI 3.1.0: Security Scheme Object
