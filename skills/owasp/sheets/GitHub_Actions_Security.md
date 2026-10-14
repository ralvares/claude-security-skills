# GitHub Actions Security Cheat Sheet

## Introduction

Guidance for securing GitHub Actions workflows, primarily public GitHub repos. Main goal: prevent attacker-controlled code execution, which may lead to:

- **Secrets exfiltration.** CI/CD pipelines often use long-lived credentials for external services (e.g., cloud provider credentials, package registry tokens). Remote code execution can exfiltrate them (print to logs, send to external endpoints, embed in artifacts).
- **Compromise of `GITHUB_TOKEN` with `write` permissions.** GitHub gives each workflow run short-lived `GITHUB_TOKEN`, scoped to repo, specific permissions. With `write` permissions, attacker exfiltrating/misusing token could modify repo contents, create/alter releases, interact with other GitHub resources.
- **GitHub Actions cache poisoning.** Workflows may reuse cached data across runs. Attacker injects malicious content into cache; later workflows (e.g. release pipelines) restore it → poisoned data executes in privileged context: compromises integrity of published release artifacts, gives code execution in privileged workflow, steals production secrets.
- **Denial-of-wallet attacks.** CI/CD often integrates paid external services, e.g. LLMs for code review. Attacker repeatedly triggering pipelines or manipulating inputs to maximize resource use → uncontrolled spending.

## Treat your CI/CD pipeline as a critical production code

CI/CD pipeline usually has access to sensitive credentials and functions/endpoints → treat as critical asset, potentially more critical than source code it processes.
Apply secure software development best practices, incl. (not limited to): threat modeling, secure code reviews, security validation, penetration testing.

Further guidance:

- NIST "Strategies for the Integration of Software Supply Chain Security in DevSecOps CI/CD Pipeline";
- OWASP CI/CD Security Cheat Sheet;
- OWASP Secure Pipeline Verification Standard.

## Assume failure and have an incident response plan in place

Assume breaches will happen; design for rapid response. Define incident response procedures: roles, communication, escalation paths.
Improve continuously by learning from others' incidents via public post-mortems (e.g., Trivy post-mortem, Cline post-mortem).

## Enable static analysis for GitHub Actions workflows

> [!IMPORTANT]
> CodeQL free for open-source repos on GitHub.
> Verify CodeQL enabled and configured to scan GitHub Actions workflow files.
> Enable via GitHub UI or workflow file under `.github/workflows` folder:
>
> - Via workflow: include `language: actions`.
> - Via `Settings` → `Advanced Security` → `Code scanning` → `CodeQL analysis`: ensure `GitHub Actions` appears under Languages section.

- If available, enable CodeQL `actions` scanning to detect workflow vulnerabilities. Add Zizmor for defense in depth. Upgrade tools periodically; new releases may contain updated detection rules.
- Run tools on every relevant pull request; mark as required status checks before merging. Minimum: block merges on high or critical severity issues.
- Run comprehensive workflow scans on schedule (e.g., daily); track and remediate findings over time.
- Scanning across several repos: use centralized reusable workflow or shared actions to standardize (see Grafana example).

## Harden repository settings

> [!IMPORTANT]
> `Require approval for first-time contributors` setting is a security risk: attacker submits initially legit-looking PR (e.g., typo fix) to gain trust, later submits PRs with malicious changes executed in CI w/o further approval.

- Enable `Require approval for all external contributors` in repo settings. Workflows from fork PRs (users not members of repo/org) don't run automatically → prevents untrusted code execution.
- Restrict default `GITHUB_TOKEN` permissions to `Read repository contents and packages permissions` in repo settings. Grant extra permissions explicitly in workflow file if required.
- Enforce strong branch protection: require pull request reviews, status checks, signed commits, `CODEOWNERS` approval before merging into protected branches. Tools like OpenSSF Scorecard help audit.
- Require workflows to pass before merging via repository rulesets to enforce org/enterprise requirements (e.g. required labels, commit message validation) before merge.

## Restrict egress traffic from GitHub-hosted runners

Use solutions (e.g., Harden-Runner) to monitor/restrict egress from GitHub-hosted runners → prevent secret exfiltration.

## Use self-hosted runners with extra caution

Self-hosted runners usually access internal networks; may cache credentials, secrets, or store internal data.
Execute arbitrary code by design → attacker can use for persistent remote access and secret exfiltration.
Generally never use self-hosted runners with public repos: anyone who can fork and open PR can potentially execute code on runner.

Self-hosted runners for public repo:

- Apply standard secure development practices (threat modeling, secure code reviews, security validation, penetration testing, patching, hardening).
- Use `Require approval for all external contributors`; review proposed changes, manually approve each workflow execution for all external contributors.
- Use ephemeral runners (e.g., container-based); destroy runner environment after each job to prevent persistence.
- No sensitive data on runner machines: any user who can invoke workflows has access to runner environment.
- Restrict runner network access; don't give self-hosted runners access to sensitive infrastructure.

## Segregate runners using runner groups and labels

Use runner groups and labels to separate high-privilege runners (may access sensitive resources) from low-privilege runners (should not).

Gives granular control over which repositories can access a runner group and which workflows can target specific runners → less risk of compromised/misconfigured workflow reaching sensitive resources.

E.g. create:

- Runner group for container image build runners, limited to repos needing those privileges.
- Runner group for runners with access to restricted networks.
- Separate runner group for low-privilege tasks (linting, static analysis), used by repos where secrets absent or isolated in separate environments.

## Maintain curated shared workflows and actions

Supporting several repos: establish centralized repo of curated, security-reviewed workflows/actions; reuse across repos.

Example: grafana/shared-workflows.

## Prevent artifact poisoning

Artifact poisoning = malicious/untrusted content introduced into build artifacts, often via shared caches or previously stored dependencies (GitHub Actions Cache Poisoning).
Can compromise integrity of released software or lead to production secret exfiltration.
Mitigation: disable all forms of caching in release/publishing workflows → avoid reusing potentially compromised artifacts or exfiltrating production secrets.

## Be careful with AI assistant running in CI/CD pipeline

AI assistant used directly in workflows (e.g., review PRs, triage issues) → prompt injection risk: malicious input manipulates assistant behavior. If workflow has access to secrets or `GITHUB_TOKEN` with `write` permissions and untrusted users (e.g., any GitHub account) can trigger it → secret exfiltration or unauthorized actions.
Real-world example: "clinejection" attack.

Mitigation: limit AI assistant capabilities — enable only minimum tools/actions needed for task.

## Write Secure GitHub Workflows

Recommendations; static code analyzer (CodeQL, Zizmor) should generally report such issues.

### Avoid dangerous triggers

#### Avoid using the `pull_request_target` trigger

`pull_request_target` workflows run in context of base (target) repo; have access to `GITHUB_TOKEN` with `write` permissions and GitHub secrets available to workflow.
Checking out and using untrusted PR code → code execution.
Some common patterns (e.g. labeling workflows w/o untrusted checkout) OK, but generally avoid `pull_request_target`.

> [!IMPORTANT]
> Never check out (via `actions/checkout` or GitHub CLI) and run untrusted code in this context.

#### Avoid using the `workflow_run` trigger

`workflow_run` automates tasks based on other workflows' execution; can grant access to `GITHUB_TOKEN` with `write` permissions and GitHub secrets.
Attacker can modify triggering workflows via PRs → privileged workflows run.
Even if initial workflow unprivileged, triggered one may run w/ higher permissions → privilege escalation.
Attackers can also exploit artifact poisoning: inject malicious files downstream workflows use w/o verification → potential code execution.
Workflow chains: use `workflow_call` with reusable workflows instead.

#### Use `issue_comment` trigger with extra care

Trigger automates workflows (e.g., end-to-end tests) in response to issue/PR comments; can grant access to `GITHUB_TOKEN` with `write` permissions and GitHub secrets.
Implementation may introduce Time-of-Check to Time-of-Use (TOCTOU) issue: attacker modifies PR between comment approval and workflow execution to run malicious code.
Also can bypass PR approval mechanisms → attackers execute workflows w/o proper review.

Secure `issue_comment` implementation:

1. Check triggering actor meets authorization criteria, e.g., allow execution only if triggered by trusted member of specific GitHub org.
2. Use commit SHA in triggering comment: instead of `/ok-to-test` comment, design workflow to accept `/ok-to-test(<trusted_sha_commit>)` and check out code only from `<trusted_sha_commit>` submitted by authorized actor. Mitigates checkout/execution of untrusted code.

Alternative: replace `issue_comment` trigger with label-based triggers.
`pull_request` trigger with labeled event: `github.event.pull_request.head.sha` = latest commit SHA of PR.
Users with triage access can apply labels. Verify actor applying workflow-triggering label is authorized for that operation; permission to label ≠ commit reviewed.
Applying label does not elevate workflow permissions. PRs from forks of public repos: `pull_request` workflows still get read-only `GITHUB_TOKEN`, no other secrets (GitHub's fork workflow restrictions).
After reviewing proposed code, check out exact commit SHA from `github.event.pull_request.head.sha`, reflecting PR state when label applied. Don't treat label as approval for later commits.

> [!IMPORTANT]
> Generally never check out code using mutable references (e.g., pull request numbers or branch names) - always use immutable references such as full commit SHA.

### Use third-party GitHub Actions and reusable workflows securely

#### Use third-party actions with caution

Minimize third-party action usage, e.g., use GitHub API in workflows where possible for required logic.

Using third-party actions: verify origin, check author trusted and active, ensure multiple active contributors.
Check code stable and safe, action needs no unnecessary permissions.

#### Always pin all action and reusable workflow versions with a commit hash and check for impostor commits

Check used commit belongs to specified org/repo. Prevents dependency confusion attacks: currently GitHub resolves commit SHA, finds matching object, executes it regardless of originating fork. Automate with Zizmor `impostor-commit` rule.

#### Use automated dependency update tools

- Use Dependabot or Renovate to keep third-party GitHub Actions up to date.
- Configure delay between dependency release and adoption (e.g., few days): avoids immediately pulling newly published malicious/compromised versions; gives community time to detect/report. Dependabot: `cooldown` flag; Renovate: `minimumReleaseAge` flag.

### Minimize `GITHUB_TOKEN` permissions

Always set `permissions: {}` at workflow level to disable all permissions by default. Grant only specific permissions needed at job level.

### Require approval for deployments or publications to critical environments

Use GitHub environments with required approval rules. Define list of authorized accounts who must manually approve deployments to production/other critical environments before workflow execution.

### Sanitize user input

Attacker may submit malicious payload via context (e.g., PR title) → remote execution.
Prevent injection: always use intermediate environment variables to pass any context into `run:` and similar code execution blocks.
Some input contexts look relatively safe; still always follow this approach for consistency and security.

### Protect secrets used in workflows

#### Try to eliminate all static credentials from your workflows

Eliminate all static credentials (e.g., personal access tokens, static cloud keys) in workflows. Migrate to OIDC-based short-lived authentication tokens ("Trusted publishing").
Many major registries and cloud providers currently support this.
Cloud deployment trust restrictions and credential handling: [Workload Identity Federation Cheat Sheet](Workload_Identity_Federation.md).

#### Secure handling of static credentials (if elimination is unavoidable)

If elimination impossible:

- Never hardcode secrets in workflow files.
- Pass secrets at step level, not job level.
- Prefer environment-level secrets, accessible only when job targets specific environment.
- Rotate secrets regularly.

#### Eliminate `secrets: inherit` while reusing workflows

Invoking reusable workflow, `secrets: inherit` passes all secrets available to caller, incl. ones called workflow doesn't need. Explicitly pass only required secrets.
Also review any `environment` selected by job inside reusable workflow: GitHub documents environment's secrets are used there and can override secrets passed by caller. Explicit caller secret map does not remove that separate access source.

#### Mask sensitive data

Mask all sensitive info that is not GitHub secret using `::add-mask::{value}`.
Masking prevents string/variable being printed in log

#### Use secret scanning tools

Secret scanning at pre-commit and pull request stages prevents accidental exposure of sensitive data in repo:

- Run locally (e.g., pre-commit hooks) to catch issues before commit.
- Enforce in PRs to detect/block leaked secrets before merging.
- Auto-fail checks when potential secrets detected → remediation before proceeding.

#### `actions/checkout` should be used with `persist-credentials: false`

Unless needed for git operations, use `actions/checkout` with `persist-credentials: false`.
Prevents Git credentials persisting in workflow environment → less credential exposure if workflow compromised.

## References

- GitHub Actions: Secure Use Reference
- GitHub Actions: OpenID Connect
