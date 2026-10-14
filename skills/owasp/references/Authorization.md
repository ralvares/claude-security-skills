# Authorization Cheat Sheet

## Introduction

Authorization = "process of verifying that requested action or service is approved for specific entity" ([NIST](https://csrc.nist.gov/glossary/term/authorization)). ≠ authentication (verifying identity). Authenticated user often not authorized for every resource/action (e.g. admins vs regular users). Authentication not always required: unauthenticated user may be authorized for public resources (image, login page, even entire web app).

Goal: robust, business-appropriate, maintainable, scalable authorization logic; applies to all SDLC phases.

Authorization flaws = major web app concern. Broken Access Control ranked top web vulnerability in [OWASP's 2021 Top 10](https://owasp.org/Top10/A01_2021-Broken_Access_Control/); "High" exploit likelihood per [MITRE's CWE program](https://cwe.mitre.org/data/definitions/285.html). [Veracode's State of Software Vol. 10](https://www.veracode.com/sites/default/files/pdf/resources/sossreports/state-of-software-security-volume-10-veracode-report.pdf): Access Control among more common OWASP Top 10 risks in exploits/incidents despite being among least prevalent.

Impact varies in form and severity: attackers may read, create, modify, delete protected resources (C/I/A loss); business cost tracks resource criticality/sensitivity, very low → extremely high.

Exploiters: unauthenticated outsiders, authenticated-but-unauthorized users, malicious insiders. Honest mistakes may enable bypass; malicious intent usually needed to realize threat. Horizontal privilege escalation (access another user's resources) especially common. Flaws let attackers view/modify/delete sensitive resources (DB records, static files, PII, etc.) or perform forbidden actions (create account, costly order). Poor access-control logging → violations undetected or unattributable.

## Recommendations

### Enforce Least Privileges

Least Privileges = assign users only minimum privileges needed for job. Apply horizontally + vertically: accountant and sales rep same hierarchy level but need different resources (accountant ≠ customer DB, sales rep ≠ payroll); sales head needs more privilege than subordinates.

Failure jeopardizes confidentiality. Mitigate mainly in Architecture/Design phase (see [CWE-272](https://cwe.mitre.org/data/definitions/272.html)); address throughout SDLC.

- Design phase: define trust boundaries. Enumerate user types, exposed resources, operations (read, write, update, etc). For each user type × resource, decide allowed operations (by role and/or other attributes). ABAC → consider all attribute categories. E.g. Sales Rep may access customer DB from internal network during working hours, not from home at midnight.
- Write tests validating design-phase permissions are enforced.
- Post-deploy: periodically review permissions for "privilege creep"; privileges must not exceed design-phase definition (± formally approved changes).
- Easier to grant later than revoke; plan Least Privileges early to avoid revoking overly broad permissions.

### Deny by Default

Even w/o matching rule, app must decide deny or permit (implicit or explicit). Logic errors happen, esp. w/ complex requirements → don't rely solely on explicit rules matching all requests. Configure app to deny by default.

- Adopt "deny-by-default" during initial development and whenever new functionality/resources exposed. Must be able to justify why permission granted to user/group; access never the default.
- Prefer explicit configuration over framework/library defaults even if they deny by default; third-party defaults/logic may change w/o developer knowing implications.
  
### Validate the Permissions on Every Request

Validate permissions on every request, whatever source (AJAX script, server-side, other). Tech used should allow global app-wide configuration, not per-method/class application. Attacker needs one way in; single missed check can compromise confidentiality/integrity; checking majority of requests insufficient. Technologies helping consistent checks:

- [Java/Jakarta EE Filters](https://jakarta.ee/specifications/platform/8/apidocs/javax/servlet/Filter.html) incl. implementations in [Spring Security](https://docs.spring.io/spring-security/site/docs/5.4.0/reference/html5/#servlet-security-filters)
- [Middleware in the Django Framework](https://docs.djangoproject.com/en/4.0/ref/middleware/)
- [.NET Core Filters](https://docs.microsoft.com/en-us/aspnet/core/mvc/controllers/filters?view=aspnetcore-3.1#authorization-filters)
- [Middleware in the Laravel PHP Framework](https://laravel.com/docs/8.x/middleware)

### Thoroughly Review the Authorization Logic of Chosen Tools and Technologies, Implementing Custom Logic if Necessary

Libraries/frameworks ≠ panacea; use responsibly. Two concerns: developer misconfiguration/lack of configuration, and vulnerabilities in components themselves (see [A6](https://owasp.org/www-project-top-ten/OWASP_Top_Ten_2017/Top_10-2017_A6-Security_Misconfiguration) and [A9](https://owasp.org/www-project-top-ten/2017/A9_2017-Using_Components_with_Known_Vulnerabilities.html)).

Third-party component vulns can bypass authorization even in otherwise secure app; affects even most robust/popular libraries, not just unproven/poorly maintained ones. Even competent developers err. Assume any third-party component *could* be or become subject to authorization vulnerability. Considerations:

- Create, maintain, follow process for detecting/responding to vulnerable components.
- Incorporate tools like [Dependency Check](https://owasp.org/www-project-dependency-check/) into SDLC; consider vendor data feeds, [the NVD](https://nvd.nist.gov/vuln/data-feeds), other sources.
- Defense in depth: no single framework, library, technology or control sole enforcer of access control.

Misconfiguration (or no configuration) also breaks authorization. Components are general-purpose; for all but simplest cases must be customized/supplemented to meet app/environment requirements, esp. security + authorization. Configuration considerations:

- Thoroughly understand tech underlying authorization logic. *Component's authorization logic may be insufficient for app's specific security requirements*. Prebuilt logic convenient ≠ sufficient. Custom authorization logic may be necessary.
- Capabilities of library/platform/framework must not drive authorization requirements. Decide requirements first, then analyze components against them.
- Don't rely on default configurations.
- Test configuration; don't assume it works as intended in your environment. Docs can be misunderstood, vague, outdated, inaccurate.

### Prefer Attribute and Relationship Based Access Control over RBAC

Access control models: Role-Based (RBAC), Attribute-Based (ABAC), newer Relationship-Based (ReBAC). Choice affects entire SDLC; decide as early as possible.

- RBAC: access granted/denied by user's assigned roles. Permissions attach to roles, not entities; entity inherits permissions of its roles. Role-user relationship generally many-to-many; roles may be hierarchical.

- ABAC: "subject requests to perform operations on objects are granted or denied based on assigned attributes of the subject, assigned attributes of the object, environment conditions, and a set of policies that are specified in terms of those attributes and conditions" ([NIST SP 800-162](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-162.pdf), pg. 7). Attributes = characteristics as name-value pairs assigned to subject, object, or environment. E.g. job role, time of day, project name, MAC address, creation date.

- ReBAC: grants access by relationships between resources. E.g. only post creator may edit it. Needed esp. in social networks (Twitter, Facebook) where users limit data (tweets, posts) to chosen people (friends, family, followers).

RBAC long-established and popular, but ABAC and ReBAC should typically be preferred. Advantages over RBAC:

- **Support fine-grained, complex Boolean logic**. RBAC decides on presence/absence of roles; poor for object-level/horizontal access decisions and multi-factor decisions.

    - ABAC expands number/type of characteristics: role/job function can be one attribute, not necessarily considered in isolation (or at all if irrelevant). Incorporates environmental/dynamic attributes: time of day, device type, geographic location. E.g. deny sensitive resource outside business hours or if user hasn't recently completed mandatory training; RBAC struggles here. → ABAC better serves least privileges.
    - ReBAC supports relationships between direct objects and direct users (not just role) → fine-grained permissions. Some systems support algebraic operators like AND and NOT: "if this user has relationship X but not relationship Y with the object, then grant access".

- **Robustness**. Large projects/many roles → role checks easily missed or done wrong ([OWASP C7: Enforce Access Controls](https://owasp.org/www-project-proactive-controls/v3/en/c7-enforce-access-controls)); too much or too little access. Esp. RBAC w/o role hierarchy, needing chained role checks (i.e., `if(user.hasAnyRole("SUPERUSER", "ADMIN", "ACCT_MANAGER"))` ).
- **Speed**. RBAC "role explosion" when too many roles. Credentials + roles sent via size-limited means (e.g. HTTP headers) may not fit all roles. Workaround: send only user ID, app retrieves roles; adds latency to every request.
- **Supports Multi-Tenancy and Cross-Organizational Requests**. RBAC poorly suited when distinct organizations/customers access same protected resources; would need per-customer rule sets in multi-tenant env or pre-provisioned identities for cross-org requests ([OWASP C7](https://owasp.org/www-project-proactive-controls/v3/en/c7-enforce-access-controls); [NIST SP 800-162](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-162.pdf)). ABAC, given consistently defined attributes, lets decisions be "executed and administered in the same or separate infrastructures, while maintaining appropriate levels of security" ([NIST SP 800-162](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-162.pdf), pg. 6).
- **Ease of Management**. RBAC initial setup often simpler, but benefit vanishes as scale/complexity grows. Couple of roles (User, Admin) rarely suffice in production for long. More roles → testing and auditing (critical for trust in codebase/logic) harder ([OWASP C7](https://owasp.org/www-project-proactive-controls/v3/en/c7-enforce-access-controls)). ABAC/ReBAC more expressive, attributes + Boolean logic reflect real-world concerns, easier to update when needs change, separate policy management from enforcement and identity provisioning ([NIST SP 800-162](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-162.pdf); see also [XACML-V3.0](https://docs.oasis-open.org/xacml/3.0/xacml-3.0-core-spec-os-en.html), standard highlighting these benefits)

### Ensure Lookup IDs are Not Accessible Even When Guessed or Cannot Be Tampered With

Apps often expose internal object identifiers (account number, DB Primary Key) used to locate objects: query parameter, path variable, "hidden" form field, elsewhere. E.g.:

```https://mybank.com/accountTransactions?acct_id=901```

Assumed: returns transactions restricted to account in `acct_id`. If user changes `acct_id` to `523`: can they view another's transactions? If denied, is it because account "523" not found, or failed access control check? Common flaw: [CWE 639: Authorization Bypass Through User-Controlled Key](https://cwe.mitre.org/data/definitions/639.html). Results: authorization bypass, horizontal privilege escalation, less commonly vertical privilege escalation (see [CWE-639](https://cwe.mitre.org/data/definitions/639.html)). Form of Insecure Direct Object Reference (IDOR).

 Example ID was exposed, easily tampered, and predictable (perhaps sequential). Masking/randomizing IDs generally insufficient alone. User must not access unpermitted resource just by guessing/manipulating identifier. No security through obscurity; control access to underlying objects and/or identifiers. Mitigations:

- Avoid exposing identifiers when possible. E.g. retrieve some objects (account details) from authenticated user's identity/attributes only (e.g. securely implemented JSON Web Token (JWT) or server-side session).
- Implement user/session specific indirect references via tool like [OWASP ESAPI](https://owasp.org/www-project-enterprise-security-api/) (see [OWASP Top 10:2025 A01 Broken Access Control](https://owasp.org/Top10/2025/A01_2025-Broken_Access_Control/) and [Insecure Direct Object Reference Prevention Cheat Sheet](Insecure_Direct_Object_Reference_Prevention.md))
- Access control check on *every* request for *specific* object/functionality accessed. Access to one object of a type ≠ access to every object of that type.

### Enforce Authorization Checks on Static Resources

Static resource security often overlooked. Databases/data stores rightly get attention, but static resources need securing too; cloud storage (e.g. Amazon S3 Buckets) poorly secured resources rose to prominence in recent years. Consider:

- Include static resources in access control policies. Required protection is contextual: some may be public, others only accessible with highly restrictive user/environment attributes. Understand data type exposed. Consider formal Data Classification scheme incorporated into access control logic (see [here](https://resources.infosecinstitute.com/information-and-asset-classification/) for overview).
- Secure cloud services storing static resources using vendor configuration options/tools. Review provider docs ([AWS](https://aws.amazon.com/premiumsupport/knowledge-center/secure-s3-resources/), [Google Cloud](https://cloud.google.com/storage/docs/best-practices#security), [Azure](https://docs.microsoft.com/en-us/azure/storage/blobs/security-recommendations)).
- When possible, protect static resources with same access control logic/mechanisms as other app resources/functionality.

### Verify that Authorization Checks are Performed in the Right Location

NEVER rely on client-side access control checks. OK for UX only; never decisive for grant/deny; client-side logic easy to bypass. Perform checks server-side, at gateway, or in serverless functions (see [OWASP ASVS 4.0.3, V1.4.1 and V4.1.1](https://raw.githubusercontent.com/OWASP/ASVS/v4.0.3/4.0/OWASP%20Application%20Security%20Verification%20Standard%204.0.3-en.pdf))

### Exit Safely when Authorization Checks Fail

Failed checks normal in secured app; plan and handle securely. Improper handling → unpredictable app state ([CWE-280: Improper Handling of Insufficient Permissions or Privileges](https://cwe.mitre.org/data/definitions/280.html)).

- Handle all exceptions and failed checks, however unlikely ([OWASP Top Ten Proactive Controls C10: Handle all errors and exceptions](https://owasp.org/www-project-proactive-controls/v3/en/c10-errors-exceptions)). App needn't "correct" failed check; often simple message or HTTP status code suffices.
- Centralize failed-check handling logic.
- Verify exception/authorization-failure handling; failures, however unlikely, must not leave software unstable → authorization bypass.
- Don't expose sensitive info (system logs, debug output) in error messages; misconfigured errors enlarge attack surface. ([CWE-209: Generation of Error Message Containing Sensitive Information](https://cwe.mitre.org/data/definitions/209.html))

### Implement Appropriate Logging

Logging = key detective control; insufficient logging/monitoring among most critical risks in [OWASP's Top Ten 2021](https://owasp.org/Top10/A09_2021-Security_Logging_and_Monitoring_Failures/). Logs detect malicious activity, support post-incident investigation, troubleshoot access control/security problems, aid auditing. Easy to overlook at design/requirements; incorporate in all SDLC phases.

- Log in consistent, well-defined, parseable formats. Per [OWASP Top Ten Proactive Controls C9](https://owasp.org/www-project-proactive-controls/v3/en/c9-security-logging), [Apache Logging Services](https://logging.apache.org/) = one project supporting many languages/platforms
- Choose log volume per app environment/requirements. Too much and too little both weaknesses (see [CWE-778](https://cwe.mitre.org/data/definitions/778.html) and [CWE-779](https://cwe.mitre.org/data/definitions/779.html)). Too little: malicious activity undetected, weak post-incident analysis. Too much: strains resources, excess false positives, sensitive data needlessly logged.
- Synchronize clocks and timezones across systems; accuracy crucial for reconstructing attack sequence during/after incident response.
- Consider centralized log server or SIEM.

### Create Unit and Integration Test Cases for Authorization Logic

Unit/integration tests verify consistent behavior across changes. Access-control flaws subtle, esp. with complex requirements; small logic/config error can have severe consequences. Not substitute for dedicated security test or pen test (see [OWASP WSTG 4.5](https://owasp.org/www-project-web-security-testing-guide/v42/4-Web_Application_Security_Testing/05-Authorization_Testing/README)), but reduce flaws reaching production. Catch "low-hanging fruit", not sophisticated attack vectors ([OWASP SAMM: Security Testing](https://owaspsamm.org/model/verification/security-testing/)).

Tests should cover concepts here: access denied by default? App terminates safely on failed check, even under abnormal conditions? ABAC policies properly enforced? Never replace manual testing by skilled hacker, but find/fix issues quickly with far fewer resources.

## References

- NIST SP 800-162: Guide to ABAC
- OWASP Proactive Controls 2018: Enforce Access Controls
- Ferraiolo and Kuhn: Role-Based Access Controls (1992)
