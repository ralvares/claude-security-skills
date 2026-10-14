# AML and Sanctions Compliance for AI Agent Payments Cheat Sheet

## Introduction

AI agents initiate regulated financial transactions in production. Mastercard Agent Pay, Visa Intelligent Commerce, Google A2A payments live. Using AI agent doesn't remove applicable Anti-Money Laundering (AML) or sanctions obligations. Determine requirements for institution, transaction, customer relationship, jurisdiction before implementing controls below.

Practical controls for fintechs, banks, payment processors when autonomous AI agents (not humans in browser sessions) initiate or facilitate regulated payments. Covers agent identity verification, entity screening, audit trail requirements, fail-closed enforcement.

Exposing screening tools via MCP: use [MCP authentication and authorization guidance](MCP_Security.md#6-authentication-authorization-transport-security). Message-level signing = [optional additional control](MCP_Security.md#7-optional-message-level-integrity), not core MCP requirement. Signed-audit and receipt design in Sections 4 and 8-10 = one option for systems needing verification beyond transport connection.

## Regulatory Context

Obligations depend on institution's regulated role, transaction, jurisdictions. Compliance owners identify requirements payment service must enforce:

- **Bank Secrecy Act (BSA)**: US BSA regulations set recordkeeping, reporting, other requirements for covered financial institutions and businesses. Determine which apply to service's activities.
- **Office of Foreign Assets Control (OFAC) Sanctions**: Comply w/ applicable sanctions prohibitions and blocking requirements. Screening supports those controls, but OFAC imposes no general requirement to scan names or use screening software. Complete necessary analysis before concluding transaction.
- **Financial Crimes Enforcement Network (FinCEN)**: Apply Customer Identification Program (CIP) and Customer Due Diligence (CDD) requirements to relevant customers and beneficial owners under institution's applicable rules and exceptions. CDD rule covers specified financial institution types; authenticating software ≠ identifying legal customer. CIP guidance distinguishes account owner from person merely acting as owner's agent.
- **UK Financial Sanctions**: Office of Financial Sanctions Implementation (OFSI) guides applying sanctions requirements relevant to parties and activities. OFSI assesses whether due diligence appropriate to sanctions risk and transaction; prescribes no single level or type of due diligence for every case.
- **EU Sanctions**: Identify applicable sanctions regimes and legal acts. European Commission sanctions resources distinguish consolidated list of designated parties from legal acts governing sanctions; list check alone ≠ compliance w/ every restriction.
- **Funds-Transfer Recordkeeping**: Follow requirements for institution's role and payment type. FFIEC examination manual describes thresholds, exceptions, required originator and beneficiary information; sets no universal requirement for cryptographic software-agent identity.

### Key Principle

Separate legal customer and counterparty identification from software authentication and authorization. Record which customer agent acts for and what it may do as application security control. Compliance owners define screening, monitoring, reporting, retention rules; never treat agent credential or successful list match check as proof all legal obligations satisfied.

## Section 1: Agent Identity Before Screening

Before agent may access sanctions screening services or initiate payment, identity must be cryptographically verified. Self-declared identity headers (e.g. `X-Agent-ID`, `X-Agent-Role`) w/o cryptographic proof MUST be rejected. Protected MCP endpoints: follow MCP authorization profile; validate authorization on every request.

### Do

- Require agents present cryptographic identity credential (e.g. signed passport, ECDSA key pair, verifiable credential) before accessing screening endpoints.
- Bind agent identity to screening request → audit trail proves which agent performed check.
- Verify agent trust level before granting access. Not all agents get same access to sanctions data. Graduated trust levels (e.g. L0 to L4) w/ increasing access rights.
- Record agent public key fingerprint or passport ID in every screening request log entry.

### Don't

- Accept self-declared identity claims w/o cryptographic verification.
- Allow agents to access screening endpoints w/o authentication.
- Trust caller-supplied identity headers merely because TLS terminates at proxy. Forwarding validated client-certificate identity: accept only over trusted proxy path and remove caller-supplied certificate headers (RFC 9440 Section 4).
- Allow agents to escalate own trust level or modify own permissions.

## Section 2: Entity Screening

Entity screening against global sanctions lists (OFAC SDN, UK Sanctions List, EU Consolidated, UN Consolidated) fundamentally unchanged when agents call. Engine matches names, addresses, vessels, identifiers against lists. Context around request changes. Authoritative US source: OFAC Sanctions List Search.

### Do

- Screen all counterparties (individuals, businesses, vessels, addresses) against applicable sanctions lists before processing payment.
- Include agent identity and trust level in screening context → downstream systems distinguish agent-initiated from human-initiated screens.
- Return structured machine-readable results to agent. Agents can't interpret PDF reports or HTML pages. JSON w/ clear match/no-match/partial-match indicators and match scores.
- Enforce minimum match thresholds. Agent must not override or lower threshold below institution's configured minimum.
- Log every screening request and result w/ agent's cryptographic identity, timestamp, unique request nonce.

### Don't

- Allow agents to bypass screening by calling payment endpoints directly w/o prior screening step.
- Accept unsigned or invalidly signed results when chosen message-signing profile requires signatures. TLS protects connection, doesn't stop compromised component changing data after termination.
- Allow agents to cache screening results beyond configurable time window. Lists update frequently; stale results create compliance gaps.
- Expose raw sanctions list data to agents. Agents call screening API; no full list download.

## Section 3: Agent Operator Screening

Identify customer and organization responsible for operating agent. Determine which parties need sanctions screening and due diligence under institution's approved compliance program. Don't assume every developer, deployer, operator is legal customer merely for providing software; FinCEN CIP guidance makes customer identification depend on account relationship. Bind authenticated agent to verified account and delegated permissions as application security control.

### Do

- Verify organization responsible for agent during onboarding; screen parties identified by compliance program against applicable sanctions lists.
- Define rescreening triggers and frequency in compliance program, incl. relevant list and ownership changes; restrict agent access when required assessment doesn't permit relationship to continue.
- Record operator's screening status in agent's trust profile.
- Require agents declare operator identity in cryptographic passport or identity credential.

### Don't

- Assume agent verified once → operator stays non-sanctioned indefinitely.
- Allow agents to operate w/o declared operator. Anonymous agents MUST NOT access sanctions screening services.
- Accept operator identity claims w/o independent verification against business registries or KYB (Know Your Business) databases.

## Section 4: Signed Audit Trail

Keep tamper-evident audit records associating authenticated agent w/ screening request and result. Bullets below describe optional signed, hash-chained audit design. MCPS Internet-Draft separately proposes message-signing and replay-protection layer; individual work in progress, not adopted MCP standard. Select reviewed, interoperable profile when protection needed; apply [log-protection controls](Logging.md#protection) regardless of design.

### Do

- Sign every screening request w/ agent's private key, incl. unique nonce and timestamp.
- Sign every screening response w/ server's private key, incl. own nonce and timestamp.
- Chain audit entries via cryptographic hashes (each entry includes SHA-256 hash of previous entry) → tamper-evident log.
- Each audit entry includes: agent identity (public key fingerprint or passport ID), tool invoked, hash of screening arguments (not raw arguments, for privacy), screening result (match/no-match/partial), timestamp, hash of previous audit entry.
- Retain audit records for period required by applicable regulations (typically 5 years for BSA/AML).
- Make audit records exportable in machine-readable format for regulatory examination.

### Don't

- Rely on application-level logging (e.g. `console.log`, syslog) as sole audit trail. Not tamper-evident; modifiable undetected.
- Store audit records on agent's device or agent-controlled storage. Must be on infrastructure controlled by financial institution.
- Omit agent identity from audit records. Screening record not identifying agent useless for regulatory purposes.
- Allow gaps in hash chain. Broken chain = tampering or data loss; must trigger alert.

## Section 5: Fail-Closed Enforcement

Treat incomplete or unavailable screening result as unresolved, never clearance. Withhold transaction execution while required assessment unresolved; bounded retries, manual review, or rejection per institution's approved policy. OFAC advises financial institutions not to conclude transactions before necessary analysis complete. Service failure ≠ confirmed sanctions match; compliance owners define appropriate response per case.

### Do

- Hold or reject payment when required screening can't complete; release only if required assessment permits.
- Return clear structured error to agent: screening failed, transaction can't proceed.
- Log all screening failures w/ same detail as successful screens, incl. failure reason.
- Alert compliance teams when screening failure rates exceed threshold; may indicate denial-of-service attack designed to force fail-open.
- Circuit breakers halt agent-initiated payments entirely if screening service unavailable for extended period.

### Don't

- Allow transactions to proceed when screening results unavailable, ambiguous, or timed out.
- Implement fallback logic bypassing screening under any condition.
- Allow agents to retry screening indefinitely w/o rate limiting (could probe for timing-based information leakage).
- Return generic errors not distinguishing "screening service unavailable" from "screening completed with a match."

## Section 6: Trust-Tiered Rate Limiting

Not all agents equal. Rate-limit unverified or low-trust agents more aggressively than verified high-trust agents. Base rate limiting on agent's cryptographic identity, not IP address (shared or spoofed). Operationalises OWASP API Security Top 10 API4:2023 (Unrestricted Resource Consumption) in agent-payment context.

### Do

- Per-agent rate limits based on cryptographic identity (public key fingerprint or passport ID).
- Lower limits for newly registered or low-trust agents (e.g. L0/L1), higher for verified high-trust agents (e.g. L3/L4).
- Include rate limit status in screening responses (remaining quota, reset time) → agents adjust behavior.
- Downgrade agent's rate limit allocation on anomalous behavior (e.g. sudden spike in screening requests, unusual entity patterns).

### Don't

- Apply rate limits solely by IP address. Multiple agents may share IP; single agent may use multiple IPs.
- Set rate limits so high they give no meaningful abuse protection.
- Allow agents to circumvent rate limits by creating multiple identities. Tie agent identities to verified operator accounts → prevents sybil attacks.

## Section 7: Self-Hosted vs Hosted Screening Architecture

Institutions decide: run own screening engine or use hosted screening API. Both valid; each has different security considerations when agents call. Microservice-boundary trust posture here follows NIST SP 800-209 (Security Guidelines for Storage Infrastructure) applied to screening service plane.

### Self-Hosted Screening

- Institution maintains sanctions lists, matching engine, screening API on own infrastructure.
- Agent requests stay within institution's network boundary.
- Institution fully controls list update frequency, matching algorithms, data retention.
- Requires operational investment in list ingestion, normalization, matching quality.

### Hosted Screening (Third-Party API)

- Institution calls third-party screening API (e.g. sanctions screening provider).
- Agent identity credentials and screening data leave institution's network boundary.
- Institution must ensure provider meets applicable regulatory requirements.
- Data minimization applies: send minimum data needed for screening, not agent's full context.

### Do

- Encrypt all screening requests in transit (TLS 1.2 minimum) regardless of architecture.
- Threat model requires verification across untrusted intermediaries → use reviewed message-signing profile supported by both endpoints; define trusted keys, signed fields, replay handling, verification failures.
- Verify provider's response signatures when agreed profile requires them.

### Don't

- Send agent private keys or full identity credentials to third-party screening provider. Send only minimum identity attributes needed.
- Assume TLS protects data after connection terminates. Protect each subsequent connection; decide which intermediaries are trusted to read or modify requests.

## Section 8: Receipt Canonicalization (RFC 8785 / JCS)

Systems independently serializing same JSON object for hashing or signature verification need agreed byte representation. JSON permits variable key order, whitespace, number formatting → two systems can produce different bytes for same logical object.

JSON Canonicalization Scheme (JCS), RFC 8785 gives one deterministic JSON representation for this use. Not required for every signed-token format: JSON Web Signature (JWS) verifier checks encoded signing input, doesn't reserialize payload (RFC 7515 Section 5.2). Cross-system verification also needs agreed signature profile and trusted verification key. Canonicalization alone supplies neither.

### Do

- Receipt profile calls for independent JSON serialization → canonicalize agreed payload before signing and before verification.
- Use hashing and signing procedure required by chosen signature profile and API; no separate prehash unless profile requires.
- Record canonicalization and signature profile used → verifier reproduces signing input.

### Don't

- Profile requiring reconstruction of signed JSON: don't rely on framework-default or pretty-printed serialization; key order and whitespace can differ across systems.
- Don't assume two services emit identical JSON for same object; usually won't.

## Section 9: Cross-Agent Payment Accountability

Agent payments can traverse multiple agents. Downstream services relying on signed screening receipt must verify it using key bound to trusted screening issuer. Digital signatures give data-origin and integrity assurance (FIPS 186-5); don't prove issuer screened correctly. Receipt records issuer's assertions about entities, lists, decision; verifier still needs policy for which screening issuers it trusts.

Bind each receipt to specific transaction (transaction or intent hash in signed payload); propagate end-to-end. Each hop verifies inbound receipt and, if taking own action, appends own signed receipt → verifiable accountability chain across agents. See [Optional Message-Level Integrity](MCP_Security.md#7-optional-message-level-integrity) for additional threat model and profile requirements.

### Do

- Attach signed compliance receipt to transaction; propagate across every agent hop.
- Bind each receipt to transaction by signing over transaction or intent hash.
- At each hop verify signature, trusted issuer, transaction binding, acceptable screening freshness before relying on receipt; append new signed receipt for any action taken.

### Don't

- Keep receipt only in issuing system's logs; downstream agents then can't prove screening occurred.
- Let downstream agent rely on upstream agent's unverifiable claim that screening happened.

## Section 10: Binding Sanctions-List Freshness to the Receipt

Receipt "screened, no match" meaningless w/o list version and as-of time. Lists change frequently; clean screen against stale list = compliance gap. Bind **list version and timestamp** into signed receipt → freshness non-tamperable and auditable. Public sources such as OFAC Sanctions List Search and EU Consolidated Sanctions List change frequently → record version screened against.

### Do

- Include sanctions-list source(s), version or publication date, screening timestamp **inside the signed receipt**.
- Bind each screening result and list version to specific transaction or payment intent in signed data → later verifier distinguishes it from another transaction.
- Enforce verifier's maximum acceptable list age and screening age; issuer-supplied age limit must not override that policy.
- Retain evidence of list version used and screening service's update history. Signed timestamp or version protects recorded assertion from alteration; doesn't independently establish list was current or actually used.

### Don't

- Don't assert screening result w/o recording list version and date screened against.
- Don't treat "screened" as boolean; clean result against out-of-date list not compliant.

## Section 11: Regulatory Mapping

Controls here map to common AML and sanctions obligations. Mapping illustrative, not legal advice; obligations vary by jurisdiction. Underlying obligations e.g. Bank Secrecy Act and FinCEN Customer Due Diligence Requirements.

| Control (this cheat sheet) | Maps to |
| --- | --- |
| Agent identity before screening (Section 1) | Technical attribution and authorization; doesn't replace applicable customer or beneficial-owner identification |
| Entity and operator screening (Sections 2-3) | Screening parties identified by applicable sanctions compliance program; no universal legal duty to screen every software operator |
| Signed audit trail and receipt (Sections 4, 8-10) | Recordkeeping; FATF Recommendation 11; multi-year retention (BSA, EU AMLD) |
| Sanctions-list freshness in receipt (Section 10) | Evidence of which list data supported assessment; list screening alone ≠ compliance |
| Fail-closed enforcement (Section 5) | Prevent execution while required checks unresolved; distinguish this technical gate from legal blocking obligations for confirmed sanctions matches |
| Trust-tiered limits (Section 6) | Risk-based approach (FATF Recommendation 1); monitoring thresholds |

### Do

- Treat table as starting point; confirm specific obligations w/ qualified counsel per operating jurisdiction.

### Don't

- Don't rely on single jurisdiction's lists or rules for cross-border agent payment system.

## Section 12: Do's and Don'ts Summary

Consolidated controls align with AI-system-specific verification requirements in OWASP Artificial Intelligence Security Verification Standard (AISVS), esp. Chapter 10 (MCP Security Requirements).

### Do

- Verify agent identity cryptographically before every screening request.
- Message-signing profile in use: sign and verify screening requests and responses; enforce its replay controls.
- Screen counterparties and relevant operator entities as defined by institution's applicable compliance program.
- Protect screening audit records against unauthorized changes and deletion; hash chaining when chosen audit design requires.
- Withhold transaction execution on screening error, timeout, or ambiguous result until required assessment permits proceeding.
- Rate limit by cryptographic agent identity, not IP address.
- Graduated trust levels w/ different access rights and rate limits.
- Re-screen relevant parties per compliance program's list-change and other review triggers.
- Make audit records exportable for regulatory examination.

### Don't

- Accept self-declared agent identity w/o cryptographic proof.
- Allow transactions to proceed when screening fails or unavailable.
- Store audit records in agent-controlled infrastructure.
- Cache screening results beyond configurable time window.
- Allow agents to lower match thresholds or override screening results.
- Treat transport protection as protection from compromised component after TLS termination.
- Allow anonymous agents to access screening services.
- Assume one-time identity check sufficient for ongoing access.

## References

- FinCEN: Customer Due Diligence Requirements for Financial Institutions
- NIST SP 800-53 Rev. 5: Security and Privacy Controls
- OFAC: A Framework for Compliance Commitments
