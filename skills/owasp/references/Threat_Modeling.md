# Threat Modeling Cheat Sheet

## Introduction

Concise actionable reference on threat modeling for newcomers and refreshers. OWASP Threat Modeling project has further info.

## Overview

Threat modeling: structured, repeatable process giving actionable insight into system security. Model system from security perspective, identify applicable threats, determine responses. Analyzes system adversarially: how attacker can exploit it.

Perform early in SDLC (design phase). Not one-off: maintain, update, refine alongside system. Integrate seamlessly into team's SDLC as standard necessary step, not add-on.

Per Threat Modeling Manifesto, process answers four questions:

1. What are we working on?
2. What can go wrong?
3. What are we going to do about it?
4. Did we do a good enough job?

These form foundation for four major phases below.

## Advantages

Why threat model? Benefits:

### Identify Risks Early On

Finds security issues in design phase → security "built-into" system, not "bolted-on". Far more efficient than fixing flaws in production.

### Increased Security Awareness

Requires participants to think creatively/critically about app's security and threat landscape; "think like an attacker", apply general security knowledge to specific context. Team effort, ideas and feedback shared. Highly educational.

### Improved Visibility of Target of Evaluation (TOE)

Requires deep system understanding: data flows, trust boundaries, other characteristics. Improves visibility into system and interactions.

## Addressing Each Question

No universally accepted industry standard, no "right" answer for every use case. Most approaches include system modeling, threat identification, risk response. Sheet breaks into four steps: application decomposition, threat identification and ranking, mitigations, review and validation. Less aligned processes exist, incl. Process for Attack Simulation and Threat Analysis (PASTA) and Operationally Critical Threat, Asset, and Vulnerability Evaluation (OCTAVE), each w/ passionate advocates.

### System Modeling

Answers "what are we working on"? Can't know applicable threats w/o understanding system; critical foundation. Data flow diagrams (DFDs) arguably most common technique.

DFDs visually model system, data flows, interactions w/ external entities. Create w/ diagramming tool or whiteboard; save in form team can update. Complex systems: high-level overview plus detailed diagrams of individual components.

However generated, model must clearly show trust boundaries, data flows, data stores, processes, external entities interacting w/ system. These often are possible attack points, crucial input for later steps.

Alternative to DFDs: brainstorming; effective for generating ideas and discovering project domain. Benefits: team engagement, unified knowledge and terminology, shared domain understanding, quick identification of key processes and dependencies. Flexible, adaptable to almost any scenario incl. business logic. Useful w/ less technical participants: removes barriers to understanding/applying DFD components and correctness.

Engages all participants, better communication/mutual understanding. Every member contributes → more responsibility, involvement. Participants define and agree key terms → unified project language; important in complex projects where teams use different terminology. Dynamic nature → quickly identifies key business processes and interrelations.

Integrate brainstorming results with formal modeling → better domain understanding, more effective system design.

### Cloud Threat Modeling

Most modern systems cloud-native or hybrid. Traditional techniques (STRIDE, DFDs) often need adaptation for cloud architectures, which introduce:

- Shared responsibility models
- Managed services and APIs
- Multi-tenant and identity federation considerations
- Dynamic infrastructure (IaC, serverless, containers)

Cloud-native systems: distributed, service-oriented, shared responsibility. Process should account for:

- **Cloud architecture components:** virtual networks, IAM roles, managed services, storage buckets.
- **Shared responsibility:** which controls provider manages vs. customer.
- **Dynamic environments:** container orchestration, serverless functions, ephemeral infrastructure.
- **Compliance and data residency:** workloads meet jurisdictional and privacy requirements.

### Threat Identification

After modeling, address "what can go wrong?" using step-one inputs: identify and rank threats in context of specific system. Many data sources/techniques available. Sheet uses STRIDE for illustration; other approaches may be used alongside or instead.

STRIDE: mature, popular technique and mnemonic, originally from Microsoft employees. Groups threats into six general prompts; engineers systematically consider how each may materialize in specific system. Each STRIDE threat = violation of desirable security attribute:

| Threat Category             | Violates          | Examples                                                                                                    |
| --------------------------- | ----------------- | ----------------------------------------------------------------------------------------------------------- |
| **S**poofing                | Authentication    | Attacker steals legitimate user's authentication token, impersonates user.       |
| **T**ampering               | Integrity         | Attacker abuses app to make unintended database updates.                             |
| **R**epudiation             | Accounting        | Attacker manipulates logs to cover actions.                                                        |
| **I**nformation Disclosure  | Confidentiality   | Attacker extracts data from database containing user account info.                                     |
| **D**enial of Service       | Availability      | Attacker locks legitimate user out of account via many failed authentication attempts. |
| **E**levation of Privileges | Authorization     | Attacker tampers with JWT to change role.                                                        |

Use six categories as prompts reviewing system model. Brainstorm threats w/ team; record affected components, data flows, trust boundaries.

Then rank threats. In theory rank by product of likelihood and impact: likely + serious damage prioritized far above unlikely + moderate impact. Both hard to calculate and ignore fix effort; some advocate including effort in single prioritization.

#### Choosing a Threat Modeling Technique

Start with STRIDE for technical design; pick another technique when scope needs different view. Software Engineering Institute comparison: methods focus on different concerns, may be combined.

| When the team needs to analyze | Consider | How to use it |
| ------------------------------ | -------- | ------------- |
| Security threats in a technical design | STRIDE | Apply six threat categories to components, data flows, trust boundaries. |
| A high-value attacker goal or multi-step attack | Attack trees | Start from attacker goal, decompose alternative/required paths. |
| Abuse of a valid workflow or business rule | Misuse or abuse cases | Explore actions out of order, repeated, concurrent, or for unintended outcome. |
| Privacy properties and harms | LINDDUN (Linking, Identifying, Non-repudiation, Detecting, Data disclosure, Unawareness and Unintervenability, Non-compliance) | Apply privacy-specific prompts not fully covered by STRIDE's security properties. |
| Application threats with business impact | PASTA | Connect business objectives + technical requirements to application threats. |
| Organization-wide risk to critical assets | OCTAVE | Assess organizational risk, plan security strategy for critical assets. |
| Application and operational threats across many teams | VAST (Visual, Agile, and Simple Threat Modeling) | Maintain separate application and operational threat models within development workflows. |

Don't add techniques just to look comprehensive. State why each fits scope; record concerns it doesn't address.

### Response and Mitigations

Answers "what are we going to do about it"? Every identified threat needs a response. Similar, not identical, to risk responses. Adam Shostack's list:

- **Mitigate:** reduce likelihood threat materializes.
- **Eliminate:** remove feature/component causing threat.
- **Transfer:** allocate contractual/financial responsibility to another party. Risk transfer doesn't itself reduce likelihood or harmful consequences; document who owns remaining controls and residual risk.
- **Accept:** don't mitigate, eliminate or transfer because none acceptable given business requirements/constraints.

Document each threat's response; turn agreed mitigations into actionable security requirements. Record how team implements each mitigation and why it accepts remaining risk. Keep current as system changes (NIST SP 800-218, practice PW.1.2).

### Review and Validation

Answers "did we do a good enough job"? All stakeholders review threat model, not just dev/security teams. Focus:

- Does DFD (or comparable) accurately reflect system?
- All threats identified?
- Response strategy agreed for each threat?
- Where mitigation is desired response, do mitigation strategies reduce risk to acceptable level?
- Threat model formally documented? Artifacts stored so "need to know" parties can access?
- Can agreed mitigations be tested? Can success/failure of requirements and recommendations be measured?

## Threat Modeling and the Development Team

### Challenges

Hard for dev teams because:

- Many developers lack security knowledge/experience → struggle to use methodologies and frameworks, identify and model threats. W/o training in basic security principles may overlook threats or misjudge risk.
- Process complex, time-consuming; needs systematic approach and in-depth analysis, hard to reconcile w/ tight schedules and delivery pressure. Perceived lack of tools/resources → frustration, discouragement.
- Communication/collaboration gaps between departments. W/o effective communication among dev, security, other stakeholders, threat modeling incomplete or misdirected.

### Addressing the Challenges

- Invite security team members to threat modeling sessions. They bring knowledge of potential threats, crucial for identification, risk analysis, mitigation, plus latest attacker trends/techniques; teach dev teams. Joint sessions build collaboration and mutual support culture, more comprehensive security approach.
- Invest in regular IT security training for dev teams, by experts, tailored to team needs. Implement processes/tools simplifying and automating threat modeling (identify/assess threats), more accessible and less time-consuming.
- Promote security culture: threat modeling = integral part of Software Development Life Cycle (SDLC), not extra burden. Regular review sessions and cross-team workshops improve collaboration/communication → more effective, comprehensive security, less burdensome threat modeling.

## References

- Threat Modeling Manifesto
- SEI: Threat Modeling — A Summary of Available Methods
- NIST SP 800-218: Secure Software Development Framework
