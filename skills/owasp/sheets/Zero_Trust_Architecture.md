# Zero Trust Architecture Cheat Sheet

## Introduction

Implement Zero Trust Architecture (ZTA). Zero Trust = "never trust, always verify": trust no one/nothing by default, even inside network.

Traditional security = castle walls; inside, access everything. Zero Trust checks every person and device on every access attempt, like guards at every door. Prevents attackers who get inside from moving around and stealing data.

## Core Zero Trust Principles

From NIST SP 800-207:

### 1. All Data Sources and Computing Services are Resources

Everything in network = resource needing protection: servers, databases, cloud services, IoT devices, user devices. Nothing safe just because "internal." Each resource needs own security controls.

### 2. All Communication is Secured Regardless of Network Location

Every connection encrypted + authenticated: office to cloud, between internal systems, home to work. Network location ≠ trust level. Use strong encryption (TLS 1.3 or better) for everything.

### 3. Access to Resources is Granted on a Per-Session Basis

Authorize each resource session w/ least privileges needed. Authorization for one resource must not automatically grant access to another. NIST SP 800-207, Section 2.1 permits sufficiently recent trust evaluation; doesn't require new interactive login per request. Set [session expiration and reauthentication requirements](Session_Management.md#automatic-session-expiration) by resource sensitivity and risk.

### 4. Access is Determined by Dynamic Policy

Access decisions weigh: who asks, device used, connection location, time, normal behavior. Policies change with risk. Payroll access during work hours from work laptop = low risk. Same person downloading lots of data at 2 AM from coffee shop = high risk.

### 5. Monitor and Measure the Security Posture of All Assets

Continuously check health/security of all devices and systems. Can't see it, can't protect it. Monitor patches, antivirus status, configuration changes, suspicious behavior. Assets falling out of compliance lose access.

### 6. All Authentication and Authorization is Dynamic and Strictly Enforced

Enforce authentication and authorization before granting access; reevaluate ongoing sessions per policy. Trigger reauthentication/reauthorization when policy requires: time limit, request for another resource, suspicious activity. Revoke access when applicable policy no longer permits, balancing security with availability and usability per NIST SP 800-207, Section 2.1.

### 7. Collect Information to Improve Security Posture

Collect asset posture, traffic, access-request data to improve security decisions. Assess and mitigate privacy risks of this monitoring per NIST SP 800-207, Section 6.2. Apply [Logging Cheat Sheet](Logging.md#data-to-exclude) guidance on excluding sensitive data and protecting collected logs.

## Core Zero Trust Architecture Components

Three main parts work together:

**Policy Engine** - decides allow/block. Weighs user identity, device health, location, behavior, risk scores. Hard part: policies secure but not making work impossible.

**Policy Administrator** - takes Policy Engine decision, tells enforcement systems what to do. Engine says "allow access but require extra verification" → Administrator works out details, sends commands to right systems.

**Policy Enforcement Point** - actually blocks/allows access attempts: firewalls, proxy servers, application gateways, API gateways. Enforcement must happen everywhere, not just network edge.

Components decide, establish, monitor, terminate resource access per policy; doesn't require new interactive login at every enforcement point.

## How Zero Trust Addresses Modern Security Challenges

Zero Trust tackles problems traditional approaches can't handle effectively:

### Traditional vs. Zero Trust Responses

| Attack Scenario | Traditional Security Response | Zero Trust Response |
|----------------|------------------------------|-------------------|
| **Stolen credentials** | Reset password, add basic MFA | Continuous risk assessment, device verification, behavioral analysis - access denied even w/ valid credentials if risk high |
| **Insider threat** | Trust employees inside network perimeter | Verify every action regardless of location, role, tenure - no implicit trust |
| **Lateral movement** | Perimeter security w/ flat internal network | Micro-segmentation blocks movement between systems, each connection verified |
| **Compromised device** | VPN access grants network access | Device health continuously monitored, access immediately revoked on detected compromise |
| **Privileged account abuse** | Permanent admin rights w/ periodic reviews | Just-in-time access w/ automatic expiration + continuous monitoring |
| **Data exfiltration** | Network monitoring and DLP at perimeter | Data-level access controls w/ real-time behavior analysis |

### Modern Threats That Require Zero Trust

Some attack patterns designed to bypass traditional security; Zero Trust gives advanced capabilities against them:

**Supply Chain Attacks** - malicious code hidden in trusted software (e.g. SolarWinds) bypasses perimeter completely. Zero Trust: application-level identity verification, runtime behavior monitoring, micro-segmentation to limit damage.

**Cloud Configuration Drift** - misconfigured cloud resources expose data outside traditional network boundaries. Zero Trust: policy-as-code, continuous compliance monitoring, resource-level access controls.

**API-First Attacks** - direct API attacks bypass network security. Zero Trust: authentication + authorization on every API call, request schema validation, behavioral analysis for abuse patterns.

**Identity-Based Attacks** - Pass-the-Hash, Golden Ticket steal identity tokens to impersonate users. Zero Trust: short-lived tokens w/ continuous validation, device binding, behavioral analysis for unusual access patterns.

### ZTA Decision-Making in Action

Three examples of correctly set up Zero Trust:

#### Case Study 1: Working Late from Home

**What happened:** Finance manager needed payroll data from home at 11:30 PM for early morning meeting. Never accessed payroll outside normal work hours before.

**How Zero Trust handled it:**

Risk factors: odd time (way outside 9-5), home network not office, sensitive data (payroll = personal info + salaries). Good signs: company laptop w/ current security, valid device certificate, right job role.

Not blocked; extra verification: hardware security key + approve phone notification. Then access with limits: 90-minute session, detailed logging of all actions, extra verification if downloading large data amounts.

**Why this worked:** Urgent work done without calling IT; strong controls matched risk level.

#### Case Study 2: New Contractor Laptop

**What happened:** External contractor on software project needed development systems access from brand-new laptop never connected before.

**How Zero Trust handled it:**

Unknown device → direct network access blocked immediately. Contractor sent to secure browser platform with access only to needed development tools.

All work in isolated cloud environment: write code, read documentation, work with team; nothing touched laptop. Session recorded for security review; no file downloads, no access outside project.

**Why this worked:** Contractor productive without security risk; company kept complete control of code and data.

#### Case Study 3: Cross-Team Project Access

**What happened:** Marketing manager suddenly viewed engineering documents never accessed before. Legitimate (cross-team project), but system couldn't know automatically.

**How Zero Trust handled it:**

Unusual access pattern → medium-risk alert. Not blocked right away; required manager approval via automated workflow. Notified her boss and engineering team lead explaining requested access.

Once approved: temporary access expiring in 24 hours. Everything viewed logged in detail; security team got summary. More time needed → request extension with business reason.

**Why this worked:** Cross-team collaboration not blocked by security rules; company kept visibility and control over sensitive technical info.

#### What These Cases Show

Zero Trust didn't just say "yes"/"no"; made decisions balancing security and business needs. Weighed multiple risk factors, applied appropriate controls, kept detailed records for compliance and investigation.

Separates good Zero Trust implementations from basic access control: technology adapts to situation instead of forcing users around rigid rules.

Next: implementation. Start with identity and access management, foundation for everything else.

## Identity and Access Management

### Multi-Factor Authentication (MFA)

MFA for everyone: employees, contractors, partners. Best options:

**Most Secure (Highly Phishing-Resistant):**

- **FIDO2 hardware security keys**: use with PIN, biometric activation, or separate password for MFA
- **WebAuthn-based platform authenticators**: passkeys w/ required user verification via device PIN or biometrics
- **Smart cards or PIV cards**: PKI-based authentication

Biometrics alone ≠ MFA. They can activate physical cryptographic authenticator, combining possession of authenticator with biometric match. See NIST SP 800-63B-4, Section 3.2.3 and [Passkey Security Cheat Sheet](Passkey_Security.md#verify-the-authentication-response).

**Good Options:**

- **Mobile apps**: TOTP-based authenticator applications
- **Backup codes**: when primary methods fail

**Avoid:**

- **SMS-based MFA**: vulnerable to SIM swapping and phishing

Conditional access: high-risk situations require stronger authentication. OMB M-22-09 mandates phishing-resistant MFA for U.S. federal agencies.

### Managing User Accounts

- **Use one identity system**: no multiple user databases
- **Automate account creation**: set up role-based access automatically
- **Review access regularly**: check who has access every quarter
- **Separate admin accounts**: no regular accounts for administration

Follow comprehensive authentication best practices for user account management.

### Access Controls

Rules for giving access:

- **Least privilege**: minimum access needed for job
- **Just-in-time access**: elevated access only when needed for specific task
- **No permanent admin rights**: remove always-on administrative privileges
- **Smart decisions**: consider user role, location, device when granting access

## Device Security

### Trusting Devices

Before trusting any device, ensure it meets standards:

- **Register all devices**: list of approved devices w/ unique certificates
- **Continuous health assessment**: real-time monitoring of antivirus status, OS patches, security configurations, device security posture
- **Certificate-based device identity**: PKI certificates uniquely identify and authenticate each device
- **Vulnerability scanning**: regular assessment of device security posture and patch levels
- **Revoke trust when compromised**: automatically remove access if device security compromised

### Protecting Endpoints

Every device needs:

- **Anti-malware software**: real-time protection against viruses and malware
- **Behavior monitoring**: watch for suspicious device activity
- **Full disk encryption**: encrypt all data on device
- **Remote wipe**: erase lost or stolen devices

## Network Architecture

### Micro-Segmentation

Replace one big network w/ small isolated segments:

- **Separate by application**: each app gets own network segment
- **Block by default**: no traffic unless specifically permitted
- **Monitor internal traffic**: watch data moving between systems
- **Use encrypted communications**: all inter-system communication encrypted

### Network Controls

Implement:

- **DNS filtering**: block malicious websites
- **Web filtering**: control which websites users can visit
- **Limit remote access**: prefer access to specific resources over broad network access. During migration, restrict and monitor any necessary remaining VPN access; VPN connection alone must not authorize access to other resources.
- **Monitor traffic**: analyze all network connections

## Application and Data Protection

### Securing Applications

Controls:

- **Identity-aware proxy**: check user identity before allowing app access
- **Web Application Firewalls (WAFs)**: request filtering as defense in depth for common attack patterns, e.g. covered by OWASP CRS. WAF doesn't replace application authorization or business-rule enforcement; enforce access control in trusted server-side code.
- **API security gateways**: authenticate every API call, validate request schemas, enforce rate limits for microservices communication per REST security best practices
- **Secure development**: build security into development process

### Protecting Data

Methods:

- **Classify data**: label by sensitivity level
- **Use encryption**: protect data stored or moving w/ proper cryptographic storage
- **Prevent data loss**: monitor and block unauthorized data transfers
- **Log all access**: record who accesses what data and when

## Monitoring and Analytics

### Security Operations

Monitoring capabilities:

- **SIEM integration**: collect and analyze logs from all systems
- **Threat hunting**: actively look for signs of attack
- **Automated response**: automatically block suspicious activity
- **Behavior analysis**: learn normal patterns, detect anomalies

### Key Metrics to Track

- How often authentication succeeds vs. fails
- Number of security policy violations
- How quickly threats detected (MTTD)
- How quickly incidents responded to (MTTR)

## Implementation Steps

Plan migration around resources, risks, dependencies. NIST SP 800-207, Section 7 recommends incremental migration and allows existing and Zero Trust workflows to coexist. Phases below = illustrative activities, not fixed schedule.

### Phase 1: Get the Basics Right

Before investing in new Zero Trust technologies, know what you're protecting:

**Figure out what you have** - list all users, devices, applications, data flows. Takes longer than expected. Expect forgotten systems, shadow IT, undocumented connections.

**Set up strong MFA everywhere** - phishing-resistant MFA per [Multi-Factor Authentication](#multi-factor-authentication-mfa), not biometric match alone as MFA. Plan user training; changes how people log in.

**Narrow remote access** - move suitable workflows to application-specific access, e.g. Zero Trust Network Access (ZTNA). Test authentication and resource authorization before retiring existing access paths. Restrict and monitor legacy VPN paths during transition; network admission ≠ authorization.

**Control admin access** - privileged access management (PAM) for administrative accounts. Remove permanent admin rights, switch to temporary access. May slow some processes initially.

### Phase 2: Add Zero Trust Controls

Build actual Zero Trust capabilities:

**Break up your network** - split flat network into smaller separate segments. Start with most important applications. Technically hard; network teams may resist extra work.

**Monitor devices constantly** - systems continuously checking device health, updates, security. Insecure devices automatically lose or get limited access. Pressures people to keep devices updated.

**Secure applications properly** - identity-aware access at application entry points plus [resource-level authorization](Authorization.md#validate-the-permissions-on-every-request) within application. WAF filtering complements; doesn't establish user's right to access object or perform business action.

### Phase 3: Advanced Capabilities

**Add behavior monitoring** - systems learning normal user/device behavior. Odd behavior → system automatically changes access or asks for more verification. Needs machine learning and lots of data.

**Automate responses** - tools automatically isolating compromised accounts, quarantining suspicious devices, updating security policies on new threats. Goal: respond faster than humans.

**Use your data** - use collected security data to improve policies. Fine-tuning, not building new.

### Phase 4: Keep Getting Better (Ongoing)

Zero Trust never done:

**Stay current** - update threat intelligence, adjust risk scoring, change policies for new attack methods. Last year's controls may not work now.

**Plan ahead** - consider post-quantum cryptography, new authentication methods, AI-powered security tools.

**Measure what matters** - track detection speed, response speed, policy violation count, user satisfaction. Use data to keep improving.

Use CISA Zero Trust Maturity Model v2.0 to assess progress across identity, devices, networks, applications and workloads, data. Traditional, Initial, Advanced, Optimal stages describe capabilities, not calendar deadlines; pillars may progress at different rates.

## Legacy System Challenges

### Common Problems

Legacy systems = among biggest Zero Trust challenges; attackers focus there since harder to secure.

**Weak authentication** - probably most common. Many older systems support only basic username/password, no MFA option. Built when passwords considered sufficient; modern authentication needs significant modification or replacement. Most sensitive systems often have weakest authentication.

**Network dependencies** - older systems designed for flat trusted networks, everything inside perimeter considered safe. Often need direct network access between components, can't work with micro-segmentation. Expect free communication with other systems without identity checks.

**No encryption** - common in legacy environments. Many send data in plain text (designed for internal networks considered secure). Adding encryption often needs significant changes to systems and dependent network infrastructure.

**Limited logging** - hard to monitor for threats. Older systems often lack detailed security logs needed for modern threat detection and compliance. Can't manage what you can't measure; poor logging leaves blind spots.

### Solutions That Work

Protect legacy systems without full replacement via creative approaches:

**Security proxies and wrappers** - add modern authentication and security controls in front of systems that can't support them natively. Proxy handles strong authentication, multi-factor verification, session management, other Zero Trust verification, then passes authenticated requests to legacy system in whatever method it understands. May include identity-aware proxies, application firewalls, API gateways. Works particularly well for web-based legacy applications.

**Network isolation** - put legacy systems in separate heavily monitored network zones w/ very restricted access. Can't apply Zero Trust principles directly, but can control how they communicate with everything else. Monitor all traffic to/from zones; require modern authentication for any zone access.

**Protocol translation** - for systems using old authentication methods that can't be modified. Translation gateways convert modern authentication tokens (e.g. SAML or OAuth) to format legacy system expects (e.g. Kerberos or basic auth), bridging old and new.

**Enhanced monitoring** - critical for systems that can't log properly. Network-based detection tools monitor traffic patterns, connection attempts, data flows. Less visibility than modern applications, better than none.

## Cloud Security

### Multi-Cloud Considerations

Multiple cloud providers:

- **Connect identities**: same login across all clouds
- **Secure connections**: encrypt communication between cloud environments
- **Consistent policies**: same security rules everywhere
- **Centralized monitoring**: security events from all clouds in one place

### Container Security

Containerized applications:

- **Service mesh**: automatically handle identity and encryption between containers
- **Network policies**: control which containers can talk to each other
- **Scan images**: check container images for vulnerabilities
- **Runtime protection**: monitor container behavior for threats

## Common Mistakes to Avoid

### Technical Mistakes

**Relying only on network security** - many think adding network controls = Zero Trust. Zero Trust is fundamentally identity-based, not network security. Thinking "inside"/"outside" network misses point. Verify identity and device health for every access request regardless of origin.

**Not monitoring enough** - Zero Trust generates massive security data; some organizations get overwhelmed, don't use it effectively. Need comprehensive logging and analysis, not basic monitoring. Without visibility, can't detect threats, tune policies, prove compliance. Invest in SIEM tools and security analytics platforms handling data volume, following comprehensive logging practices.

**Making security too hard for users** - painful implementation → workarounds bypassing security. Balance security with user experience. Risk-based authentication: low-risk activities seamless, friction only when risk justifies. Test policies with real users before rollout.

**Forgetting about legacy systems** - many projects focus on new cloud-native apps, ignore older systems unable to support modern authentication. Legacy systems often hold most sensitive data, become weakest links. Need strategy for systems not easily upgraded.

### Organizational Mistakes

**No executive support** - requires significant changes in how people work, substantial budget, coordination across teams. Without leadership commitment and budget approval, project stalls on resistance or resource constraints. Get executive sponsorship before starting.

**Skipping user training** - changes how people authenticate, access applications, handle security alerts. Without educating staff why and how, face constant resistance and support tickets. Plan comprehensive training programs, not just email announcements.

**Skipping migration validation** - pilot changes on selected workflows, verify legitimate access still works, monitor policy decisions before expanding. Choose next workflow by risk and dependencies per NIST SP 800-207, Section 7.3.

**Vendor lock-in** - Zero Trust spans many technologies; some vendors sell complete "Zero Trust platform" locking into their ecosystem. Keep options open: choose solutions supporting open standards, integrating with multiple vendors. Architecture flexible enough to adapt as threats and technologies evolve.

## Compliance Benefits

Zero Trust architecture helps meet compliance requirements:

### Framework Mapping

| Compliance Standard | Zero Trust Controls That Help |
|-------------------|------------------------------|
| **SOC 2** | Strong access controls, continuous monitoring, audit logging |
| **ISO 27001** | Risk-based access decisions, information security management |
| **PCI DSS** | Network segmentation, encrypted communications, access monitoring |
| **HIPAA** | Granular access controls, data encryption, audit trails |
| **GDPR** | Privacy-by-design, data access logging, breach detection |
| **OMB M-22-09** | Phishing-resistant MFA, device certificates, encrypted DNS |

## Technology Components

Several technology categories work together:

- **Identity and Access Management**: strong authentication (MFA), risk-based access decisions
- **Zero Trust Network Access (ZTNA)**: resource-specific access controls, restricted legacy access paths during migration
- **Web Application Security**: protect applications and APIs from OWASP Top 10 attacks
- **Security Monitoring**: real-time visibility, automated response to threats

### Policy-as-Code + Continuous Verification + Telemetry Signals

Implementation options for cloud-native workloads, not universal Zero Trust requirements. NIST SP 800-207, Section 2.1 defines technology-agnostic principles. Implementation guidance: [Kubernetes policy management](Kubernetes_Security.md#implementing-centralized-policy-management), [CI/CD Security](CI_CD_Security.md).

#### 1. Policy-as-Code (PaC)

Can make supported policy changes version-controlled, testable, auditable. Choose enforcement mechanisms fitting resources and workflows protected.

**Key principles:**

- Version-controlled policies
- Tested within CI/CD pipelines
- Automatically enforced at deployment
- Traceable via audit logs

**Recommended tools:**

- Open Policy Agent (OPA) / Gatekeeper
- Kyverno
- Cilium Network Policies
- Cloud provider policy engines (AWS SCP, Azure Policy, GCP Org Policy)

**Use cases:**

- Admission control
- Workload security (privileges, capabilities, runtime profiles)
- Network segmentation (L3–L7)
- Image and artifact security
- RBAC enforcement

#### 2. Continuous Verification

Automated deployment/configuration checks help enforce workload security policies. Complement resource-access authentication and authorization above.

**Verification examples:**

- Workload identity verification (SPIFFE/SPIRE, IAM)
- Image signature validation (cosign / sigstore)
- Security quality gates (SAST, IaC scanning, image scanning)
- RBAC drift detection
- Network policy drift detection
- Automated enforcement at admission

Admission checks can reject deployments violating configured policies; don't replace runtime resource authorization.

#### 3. Telemetry Signals

Zero Trust decisions rely on **telemetry signals** collected continuously across all layers.

**Suggested signals:**

- **Identity telemetry:** user + service + workload identity correlation
- **Network telemetry:** anomalous east-west traffic, failed login attempts
- **Runtime telemetry:** syscall anomalies, unauthorized execs, file system changes
- **Deployment telemetry:** manifest change anomalies, signature mismatches
- **Vulnerability telemetry:** CVSS, exploitability, runtime reachability

**Recommended tools:**

- Cilium Hubble
- Falco or Tetragon (eBPF-based runtime signals)
- OpenTelemetry (OTel)
- Istio / Linkerd telemetry

#### 4. Zero Trust Security Loop

1. **Policy-as-Code** → policies defined in code repositories, tested.
2. **Continuous Verification** → every change/deployment validated against policies.
3. **Telemetry Signals** → runtime signals give continuous monitoring.
4. **Feedback Loop** → collected signals refine policies.

Use loop to improve selected controls; particular tool or deployment pipeline ≠ proof of Zero Trust.

## References

- NIST SP 800-207: Zero Trust Architecture
- CISA: Zero Trust Maturity Model, Version 2.0
