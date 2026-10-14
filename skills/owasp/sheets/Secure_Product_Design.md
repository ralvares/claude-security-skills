# Secure Product Design Cheat Sheet

## Introduction

Goal: all products meet/exceed organization security requirements set in development lifecycle; every product security decision = explicit choice giving correct security level.

## Methodology

Start: secure defaults, minimize attack surface, fail securely to those well-defined defaults.

Two processes:

1. **_Product Inception_**; and
2. **_Product Design_**

First: when product conceived or existing product re-invented. Second: continuous, evolutionary, agile, close to where code is written.

## Security Principles

### 1. The principle of Least Privilege and Separation of Duties

Least Privilege: users get minimum access needed for job, no more. Reduces unauthorized access risk to sensitive data/systems.

Separation of duties: internal control principle, checks and balances so no single individual controls all aspects of a transaction. Assign different tasks to different people. Reduces fraud + errors, ensures tasks complete timely, maintains integrity of financial records.

### 2. The principle of Defense-in-Depth

Multiple layers of security controls protect assets; if one layer fails, others still protect. Layers: physical, network, application, data security. Goal: environment resilient to attack, quickly detects/responds to incidents. Reduces successful-attack risk, limits damage.

### 3. The principle of Zero Trust

Assume all users, devices, networks untrusted; verify before access, even inside organization's network. All access requests authenticated + authorized. Continuously monitor + audit user activity so access goes only to those who need it. Reduces data breach/incident risk.

### 4. The principle of Security-in-the-Open

Security in open source development. Developers aware of security implications of code and act: secure coding practices, vulnerability testing, secure development tools, collaboration with security experts.

## Security Focus Areas

### 1. Context

Where does application fit in organization's ecosystem, which departments use it and why? What data, what resulting risk profile?

Context built via [Threat Modeling](Threat_Modeling.md) (adds security stories during **_Product Design_** every iteration of _product delivery_) and Business Impact Assessment (sets correct Product Security Levels during **_Product Inception_**).

Context is all important: over-engineering security can cost even more than over-engineering scale/performance, but under-engineering can be devastating too.

### 2. Components

Libraries (selected in any **_Product Design_** stage) to external services (changes happen in **_Product Inception_**): what makes up application, how are parts kept secure? Use library of secure design patterns + ready-to-use components from Golden Path / Paved Road documentation; analyze choices via [Threat Modeling](Threat_Modeling.md).

Component review also covers commercial aspects (licensing, maintenance) and required usage limits.

### 3. Connections

How do you interact with application, how does it connect to components/services? Where is data stored, how accessed? Connections can also describe intentional lack of connections. Consider tier segregation per required Product Security Levels, and segregation of data/whole environments per tenant if required.

Adding/removing connections probably signals **_Product Inception_**.

### 4. Code

Code = ultimate expression of product intent; functional first, but quality of how functionality is provided must meet/exceed expectations.

Secure coding basics:

   1. Input validation: check input types, formats, lengths, business constraints before processing. SQL data values: use [parameterized queries](SQL_Injection_Prevention.md#primary-defenses); validation doesn't replace parameterization. Enforce buffer bounds separately w/ memory-unsafe components.
   2. Error handling: handle errors/exceptions securely, e.g. log securely, don't disclose sensitive info to attacker.
   3. Authentication and Authorization: strong mechanisms so only authorized users access sensitive data/resources.
   4. Cryptography: protect data in transit + at rest, e.g. HTTPS, encryption; expected levels per Product Security Level often in Golden Path / Paved Road documentation.
   5. Least privilege: code and host system get minimum access rights needed.
   6. Secure memory management: use high-level languages recommended in Golden Path / Paved Road documentation or manage memory properly to prevent buffer overflows, use-after-free.
   7. Avoiding hardcoded secrets: no hardcoded passwords/encryption keys in code; store in secure storage.
   8. Security testing: test for vulnerabilities during development and just prior to deployment.
   9. Auditing and reviewing the code: regularly audit/review for vulnerabilities, e.g. automated tools or third-party review.
   10. Keeping up-to-date: latest security best practices + vulnerability fixes.

Integrate plausibility checks at each application tier (e.g., frontend to backend). Write unit + integration tests validating all [Threat Modeling](Threat_Modeling.md) threats mitigated to organization-acceptable risk. Compile use-cases and [abuse-cases](Abuse_Case.md) per tier.

### 5. Configuration

Secure build easily undone by insecure configuration. Minimum:

1. Least Privilege: limit access/permissions of system components and users to minimum needed.
2. Defense-in-Depth: multiple layers of security controls vs wide range of threats.
3. Secure by Default: systems/software secure by default, minimal manual setup.
4. Secure Data: encrypt sensitive data (personal, financial) in transit + at rest. Also correct backups and data retention set for desired Product Security Level.
5. Fail Securely: systems fail in secure state, not exposing vulnerabilities on malfunction.
6. Secure Communications: secure protocols (e.g., HTTPS) vs eavesdropping/tampering.
7. Regular updates, or use maintained images: keep software, docker images, base operating systems current with latest security patches.
8. Practiced Security Incident response plan: minimizes damage from successful attack; crucial part of Product Support Model.

Precise secure configuration: [Infrastructure as Code Security Cheat Sheet](Infrastructure_as_Code_Security.md)

## References

- NIST SP 800-218: Secure Software Development Framework (SSDF) Version 1.1
- OWASP: Threat Modeling
