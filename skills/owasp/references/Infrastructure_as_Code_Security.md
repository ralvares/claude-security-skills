# Infrastructure as Code Security Cheatsheet

<!---
Copyright 2021 Nokia
Licensed under the Creative Commons Attribution-ShareAlike 3.0 Unported License
SPDX-License-Identifier: CC-BY-SA-3.0
--->

## Introduction

Infrastructure as code (IaC), aka software-defined infrastructure: infrastructure config/deployment defined as code → faster, consistent, repeatable across environments.

### Security best practices

Practices easily integrated into SDLC:

### Develop and Distribute

- IDE plugins - Use standard security plug-ins in IDE: early risk detection, far less fix time later. E.g. TFLint, Checkov, Docker Linter, docker-vulnerability-extension, Security Scan, Contrast Security.
- Threat modeling - Build early in dev cycle: visibility of high-risk, high-volume code aspects; flexibility to include security throughout so assets managed safely.
- Managing secrets - Secrets = confidential data: app tokens for authentication, passwords, SSH (Secure Shell) keys. Problem = where stored, not secrets themselves. Plain text file or SCMs like Git → easily exposed. Detect w/ open-source tools: truffleHog, git-secrets, GitGuardian, similar. See [Secrets Management Cheat Sheet](Secrets_Management.md).
- Version control - Track and manage all IaC changes w/ right info for revert. Check in changes alongside features they support, not separately: feature's infrastructure requirements belong in feature's branch or merge request. Git generally used.
- Principle of least privilege - define access management policies by least privilege, priorities:
  
    - Define who is/is not authorized to create/update/run/delete scripts and inventory.
    - Limit authorized IaC users' permissions to what tasks need. IaC scripts must limit permissions granted to resources they create to what resources need.

- Static analysis - Analyzes code in isolation; finds risks, misconfigurations, compliance faults relevant only to IaC itself. Tools: kubescan, Snyk, Coverity etc.
- Open Source dependency check - Analyzes open source dependencies (OS packages, libraries etc.) for risks. Tools: BlackDuck, Snyk, WhiteSource Bolt for GitHub, similar.
- Container image scan - Analyze container image contents and build process for security issues, vulnerabilities, risks. Open-source tools: Dagda, Clair, Trivy, Anchore etc.
CI/CD pipeline and Consolidated reporting - security checks in CI/CD pipeline analyze each code change, remove manual intervention, keep compliance history. Consolidated reporting speeds secure IaC development. Jenkins etc. build pipelines; DefectDojo and OWASP Glue tie checks together, show results in single dashboard.
- Artifact signing - Digitally sign artifacts at build time, validate signed data before use → protects from tampering between build and runtime; ensures integrity and provenance. Open-source TUF helps.

### Deploy

- Inventory management:
    - Commissioning - on resource deploy, label, track, log in inventory management.
    - Decommissioning - on resource deletion, erase underlying configurations, securely delete data, remove resource completely from runtime and inventory management.
    - Tagging - Tag cloud assets properly. Untagged assets in IaC operations → ghost resources: hard to detect, visualize, observe; affect posture (drift); add billing cost, complicate maintenance, hurt reliability. Only solution: careful tagging + monitoring for untagged resources.
- Dynamic analysis - Evaluates existing environments and services it interoperates with/runs on; uncovers interoperability risks. Open-source tools: ZAP, Burp, GVM etc.

### Runtime

- Immutability of infrastructure - Build components to exact specifications; no deviation, no changes. Spec change → provision whole new infrastructure from updated requirements; take previous out of service as obsolete.
- Logging - Critical for watching risks. Enable security logs and audit logs while provisioning: assess risks to sensitive assets, root-cause incident analysis, identify threats. Open-source ELK etc. for log analysis.
- Monitoring - Continuous monitoring finds security/compliance violations, identifies attacks, alerts. Some solutions use AI to identify threats early. Open-source Prometheus, Grafana etc. for cloud infrastructure monitoring.
- Runtime threat detection: Recognizes unexpected app behavior, alerts on threats at runtime. Open-source Falco etc. Contrast (Contrast Community Edition) can also detect OWASP Top 10 attacks at runtime and block them.

## References

- Terraform: Manage sensitive data in your configuration
- NIST SP 800-218: Secure Software Development Framework
