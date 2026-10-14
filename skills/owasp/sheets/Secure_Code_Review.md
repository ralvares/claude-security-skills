# Secure Code Review Cheat Sheet

## Introduction

**Secure Code Review**: manually examine source code for security vulnerabilities automated tools often miss. Analyze application logic, data flow, implementation details; needs human expertise + context.

**Manual Code Review** complements automated testing (SAST/DAST), focusing where humans add most value: business logic validation, complex security implementations, context-specific vulnerabilities. Tools can highlight areas of concern; core analysis relies on human judgment + domain expertise.

**Security-Focused Review** differs from functional review: targets input validation, authentication mechanisms, authorization controls, cryptographic implementations, attack vectors.

### Review Types

**Baseline Reviews**: examine entire codebase. Use for:

- New applications or major releases
- Legacy system onboarding
- Compliance requirements
- Post-incident analysis

**Diff-Based Reviews**: code changes only. Use for:

- Pull requests and commits
- Daily development workflow
- Feature completion
- Continuous security validation

Practical guidance for manual security code reviews, baseline + incremental methodologies.

## Review Methodology

### Preparation

**For All Reviews:**

- Understand architecture + business requirements
- Gather [threat models](Threat_Modeling.md) + previous security findings
- Identify critical assets, high-risk functions
- Review security requirements + documentation

**Additional for Baseline Reviews:**

- Map complete [application boundaries and dependencies](Attack_Surface_Analysis.md)
- Analyze overall security architecture
- Review security incident history
- Audit all third-party libraries

**Additional for Diff-Based Reviews:**

- Identify modified files + affected components
- Assess impact on existing security controls
- Understand purpose of changes
- Prioritize high-risk modifications

### Review Process

**Baseline Review Steps:**

1. Architecture review for security anti-patterns
2. Entry point analysis + input validation
3. Authentication + authorization verification
4. Data flow tracing
5. Business logic analysis
6. Cryptographic implementation review
7. Error handling verification
8. Configuration + deployment review

**Diff-Based Review Steps:**

1. Analyze impact on existing security controls
2. Identify new attack vectors
3. Verify security at modified trust boundaries
4. Check new integrations
5. Ensure no security regression
6. Apply relevant security patterns

## Common Vulnerability Patterns

Request forgery + redirect checks: also see [CSRF Prevention](Cross-Site_Request_Forgery_Prevention.md), [SSRF Prevention](Server_Side_Request_Forgery_Prevention.md), [Unvalidated Redirects and Forwards](Unvalidated_Redirects_and_Forwards.md) cheat sheets.

### Input Validation Vulnerabilities

Check missing server-side validation, improper sanitization, weak input filtering. See [Input Validation Cheat Sheet](Input_Validation.md), [Mass Assignment Cheat Sheet](Mass_Assignment.md).

### Injection Vulnerabilities

**SQL Injection:**

Look for string concatenation in database queries, unsafe query construction. See [SQL Injection Prevention Cheat Sheet](SQL_Injection_Prevention.md).

**Cross-Site Scripting (XSS):**

Review output encoding, DOM manipulation, user input rendering. See [Cross Site Scripting Prevention Cheat Sheet](Cross_Site_Scripting_Prevention.md).

**Path Traversal:**

Check unsafe file path construction, directory traversal. See [File Upload Cheat Sheet](File_Upload.md).

**Command Injection:**

Identify direct command execution w/ user input, unsafe system calls. See [OS Command Injection Defense Cheat Sheet](OS_Command_Injection_Defense.md).

**NoSQL Injection:**

Examine NoSQL query construction + parameter binding. See [NoSQL Security Cheat Sheet](NoSQL_Security.md).

### Authentication & Session Management Vulnerabilities

Review authentication mechanisms, session token generation, user credential handling. See [Authentication Cheat Sheet](Authentication.md), [Session Management Cheat Sheet](Session_Management.md).

### Access Control Vulnerabilities

Examine authorization checks, role-based access controls, privilege escalation prevention. See [Authorization Cheat Sheet](Authorization.md).

### Deserialization Vulnerabilities

**Insecure Deserialization:**

Check unsafe deserialization of untrusted data, object injection. See [Deserialization Cheat Sheet](Deserialization.md).

**XML External Entity (XXE):**

Review XML parsing configurations, external entity processing. See [XML External Entity Prevention Cheat Sheet](XML_External_Entity_Prevention.md).

### Cryptographic Implementation Flaws

Examine encryption algorithms, key management, cryptographic implementations. See [Cryptographic Storage Cheat Sheet](Cryptographic_Storage.md).

## Review Techniques

### Code Pattern Analysis

Focus on high-risk code patterns:

- Input processing + validation functions
- Database query construction, ORM usage
- File operations, path handling
- Authentication + session management logic
- Authorization + access control checks
- Cryptographic operations, key management
- Error handling + logging mechanisms
- Configuration loading + environment variables

### Data Flow Analysis

Trace data through application:

1. **Identify Sources**: user inputs, file uploads, API calls, database reads, environment variables
2. **Follow Processing**: validation, transformation, business logic, caching
3. **Check Sinks**: database queries, file writes, output rendering, logging, external APIs
4. **Validate Boundaries**: input validation + output encoding at trust boundaries
5. **Trust Zones**: verify security controls at each trust boundary crossing
6. **Data Classification**: sensitive data gets appropriate protection

### Threat-Based Review

Align review with common attack patterns:

- **OWASP Top 10**: prevalent web application risks
- **STRIDE Model**: Spoofing, Tampering, Repudiation, Information Disclosure, DoS, Elevation
- **Attack Trees**: map potential attack paths
- **Abuse Cases**: how attackers could misuse features
- **Security Controls**: verify defense-in-depth implementation

### Business Logic Review

Use [Abuse Case Cheat Sheet](Abuse_Case.md) to identify misuse scenarios.

Analyze workflows for:

- State management + transition validation
- Race conditions + concurrency issues
- Transaction integrity + rollback mechanisms
- Resource limits + quota enforcement
- Authorization at each workflow step
- Workflow bypass opportunities

## Review Checklists

### Input Validation

- [ ] **Server-side validation**: all inputs validated on server regardless of client-side checks
- [ ] **Allowlist validation**: allowlists, not blocklists
- [ ] **Output encoding**: context-appropriate encoding (HTML, JavaScript, CSS, URL)
- [ ] **File upload security**: content-based validation, size limits, safe storage
- [ ] **SQL injection prevention**: [Parameterized queries or safely implemented stored procedures](SQL_Injection_Prevention.md#primary-defenses) used; user-controlled data values passed as parameters, not concatenated into SQL
- [ ] **Length limits**: input length restrictions enforced
- [ ] **Character handling**: special characters + Unicode properly processed
- [ ] **Error messages**: no sensitive info in error responses

### Authentication & Session Management

- [ ] **Password security**: strong hashing algorithms + salt (see [Password Storage Cheat Sheet](Password_Storage.md))
- [ ] **Account protection**: lockout mechanisms w/ appropriate thresholds
- [ ] **Session management**: secure token generation (≥128 bits entropy)
- [ ] **Session lifecycle**: proper invalidation on logout/timeout
- [ ] **Re-authentication**: required for sensitive operations
- [ ] **Multi-factor authentication**: implemented for high-risk accounts (see [Multifactor Authentication Cheat Sheet](Multifactor_Authentication.md))
- [ ] **Password reset**: secure, time-limited reset mechanisms (see [Forgot Password Cheat Sheet](Forgot_Password.md))
- [ ] **Session security**: HttpOnly, Secure, SameSite cookie attributes
- [ ] **Concurrent sessions**: appropriate limits + monitoring

### Authorization

- [ ] **Server-side enforcement**: all access controls enforced server-side
- [ ] **Fail-safe defaults**: default deny
- [ ] **IDOR prevention**: proper authorization for resource access (see [Insecure Direct Object Reference Prevention Cheat Sheet](Insecure_Direct_Object_Reference_Prevention.md))
- [ ] **Function-level controls**: administrative functions protected
- [ ] **Role validation**: role assignments cannot be manipulated
- [ ] **Privilege escalation**: horizontal + vertical escalation prevented
- [ ] **Centralized decisions**: access control logic centralized
- [ ] **Post-authentication checks**: authorization verified after authentication

### Cryptography

- [ ] **Strong algorithms**: modern algorithms (AES-256, RSA-2048+, ECDSA P-256+)
- [ ] **Key management**: proper key generation, storage, rotation (see [Key Management Cheat Sheet](Key_Management.md))
- [ ] **Certificate validation**: proper validation incl. hostname verification
- [ ] **Random generation**: cryptographically secure random number generation
- [ ] **Data protection**: encryption at rest + in transit
- [ ] **IV/Nonce handling**: follow selected mode's requirements for initialization vectors (IVs) + nonces. E.g., cipher block chaining (CBC) requires unpredictable IVs (NIST SP 800-38A), while Galois/Counter Mode (GCM) requires IV uniqueness under each key (NIST SP 800-38D) and permits deterministic generation
- [ ] **Library maintenance**: up-to-date cryptographic libraries
- [ ] **Side-channel protection**: consider timing + other side-channel attacks

### Business Logic

- [ ] **Workflow integrity**: proper state validation in multi-step processes
- [ ] **Race condition prevention**: synchronization in concurrent operations
- [ ] **Transaction atomicity**: proper rollback + consistency mechanisms
- [ ] **Resource limits**: rate limiting + resource quotas implemented (see [Denial of Service Cheat Sheet](Denial_of_Service.md))
- [ ] **Business rule enforcement**: rules cannot be bypassed via direct API access

### Configuration & Deployment

- [ ] **Secure defaults**: security-focused default configurations
- [ ] **Environment separation**: proper isolation between environments
- [ ] **Secrets management**: no hardcoded secrets, proper secret storage + rotation (see [Secrets Management Cheat Sheet](Secrets_Management.md))
- [ ] **Error handling**: graceful, no information disclosure (see [Error Handling Cheat Sheet](Error_Handling.md))
- [ ] **Logging security**: sensitive data not logged, logs protected (see [Logging Cheat Sheet](Logging.md))
- [ ] **Security headers**: appropriate HTTP security headers (see [HTTP Headers Cheat Sheet](HTTP_Headers.md))
- [ ] **TLS configuration**: strong cipher suites + protocol versions (see [Transport Layer Security Cheat Sheet](Transport_Layer_Security.md))
- [ ] **Dependency management**: up-to-date libraries w/o known vulnerabilities (see [Vulnerable Dependency Management Cheat Sheet](Vulnerable_Dependency_Management.md))

### Security Monitoring

- [ ] **Security events**: authentication failures, authorization violations logged
- [ ] **Anomaly detection**: unusual patterns/behaviors monitored
- [ ] **Audit trails**: complete audit logs for sensitive operations
- [ ] **Real-time alerts**: critical security events trigger immediate notifications
- [ ] **Log integrity**: logs protected from tampering + unauthorized access
- [ ] **Incident response**: clear procedures for security incident handling

## Tools and Techniques

### Code Editors

Editors w/ security extensions:

- Visual Studio Code w/ ESLint, SonarLint
- IntelliJ IDEA w/ SpotBugs, SonarLint
- Eclipse w/ security plugins
- Vim/Neovim w/ security linters

### Command-Line Pattern Detection

```bash
# Find hardcoded secrets
grep -ri "password\s*=\|api_key\s*=\|secret\s*=" source/

# Find unsafe functions
grep -r "eval(\|exec(\|innerHTML\|document\.write" source/

# Find potential injections
grep -r "SELECT.*+\|executeQuery.*+" source/
```

### Manual Review Focus Areas

**Human Expertise Advantages:**

- **Business Logic Flaws**: complex workflows, state management issues needing domain understanding
- **Context-Specific Vulnerabilities**: issues depending on application-specific business rules
- **Authorization Logic**: complex permission models, access control implementations
- **Race Conditions**: timing-based vulnerabilities in concurrent operations
- **Cryptographic Misuse**: proper implementation of cryptographic primitives + protocols
- **Architecture Security**: high-level design flaws, security anti-patterns

**Manual Analysis Techniques:**

- **Code Path Tracing**: follow execution paths through complex business logic
- **State Analysis**: understand state transitions + validation
- **Trust Boundary Mapping**: identify/analyze security control points
- **Threat Modeling Integration**: apply threat models to specific code
- **Attack Scenario Simulation**: mentally simulate attack paths through code

### Automated Tool Integration

**Supporting Manual Reviews:**

- **SAST Tool Triage**: use automated findings to prioritize manual review areas
- **Dependency Scanning**: identify vulnerable libraries needing manual assessment
- **Code Quality Metrics**: focus manual effort on complex or frequently changed code
- **Pattern Detection**: tools highlight potential security anti-patterns for human analysis

**Tool Integration Strategy:**

- **Pre-Review Scanning**: run automated tools before manual review to find obvious issues
- **Complementary Analysis**: tool findings guide deeper manual investigation
- **False Positive Filtering**: human judgment validates automated findings
- **Coverage Gaps**: manual review targets areas tools cannot effectively analyze

**Security Metrics:**

- **Manual Review Coverage**: percentage of critical code paths reviewed by humans
- **Finding Quality**: ratio of valid security issues to total findings
- **Review Efficiency**: manual review time vs. security value delivered
- **Trend Analysis**: security posture improvement over time

### Documentation Templates

**Finding Report Template:**

```text
Title: [Vulnerability Type] in [Component]
Severity: [Critical/High/Medium/Low]
CWE: [CWE Number and Name]
Location: [File:Line or Function]
Description: [Detailed explanation of the vulnerability]
Impact: [Security implications and potential attack scenarios]
Reproduction: [Steps to reproduce or proof of concept]
Recommendation: [Specific fix guidance with code examples]
References: [CWE links, OWASP references, vendor documentation]
Status: [Open/In Progress/Fixed/Accepted Risk]
Assignee: [Developer responsible for fix]
Due Date: [Target fix date]
```

**Review Summary Template:**

```text
Review Summary
==============
Application: [Application Name]
Version: [Version/Commit Hash]
Reviewer(s): [Names]
Review Date: [Date]
Scope: [Files/Components Reviewed]

Findings Summary:
- Critical: [Count]
- High: [Count] 
- Medium: [Count]
- Low: [Count]
- Informational: [Count]

Key Recommendations:
1. [Priority recommendation]
2. [Priority recommendation]
3. [Priority recommendation]

Overall Risk Assessment: [Low/Medium/High/Critical]
```

## Integration with SDLC

### Review Timing

#### Baseline Review Integration

- **Project Initiation**: comprehensive security assessment of existing codebase
- **Major Releases**: full security review before significant version releases
- **Architecture Changes**: complete review on fundamental design changes
- **Compliance Cycles**: periodic comprehensive reviews for regulatory requirements
- **Security Incidents**: thorough review after breaches/major vulnerabilities
- **Onboarding Legacy Systems**: initial security assessment when bringing existing applications under secure development practices

#### Diff-Based Review Integration

- **Pull Requests**: security-focused review of changes in standard PR process
- **Pre-commit Hooks**: lightweight security checks on developer commits
- **Feature Completion**: security review of completed user stories/features
- **Sprint Reviews**: regular assessment of security implications of sprint deliverables
- **Hotfix Reviews**: rapid security assessment of emergency fixes
- **Continuous Integration**: automated triggering of security reviews on code changes

#### Hybrid Approach

- **Risk-Based Scheduling**: baseline reviews for high-risk components + diff-based for routine changes
- **Incremental Baseline Updates**: gradually expand baseline coverage over multiple development cycles
- **Trigger-Based Reviews**: escalate diff-based → baseline when significant security concerns identified

CI/CD integration + automated security testing: [CI CD Security Cheat Sheet](CI_CD_Security.md).

### Team Collaboration

**Roles:**

- **Security reviewers**: conduct analysis, provide guidance
- **Developers**: implement fixes, follow secure coding practices
- **Security champions**: bridge security + development teams

**Best Practices:**

- Standardized checklists + templates
- Maintain knowledge base of common issues
- Track metrics on review effectiveness
- Regular security training
- Integrate w/ existing development workflows

## Advanced Techniques

### Race Condition Analysis

Focus on Time-of-Check vs Time-of-Use (TOCTOU) vulnerabilities; ensure atomic operations.

### Business Logic Analysis

Analyze workflows for:

- State transitions + validation
- Opportunities to bypass steps/validation
- Proper validation at each workflow step
- Rollback mechanisms + cleanup on failures
- Behavior under concurrent access
- Boundary conditions + error scenarios

### Security Architecture Review

Review architecture patterns for consistent security enforcement + proper API security controls; see [Secure Product Design Cheat Sheet](Secure_Product_Design.md).

### Memory Safety

Review buffer management, integer overflow protection, resource limits.

## References

- OWASP Code Review Guide, Version 2
- NIST SP 800-218: Secure Software Development Framework (SSDF) Version 1.1
