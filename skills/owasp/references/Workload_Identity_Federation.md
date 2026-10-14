# Workload Identity Federation Cheat Sheet

## Introduction

Use workload identity federation instead of stored long-lived cloud credentials for continuous integration and continuous deployment (CI/CD), when both platforms support it. Covers OpenID Connect (OIDC) federation for deployment jobs. Removes need for reusable cloud key in pipeline (GitHub OIDC overview). Manage non-replaceable secrets via [Secrets Management Cheat Sheet](Secrets_Management.md).

Federation doesn't make compromised job trustworthy. Code in authorized job can use its identity and credentials. Keep untrusted pull request code out of jobs that can obtain production access; apply [CI/CD Security Cheat Sheet](CI_CD_Security.md) and, where applicable, [GitHub Actions Security Cheat Sheet](GitHub_Actions_Security.md). See GitHub's compromised runner risks explanation.

## Understand the Trust Boundary

CI/CD platform issues signed OIDC token describing job. Job presents it to cloud provider, which validates against configured trust policy before issuing temporary credentials (access tokens or temporary access keys, per provider). Use provider's supported federation integration; do not implement token validator in pipeline. See Google Cloud deployment pipeline integration.

Validating token against configured trusted issuer ≠ authorizing production access. Configure both controls:

- **Trust policy:** which external workloads may obtain credentials.
- **Permissions policy:** which resources/operations credentials authorize. Tightly scoped trust policy doesn't compensate for administrative deployment role. AWS distinguishes role's trust and permissions policies.

## Restrict Which Jobs Are Trusted

- Configure exact trusted issuer (`iss`), expected audience (`aud`), allowed subject (`sub`) or equivalent workload attributes. Provider MUST validate signature and token validity period plus these restrictions. Use actual claims issued for job and provider's documented matching rules; e.g., Microsoft Entra requires matching issuer, subject, audience values.
- Restrict to intended organization, repository/project, deployment context. Trusting shared CI/CD issuer alone can admit other tenants. Prefer immutable non-reusable organization/repository identifiers where supported, not names another owner could acquire. Google Cloud documents these tenant restrictions and identifier risks.
- Allow only required branches, environments, workflows. Avoid wildcards admitting every repository or job context. Verify which claims provider can actually enforce; claim in token ≠ available as policy condition. Follow provider integration docs, e.g. GitHub's AWS OIDC configuration guidance.
- Require reviews for changes to trusted deployment workflow files; see [GitHub Actions repository hardening guidance](GitHub_Actions_Security.md#harden-repository-settings).
- Trusting deployment environment: protect who can use it and which branches/tags may deploy to it. GitHub Actions: default environment-based subject doesn't contain branch. Match subject format configured for repository; enforce branch restriction via environment protection or other supported condition. See GitHub OIDC subject reference.

## Limit Credential Exposure and Permissions

- Grant only cloud operations/resources deployment needs. Separate identities and trust rules for production and non-production. Keep federation configuration and permission administration outside ordinary deployment roles so compromised job can't widen own access. See Google Cloud's federation security practices.
- Enable OIDC token requests only for jobs needing cloud access. GitHub Actions: set `id-token: write` at job level; permits token requests, doesn't itself grant cloud permissions. See GitHub's OIDC permission requirements.
- Request shortest credential lifetime provider supports that meets job needs. Don't assume credentials expire when job ends or OIDC token expires: issued cloud credentials have own lifetime. E.g., AWS temporary credentials remain valid until expiry unless access disabled.
- Treat OIDC token and issued credentials as secrets: don't print, place in artifacts/caches, or pass to unrelated jobs. After verifying migration, revoke replaced static keys, remove pipeline copies so they can't bypass federation restrictions. Apply [Secrets Management lifecycle guidance](Secrets_Management.md#27-secret-lifecycle).

## Verify and Monitor Access

Before production use, test permitted deployment; verify unauthorized repositories, branches, job contexts cannot obtain production credentials. Confirm authorized job cannot access resources outside assigned permissions. Repeat after changes to trust policies, claim formats, workflow configuration. Use platform's documented claims (e.g. GitHub OIDC reference) to select cases.

Enable cloud audit events for token exchange and role/service account use. Check which identity fields recorded; correlate w/ CI/CD run records (complete workflow attribution not automatic). E.g., Google Cloud requires enabling relevant data access logs and choosing unambiguous subject mapping. Alert on unexpected identities and changes to federation trust/permissions.

Prepare to stop new credential issuance and restrict already-issued credentials if job compromised. Removing trust relationship alone doesn't guarantee existing sessions stop. Follow provider incident procedure, e.g. revoking AWS role session permissions; account for policy propagation delays.

## References

- GitHub: OpenID Connect reference
- Google Cloud: Workload Identity Federation with deployment pipelines
- AWS: Create a role for OpenID Connect federation
