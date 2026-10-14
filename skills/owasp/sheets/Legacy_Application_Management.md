# Legacy Application Management Cheat Sheet

## Introduction

Legacy applications = recognized as outdated but still in active use. Causes: no viable alternative, replacement currently too expensive, or highly bespoke application serving very niche role in organization's digital ecosystem. Significant security risks:

- May have reached End-of-Life (EoL): no patching or vendor support → vulnerabilities drastically more likely left exploitable.
- Built with technologies no longer conventionally used or taught → knowledge to troubleshoot/fix vulnerabilities may be lacking.
- May produce data in custom formats and/or use old interfaces or networking protocols → may stifle using application data with vulnerability management or security logging services, e.g. SIEM (Security Information and Event Management).

No one-size fits all approach. Sheet offers practical hardening suggestions when no alternative to legacy applications exists. Preferred approach depends on: type of data stored/produced, whether application + infrastructure have known vulnerabilities, extent access to application or riskier components can be restricted. Engaging security domain experts (in-house or external) for specific, contextualized advice may be necessary.

## Inventory and Asset Management

Baseline: organizations clearly understand which legacy applications are in use and expected risk of each.

**Inventory Management:** Compile documentation identifying legacy applications: version numbers, date of production, relevant configuration settings. Ideally incl. network hosts needed to reach application + associated infrastructure. Record services running on hosting/data storage infrastructure. Sometimes incl. physical location of, and permitted access to, associated servers. May generate formal SBOM (Software Bill of Materials); useful when application relies on third-party dependencies to function.

**Risk Assessment and Threat Modeling:** Understand risk level and kinds of threats theoretically posed by legacy application and its specific components (e.g. specific API routes, open ports on hosting infrastructure). Informed by formal/informal threat-modeling (see [Threat Modeling Cheat Sheet](Threat_Modeling.md)). Industry standard risk assessment framework can help qualify risk, e.g. NIST (National Institute of Standards and Technology) Risk Management Framework. Many threat modeling/risk assessment frameworks and tools exist with different strengths and weaknesses.

Informal indicator of how conservative protective security measures should be; questions contextualizing risk profile of legacy application or its components:

- What information is handled/stored? If compromised, impact on business and regulatory/compliance requirements?
- Do application/dependencies/supporting infrastructure have known vulnerabilities? How easily exploitable? Patchable with right resources incl. skilled professionals?
- How critical is availability to business continuity?
- If attacker gains access, risk of exfiltrating other critical organization information? Could attacker establish access to particularly privileged network or environment by compromising legacy application?

## Authentication/Authorization

Authorization enforces rules on who can access resource and how. Covered in depth in [Authorization Cheat Sheet](Authorization.md).

Treat legacy systems as inherently high risk. Least privilege (only access strictly required for staff/users/systems to perform roles and facilitate business operations) applies especially. Consider, as applicable:

- Network-level access controls: host in restricted subnet and/or IP allow-listing to prevent arbitrary users/hosts interacting, esp. with public-facing legacy applications. Sometimes application must run in air-gapped environment.
- More granular authorization by reducing feature set available to end users. E.g. disable certain high risk functionalities, esp. administrative.
- Only authenticated users access application: enforced by application itself or IdP (Identity Provider) service. Restricted network environment: also require authentication to access network (e.g. VPN server authentication before accessing application). These controls slow attacker + assist investigations. See [Authentication Cheat Sheet](Authentication.md).
- Close ports on application hosts not strictly needed for tasks organization requires. Restrict port access with firewall/application firewall rules to lock down server infrastructure.
- Possibly restrict almost all users from direct access by developing intermediary service (e.g. separate set of APIs) handling essential data movement into/out of legacy application; end users never interact directly.

## Vulnerability Management

**Vulnerability Scanning:** Regularly scan legacy applications with industry standard vulnerability assessment tool where possible, e.g. Nessus, Qualys. Ideally automated scans at set time interval. Where appropriate, also code scanning tools: SAST (Static Application Security Testing) for obvious codebase vulnerabilities, SCA (Software Composition Analysis) for vulnerable dependencies. If none viable, direct human assessment of host configuration + manual code reviews may be only option for assessing security posture.

**Patch Management:** Apply patches for confirmed vulnerabilities where possible. Prioritize remediation using application's exposure + criticality, vulnerability's impact + exploitability, evidence of active exploitation. Use CISA Known Exploited Vulnerabilities catalog as one prioritization input.

Common Vulnerabilities and Exposures (CVE) identifier helps track vulnerability; assignment depends on vulnerability determination, disclosure, assigning authority's scope. Presence or absence alone doesn't establish remediation priority. Patching not practically possible: consider additional restrictions on application/affected components per Authentication/Authorization section.

## Data Storage

Wherever possible, encrypt data handled by application at rest (e.g. stored in database) and in transit. See Cheat Sheets on [Cryptographic Storage](Cryptographic_Storage.md) and [HTTP Strict Transport Security](HTTP_Strict_Transport_Security.md). Legacy applications might be restricted to older network protocols supporting only plain text transmission → especially important to apply most restrictive network access controls possible. May need temporary or permanent air-gapping (functional isolation).

## Ensuring Maintainability

Maintain high institutional expertise so staff can remediate vulnerabilities and troubleshoot to ensure business continuity:

- More than one staff member adequately trained to troubleshoot/reconfigure; reduces risk of total maintenance capability loss if one trained staff member leaves.
- Encourage regular process documentation incl. troubleshoot guides for common failure scenarios.
- May need to teach core staff group to write basic programs in language used by legacy application where expertise doesn't exist.

## Change Management

Ultimate goal for most legacy applications: migrate from unmaintainable system to solution both maintainable and architected resilient to contemporary threats. Staged change management considers:

- Budget practically allocatable for upgrading to modern solution, and time frame for availability?
- Do people with migration expertise exist in organization, or could be acquired/developed?
- Migration urgency given application's risk profile and organization's risk appetite?

Change management plan, formal or informal, should include: clear description of granular migration steps, explicit expected completion date, clear articulation of business + security case. Realistic plan: extensively consult staff overseeing/using existing solution on how critical application is and barriers to migration or complete decommissioning.

## Continuous Monitoring and Incident Response

Subject legacy applications to especially high security monitoring; rapid response investigating potential incidents. Intra-operability issues may mean application logs in format security monitoring tools can't readily ingest. Workarounds:

- Custom APIs converting security-applicable information from legacy application and/or logs into format ingestible by organization's security monitoring solutions.
- Above not possible: automation scripts generating reports assessing indicators of compromise.
- Watch anomalous network traffic into/out of legacy application environment and surges in network activity.
- Internal or hired incident response team: ensure they know incident response + investigation of unusual events prioritized for critical legacy systems. Ideally document in advance, in incident response playbook, processes for handling application downtime and compromise: clear rundown of emergency procedures incl. escalation contacts + incident response leaders.
- Incident response planning within broader business continuity plan.

## References

- NIST SP 800-40 Rev. 4: Guide to Enterprise Patch Management Planning
- Red Hat: Backporting Security Fixes
