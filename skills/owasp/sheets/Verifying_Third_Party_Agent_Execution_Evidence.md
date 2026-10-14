# Verifying Third-Party Agent Execution Evidence Cheat Sheet

## Introduction

Helps assess execution records from an agent, Model Context Protocol (MCP) server, or service you don't control. Supplier can sign record omitting actions or describing run that never happened. Verify the specific claim needed; identify who could fabricate supporting evidence.

Supply-chain Levels for Software Artifacts (SLSA) verification guidance separates checking signatures/artifact identity from deciding which producers to trust. Apply same distinction to execution records. Outcomes per question below:

| Outcome | What the evidence supports |
|---|---|
| Independently re-checkable | Another reviewer can verify stated property using authenticated evidence + trust material supplier doesn't exclusively control. Doesn't establish other execution properties. |
| Supplier assertion | Supplier claims property, independent evidence missing. Record still useful for debugging, routine ops. |
| No information | Evidence doesn't allow assessing this property. Don't infer run was clean. |

Signature may establish who made assertion, not that it's true. Don't use supplier assertions alone to resolve incident attribution or dispute involving that supplier.

Own logs: [Logging Cheat Sheet](Logging.md). Optional message integrity + replay protection between agent and server: [MCP Security Section 7](MCP_Security.md#7-optional-message-level-integrity). These checks assess individual records; no end-to-end completeness across chain of delegated actions.

## Six Questions to Ask About an Execution Record

### 1. Who could have written or altered it?

List component, host, recorder, operator, signing-key holder. Count independent parties, not processes: several services under one supplier = one party. Recorder fed only by component preserves component's account. Signing service accepting arbitrary content from component doesn't independently confirm content.

- Identify observer obtaining event data independently of component's own reports.
- Keep its records where component and supplier can't rewrite them.
- Corroborate supplier's record against calls recorded at gateway/other boundary you control.

Boundary recorder covers only what crosses boundary. Can't establish local file writes or in-process actions; can't inspect encrypted request bodies w/o plaintext access. W/o independent observation, classify account of execution as supplier assertion, limit decisions based on it.

### 2. What does the timing evidence actually establish?

Supplier-written timestamp = supplier assertion. Check freshness: send fresh unpredictable challenge (nonce), require it signed together w/ execution claims. Verify signature, compare returned nonce w/ one sent.

RFC 9334 Section 10 limit: matching nonce bounds signing to after challenge generated; doesn't show when individual claims captured. Trusted timestamp bound to signed record establishes it existed by a time, not that contents describe real events.

Record which timing property checked. Don't label capture contemporaneous merely because signature fresh or record in transparency log. That needs evidence from observer positioned to witness execution.

### 3. Does it identify the intended artifact and execution?

Valid signature on record about another artifact/run doesn't answer your question.

- Recompute collision-resistant digest of expected artifact, compare w/ signed subject. Obtain expected artifact/digest independently of report assessed.
- Separately match signed execution identifier/challenge to intended run.
- Check which relevant inputs covered: tool definitions, configuration, prompts, model version, policy. Binary digest alone doesn't identify these.

Artifact digest can legitimately stay same across many runs. Problem: using digest as only binding to an execution. Matched digest = artifact identity; matched run identifier = which execution supplier claims to describe. Neither establishes reported actions occurred.

### 4. Would an omitted event be detectable?

Define execution/time window and events independent observer could see. Reconcile record against expected-event list or per-execution sequence supplier can't silently redefine. Supplier-maintained sequence counts only what supplier chose to include.

Transparency log makes post-entry changes detectable; can't reveal event never submitted. RFC 9162 describes inclusion and consistency checks, warns log can present inconsistent views to different clients. Verify proofs, check how deployment detects inconsistent views, e.g., comparing signed log states across independent observers. Log operator remains trust dependency.

Log total entry count ≠ execution event count. Unrelated entries raise it while run events missing. Injecting one expected event and finding it in returned record = useful spot-check, not completeness test. Limit any coverage claim to events independent observer could see and reconcile.

### 5. What happens when recording or delivery fails?

Determine whether component continues and drops events, buffers and retries, or stops execution. Check buffer overflow behavior, not just normal operation.

- Environment you control: interrupt recording path, observe whether execution continues and gaps become visible.
- Can't test: request evidence from outage or exercised failure scenario. Documentation alone = supplier assertion.
- Preserve independently observed delivery failures outside component's control. Gap marker written solely by component is still its assertion, even if stored elsewhere.

Test establishes behavior under its conditions, not that another execution had no gaps. Empty report from recorder that may have dropped events gives no basis to declare run clean. Stopping execution on every logging failure not automatically appropriate: turns recording outage into availability failure. Choose behavior by action risk; make evidence loss visible.

### 6. Can the reviewer verify it without being able to forge it?

Use maintained verifier w/ trusted signer identities, keys or certificate roots, permitted algorithms configured independently of record. Key packaged w/ record isn't trust anchor merely because it verifies that record; must connect to trust already established. SLSA verification steps: check signature, subject digest, expected producer before relying on provenance.

Validate applicable certificate paths + revocation info per RFC 9334 Section 12.4. Don't accept signature solely because cryptographic calculation succeeds.

Public-key verification needs no signing secret. Shared secret verifying a message authentication code also lets every holder create one → such record can't independently attribute authorship between key holders. Asking supplier's service whether its own record is valid leaves supplier as source of assertion.

### Worked Examples

Evidence after stated checks, not guarantees per file format.

| Evidence and checks performed | What you may conclude | What remains unestablished |
|---|---|---|
| Vendor-exported traces, no independent corroboration | Vendor supplied these claims. | Whether actions occurred, whether record complete. |
| Signed record verified against your trusted signer, artifact digest + run identifier matched to expectations | Signer asserted these bytes about expected artifact and run. | Whether assertions true or complete. |
| Same record, verified log inclusion + consistency evidence plus independently trusted timestamp over signed record | Signed record existed by supported time, included in checked log state. | When events captured, whether they occurred, whether any omitted before submission. |
| Record reconciled against events captured by independent boundary observer | Whether record includes events observer saw in stated window. | Internal actions, other boundaries, events outside observer coverage. |

## Do's and Don'ts

Keep verification policy and expected values outside evidence under review (SLSA verification guidance separation).

### Do

- State exact property checked: signer, artifact, execution binding, timing, or coverage.
- Record trust assumptions + limits alongside each result.
- Reconcile supplier reports w/ observations you control when possible.
- Exercise recording failures in environment you control; preserve results.

### Don't

- Treat valid signature or log inclusion proof as proof action occurred.
- Confuse stable artifact digest w/ unique execution identifier.
- Treat fresh signature as proof of live capture, or successful spot-check as proof of completeness.
- Treat missing entries as evidence nothing happened when recording could have failed.

## References

- SLSA: Verifying Artifacts
- RFC 9334: Remote ATtestation procedureS (RATS) Architecture
- RFC 9162: Certificate Transparency Version 2.0
