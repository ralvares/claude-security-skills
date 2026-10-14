# Virtual Patching Cheat Sheet

## Introduction

Concise virtual patching framework for organizations to maximize timely mitigation.

## Definition: Virtual Patching

**Security policy enforcement layer detecting and blocking matching exploitation attempts against known vulnerability w/o changing vulnerable code.**

Virtual patch reduces exposure only for traffic the enforcement layer inspects and attack variants its rules recognize. Doesn't remove underlying vulnerability. Test for bypasses; continue code/vendor fix; rule matching and transformations can miss attacks.

## Why Not Just Fix the Code

Technically, number one remediation = fix vulnerability in web app source code; universally agreed by security experts and system owners. In real business, updating source often hard:

- **Lack of resources** - Devs allocated to other projects.
- **Third-party Software** - User can't modify code.
- **Outsourced App Dev** - Changes need new project.

Key point: **Code level fixes and Virtual Patching are NOT mutually exclusive**. Run by different teams (OWASP Builders/Devs vs. OWASP Defenders/OpSec), can run in tandem.

## Value of Virtual Patching

Two main goals:

- **Minimize Time-to-Fix** - Fixing source takes time. Virtual patch implements mitigation ASAP. Urgency differs: vulnerability found in-house via code review/pen test vs. during live incident response.
- **Attack Surface Reduction** - Block known exploitation path while permanent fix prepared. Test alternate encodings, affected endpoints, paths bypassing enforcement layer before claiming coverage. Passing test for one payload ≠ complete protection; Core Rule Set (CRS) rule-writing guidance shows how small payload changes evade a rule.

## Virtual Patching Tools

Definition names no specific tool; options include:

- Intermediary devices such as WAF or IPS appliance
- Web server plugin such as ModSecurity
- Application layer filter such as ESAPI WAF

Examples below use open source ModSecurity WAF.

## A Virtual Patching Methodology

Use consistent, repeatable process, not haphazard approach. Workflow mimics industry-accepted IT Incident Response practice, phases:

1. Preparation.
2. Identification.
3. Analysis.
4. Virtual Patch Creation.
5. Implementation/Testing.
6. Recovery/Follow Up.

## Example Public Vulnerability

Example for rest of sheet: SQL Injection vulnerability:

```text
WordPress Shopping Cart Plugin for WordPress
/wp-content/plugins/levelfourstorefront/scripts/administration/exportsubscribers.php
reqID Parameter prone to SQL Injection.
```

**Description**:

WordPress Shopping Cart Plugin for WordPress contains flaw that may allow SQL injection attack.

Cause: `/wp-content/plugins/levelfourstorefront/scripts/administration/exportsubscribers.php` script doesn't properly sanitize user-supplied input to `reqID` parameter.

May allow attacker to inject/manipulate SQL queries in back-end database → manipulation or disclosure of arbitrary data.

## Preparation Phase

Preparation critical. Set up virtual patching processes and framework **prior** to identified vulnerability or live intrusion. Live compromise = bad time to propose WAF and virtual patch concept: tension high, time of essence. Lay foundation when calm; have everything ready.

Critical preparation items:

- **Public/Vendor Vulnerability Monitoring** - Sign up for all vendor alert mail-lists for commercial software used → notified on vendor vulnerability info and patching data.
<!-- textlint-disable -->
- **Virtual Patching Pre-Authorization** – Establish expedited review and rollout process before incident. Test exploit attempts and legitimate application workflows: false positives can block valid transactions though application code unchanged. Define monitoring and rollback criteria before enabling blocking.
<!-- textlint-enable -->
- **Deploy Virtual Patching Tool In Advance** - Time critical in incident response; bad time to get approvals to install new software. E.g., install ModSecurity WAF in embedded mode on Apache servers, or Apache reverse proxy server; advantage: can create fixes for non-Apache back-end servers. Even if ModSecurity unused normally, keep "on deck" ready to enable.
- **Configure HTTP Audit Logging** – Record rule ID, timestamp, affected endpoint, enforcement outcome, correlation identifier for investigation. Avoid indiscriminate capture of query strings, headers, cookies, request/response bodies: WAF alerts can expose passwords and payment data. Exclude or redact sensitive fields before logging per [Logging Cheat Sheet](Logging.md#data-to-exclude).

## Identification Phase

Occurs when organization becomes aware of web app vulnerability. Two identification methods: `Proactive` and `Reactive`.

### Proactive Identification

Organization assesses own web security posture:

- **Dynamic Application Assessments** - Ethical attackers run penetration tests or automated web assessment tools against live app to find flaws.
- **Source code reviews** - Ethical attackers analyze web app source manually/automatically to find flaws.

Custom coded apps unique → proactive identification extremely important; can't rely on third-party vulnerability notifications.

### Reactive Identification

Three main reactive methods:

- **Vendor contact (e.g. pre-warning)** - Vendor discloses vulnerability in commercial web app software you use. Example: Microsoft's Active Protections Program (MAPP)
- **Public disclosure** - Public vulnerability disclosure for commercial/open source web app software you use. Threat level increases as more people know.
- **Security incident** – Most urgent: attack active. Remediation must be immediate.

## Analysis Phase

Recommended analysis steps:

1. **Determine Virtual Patching Applicability** - Ideal for injection-type flaws; may give inadequate attack surface reduction for other attack types. Analyze underlying flaw thoroughly to determine whether tool has adequate detection logic.
2. **Utilize Bug Tracking/Ticketing System** - Enter vulnerability info for tracking and metrics. Use existing ticketing (e.g., Jira) or specialized tool such as ThreadFix.
3. **Verify the name of the vulnerability** - Need proper public vulnerability identifier (such as CVE name/number) from announcement, vulnerability scan, etc. If found proactively, assign own unique identifier per vulnerability.
4. **Designate the impact level** - Understand criticality; information leakages not treated same as SQL Injection.
5. **Specify which versions of software are impacted** - Identify listed versions to determine whether installed version(s) affected.
6. **List what configuration is required to trigger the problem** - Some vulnerabilities manifest only under certain configuration settings.
7. **List Proof of Concept (PoC) exploit code or payloads used during attacks/testing** - Many announcements include exploit code demonstrating vulnerability. Download for analysis; useful later developing and testing virtual patch.

## Virtual Patch Creation Phase

Accurate virtual patch bound by two main tenants:

1. **No false positives** - Never block legitimate traffic under any circumstances.
2. **No false negatives** - Never miss attacks, even when attacker intentionally evades detection.

Minimize both. Adhering 100% to each may be impossible; virtual patching is about **Risk Reduction**. Business owners should understand that shortening Time-to-Fix may not be complete fix for flaw.

### Manual Virtual Patch Creation

#### Positive Security (Allow List) Virtual Patches (**Recommended Solution**)

Positive security model (allowlist): comprehensive mechanism giving app independent input validation envelope. Specifies valid input characteristics (character set, length, etc…), denies anything nonconforming. Rules for every parameter in every page → additional security envelope independent from app code.

##### Example Allow List ModSecurity Virtual Patch

Allow-list virtual patch needs verified normal expected input values. With proper audit logging from Preparation Phase, review audit logs to identify expected input formats. Here `reqID` parameter should hold only integer characters, so use this virtual patch:

```text
##
## Verify we only receive 1 parameter called "reqID"
##
SecRule REQUEST_URI "@contains /wp-content/plugins/levelfourstorefront/scripts/administration/exportsubscribers.php" "chain,id:1,phase:2,t:none,t:Utf8toUnicode,t:urlDecodeUni,t:normalizePathWin,t:lowercase,block,msg:'Input Validation Error for \'reqID\' parameter - Duplicate Parameters Names Seen.',logdata:'%{matched_var}'"
  SecRule &ARGS:/reqID/ "!@eq 1"

##
## Verify reqID's payload only contains integers
##
SecRule REQUEST_URI "@contains /wp-content/plugins/levelfourstorefront/scripts/administration/exportsubscribers.php" "chain,id:2,phase:2,t:none,t:Utf8toUnicode,t:urlDecodeUni,t:normalizePathWin,t:lowercase,block,msg:'Input Validation Error for \'reqID\' parameter.',logdata:'%{args.reqid}'"
  SecRule ARGS:/reqID/ "!@rx ^[0-9]+$"
```

Inspects `reqID` value on specified page, blocks any non-integer characters.

- **Note** - Assign rule IDs properly, track in bug tracking system.
- **Caution**: numerous evasion vectors when creating virtual patches. See OWASP Best Practices: Virtual Patching document for countering evasion.

#### Negative Security (Block List) Virtual Patches

Negative security model (denylist): rules detecting specific known attacks rather than allowing only valid traffic.

##### Example Block List ModSecurity Virtual Patch

PoC code from public advisory:

```text
http://localhost/wordpress/wp-content/plugins/levelfourstorefront/scripts/administration/exportsubscribers.php?reqID=1' or 1='1
```

Payload inserts single quote, then adds SQL query logic at end. So disallow single quote:

```text
SecRule REQUEST_URI "@contains /wp-content/plugins/levelfourstorefront/scripts/administration/exportsubscribers.php" "chain,id:1,phase:2,t:none,t:Utf8toUnicode,t:urlDecodeUni,t:normalizePathWin,t:lowercase,block,msg:'Input Validation Error for \'reqID\' parameter.',logdata:'%{args.reqid}'"
  SecRule ARGS:/reqID/ "@pm '"
```

#### Which Method is Better for Virtual Patching – Positive or Negative Security

Either model works; choice depends on situation. Negative rules usually quicker to implement, but evasions more likely.

Positive rules protect better but often manual → not scalable, hard to maintain for large/dynamic sites. Entire-site manual positive rules may be infeasible; apply selectively when vulnerability alert identifies specific problem location.

#### Beware of Exploit-Specific Virtual Patches

Resist urge to quickly create **exploit-specific virtual patch**.

E.g., authorized pen test finds XSS on page, report uses payload:

```html
<script>
  alert('XSS Test')
</script>
```

Unwise to implement virtual patch blocking only that exact payload. Some immediate protection, but long term value significantly decreased.

### Automated Virtual Patch Creation

Manual creation may become unfeasible as vulnerabilities grow; automation may be necessary. If vulnerabilities found by automated tools and XML report available, auto-convert data into virtual patches for protection systems.

Three examples:

- **OWASP ModSecurity Core Rule Set (CRS) Scripts** - OWASP CRS includes scripts auto-converting XML output from tools such as [ZAP into ModSecurity Virtual Patches].
- **ThreadFix Virtual Patching** - ThreadFix automatically converts imported vulnerability XML data into virtual patches for tools such as ModSecurity.
- **Direct Importing to WAF Device** - Many commercial WAFs import DAST tool XML report data, auto-adjust protection profiles.

## Implementation/Testing Phase

Testing new virtual patches may need application other than web browser. Useful tools:

- Web browser.
- Command-line web clients such as Curl and Wget.
- Local Proxy Servers such as ZAP.
- ModSecurity AuditViewer – loads ModSecurity audit log file, manipulate, re-inject data into any web server.

### Testing Steps

- Implement virtual patches initially in "Log Only" configuration to avoid blocking normal user traffic (false positives).
- If vulnerability identified by specific tool or assessment team - request retest.
- Retest fails due to evasions → return to Analysis phase to find better fix.

## Recovery/Follow-Up Phase

- **Update Data in Ticket System** - Even when expediting virtual patches, track in normal Patch Management processes: create proper change request tickets, etc… to document existence and functionality. Also yields "time-to-fix" metrics per vulnerability type. Log virtual patch rule ID values properly.
- **Periodic Re-assessments** - Periodically verify if/when previous virtual patches can be removed after real source code fix. Many opt to keep virtual patches due to better identification/logging vs. application or db capabilities.
- **Running Virtual Patch Alert Reports** - Run reports identifying if/when virtual patches triggered; shows virtual patching value relative to windows of exposure for source code time-to-fix.

## References

- OWASP Virtual Patching Best Practices
- OWASP CRS: Making Rules
