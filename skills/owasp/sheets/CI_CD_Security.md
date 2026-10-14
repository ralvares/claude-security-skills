# CI/CD Security Cheat Sheet

## Introduction

CI/CD pipelines enable efficient, repeatable builds and deployments; important in modern SDLC. Also appealing targets for malicious hackers; security can't be ignored. Goal: practical guidelines for reducing risk of these components. Focus: securing pipeline itself. Brief background, then CI/CD security best practices.

### Definition and Background

CI/CD = largely automated processes to build and deliver software; often portrayed as pipeline of sequential, discrete steps. Starts when code pushed to repository; if all steps succeed, ends w/ software built, tested, deployed to production. Two parts: continuous integration (CI) and continuous delivery and/or continuous deployment (CD). CI: build and test automation; continuous delivery: promote built code to staging or higher environment, generally more automated testing. Delivery and deployment not always distinguished; per NIST, continuous delivery requires code manually pushed to production, continuous deployment automates even this step.

Exact steps vary by organization and project; automation, plus repeatability and agility it brings, should be core focus of any CI/CD implementation.

### Understanding CI/CD Risk

CI/CD increases attack surface. People, processes, technology all required and all attack avenues: code repositories, automation servers such as Jenkins, deployment procedures, nodes running pipelines. CI/CD steps frequently run w/ high-privileged identities → successful attacks have high damage potential. Adopting CI/CD → invest resources to secure it; Codecov and SolarWinds breaches show impact of CI/CD compromise.

Attacker methods diverse; certain risks more prominent. Knowing them helps allocate security resources. OWASP's Top 10 CI/CD Security Risks identifies top 10:

- CICD-SEC-1: Insufficient Flow Control Mechanisms
- CICD-SEC-2: Inadequate Identity and Access Management
- CICD-SEC-3: Dependency Chain Abuse
- CICD-SEC-4: Poisoned Pipeline Execution (PPE)
- CICD-SEC-5: Insufficient PBAC (Pipeline-Based Access Controls)
- CICD-SEC-6: Insufficient Credential Hygiene
- CICD-SEC-7: Insecure System Configuration
- CICD-SEC-8: Ungoverned Usage of Third-Party Services
- CICD-SEC-9: Improper Artifact Integrity Validation
- CICD-SEC-10: Insufficient Logging and Visibility

Rest of sheet: mitigating these top 10 and other CI/CD risks.

## Secure Configuration

Invest time and effort securing components enabling CI/CD, e.g. SCM systems and automation servers (Jenkins, TeamCity, etc). Never blindly rely on default vendor settings. Don't adjust settings w/o fully understanding implications, nor do configuration updates uncontrolled/ad-hoc. Need change management and governance. Education key: before using tool for critical, security-sensitive operations such as code deployment, understand underlying technology. Secure configuration not automatic; requires education and planning.

Also secure operating systems, container images, web servers, other infrastructure running or supporting CI/CD components. Keep patched; maintain asset inventory incl. software versions. Harden per standards such as CIS Benchmarks or STIGs where appropriate.

Specific CI/CD configuration guidelines below.

### Secure SCM Configuration

CI/CD allows code pushed to repository then deployed to production w/ little to no manual intervention. Becomes attack vector if untrusted, potentially malicious code deploys directly to production. Proper SCM configuration mitigates. Best practices:

- Avoid auto-merge rules in platforms such as GitLab, GitHub, Bitbucket.
- Require pull requests reviewed before merging; ensure review can't be bypassed.
- Use protected branches.
- Require signed commits
- Weigh risk vs benefits of ephemeral contributors. Limit number and permissions of external contributions when possible.
- Enable MFA where available
- Avoid default permissions for users and roles with access to SCM assets. Manage permissions carefully.
- Restrict ability to fork private or internal repositories.
- Limit option to change repository visibility to public.
Many more policies: Legitify policies documentation.

Tools help: Legitify, open-source tool by Legit security. Scans SCM assets, identifies misconfigurations and security issues, incl. policies for all above best practices (GitHub and GitLab).

### Pipeline and Execution Environment

Also securely configure automation servers running pipelines, e.g. Travis, TeamCity, Jenkins, CircleCI. Hardening varies by platform; general best practices:

- Build in appropriately isolated nodes (see Jenkins controller isolation example)
- Secure SCM-to-CI/CD communication w/ widely accepted protocols such as TLS 1.2 or greater.
- Restrict access to CI/CD environments by IP if possible.
- If feasible, store CI config file outside repository hosting code being built. If stored alongside code, review file before any merge request approved.
- Enable appropriate logging (see [Visibility and Monitoring](#visibility-and-monitoring) below)
- Incorporate language-appropriate SAST, DAST, IaC vulnerability scanning and related tools into pipeline.
- Require manual approval and review before triggering production deployment.
- Pipeline steps in Docker image: avoid `--privileged` flag (NCC Group research)
- Version control pipeline configuration code (CISA)
- Enforce MFA where possible

## IAM

Identity and Access Management (IAM) = managing digital identities and controlling their access to digital resources. Identities: system accounts, roles, groups, individual user accounts. IAM wide beyond CI/CD, but identity and credential mismanagement among most prominent CI/CD risks. Subsections: IAM best practices esp. relevant to CI/CD.

### Secrets Management

Secrets (API keys, passwords) often required for pipeline execution. Often numerous, some giving substantial access to sensitive systems/operations. Challenge: secure secret management while letting automated CI/CD processes access them. Simple guidelines substantially mitigate, not eliminate, risk.

First, reduce likelihood secrets stolen in usable format. Secrets **never** hardcoded in code repositories or CI/CD configuration files. Use tools such as git-leaks or git-secrets to detect. Prevent secrets ever being committed; ongoing monitoring to detect deviations. Remove secrets from other artifacts such as Docker images and compiled binaries. Always encrypt secrets using industry accepted standards. Encrypt at-rest in file-system, vault, similar store; also ensure secrets not disclosed or persisted in cleartext through CI/CD pipeline use. E.g., secrets must not be printed to console, logged, or stored in system command history files (such as `~/.bash-history`). Third-party solution such as HashiCorp Vault, AWS Secrets Manager, AKeyless, or CyberArk may be used.

Second, reduce impact if secrets stolen in attacker-usable format. Temporary credentials or OTPs reduce impact. Impose IP-based or other restrictions so even valid credentials can't access resources unless further requirements met. [Least Privilege](#least-privilege) and [Identity Lifecycle Management](#identity-lifecycle-management) sections: more techniques vs secrets theft.

More: [Secrets Management Cheat Sheet](Secrets_Management.md).

### Least Privilege

Least privilege, per NIST:

> The principle that a security architecture is designed so that each entity is granted the minimum system resources and authorizations that the entity needs to perform its function".

In CI/CD, apply to at least three areas: secrets used in pipeline steps to access external resources; access one pipeline or step has to other resources configured in CI/CD platform (OWASP pipeline-based access controls); permissions of OS user executing pipeline.

General guidance: access justified, not assumed. "Deny by default" mindset. Identities used in pipeline get only minimum permissions needed. E.g., pipeline accessing AWS service: AWS credentials can perform only specific operations on specific services and resources required. Minimize credential sharing across pipelines; never across pipelines of different sensitivity or value. If pipeline A doesn't need secrets pipeline B needs, ideally don't share. OS accounts running pipeline must not have root or comparable privileges; mitigates compromise impact.

### Identity Lifecycle Management

Secrets management and least privilege necessary for secure IAM, not sufficient. Carefully manage identity lifecycle, creation to deprovisioning, for CI/CD and other environments.

Initial "Joiner" phase of Identity Management (per ILM Playbook): use centralized IdP rather than local accounts, disallow shared accounts, disallow self-provisioning of identities, allow only email accounts with domains controlled by organization responsible for CI/CD environment (OWASP CI/CD identity and access management). Once provisioned, track, maintain, and when necessary deprovision identities. Complex, distributed CI/CD environments: keep accurate, comprehensive, up-to-date identity inventory. Format varies; besides identity itself, suggested fields: identity owner or responsible party, identity provider, last used, last updated, granted permissions, permissions actually used. Inventory exposes over-privileged identities and deprovisioning candidates. Don't overlook identity maintenance; "forgotten" identity can be attacker's vector into CI/CD system.

## Managing Third-Party Code

High-profile breaches such as SolarWinds raised software supply chain security attention. Especially pressing for CI/CD: interacts with third-party code multiple ways. Two areas below: dependencies used by projects in pipeline; third-party integrations and plug-ins of CI/CD system itself.

### Dependency Management

Third-party packages with known vulnerabilities: well-known problem, many tools. In CI/CD, automated SCA and comparable tools can improve security. But CI/CD environment faces related risk: dependency chain abuse.

Dependency chain abuse = exploiting flaws in system's dependency chain and dependency resolution; success → execution of malicious code from attacker-controlled package. Dependency chain = set of packages (internal, direct third-party, transitive) software needs to function. Attack methods: dependency confusion, typosquatting, takeover of valid package maintainer's account. Attacks can be complex, comprehensive defense correspondingly so; basic mitigations straightforward.

Mitigations begin early in SDLC, before pipeline runs. Configure project's package management technology (such as npm) so dependency references immutable (CISA et al. 2022). Pin versions; pinned version must be known valid and secure; validate integrity of any downloaded package by comparing hash or checksum to known good hash of pinned package. Procedures vary by project technology, but generally version pinning and hash verification via platform "lock" or similar file (i.e. package-lock.json or Pipfile.lock). [Enforce the lockfile](NPM_Security.md). Prefer private repositories where possible; configure package manager to use only single private feed (Microsoft's feed configuration guidance). For private packages use scoped NPM packages, ID prefixes for NuGet packages, or comparable feature to reduce dependency confusion risk. Regardless of platform, commit file(s) controlling these settings (such as `.npmrc` in node environments) to source control and make accessible in CI/CD environment.

### Plug-In and Integration Management

Most CI/CD platforms extensible via plug-ins or third-party integrations. Benefits incl. potentially improved security capabilities, but increase attack surface. Plug-ins not necessarily disallowed; consider and reduce risk to acceptable level.

Treat plug-in installation or third-party service integration like any software acquisition. Easy to install doesn't mean ungoverned. Enforce least privileges so only small subset of users can extend CI/CD platforms. Vet extensions before installation. Questions, as before any software acquisition:

- Is vendor recognized and respected developer or company?
- Does vendor have strong or weak application security history?
- How popular is specific plug-in or integration endpoint?
- Is plugin or integration actively maintained?
- Will extension require configuration changes that could reduce security (such as exposing additional ports)?
- Does organization have experience and resources to properly configure and maintain offering?

After approval, incorporate into configuration management processes. Keep up-to-date, esp. security patches. Continually review value; remove if no longer needed.

## Integrity Assurance

CI/CD exploits often require attackers inserting themselves into pipeline flow and modifying inputs and/or outputs of steps. Integrity verification important risk reducer.

Integrity controls begin early in SDLC. As noted, SCM should require signed commits before merge. Per [Dependency Management](#dependency-management), package management platform should use hashes or comparable to verify package integrity. Also employ code signing; technologies such as Sigstore or Signserver. Code signing and related technologies ≠ absolute guarantors; code signing processes themselves can be exploited. See NIST's Security Considerations for Code Signing for securing code signing processes. Integrating in-toto framework or similar further improves integrity in CI/CD.

## Visibility and Monitoring

CI/CD environments complex, often opaque-box to developers. Visibility critical for detecting potential attacks, understanding risk posture, detecting and remediating vulnerabilities. Logging and log analysis vital though value often underestimated.

First: logging configuration in CI/CD environment compliant w/ organization's log management policy. Also log in readily parsable format such as JSON or syslog. Carefully consider content and verbosity. Proper logging allows end-to-end pipeline visibility, but more logging not inherently better: consider storage costs, avoid logging sensitive data. E.g., most authentication-related events likely logged; never log plaintext passwords, authentication tokens, API keys, or similar secrets.

After logging strategy and configuration: use logs to reduce risk. First step: send aggregate logs to centralized log management system or, preferably, SIEM. With SIEM, carefully configure and regularly refine alerts for timely anomaly and attack alerts. Configuration varies by CI/CD environment, SIEM platform, other factors. ELK Stack (popular SIEM platform) CI/CD observability overview: Elastic observability docs; alternative readily adaptable approach: DZone Jenkins log monitoring with ELK. SIEM alerts never 100% accurate detecting CI/CD attacks; false positives and false negatives occur. Don't rely unquestioningly, but they give important visibility and act as important alert systems when thoughtfully configured.

## References

- CISA, NSA, and ODNI: Securing the Software Supply Chain - Recommended Practices for Developers
- NIST: Security Considerations for Code Signing
