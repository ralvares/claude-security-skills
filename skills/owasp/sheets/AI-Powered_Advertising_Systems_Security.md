# AI-Powered Advertising Systems Security Cheat Sheet

## Introduction

Ad platforms make AI-driven financial decisions on every ad request. Checklist of ad-tech-specific controls stopping AI itself becoming attack surface. Applies to every ad-serving mode: programmatic via IAB Tech Lab OpenRTB specification, search, retail media, CTV/OTT (Connected TV and Over-The-Top streaming ads), DOOH (Digital-Out-of-Home screens), direct-sold, native, mobile mediation. Covers classical machine learning (ML) and generative AI on live serving path, incl. large language models (LLMs) and vision-language models (VLMs); generic LLM risks catalogued in OWASP LLM Top 10 (2025).

Each section pairs primary controls w/ compact threat / evidence / runtime-signal table → reviewer traces each threat to verification and monitoring.

## 1. Gate AI Decisions on Consent

Running personalization, targeting, ranking, or lookalike model on personal data = profiling under GDPR Art. 4(4). Contextual review reading page content and no user data is outside definition → don't gate on profiling consent. Exemption ends when output joined to user identifier; treat join, not review, as consent attachment point. Gate identifier write and model call separately. ePrivacy Art. 5(3) attaches consent to storage/access itself → write needs consent even when no model runs; model call = gate teams usually miss.

- Treat consent as authorization check, not model feature.
- Refuse model call on child-directed traffic based on platform-controlled classification (publisher-side child-directed flag, age-of-majority signal, kids-account tag). OpenRTB `regs.coppa` is sender-declared under OpenRTB 2.6 §3.2.3 and fails open when omitted → signal that raises bar, not boundary. Platform-controlled classification unavailable → fail closed, treat traffic as child-directed. Regulatory anchors: COPPA, California CPRA 1798.120(c), DSA Art. 28.
- Consent-scope training corpus per IAB Europe TCF. TC strings are personal data (CJEU C-604/22).
- Honor real-time opt-outs at feature-fetch step: Sec-GPC, `regs.gpp`, ATT, Android Ad ID reset.
- Invalidate downstream materializations (segments, lookalike scores, key-value (KV) caches used by LLM serving stacks, adapter warm-pools) on opt-out.
- Test for special-category inference from generic inputs (GDPR Art. 9, DSA Art. 26(3)).
- Route employment, housing, credit ads through stricter path. Targeted employment advertising named high-risk under EU AI Act Art. 6 plus Annex III point 4(a). Housing ad targeting governed by US Fair Housing Act and United States v. Meta Platforms 2022 settlement that retired Special Ad Audience tool used for lookalike targeting on housing ads. Credit ad targeting governed by US Equal Credit Opportunity Act (ECOA). Annex III point 5(b) covers creditworthiness scoring, not ad targeting.

| Threat | Evidence | Runtime signal |
|---|---|---|
| Model runs on non-consented user | Integration test: non-consented request → no model invocation | Model-invocation rate per consent state |
| Non-consented rows enter training corpus | Row-level audit sample carries consent-reason code | Training-admission rate by consent-reason-code |
| Special-category inference from generic inputs | Disparate-impact audit on each refresh | Per-classifier output distribution vs. protected class |
| Withdrawn consent but model still runs | Withdraw-and-replay regression | Opt-out cache miss/hit rate; stale-cache alert |

## 2. Protect the Corpus (Training and Retrieval)

Training data and Retrieval-Augmented Generation (RAG) indexes written by adversarial participants at line rate. See [RAG Security Cheat Sheet](RAG_Security.md) for pipeline controls.

- Sign dataset manifests and RAG chunks w/ offline key using in-toto attestation framework wrapped in DSSE envelope, same envelope shape sigstore model-transparency uses for model artifacts.
- Tag every training row and RAG chunk w/ participant-provenance tag → scoped-rollback ("exclude every row from partner X during window Y") answerable w/o re-hashing.
- Pin fixed set of canonical policy chunks per restricted category (alcohol, gambling, health claims, political, financial services, minors) as retrieval-integrity check, not boundary. Every retrieval query in these categories must return ≥ k of n pinned anchor chunks (e.g., k=3 of n=5: small enough to tolerate index churn, large enough that attacker must displace majority of anchors). Category classification selecting anchor set is itself made from attacker-controlled text → attacker steering classification upstream can skip check entirely. Query returns fewer than required anchors → route to non-LLM rules baseline instead of LLM verdict; treat baseline as actual last line of defense.
- Prefer diversity-sampled retrieval e.g. MMR (Maximal Marginal Relevance) over similarity top-k alone. Defense-in-depth, not boundary. Hu et al. 2024, arXiv:2402.07179 don't evaluate MMR against adversarial prefixes; their finding that prefixes override "ignore irrelevant context" instructions → retrieval-layer defense can't be relied on alone. Combine w/ pinned-anchor check above and non-LLM rules baseline.
- Quarantine outcome events before training for documented adjudication window based on observed verdict latency and partner reconciliation terms. MRC Invalid Traffic Detection and Filtration Standards, Sections 1.1.2 and 4.5 address delayed detection and backward correction; prescribe no universal training-admission delay. Reconcile later verdicts; remove rows flagged SIVT (Sophisticated Invalid Traffic), even if event signature valid at fire time.
- Trigger-scan every refreshed model as defense-in-depth, not boundary. NIST AI 100-2e2025 §2.3.3 documents spectral signatures and activation clustering ineffective against clean-label backdoors; semantic or functional triggers challenge trigger-reconstruction and model-inspection approaches assuming fixed patterns. Hubinger et al. 2024, arXiv:2401.05566 show safety training doesn't remove them. Provenance (signed weights, known training data, reproducible builds) bounds who can ship model and keeps rollback scoped, but doesn't verify what was trained: authorized supplier can sign backdoored artifact and every signature check passes. Gate promotion on held-out trigger corpus built from own policy taxonomy; limit blast radius via staged rollout and per-supplier champion/challenger on clean holdout.
- Refuse to load any unsigned fine-tune adapter. Bind adapter signatures to CycloneDX ML-BOM entries.
- Normalize participant-supplied text (Unicode NFC, strip zero-width, strip bidi-control) before classifier or retrieval indexing.

| Threat | Evidence | Runtime signal |
|---|---|---|
| Corpus or RAG poisoning by adversarial participant | Red-team unsigned reversal chunk against reviewer LLM | Chunk signature verdict per retrieval; anchor-missing alert |
| Fine-tune trigger backdoor persists through safety training | Trigger-corpus block regression on promotion | Per-adapter promotion-gate block rate |
| Embedding-cluster drown-out via seeded near-neighbor chunks | Seed-chunk red-team; assert MMR restores anchors | Top-k anchor-missing rate per cluster |
| Unadjudicated Sophisticated Invalid Traffic (SIVT) events enter training | Admit-then-reverse regression test on beacon later SIVT-reversed | Admission lag vs. adjudication lag per mode |

## 3. Protect Inference and the Prompt Boundary

General input-boundary controls: [LLM Prompt Injection Prevention Cheat Sheet](LLM_Prompt_Injection_Prevention.md).

Every scoring surface exposed to paying partner = queryable oracle (Tramèr et al. 2016).

- Return tier labels, not raw scores, on partner-visible outputs. Raises extraction cost, doesn't prevent it. Tramèr et al. 2016 Section 6 extracts models matching target on over 99 percent of inputs from labels alone, needing up to 100 times more queries → query budget is the control. Money fields required by protocol (OpenRTB `seatbid.bid.price`, search ad-rank, retail sponsored-rank) must stay precise; guard w/ query budgets and probing detection.
- Enforce contractual query budgets technically. Reject-not-coerce out-of-domain feature values.
- Cap inference cost per call, budgeted in dollars per minute (OWASP LLM10:2025 Unbounded Consumption).
- Dual-LLM structural handoff on every attacker-controlled text input (publisher HTML, landing page, brief field). Quarantined LLM emits fixed JSON schema; privileged LLM reads only schema. Ad-tech-specific relocation of OWASP LLM01:2025 Prompt Injection (MITRE ATLAS AML.T0051, indirect variant `AML.T0051.001`).
- Cross-check every monetization-changing boolean verdict against non-LLM rules baseline.
- Run ensemble of two differently-trained VLMs on submitted images as defense-in-depth, not boundary. Qi et al. 2023 Table 3 shows one image transferring across models, raising Perspective-API toxicity 9 to 23 percentage points over each target's no-attack baseline. Largest gains between models sharing LLM backbone and alignment → vary backbone, not only weights; expect both members to agree on some wrong verdicts. Route disagreement and high-risk tags (minors, celebrity likeness, trademark) to human review. Rules-based creative-policy classifier (allowlists, banned-terms lists, structural checks) = automated floor; human review = boundary for cases automated path can't resolve.
- Use voice-clone and AI-content detectors to prioritize audio review, not to establish submission authentic or authorized. NIST AI 100-4, Sections 3.2.2.3 and 4.2 describe limitations across generators, languages, noisy audio. Measure false positives and negatives on representative submissions, incl. unfamiliar generators. Verify voice-use authorization independently of detector results; hold ambiguous or high-risk submissions for human review; negative detector result ≠ permission to use voice.
- On-device LLMs (Chrome Prompt API) reach only top-level windows and same-origin iframes. Cross-origin ad iframe gets access only if page delegates via `allow="language-model"` → never add that token to ad slot. Every model output untrusted at DOM boundary; [CSP](Content_Security_Policy.md) doesn't inherit into cross-origin ad iframe.
- Isolate every cache by tenant ID: KV cache (paged-attention serving stacks), RAG index namespace, plan cache, adapter pool (OWASP LLM02:2025). System-prompt secrecy ≠ boundary (LLM07:2025); enforce thresholds in deterministic post-processor keyed off LLM's structured output.

| Threat | Evidence | Runtime signal |
|---|---|---|
| Model extraction by paying partner | Extraction red-team on shadow model | Per-partner query volume vs. contract rate; score-vs-outcome divergence |
| Prompt injection at publisher HTML, advertiser landing page, or brief field | Red-team page corpus w/ hidden brand-safe-steer payloads | Per-publisher quarantined-vs-baseline disagreement rate |
| Adversarial patch flips VLM policy verdict | Adversarial-patch red-team on held-out corpus | Per-reviewer-version disagreement rate |
| Cross-tenant cache leak (KV, RAG, plan, adapter) | Cross-tenant probe red-team on deployed backend | Cross-tenant cache-hit alarm; identifier Data Loss Prevention (DLP) alerts on model output |
| Denial-of-wallet on paid contextual LLM | Sponge-input red-team | Per-partner `cost_per_bid` SLO; P99 latency outlier |

## 4. Protect Outcome Events and Agentic Actions

Every outcome callback = money + training label in one packet.

- Sign every callback w/ ad-tech-specific field set: `key_id`, `event_type`, event ID, `timestamp`, monetary value, receiving endpoint. `event_type` must be in signed set because same `impression_id` reuses across event types.
- Use HMAC-SHA256 over length-prefixed serialization, or RFC 9421 HTTP Message Signatures w/ receiver-enforced required-minimum covered-components (Section 3.2.1, Section 7.2.1).
- Cover request body, not only named fields. RFC 9421 doesn't sign message content on its own (Section 7.2.8) → `currency`, `quantity`, label fields stay malleable while signature verifies. Require RFC 9530 `Content-Digest` as covered component; revalidate digest against received bytes, because verifying signature alone still admits content substitution. No field outside covered set may influence monetary amount or training label.
- Deduplicate on event ID, never `(event_id, timestamp)`. Retain dedup records for at least entire signature-acceptance period, incl. clock skew, and any longer retry period agreed w/ partner. Set periods from callback delivery contract and measured delays, not fixed 24-hour default. Reject expired callbacks; RFC 9421 Section 7.2.2 explains why signatures alone don't prevent replay.
- Verify HMAC before any payload field influences control-flow decision.
- Separate financial settlement from training-label materialization.
- Pin certificate identity to specific `partner_id`, using typed Subject Alternative Name (SAN) entry or Subject Public Key Info (SPKI) hash, not just trusted issuer. RFC 9525, which obsoletes RFC 6125, states Common Name RDN MUST NOT be used to identify service, and extends prohibition to other RDNs within subjectName. See [JSON Web Token Cheat Sheet](JSON_Web_Token.md) for generic JWT hardening.
- Auth incidents = data incidents: rotate credentials, mark exposure-window rows suspect, invalidate per-partner weights, invalidate model artifacts.
- Tier every agentic tool by risk. HITL (human-in-the-loop) approvals bind six-tuple: actor, tool, target, normalized parameters, timestamp, expiry (OWASP LLM06:2025 Excessive Agency). Generic agentic patterns: [AI Agent Security Cheat Sheet](AI_Agent_Security.md).
- Kill-switch fallback: warm, pre-deployed rules-based bidder. Single control-plane flip diverts campaign traffic to it while agent quarantined.
- Quarantine reward events past fraud-adjudication lag; cap max policy shift per epoch.

| Threat | Evidence | Runtime signal |
|---|---|---|
| Forged outcome event = payment fraud AND poisoned label | CI negative tests: forged, stale, cross-endpoint rejected | Rejected-callback rate per partner |
| `impression_id` re-signed w/ fresh timestamps to over-credit | Re-sign regression test on same `impression_id` | Per-partner dedup-hit rate |
| Injected-agent budget drain (OWASP LLM06:2025) | Red-team injection targeting budget tool | Per-tenant tool-call rate SLO; missing-approval alarm |
| Partner-credential compromise silently poisons rows | Rotation drill; confirm all three data-side actions fire | Per-partner-scoped model-drift monitor after rotation |

## 5. Protect the AI Supply Chain and Generative Provenance

Model lifecycle controls: [Secure AI Model Ops Cheat Sheet](Secure_AI_Model_Ops.md).

Model artifacts, feature stores, RAG indexes, generative endpoints reachable via paths never crossing ad-serving surface.

- Sign every model artifact w/ OpenSSF Model Signing. Block deploy on signature failure. Pair signing w/ trigger-scan behavioral gate for externally sourced classifiers.
- Bind CycloneDX ML-BOM entries to participant-provenance tag from Section 2. ML-BOM = primary key for scoped-rollback query.
- Purpose-scope feature-store namespaces. Rotate materialization-write credentials on production-secrets cadence.
- Verify participant provenance per mode: ads.txt and OpenRTB SupplyChain object (programmatic); seller-ID authorization on catalog uploads (retail); advertiser-domain ownership (search); ads.cert 2.0 or device attestation via Google Play Integrity or Apple App Attest (CTV).
- Reject VPAID creatives outright in video-programmatic and CTV. VPAID (Video Player-Ad Interface Definition) = VAST extension letting video ad ship own JavaScript inside player. Deprecated in VAST 4.1, replaced by SIMID (Secure Interactive Media Interface Definition) in VAST 4.2. Sandboxing VPAID not viable.
- Platform developing generative endpoint and putting it into service under own name = *provider* under EU AI Act Art. 3(3), carrying machine-readable marking duty in Art. 50(2). Duty doesn't apply to extent system performs assistive function for standard editing or doesn't substantially alter input data or its semantics. Advertiser using endpoint under own authority = *deployer* under Art. 3(4), carrying Art. 50(4) disclosure duty whenever creative constitutes deep fake under Art. 3(60).
- Emit C2PA 2.4 manifest w/ hard binding over generator output bytes at egress. Re-sign per rendition (image resize, video Adaptive-Bit-Rate (ABR) ladder step, audio Server-Side Ad-Insertion (SSAI) stitch). Don't rely on soft binding.
- Require likeness or voice-use authorization artifact on file before generator accepts brief asserting real person.
- Freeze generation model version from control plane during incident.

| Threat | Evidence | Runtime signal |
|---|---|---|
| Model-artifact tampering | CI signature test; trigger-scan report per model version | Failed-signature-verification alerts on deploy |
| Unauthorized supply-chain provenance (spoofing seller, gaming seller, unowned domain) | Daily provenance-reconciliation report per mode | Per-participant verification failure rate; auto-quarantine above threshold |
| Legacy or unsafe creative format (VPAID JavaScript) | Ingest test: VPAID tag rejected; homoglyph fuzz suite | VPAID-rejection dashboard; SIMID adoption metric |
| Missing Art. 50(2) provider marking at generation | Regression: every generator emit produces signed manifest | Per-asset generator-egress manifest-signed metric |
| Deep-fake composition from legitimate advertiser assets (Art. 3(60)) | Red-team recombining brief without authorization | Brief-rejected-no-likeness-auth counter |

## References

- NIST AI 100-2e2025: Adversarial Machine Learning — A Taxonomy and Terminology of Attacks and Mitigations
- RFC 9421: HTTP Message Signatures
- C2PA 2.4 Technical Specification: Hard Bindings
- Shokri et al.: Membership Inference Attacks Against Machine Learning Models
