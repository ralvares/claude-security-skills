# Software Supply Chain Security

## Introduction

All software embedded in Software Supply Chain (SSC). NIST: entity's SSC = "a collection of steps that create, transform, and assess the quality and  policy conformance of software artifacts". Steps span entire SDLC, use many components/tools. Common developer-relevant components (non-exhaustive):

- IDEs and code editors
- Internally developed source code
- Third-party software libraries
- Version control systems (VCS)
- Build tools (Maven, Rake, make, Grunt, etc.)
- CI/CD software (Jenkins, CircleCI, TeamCity, etc.)
- Configuration management tools (Ansible, Puppet, Chef, etc.)
- Package management software and ecosystems (pip, npm, Composer, etc.)

Secure each component; flaw in one (vulnerable third-party dependency, misconfigured VCS) endangers whole SSC. To strengthen Software Supply Chain Security (SCSS), developers need general understanding of SSC, common threats, risk-reducing practices.

## Overview of Threat Landscape

Threat landscape as broad as SSC. Threats: dependency confusion, upstream provider infrastructure compromise, code signing certificate theft, CI/CD system exploits. Four categories by targeted component (Google supply-chain threat categories, SLSA 1.0 threats):

- Source code threats. Violate integrity of source code later built, deployed, or consumed by other projects. Include VCS exploits, malicious/vulnerable code introduced into codebase, building from unauthorized branch.
- Build environment threats. Modify artifact w/o altering source or exploiting build process itself. E.g., build cache poisoning, compromising privileged account used by build tool, publishing software built from untrusted source.
- Dependency related threats. From consuming direct and transitive dependencies. Most common: using vulnerable/compromised dependency.
- Deployment and runtime threats. Exploit deployment process or runtime environment. E.g., compromising privileged CI/CD account, software misconfigurations, deploying compromised binaries.

Threat actors diverse. SSC compromise often associated w/ sophisticated actors, but sophistication not required, esp. against entities w/ poor security practices. Motives vary: SSC exploit can cost confidentiality, integrity, and/or availability of any organization's assets → espionage, financial gain, etc.

Many SSC threats propagate across entities via consumer-supplier relationship. Compromised large supplier (proprietary or open-source) → many downstream consumers impacted. Examples: 2020 SolarWinds, 2021 Codecov.

## Mitigations and Security Best Practices

Mitigation feasible: even vs. upstream supplier compromise, organization can take reasonable steps to defend own assets. Some SCSS parts outside dev team control; teams still do their part. Guidance below = starting point.

### General

General techniques mitigating wide variety of threat types.

#### Implement Strong Access Control

  Compromised accounts, esp. privileged, = significant SSC threat. Account takeover enables injecting code into legitimate dependencies, manipulating CI/CD pipeline execution, replacing benign artifact with malicious one. Strong access control for build, development, version control, similar environments critical. Practices: least privilege, separation of duties, enforce MFA, rotate credentials, never store/transmit credentials in clear text or commit to source control.

#### Logging and Monitoring

  Detective controls essential for detecting attacks, enabling prompt response. Logging critical. All SSC systems (VCS, build tools, delivery mechanisms, artifact repositories, systems running applications) must log authentication attempts, configuration changes, other events aiding anomaly identification or incident response. Logs throughout SSC must have sufficient depth and breadth to support detection and response.

  Logging not enough: monitor logs, act if necessary. Prefer centralized SIEM, log aggregator, or similar given SSC complexity. Log data must be actionable.

#### Leverage Security Automation

Complex SSCs: automate security tasks (scanning, monitoring, testing). Not replacement for manual review by skilled professionals, but detects (sometimes responds to) vulnerabilities/attacks at scale and consistency hard to reach manually. Tool types: SAST, DAST, SCA, container image scanners, more. Best tools vary by organization. Tools themselves must be maintained, secured, configured correctly; otherwise may increase SSC risk or bring no benefit. Tools = one component of overall SCSS program; not comprehensive, can't be relied on to find all vulnerabilities.

### Mitigating Source Code Threats

Reduce SSC risk tied to source code and development.

#### Peer Reviews

Manual code reviews: important, relatively low cost; detective controls and deterrents. Reviewers: peers experienced in technology and secure coding; review before merge in source control system (Google source safeguards). Look for unintentional security flaws and intentional malicious code. Document results for later review.

#### Secure Config of Version Control Systems

VCS compromise/abuse consistently recognized as significant SSC risk (Google supply-chain threat categories, SLSA 1.0 threats). Strong access control, logging and monitoring help secure VCS. Use VCS-specific security features too, e.g., protected branches and merge policies in git. Recommended policies: policies.legitify.dev. Tools help manage SCM config, e.g., Legitify (open-source, Legit security): detects misconfigurations in GitHub and GitLab, assists best-practice implementation. Whatever controls added, never commit secrets to VCS.

#### Secure Development Platform

IDEs, development plugins, similar tools can have vulnerabilities, become attack vector. Use tools securely and secure underlying system. Development system: endpoint security software, threat assessments (ESF developer practices). Only trusted, well-vetted software in development, incl. "core" tools (IDEs) and plugins/extensions. Include these tools in organization's system inventory.

### Mitigating Dependency Threats

Secure dependency use:

#### Assess Suppliers

Before incorporating third-party service, product, or component into SSC, thoroughly assess vendor and specific offering for security. Applies to open-source and proprietary. Form/extent of analysis varies w/ criticality and nature of component. Component maturity, security history, vendor response to past vulnerabilities useful nearly always. Larger vendors/offerings: check evaluation against third-party assessments/certifications, e.g., FedRAMP, CSA, ISO standards (ISO/IEC 27001, ISO/IEC 15408,
ISO/IEC 27034); useful data point, must not be relied on exclusively.

Open-source transparency gives extra assessment opportunities. Questions (OpenSSF component evaluation):

- Actively maintained?
- Sufficiently popular and well-known in community?
- Sufficiently mature?
- Product/version evaluated a "release" version, e.g. not alpha, beta, or comparable?
- Given complexity, sufficient maintainers and contributors?
- Keeps its dependencies updated?
- Sufficient test coverage, tests include security relevant rules?
- Well-documented, incl. guidance on secure use?
- Established, documented vulnerability reporting process; vulnerabilities addressed timely?
- Intended usage consistent w/ project's license?

#### Understand and Monitor Software Dependencies

Third-party dependencies speed development but are leading risk in modern apps. Select carefully; monitor and maintain throughout SDLC. First step: insight into consumed dependencies, e.g., SBOMs. Automate SBOM production and consumption, preferably in CI/CD.

Once inventoried, monitor for known vulnerabilities, automated as much as possible; tools: OWASP Dependency Check, retire.js. Also monitor sources like NVD, OSVDB, CISA KEV catalog for vulnerabilities in dependencies used in SSC.

#### SAST

SAST for custom code is widely used; also applicable to OSS components in SSC (ESF developer practices). Tools give false positives and false negatives: don't accept SAST results w/o manual verification; not comprehensive view of project security. Useful on internal and OSS code if limitations understood.

#### Lockfile/Version Pinning

Limit dependencies to specific previously verified legitimate, secure versions → avoids unwittingly pulling compromised/vulnerable version. Commonly via lockfiles like npm's package-lock.json.

### Build Threats

Techniques for build-related threats.

#### Inventory Build Tools

Know SSC components, incl. build tools. Automatically collect and maintain inventory of all build tools, versions, plugins. Monitor vulnerability databases, vendor advisories, other sources for vulnerabilities in identified build tools.

#### Harden Build Tools

Compromised build tools enable wide range of exploits; appealing target. Harden all build infrastructure/tools. Techniques (ESF developer practices):

- Locate build tools in appropriately segregated networks.
- Use DLP and other tools/techniques to detect and prevent exfiltration.
- Disable/remove unused services.
- Use version control systems to manage and store pipeline configurations.

#### Enforce Code Signing

Consumers: accept only digitally signed components, validate signature before use → ensures authentic, untampered component. Signers: thoroughly harden code signing infrastructure; else compromise of signing system enables further exploits, incl. against consumers.

#### Use Private Artifact Repository

Private artifact repository increases control over artifacts used in SSC. Review artifacts before admitting to repository; ensure repository usage can't be bypassed. May add maintenance or reduce agility, but important for SCSS, esp. sensitive/critical apps.

#### Use Source Control for Build Scripts and Config

VCS benefits extend beyond source, esp. CI/CD pipeline config and scripts. Version control lets reviews, merge rules, similar controls apply to config updates. Also increases visibility into changes, malicious or benign (ESF developer practices).

#### Verify Provenance/Ensure Sufficient Metadata is Generated

Assurance that SSC component comes from trusted source and untampered is important. Generate and consume provenance, defined in SLSA 1.0 as "the verifiable information about software artifacts describing where, when and how something was produced". Provenance: generated by build platform (not local dev system), very difficult for attackers to forge, contains all details needed to link result back to builder (SLSA 1.0 provenance requirements). SLSA 1.0 compliant provenance generatable with builders like FRSCA or Github Actions; verify using SLSA Verifier.

#### Ephemeral, Isolated Builds

Reused/shared build environments allow cache poisoning or easier malicious code injection. Build in isolated, temporary ("ephemeral") environments, e.g., VMs or containers destroyed immediately afterward.

#### Limit use of Parameters

User-controllable build parameters add flexibility and risk. Attacker with sufficient permission can modify parameters, potentially compromise build (Google build safeguards). Minimize or eliminate user-controllable build parameters.

### Deployment and Runtime Threats

Techniques protecting software during deployment and runtime.

#### Scan Final Build Binary

Don't assume final build result is secure. Binary composition analysis detects exposed secrets, unauthorized components/content, verifies integrity (ESF developer practices). Both suppliers and consumers should do this.

#### Monitor Deployed Software for Vulnerabilities

SCSS continues after deployment: monitor and maintain deployed software. New vulnerabilities (from update or newly discovered/public) are continual concern (Google supply-chain threat categories). Monitor holistically: code dependencies, container images, web servers, OS components, etc. Needs accurate up-to-date inventory of system components. Also monitor and act on insecure configuration changes.

## References

- NIST SP 800-204D: Strategies for the Integration of Software Supply Chain Security in DevSecOps CI/CD Pipelines
- Securing the Software Supply Chain: Recommended Practices Guide for Developers
- SLSA 1.0: Requirements
