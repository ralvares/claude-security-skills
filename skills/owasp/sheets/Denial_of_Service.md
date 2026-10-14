# Denial of Service Cheat Sheet

## Introduction

Methodology for handling denial of service (DoS) attacks on different layers. Also platform for further discussion/analysis; many DoS methods exist.

### Fundamentals

Anti-DoS methods aren't one-step solutions; developers + application/infrastructure architects must develop DoS solutions carefully, keeping "availability" in mind as basic part of CIA triad.

If any part of computing system in interoperability flow malfunctions, infrastructure suffers. Successful DoS hinders availability of instances/objects to system, can eventually render entire system inaccessible.

**For resilience vs DoS, strongly suggest thorough analysis of inventory components by functionality, architecture, performance (application-wise, infrastructure, network).**

![DDOSFlow](../assets/Denial_of_Service_Cheat_Sheet_FlowDDOS.png)

DoS system inventory: find potential places where DoS causes problems; highlight single points of failure, from programming errors to resource exhaustion. Gives clear picture of issues (e.g. bottlenecks). **Solid understanding of environment essential to develop suitable defenses**. Align with:

1. Scaling options (**up** = inner hardware components, **out** = number of complete components).
2. Existing conceptual/logical techniques (redundancy measurements, bulk-heading, etc. - expands in-house capabilities).
3. Cost analysis for your situation.

Guidance structure adopted from CERT-EU; adapt to situation. Not complete approach; helps create fundamental blocks for anti-DoS concepts fitting your needs.

### Analyzing DoS attack surfaces

Uses DDOS classification documented by CERT-EU. Uses seven OSI model; three main attack surfaces: Application, Session, Network.

#### 1) Overview of potential DoS weaknesses

Consider each of three categories when designing DoS-resilient solution:

 **Application attacks**: render applications unavailable by exhausting resources or making functionally unusable.

 **Session (or protocol) attacks**: consume server resources, or resources of intermediary equipment like firewalls and load-balancers.

 **Network (or volumetric) attacks**: saturate bandwidth of network resource.

OSI layers 1 and 2 not in this categorization; covered here.

**Physical layer**: networking hardware transmission technologies; foundation under logical data structures of higher layers. Typical DoS: system destruction, obstruction, malfunction. E.g., Georgian elderly woman sliced underground cable → internet loss for whole of Armenia.

**Data layer**: protocol layer transferring data between adjacent network nodes in wide area network (WAN) or nodes on same local area network (LAN) segment. Typical DoS: MAC flooding (targeting switch MAC tables), ARP poisoning.

**MAC flooding**: switch flooded w/ packets all w/ different source MAC addresses. Goal: consume limited switch memory for MAC/physical port translation table (MAC table); valid MAC addresses purged, switch enters fail-over mode as network hub. All data forwarded to all ports → data leakage.

[Future additions to sheet: The impact in relation to DoS and document compact remediation]

**ARP poisoning**: malicious actor sends spoofed ARP (Address Resolution Protocol) messages. If attacker's MAC address linked to legitimate device's IP, attacker can intercept, modify, stop data intended for victim IP. ARP is LAN-specific; can cause DoS on wire communication.

Mitigation: packet filtering to inspect packets in transit, block offending ARP packets. Alternative: static ARP tables, hard to maintain.

## Application attacks

**Application layer attacks usually make applications unavailable by exhausting system resources or making functionally unusable.** Need not consume network bandwidth; strain application server operationally until unavailable, unusable, non-functional. All attacks exploiting OSI layer 7 protocol stack weaknesses generally categorised as application attacks. Hardest to identify/mitigate.

[Future additions to sheet: List all attacks per category. Because we cannot map remediations one on one with an attack vector, we will first need to list them before discussing the action points.]

**Slow HTTP attacks deliver HTTP requests very slow and fragmented, one at a time. Until request fully delivered, server keeps resources stalled waiting for missing data.** Eventually server reaches maximum concurrent connection pool → DoS. Cheap for attacker; minimal resources.

### Software Design Concepts

- **Use cheap-in-resources validation first**: reduce resource impact early. Run more (CPU, memory, bandwidth) expensive validation afterward.
- **Employ graceful degradation**: core concept in design phase to limit DoS impact. Continue some functionality when portions of system/application break. DoS causes sudden abrupt terminations throughout system. Fault tolerant design lets system continue intended operation, possibly reduced, rather than fail completely if parts fail.
- **Prevent single point of failure**: detecting/preventing single points of failure (SPOF) key to resisting DoS. Most DoS assumes system has SPOFs that fail when overwhelmed. Suggest: stateless components, redundant systems, bulkheads to stop failures spreading across infrastructure, systems surviving external service failure.
- **Avoid highly CPU consuming operations**: during DoS, CPU-heavy operations drag performance, become failure point. Strongly suggest reviewing code performance issues, incl. language-inherent ones. See Java, JVM-IBM, Microsoft-IIS.
- **Handle exceptions**: during DoS applications likely throw exceptions; systems must handle gracefully. DoS assumes overwhelmed system can't throw exceptions in way allowing continued operation. Review code; ensure exceptions handled properly. See Large-Scale-Systems, Java.
- **Protect overflow and underflow**: buffer overflow/underflow often lead to vulnerabilities; learn to prevent. OWASP, Overflow-Underflow-C, Overflow.
- **Threading**: avoid operations waiting for completion of large tasks to proceed. Asynchronous operations help.
- Identify resource intensive pages; plan ahead.

### Session

- **Limit server side session time based on inactivity and a final timeout** (resource exhaustion): session timeout usually discussed for session security/hijacking prevention, but also prevents resource exhaustion.
- **Limit session bound information storage**: less data linked to session → less burden on webserver performance.

### Input validation

- **Limit file upload size and extensions**: prevents DoS on file space storage or app functions using upload as input (e.g. image resizing, PDF creation, etc.) (resource exhaustion) - Checklist.
- **Limit total request size**: harder for resource-consuming DoS to succeed. (resource exhaustion)
- **Prevent input based resource allocation**: same reason. (resource exhaustion)
- **Prevent input based function and threading interaction**: user input can influence how many times function executes, or CPU intensity. Unfiltered user input driving resource allocation allows DoS via resource exhaustion. (resource exhaustion)
- **Input based puzzles** like captchas or simple math problems often 'protect' web forms. Classic: webform sending email after posting; captcha prevents mailbox flooding by attacker/spambot. **Puzzles help vs functionality abuse but do not defend against DoS attacks.**

### Access control

- **Authentication as a means to expose functionality**: least privilege helps prevent DoS by denying attackers access to potentially damaging functions via DoS techniques.
- **User lockout**: attacker can abuse application security mechanisms to cause DoS via login failure abuse.

## Network attacks

More on network attacks: Juniper, eSecurityPlanet.

[Future additions to cheat sheet: Discuss attacks where network bandwidth gets saturation. Volumetric in nature. Amplification techniques make these attacks effective. List attacks: NTP amplification, DNS amplification, UDP flooding, TCP flooding]

### Network Design Concepts

- **Preventing single point of failure**: see above.
- **Caching**: data stored so future requests served faster. More data served via caching → more resilience to bandwidth exhaustion.
- **Static resources hosting on different domain** reduces number of http requests on web app. Typical: images, JavaScript.

### Rate limiting

Controls traffic rate from/to server or component. Implement at infrastructure or application level. Can be based on (offending) IPs, IP block lists, geolocation, etc.

- **Define a minimum ingress data rate** w/ request-read timeouts to mitigate slow HTTP attacks; e.g., Apache's minimum-rate and timeout controls. Minimum rate too high can reject legitimate slow clients; too low weakens protection vs slow senders. Inspect logs to baseline genuine traffic rates.
- **Define an absolute connection timeout**
- **Define a maximum ingress data rate limit**; drop all connections above that rate.
- **Define a total bandwidth size limit** to prevent bandwidth exhaustion
- **Define a load limit**: number of users allowed to access any given resource at any given time.

### ISP-Level remediations

- **Filter invalid sender addresses using edge routers**, per RFC 2267, to filter IP-spoofing attacks aimed at bypassing block lists.
- **Check ISP DDOS services beforehand** (support for multiple internet access points, enough bandwidth (xx-xxx Gbit/s), special hardware for traffic analysis + application-level defense

### Global-Level remediations: Commercial cloud filter services

- Consider DDoS filtering service for larger attacks. Assess provider's mitigation capacity + coverage against availability requirements; don't assume fixed attack-size ceiling.
- **Filter services** support different mechanics to filter malicious/non-compliant traffic
- **Comply with relevant data protection/privacy laws** - many providers route traffic through USA/UK

## References

- CERT-EU: DDoS Overview and Incident Response Guide
- Juniper: Network DoS Attacks
