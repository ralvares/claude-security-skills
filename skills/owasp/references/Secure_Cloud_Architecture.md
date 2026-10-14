# Cloud Architecture Security Cheat Sheet

## Introduction

Common, necessary security patterns for creating/reviewing cloud architectures. Each section = one security guideline or cloud design decision. Written for medium to large enterprise systems; includes overhead possibly unnecessary for smaller orgs.

## Risk Analysis, Threat Modeling, and Attack Surface Assessments

Application design guidance: [Secure Product Design Cheat Sheet](Secure_Product_Design.md).

Understanding risks/threats essential for any architecture. Budget/bandwidth finite → allocate security resources properly. Enterprises must perform risk assessments, threat modeling, attack surface assessments to identify:

- Threats application might face
- Likelihood of threats becoming attacks
- Attack surface those attacks could target
- Business impact of lost data/functionality from attack

Needed to scope architecture security. Subjects deserve more detail; use resources below.

- [Threat Modeling Cheat Sheet](Threat_Modeling.md)
- [Attack Surface Analysis Cheat Sheet](Attack_Surface_Analysis.md)
- CISA Cyber Risk Assessment

## Public and Private Components

### Secure Object Storage

Object storage access options:

- Built-in Identity and Access Management policies
- Cryptographically signed URLs and HTTP requests
- Direct access via public storage

#### IAM Access

Indirect access through tooling, e.g. managed/self-managed service on ephemeral or persistent infrastructure. Authenticate service w/ workload identity or federated role obtaining short-lived credentials; no embedded persistent access key. E.g., AWS recommends temporary credentials from IAM roles or federation for application access. Limit service permissions to required storage operations + resources. Best when application has other user interfaces/data systems, when hiding as much of storage system as possible matters, or when info shouldn't/won't be seen by end user (metadata). Combine w/ web authentication + logging to better track/control access. Key concern: reliance on developed code/policies that may contain weaknesses.

|                 Pros                 |                       Cons                         |
|:------------------------------------:|:--------------------------------------------------:|
|       No direct access to data       |          Potential use of broad IAM policy         |
| No user visibility to object storage | Stolen credentials expose permitted resources |
|   Identifiable and loggable access   |           Credentials could be hardcoded           |

Acceptable for sensitive user data, but must follow rigorous coding + cloud best practices.

#### Signed URLs

URL signing: statically/dynamically generated URLs cryptographically guaranteeing entity access to storage resource. Best when direct access to specific user files necessary/preferred (no file transfer overhead). Advisable only for user data not very sensitive. Secure-capable but notable cons: code injection possible if signed URL generation custom, dynamic, injectable; anyone w/ URL accesses resource anonymously. Must also decide if/when signed URL expires, adding complexity.

|                    Pros                   |                    Cons                   |
|:-----------------------------------------:|:-----------------------------------------:|
|        Access to only one resource        |              Anonymous Access             |
| Minimal user visibility to object storage |         Anyone can access with URL        |
|           Efficient file transfer         | Possibility of injection with custom code |

#### Public Object Storage

**Not advisable for resource storage and distribution**; only for public, non-sensitive, generic resources. Gives threat actors extra reconnaissance into cloud environment; any data stored this way for any period must be considered publicly accessed (leaked).

|                 Pros                |                 Cons                 |
|:-----------------------------------:|:------------------------------------:|
| Efficient access to many resources  |     Anyone can access/No privacy     |
|       Simple public file share      |  Unauthenticated access to objects   |
|                                     |  Visibility into full file system    |
|                                     |     Accidentally leak stored info      |

### VPCs and Subnets

Virtual Private Clouds (VPC) + public/private subnets segment application/network into chunks, adding security layers. Unlike other private-vs-public trade-offs, mature architecture likely uses most/all components.

#### VPCs

Network boundaries within application; components talk to each other like physical data center network. Made of public + private subnets. VPCs can:

- Separate entire applications in same cloud account.
- Separate large application components into distinct VPCs w/ isolated networks.
- Separate duplicate applications used for different customers/data sets.

#### Public Subnets

House internet-facing components. Contain routing elements letting components connect directly to internet. Use cases:

- Public facing resources, e.g. front-end web applications.
- Initial touch points, e.g. load balancers, routers.
- Developer access points, e.g. bastions (very insecure if engineered/deployed incorrectly).

#### Private Subnets

House components w/o direct internet access. Likely routed to public subnets to receive internet traffic in structured, protected way. Good for:

- Databases and data stores.
- Backend servers + associated file systems.
- Anything too sensitive for direct internet access.

#### Simple Architecture Example

Simple diagram below: VPC houses all application components; elements sit in specific subnet by role. Normal flow:

1. Access via internet gateway, API gateway, or other internet-facing component.
2. Gateway connects to load balancer or web server in public subnet. Both provide public-facing functions, secured accordingly.
3. These interact with backend counterparts (database, backend server) in private VPC. Connections more limited, preventing extraneous access to possibly "soft" backend systems.

![VPC Diagram](../assets/Secure_Cloud_Architecture_VPC.png)

*Note: diagram intentionally skips routing + IAM elements for subnet interfacing, for simplicity and provider agnosticism.*

Prevents less hardened backend components/higher risk services like databases being directly internet-exposed. Gives common public functionality internet access w/o extra routing overhead. Easier to secure by focusing on entry points + separating functionality; non-public/sensitive info in private subnet harder for external parties to reach.

## Trust Boundaries

Trust boundaries = connections between components where trust decision needed; point where two components with potentially different trust levels meet. Range from degree of trust given to users to trusting/verifying claims between code functions/components in cloud architecture. Don't grant access merely because component internal or same-org owned. NIST SP 800-207 requires explicit authentication + authorization for protected resources, not trust based solely on network location/ownership. Identify these checks between cloud components, and at connections to end users + other vendors.

Example below: API gateway connects to compute instance (ephemeral or persistent), which accesses persistent storage resource. Separate server verifies authentication, authorization and/or identity of caller (generic OAuth, IAM or directory system controlling access to these resources). Also Ephemeral IAM server controls access to stored resources (approach like [IAM Access](#iam-access) above). Dotted lines: trust boundaries between each compute component, API gateway, auth/identity server, even if many/all elements in same application.

![Trust Boundaries](../assets/Secure_Cloud_Architecture_Trust_Boundaries_1.png)

### Exploring Different Levels of Trust

Architects choose trust configuration between components using quantitative factors (risk score/tolerance, project velocity) + subjective security goals. Examples below show trust boundary relationships and implications of trusting a resource. Resource threat level as color green (safe) to red (dangerous) shows which resources shouldn't be trusted.

#### 1. No trust example

Model where no component trusts any other, regardless of criticality/threat level. Likely for incredibly high risk applications: very personal or important business data, or extremely high business criticality.

API gateway and compute components both call out to auth/identity server → no data passing between components, even adjacent "inside" application, is trusted. Compute instance must assume ephemeral identity to access storage: instance isn't trusted to specific resource even if user trusted to instance.

Also no trust between auth/identity server, ephemeral IAM server, and each component. Not displayed, but implies more rigorous checks before authentication, possibly more overhead for cryptographic operations.

![No Trust Across Boundaries](../assets/Secure_Cloud_Architecture_Trust_Boundaries_2.png)

Possibly necessary for financial, military, critical infrastructure systems. Security must be careful advocating this model: significant performance + maintenance drawbacks.

|              Pros                |         Cons          |
|:--------------------------------:|:---------------------:|
| High assurance of data integrity | Slow and inefficient  |
|         Defense in depth         |      Complicated      |
|                                  | Likely more expensive |

#### 2. High trust example

Opposite: everything trusted. "Dangerous" user input trusted, handed directly to high criticality business component. Auth/identity resource unused. Higher likelihood of successful attack: no preventive controls. Also wasteful: auth/identity and ephemeral IAM servers not performing intended function *(could be shared corporate resources not used to full potential)*.

![Complete Trust Across Boundaries](../assets/Secure_Cloud_Architecture_Trust_Boundaries_3.png)

Unlikely architecture except simplest, lowest risk applications. **Do not use this trust boundary configuration** unless no sensitive content to protect or efficiency only success metric. Trusting user input never recommended, even in low risk applications.

| Pros      | Cons                    |
|:---------:|:-----------------------:|
| Efficient |        Insecure         |
|  Simple   |   Potentially Wasteful  |
|           | High risk of compromise |

#### 3. Some trust example

Use risk analysis to place/configure access controls, not to omit verification of internal requests. Gateway can do shared authentication checks; services enforce authorization needing resource/business context. See [gateway and service-level authorization](Microservices_Security.md#service-level-authorization).

Here compute instance must authenticate calling gateway, validate propagated user context, enforce permissions for requested operation. Prevent direct access bypassing gateway checks. Instance uses own least-privileged identity for storage; authenticated user doesn't automatically authorize every storage operation.

![Some Trust Across Boundaries](../assets/Secure_Cloud_Architecture_Trust_Boundaries_4.png)

Limits pros/cons of both previous examples. Likely used for most applications unless above examples' benefits needed for business requirements.

|                   Pros                   |          Cons          |
|:----------------------------------------:|:----------------------:|
|           Secured based on risk          | Known gaps in security |
| Cost/Efficiency derived from criticality |                        |

*Note: this trust methodology diverges from Zero Trust. Deeper look: CISA's Zero Trust Maturity Model*.

## Security Tooling

### Web Application Firewall

Web Application Firewalls (WAF) monitor/block common attack payloads (like XSS, SQLi) or allow only specific request types/patterns. Use as first line of defense, attached to entry points (load balancers, API gateways), handling malicious content before application code. Cloud providers curate base rule sets blocking/monitoring common malicious payloads:

- AWS Managed Rules
- GCP WAF Rules
- Azure Core Rule Sets

Rule sets generic by design; don't cover every attack type. Consider custom rules for application-specific needs:

- Filtering routes to acceptable endpoints (block web scraping)
- Specific protections for chosen technologies + key application endpoints
- Rate limiting sensitive APIs

### Logging & Monitoring

Required for truly secure application. Developers should know exactly what happens in environment; alerting warns engineers when systems misbehave. In security incident, logging verbose enough to track threat actor through entire application and let respondents understand actions taken against resources. Proper logging/monitoring can be expensive; discuss risk/cost trade-offs.

#### Logging

Consider:

- Log HTTP request outcomes using allow-listed event schema, e.g. method, route template, status, correlation ID, non-secret actor identifier
    - Exclude credentials, session cookies, access tokens, sensitive request/response content before collection. HTTP authentication fields contain credentials (RFC 9110 section 11.4); don't capture all headers or bodies by default. Follow [Logging Cheat Sheet data exclusions](Logging.md#data-to-exclude).
- Log internal actions w/ actor + permission info
- Send trace IDs through entire request lifecycle to track errors/malicious actions
- Mask/remove sensitive data
    - SSNs, sensitive health info, other PII not stored in logs

*Legal and compliance representatives should weigh in on log retention times for the specific application.*

#### Monitoring

Consider adding:

- Anomaly alerts:
    - HTTP 4xx and 5xx errors above percent of normal
    - Memory, storage, CPU usage above/below percent of normal
    - Database writes/reads above/below percent of normal
    - Serverless compute invocations above percent of normal
- Alerting for failed health checks
- Alerting for deployment errors or container on/off cycling
- Alerts or cutoffs for cost limits

Anomaly counts/types vary wildly per app; defining anomaly needs environment-specific baseline. Choose percentages above from that baseline plus risk and team response capacity.

WAFs can have monitoring/alerting attached for counting malicious payloads or (sometimes) anomalous activity detection.

### DDoS Protection

Cloud providers offer DDoS protection from simple to advanced. Simple: WAFs w/ rate limits + route blocking rules. Advanced: provider-specific managed tools. Examples:

- AWS Shield
- GCP Cloud Armor Managed Protection
- Azure DDoS Protection

Enable advanced DDoS protection based on application risk + business criticality, mitigating factors, cost (services can be very inexpensive vs large company budgets).

## Shared Responsibility Model

Framework for cloud service providers (CSPs) and sellers of cloud-based services to identify/segment responsibilities of developer vs provider, by control level corresponding to technology stack layers. Generally CSP owns physical computing devices + data center space. Depending on level of [management](#self-managed-tooling), developer could own entire stack from operating system up, or only ancillary functionality, code, administration.

Often categorized into three service levels:

- Infrastructure as a Service ([IaaS](#iaas))
- Platform as a Service ([PaaS](#paas))
- Software as a Service ([SaaS](#saas))

*Many other service classifications exist; omitted for brevity.*

Responsibility CSP assumes = level of "service" it provides. Each level has own pros/cons, below.

### IaaS

CSP maintains infrastructure; developer maintains everything else, incl.:

- Authentication and authorization
- Data storage, access, management
- Certain networking tasks (ports, NACLs, etc)
- Application software

Favors developer configurability/flexibility; more complex, generally higher cost than other models. Closest to on premise models, waning among large companies. Migrating certain applications to cloud IaaS may be easier than re-architecting for cloud native.

|             Pros             |            Cons           |
|:----------------------------:|:-------------------------:|
| Control over most components |        Highest cost       |
|   High level of flexilibity  | More required maintenance |
| Easy transition from on-prem |  High level of complexity |

**Responsibility held almost exclusively by developer; secure accordingly**. Consider network access control, operating system vulnerabilities, application vulnerabilities, data access, authentication/authorization in IaaS security strategy. High control over almost whole stack, but hard to maintain without adequate resources for version upgrades or end of life migrations. *([Self-managed security updates](#update-strategy-for-self-managed-services) detailed below.)*

### PaaS

Middle between IaaS and SaaS. Developer controls:

- Application authentication and authorization
- Application software
- External data storage

Neatly packaged code hosting + containerized options; lets smaller teams/less experienced developers start while ignoring complex/superfluous computing tasks. Generally cheaper than IaaS, retains some control SaaS doesn't. But developers may hit offering-specific limitations or compatibility issues: code must work with correct container, framework, language version.

Scalability depends on provider/setup, but PaaS usually higher due to containerization options + common, repeatable base OS systems. Compare IaaS, where developer builds scalability, and SaaS, where performance very platform specific.

|              Pros              |              Cons              |
|:------------------------------:|:------------------------------:|
| Easier to onboard and maintain | Potential compatibility issues |
|       Better scalability       |  Offering specific limitations |

Manual security less extensive than IaaS. Developer still handles application-specific authentication/authorization and access to external data systems. CSP secures containerized instances, operating systems, ephemeral files systems, certain networking controls.

### SaaS

Nearly complete product; end user only configures/customizes small details. User generally controls:

- Configuration, administration and/or code within product's boundaries
- Some user access, e.g. designating administrators
- High level connections to other products via permissions/integrations

Provider (cloud service or software company) controls entire stack; developer makes relatively small tweaks. Limits cost + maintenance; problems typically solved via provider customer support, no need for technical knowledge to troubleshoot whole stack.

|               Pros               |                Cons                |
|:--------------------------------:|:----------------------------------:|
|          Low maintenance         | Restricted by provider constraints |
|            Inexpensive           |           Minimal control          |
| Customer support/troubleshooting |      Minimal insight/oversight     |

SaaS security simultaneously easiest and most difficult, given lack of control. Developer manages small set of security functions: some access controls, data trust/sharing relationship with integrations, security implications of customizations. Provider controls all other layers → security fixes out of developer's hands, may be untimely or not reach satisfactory security level for end user (per security needs). But fixes need no end user involvement/resources → easier on cost + maintenance burden.

*Note: when choosing SaaS, ask for company's attestation records and proof of compliance to standards like ISO 27001. Major CSPs' attestation sites for further understanding:*

- GCP
- AWS
- Azure

### Self-managed tooling

More generic view of shared responsibility: cloud tooling on a "management" spectrum. Fully managed services leave little for developer besides coding/administrative functionality (SaaS); self-managed systems need much more maintenance overhead (IaaS).

AWS example of this difference, showing where products fall on spectrum.

![Shared Responsibility Model](../assets/Secure_Cloud_Architecture_Shared_Responsibility_Model.png)

*Note: hard to say exactly which offerings are which service type (Ex: IaaS vs PaaS). Developers should understand the model applying to the specific tool used.*

#### Update Strategy for Self-managed Services

Self-managed tooling needs extra overhead from developers + support engineers. Depending on tool: basic version updates, image upgrades like AMIs or Compute Images, other operating system level maintenance. Automate regular minor version/image updates; schedule dev-cycle time to refresh stale resources.

#### Avoid Gaps in Managed Service Security

Managed services give some security, e.g. updating/securing underlying hardware running application code. Development team still responsible for many security aspects. Ensure developers understand which security is theirs based on tool selection. Likely partially/wholly developer responsibility:

- Authentication and authorization
- Logging and monitoring
- Code security (OWASP Top 10)
- Third-party library patching

Check CSP documentation for each party's security responsibilities per selected service. E.g., serverless functions:

- AWS Lambda
- GCP Cloud Functions
- Azure Functions

## References

- CISA: Cloud Security Technical Reference Architecture
- CISA: Zero Trust Maturity Model Version 2.0
