# Attack Surface Analysis Cheat Sheet

## What is Attack Surface Analysis and Why is it Important

Pragmatic way to do Attack Surface Analysis and manage app's Attack Surface. For developers (understand/manage security risk while designing and changing app) and AppSec specialists doing risk assessment. Focus: protecting app from external attack; excludes attacks on users/operators (e.g. malware injection, social engineering); less focus on insider threats, though principles same. Internal attack surface likely differs from external; some users may have much access.

Attack Surface Analysis = mapping which system parts need review/testing for vulnerabilities. Purpose: understand risk areas, make developers and security specialists aware of what's open to attack, find ways to minimize it, notice when/how Attack Surface changes and risk meaning.

Usually done by security architects and pen testers; developers should still understand and monitor Attack Surface as they design, build, change system.

Helps to:

1. identify functions/system parts to review/test for vulnerabilities
2. identify high-risk code needing defense-in-depth; what to defend
3. identify when attack surface changed → threat assessment needed

## Defining the Attack Surface of an Application

Attack Surface = all points where attacker could get into system, and get data out.

App's Attack Surface:

1. sum of all paths for data/commands into and out of app, and
2. code protecting these paths (incl. resource connection and authentication, authorization, activity logging, data validation and encoding)
3. all valuable data in app, incl. secrets and keys, intellectual property, critical business data, personal data and PII, and
4. code protecting this data (incl. encryption and checksums, access auditing, data integrity and operational security controls).

Overlay model w/ user types (roles, privilege levels) that can access system (authorized or not). Complexity grows w/ number of user types. Focus on two extremes: unauthenticated anonymous users and highly privileged admins (e.g. DBAs, sysadmins).

Group attack points into buckets by risk (external-facing or internal-facing), purpose, implementation, design, technology. Count attack points per type. Choose cases per type. Focus review/assessment on those cases.

Need not understand every endpoint: count general endpoint types and points per type. Enables budgeting risk assessment at scale; shows when risk profile significantly changed.

### Microservice and Cloud Native Applications

Multiple smaller components, loosely coupled via APIs, independently scalable. Prioritize components reachable from attack source (e.g. external Internet traffic). Such components may sit behind tiers of proxies, load balancers, ingress controllers, and may auto-scale without warning.

Open source tooling e.g. Cilium Hubble and kubeshark helps visualize attack surface for Kubernetes and service-mesh deployments.

## Identifying and Mapping the Attack Surface

Build baseline Attack Surface description as picture + notes. Spend a few hours reviewing design/architecture docs from attacker's perspective. Read source code; identify entry/exit points:

- User interface (UI) forms and fields
- HTTP headers and cookies
- APIs
- Files
- Databases
- Other local storage
- Email or other kinds of messages
- Runtime arguments
- ...Your points of entry/exit

Attack points can total thousands+. Break model into types by function, design, technology:

- Login/authentication entry points
- Admin interfaces
- Inquiries and search functions
- Data entry (CRUD) forms
- Business workflows
- Transactional interfaces/APIs
- Operational command and monitoring interfaces/APIs
- Interfaces with other applications/systems
- ...Your types

Identify valuable data (confidential, sensitive, regulated) by interviewing developers/users and reviewing source code.

Can also scan app. Web apps: ZAP or other maintained dynamic testing tool crawls app, maps web-accessible parts. Some WAFs can export model of app entry points.

Validate/fill in understanding by walking main use cases: sign-up and profile creation, login, search, placing order, changing order, etc. Follow control and data flow: how info validated, where stored, what resources touched, what other systems involved. Recursive relationship w/ Application Threat Modeling: Attack Surface changes trigger threat modeling; threat modeling helps understand Attack Surface.

Model may start rough/incomplete, esp. if no prior security work. Fill holes as security analysis deepens or understanding improves.

## Measuring and Assessing the Attack Surface

With map, identify high-risk areas. Focus on remote entry points (interfaces with outside systems and Internet), esp. anonymous public access.

- Network-facing, esp. internet-facing code
- Web forms
- Files from outside network
- Backward compatible interfaces w/ other systems: old protocols, sometimes old code/libraries, hard to maintain/test multiple versions
- Custom APIs, protocols etc: likely design/implementation mistakes
- Security code: cryptography, authentication, authorization (access control), session management

Often most exposed. Then understand compensating controls: operational controls e.g. network firewalls, application firewalls, intrusion detection/prevention systems.

Michael Howard (Microsoft) and others developed method to measure Attack Surface and track changes over time: Relative Attack Surface Quotient (RSQ). Calculate overall attack surface score; re-measure as system and deployment change. Carnegie Mellon researchers built formal Attack Surface Metric for large systems like SAP: Attack Surface = sum of all entry and exit points, channels (ways clients or external systems connect, incl. TCP/UDP ports, RPC endpoints, named pipes...) and untrusted data elements. Apply damage potential/effort ratio to elements → high-risk areas.

Multiple deployed app versions, unused features left "just in case", old backup copies, unused code all increase Attack Surface. Use source code control and robust change management/configuration practices so deployed Attack Surface matches theoretical one as closely as possible.

Backups of code and data (online and offline media) = important but often ignored part of Attack Surface. Secure software and hardened infrastructure wasted if backups unprotected.

## Managing the Attack Surface

With baseline, identify and manage risk incrementally as app changes. Ask:

- What has changed?
- What are you doing different? (technology, new approach, ….)
- What holes could you have opened?

First web page opens Attack Surface significantly, introduces many new risks. Another field or similar page technically enlarges Attack Surface but doesn't meaningfully raise risk profile; incremental changes = more of same, unless new design or framework.

New page w/ same design and technology as existing pages: easy to gauge security testing/review needed. New web services API or Internet-uploadable file: different risk profile; check whether change fits existing bucket, whether existing controls apply. Doesn't fit bucket → more thorough risk assessment: what holes may open, what protections needed.

Review changes to: session management, authentication, password management. Authorization and access control logic, esp. adding/changing role definitions, adding admin users or high-privilege admin functions. Code handling encryption and secrets. Fundamental changes to data validation. Major architectural changes to layering and trust relationships, or technical architecture (swapping web server or database platform, changing runtime OS).

New user types/roles/privilege levels: same analysis and risk assessment. Overlay access type across data and functions; look for problems and inconsistencies. Understand access model: positive (deny by default) or negative (allow by default). Positive: mistakes in permitted data/functions for new role easy to see. Negative: must be much more careful that user gets no data/functions they shouldn't.

Assessment can be periodic, part of design work in serial/phased/spiral/waterfall projects, or continuous and incremental in Agile/iterative.

Attack Surface normally grows over time w/ more interfaces, user types, integrations. Reduce when possible: simplify model (fewer user levels, don't store confidential data you don't absolutely need), turn off unused features and interfaces, add operational controls e.g. Web Application Firewall (WAF) and real-time application-specific attack detection.

## References

- Howard, Pincus, and Wing: Measuring Relative Attack Surfaces
- OWASP: Threat Modeling
