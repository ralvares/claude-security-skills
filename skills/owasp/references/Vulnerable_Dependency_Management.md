# Vulnerable Dependency Management Cheat Sheet

## Introduction

Proposed approach for handling vulnerable third-party dependencies once detected, per situation.

Not tools oriented; [tools](#tools) section lists free and commercial detectors, by technology support.

**Note:**

Proposals not silver bullets (recipes for all situations); use as foundation, adapt to context.

## Context

Most projects use third-party dependencies for operations, _e.g._ document generation in specific format, HTTP communications, data parsing.

Lets team focus on real application code. Downside: app security posture now rests on dependency.

Referenced in:

- OWASP TOP 10 2017, _A9 - Using Components with Known Vulnerabilities_.
- OWASP Application Security Verification Standard Project, section _V14.2 Dependency_.

Project MUST ensure all third-party dependencies free of security issues; if issues exist, team must know and apply mitigations.

Highly recommended: automated dependency analysis from project birth. Added mid/late project → huge workload, burden on team, may block progress.

**Note:**

_Development team_ below assumes member with app security skills, or access to someone in company with them, to analyze dependency vulnerability.

## Remark about the detection

Know how security issues are handled after discovery.

### 1. Responsible disclosure

Researcher finds vulnerability in component; after collaboration with provider, issues [CVE](https://en.wikipedia.org/wiki/Common_Vulnerabilities_and_Exposures) (sometimes provider-specific identifier, generally CVE preferred) → public reference to issue + available fix/mitigation.

If provider doesn't cooperate, expect:

- CVE accepted by vendor yet provider refuses to fix issue.
- Usually, no response in 30 days → researcher does [full disclosure](#2-full-disclosure).

Vulnerability always referenced in CVE global database, generally one of several detection-tool input sources.

### 2. Full disclosure

Researcher releases all info incl. exploitation code/method on services like Full Disclosure mailing list, Exploit-DB.

CVE not always created → vulnerability not always in CVE global database → detection tools potentially blind unless using other input sources.

## Remark about the security issue handling decision

Risk acceptance for detected issue: decision MUST be by Chief Risk Officer (fallback Chief Information Security Officer), based on technical feedback from development team that analyzed issue (see _[Cases](#cases)_) and CVE CVSS score indicators.

## Cases

On detection, team meets one of situations (_Case_ below).

Vulnerable transitive dependency → act on project's direct dependency; acting on transitive often impacts app stability.

Acting on transitive dependency requires full understanding of relation/communication/usage from first-level dependency down to impacted one; very time consuming.

### Case 1

#### Context

Provider released patched version.

#### Ideal condition of application of the approach

Automated unit/integration/functional/security tests exist for features using impacted dependency, validating feature works.

#### Approach

**Step 1:**

Update dependency version in testing environment.

**Step 2:**

Before running tests, 2 output paths:

- All tests succeed → push update to production.
- Test(s) fail, several paths:
    - Failure from changed function calls (_e.g._ signature, argument, package). Team updates code to fit new library, re-runs tests.
    - Fixed version cannot be adopted at all (_e.g._ fix only in new major version that breaks app, or vulnerable version pinned by transitive dependency). Apply [Case 5](#case-5), [Case 2](#case-2) as interim mitigation.
    - Technical incompatibility of released dependency (_e.g._ needs newer runtime version) → actions:
    1. Raise issue to provider.
    2. Apply [Case 2](#case-2) while awaiting provider feedback.

### Case 2

#### Context

Provider says fix will take a while; patched version not available for months.

#### Ideal condition of application of the approach

Provider can share any of:

- Exploitation code.
- List of functions impacted by vulnerability.
- Workaround preventing exploitation.

#### Approach

**Step 1:**

Workaround provided → apply, validate in testing environment, deploy to production.

Identify reachable calls to affected functions + conditions required to exploit. Use wrapper only when its checks block those conditions on every affected call path. Otherwise disable affected functionality or isolate it while pursuing fix. Wrapper = temporary mitigation; track the upgrade/replacement that removes vulnerable dependency.

Security devices like Web Application Firewall (WAF) can also handle such issues via parameter validation + detection rules for specific libraries. This sheet focuses on application level: patch as close to source as possible.

_Illustrative allowlist wrapper: use only if analysis of the specific vulnerability establishes accepted values cannot trigger it. Not a general defense against remote code execution._

```java
public void callFunctionWithRCEIssue(String externalInput){
    //Apply input validation on the external input using regex
    if(Pattern.matches("[a-zA-Z0-9]{1,50}", externalInput)){
        //Call only with values covered by the vulnerability-specific analysis
        functionWithRCEIssue(externalInput);
    }else{
        //Log rejected input without assuming it was an exploit
        SecurityLogger.warn("Input rejected by temporary vulnerability mitigation");
        //Raise an exception leading to a generic error send to the client...
    }
}
```

Provider gave nothing about vulnerability → apply [Case 3](#case-3), skipping _step 2_ here. Assumes at least [CVE](https://en.wikipedia.org/wiki/Common_Vulnerabilities_and_Exposures) provided.

**Step 2:**

Use provider-supplied exploit as regression test. Blocking that payload ≠ library secure: test alternate inputs + all reachable paths to affected functionality. Core Rule Set rule-writing guidance shows how small payload changes bypass filters. Follow [virtual patch testing guidance](Virtual_Patching.md#implementationtesting-phase); keep permanent fix on remediation plan.

Existing automated unit/integration/functional/security tests → run to verify added protection code doesn't affect stability.

Add comment in project _README_: issue (specify [CVE](https://en.wikipedia.org/wiki/Common_Vulnerabilities_and_Exposures)) handled while awaiting patched version, since detection tool keeps alerting on dependency.

**Note:** Dependency may go on ignore list, but ignore scope MUST cover only the related [CVE](https://en.wikipedia.org/wiki/Common_Vulnerabilities_and_Exposures); dependency can have several vulnerabilities, each with own [CVE](https://en.wikipedia.org/wiki/Common_Vulnerabilities_and_Exposures).

### Case 3

#### Context

Provider says it cannot fix issue; no patched version ever (also if provider unwilling or unresponsive).

Only info given to team: [CVE](https://en.wikipedia.org/wiki/Common_Vulnerabilities_and_Exposures).

**Notes:**

- Complex, time consuming; generally last resort.
- Open source library → team can create patch + pull request: protects company/app at source, helps others.

#### Ideal condition of application of the approach

None specific; _patch yourself_ condition.

#### Approach

**Step 1:**

If here because provider unwilling or unresponsive, start parallel study for better-maintained component; if commercial with support, **put pressure** on provider via Chief Risk Officer (fallback Chief Information Security Officer):

- Provider does not want to fix issue.
- Provider does not answer at all.

In all cases, handle vulnerability right now.

**Step 2:**

Vulnerable dependency known → usage in app known (transitive: identify first-level dependency using it via [IDE](https://en.wikipedia.org/wiki/Integrated_development_environment) built-in feature or dependency management system (Maven, Gradle, NuGet, npm, etc.). IDE also identifies calls to dependency.

Identifying calls = first step only; still lack info on patching needed.

Use CVE description to identify reported weakness, then consult upstream advisory, issue, fix to determine affected behavior + required change. Vulnerability category alone doesn't establish which checks/config changes prevent exploitation. Root cause unclear → do not assume [Case 2](#case-2) wrapper fixes it.

_Example:_

App uses Jackson API in version exposed to [CVE-2016-3720](https://nvd.nist.gov/vuln/detail/CVE-2016-3720).

CVE description:

```text
XML external entity (XXE) vulnerability in XmlMapper in the Data format extension for Jackson
(aka jackson-dataformat-xml) allows attackers to have unspecified impact via unknown vectors.
```

Upstream issue and fix disable `XMLInputFactory.IS_SUPPORTING_EXTERNAL_ENTITIES` for input factories created by Jackson. Parser configuration change, not generic XML pre-validation. Use maintained release containing fix. Upgrade blocked → evaluate that specific fix via [Case 5](#case-5); also harden any application-supplied parser per [XXE prevention guidance](XML_External_Entity_Prevention.md#xmlinputfactory-stax).

**Step 3:**

If possible, create unit test mimicking vulnerability: ensures patch effective, continuously verifies patch stays in place as project evolves.

Existing automated unit/integration/functional/security tests → run to verify patch doesn't affect stability.

In-house patch gets no benefit of doubt vs upstream release; meet explicit bar before vulnerability considered handled:

- Test reproducing vulnerability fails against unpatched dependency, passes against patched. Test passing in both cases proves nothing about patch.
- Dependency's own tests still pass; catches behavior patch broke that app doesn't exercise directly.
- Detection-tool alert suppressed per [CVE](https://en.wikipedia.org/wiki/Common_Vulnerabilities_and_Exposures) only once both points above hold. Suppressing alert, or changing version string so tool stops matching, records a fix but doesn't make one.

Expect tool to keep flagging dependency after correct patch, since version number doesn't tell whether fix present. Reporting problem → scoped suppression, not reason to change patch.

### Case 4

#### Context

Vulnerable dependency found in situation where provider unaware:

- Full disclosure post found on Internet.
- During penetration test.

#### Ideal condition of application of the approach

Provider collaborates after notification.

#### Approach

**Step 1:**

Inform provider, sharing the post.

**Step 2:**

Using full disclosure post info or pentester's exploitation feedback: provider collaborates → [Case 2](#case-2); otherwise [Case 3](#case-3). Team analyzes full disclosure post/pentester feedback instead of CVE info.

### Case 5

#### Context

Provider released fixed version, project cannot adopt:

- Fix only in new major version that breaks app code.
- Vulnerable version pinned by [transitive dependency](https://en.wikipedia.org/wiki/Transitive_dependency) not yet updated.
- Version line in use unmaintained; fix only on newer line.

Not [Case 3](#case-3): fix exists and is public, nothing to invent, but must move onto version line project can run. Practice = _backporting_; OS vendors do it for years. Debian: "instead of upgrading to a new release we backport security fixes to the version that was shipped in the stable release"; Red Hat defines backporting as "the action of taking a fix for a security flaw out of the most recent version of an upstream software package and applying that fix to an older version".

#### Ideal condition of application of the approach

Upstream fix identifiable (commit, patch file, or advisory precise enough to locate change), source of version in use available, automated tests exist for app features using dependency.

#### Approach

**Step 1:**

Confirm upgrade really blocked by attempting in testing environment per [Case 1](#case-1). Backporting cheaper than major upgrade short term, costlier over project life → deliberate choice, not first reflex. Record exact blocker (breaking API, transitive pin, unsupported runtime) = condition to re-test later.

**Step 2:**

Isolate security-relevant change from rest of upstream release. Fix commits often bundled with refactoring, renaming, unrelated bugfixes that MUST NOT be carried over; fix may rely on internal functions absent in older line → re-implement check instead of cherry-pick. Keep patch minimal: block vulnerability without changing any existing legitimate behavior.

**Step 3:**

Verify patch, don't assume. Test reproducing vulnerability must fail against unpatched dependency, pass against patched; dependency's own test suite and app tests must still pass. Silencing scanner or bumping version string ≠ remediation.

**Step 4:**

Distribute patched artifact so every build resolves it: publish to internal registry/proxy build already trusts, not locally built file committed into each project. Version identifier stays traceable to upstream version; record provenance (source commit, CVE, producer) for audit. Expect detection tools to keep flagging dependency, since version number doesn't tell whether backported fix present; suppress alert per CVE as in note of [Case 2](#case-2).

**Step 5:**

Patch = standing commitment, not one-off. Every new upstream release must be re-patched; every new CVE adds another patch. Before maintaining patches in-house, size recurring work vs acquiring maintained backports from provider whose business is producing them. Drop backport once fixed version adoptable: re-test step 1 blocker at each dependency review, then return to [Case 1](#case-1).

## Tools

Tools analyzing project dependencies to detect vulnerabilities.

When selecting detection tool, ensure it:

- Uses several reliable input sources to cover both disclosure ways.
- Supports flagging issue on component as false-positive.

- Free
    - OWASP Dependency Check:
        - Full support: Java, .Net.
        - Experimental support: Python, Ruby, PHP (composer), NodeJS, C, C++.
    - NPM Audit
        - Full support: NodeJS, JavaScript.
        - HTML report via npm-audit-html module.
    - OWASP Dependency Track: manage vulnerable dependencies across organization.
    - Trivy
        - Full support: Base OS, Java, NodeJS, JavaScript, Ruby, Python, Go, .NET, Rust, PHP, Dart, Swift
        - Targets: Kubernetes (nodes and containers), Docker (nodes and containers), filesystem, Git repositories, cloud images
    - Grype
        - Full support across mainstream language ecosystems with SBOM-driven scanning
        - Targets: container images, filesystems, SBOMs produced by Syft
- Commercial
    - Snyk (open source and free option available):
        - Full support for many languages and package managers.
    - JFrog XRay:
        - Full support for many languages and package managers.
    - Renovate (detects old dependencies):
        - Full support for many languages and package managers.

### Remediation and maintained backports

Tools detect, don't fix. When fixed version cannot be adopted, patch still must come from somewhere: team maintains it or someone else does.

Linux distribution security teams = reference model for second option. Debian and Red Hat both backport security fixes into version shipped in stable release instead of upgrading. Dependency consumed as OS package → take distribution's patched build, not private patch.

Language ecosystem packages rarely covered that way; choice: maintain patch in-house or pay someone. Judge either option by same criteria as detection tool, plus:

- Coverage of ecosystems, version lines, severities project depends on, with published response time.
- Publication of patch itself + provenance, so change reviewable, not trusted blindly.
- Delivery as compatible artifact via registry/proxy build already uses; no manifest rewrite.
- Documented way out; leaving source ≠ re-patching everything from scratch.

## References

- OpenSSF: Concise Guide for Evaluating Open Source Software
- Debian security FAQ
- Red Hat: Backporting Security Fixes
