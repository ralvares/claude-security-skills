# Secure AI/ML Model Ops Cheat Sheet

## Introduction

Security guidance for operating/deploying AI/ML systems (traditional ML + LLMs). For MLOps, DevOps, security teams. Protects model lifecycle dev → prod vs data poisoning, adversarial input, model theft, operational abuse.

## Common Security Issues

Prompt-specific defenses: [LLM Prompt Injection Prevention Cheat Sheet](LLM_Prompt_Injection_Prevention.md).

Data Poisoning – attackers inject malicious data into training sets to manipulate model behavior.

Model Inversion & Extraction – attacks inferring training data / recreating model behavior or parameters, respectively. NIST distinguishes these attack goals (NIST AI 100-2e2025).

Membership Inference – determining whether a sample was used to train a model (NIST membership-inference definition).

Adversarial Examples – slightly modified inputs misleading predictions, no obvious change to humans.

Prompt Injection – malicious input overrides/hijacks intended LLM behavior.

Unsecured APIs – public inference endpoints w/o authentication, rate limiting, input validation.

Hardcoded Secrets – credentials (API keys, tokens) in source code/notebooks.

Unvalidated Third-party Models – external pre-trained models used w/o integrity, provenance, trust checks.

Open Artifact Stores – public model binaries, datasets, logs from misconfigured storage/missing access controls.

Lack of Monitoring & Drift Detection – no detection of shifts in model behavior, data distribution, performance.

Orphaned Deployments – test/deprecated models left accessible in prod, often unprotected.

Weak Runtime Isolation - shared training/inference infra → cross-tenant data exposure, credential reuse, side-channel leakage, unauthorized accelerator memory access.

## Real-World Examples

- Data Poisoning via Public Dataset Manipulation: mislabeled samples injected into open-source datasets; used in training → degrade accuracy/introduce bias.
- Membership Inference in Healthcare ML: attacker infers whether individual's data was in medical model's training set.
- Malicious Model Files: `.pt`/`.pkl` file w/ embedded malware uploaded to pipeline, executed on deserialization.
- Insecure LLM Prompt Injection: inputs like `"Ignore all previous instructions..."` manipulate chatbot, may leak internal system prompts.
- Leaked API Keys on GitHub: OpenAI/Hugging Face keys committed by accident, exploited for free access/abuse.
- Open MLFlow Instance: no authentication on MLFlow or similar exposes all models + training logs.
- Adversarial Input Attacks in Vision Systems: few altered pixels → classifier mislabels stop sign as speed limit sign.
- Legacy Test Models in Production: old staging models left running on public cloud endpoints, vulnerable to extraction.

## Security Recommendations

### 1. Model Development & Training

- Version-controlled, auditable training pipelines (e.g., MLFlow, DVC).
- Validate + sanitize training data.
- Differential privacy or data anonymization for sensitive training data.
- Reproducible training environments (e.g., containers, virtualenv).

### 2. Secrets & Configurations

- Never hardcode secrets in source code/notebooks.
- Use secret managers (e.g., AWS Secrets Manager, HashiCorp Vault).
- Use environment variables or CI secrets injection.

### 3. Model Storage & Artifacts

- Store models in access-controlled registries.
- Sign model binaries w/ digital signatures.
- Encrypt model weights + datasets at rest.
- Restrict access to training logs + intermediate outputs.
- Validate third-party/pre-trained models before production for integrity + safe behavior.

### 4. Inference API Security

- Authentication + authorization (OAuth, API tokens).
- Validate + sanitize all inputs.
- Rate limiting + abuse detection (e.g. bot detection, anomaly scoring).
- Structured prompt templates for LLMs to separate instructions from user input.
- Per-tenant token, request, concurrency, spend limits → reduce denial-of-wallet risk.
- Enforce recursion, retry, chain-depth limits for agentic/tool-using inference flows.
- Circuit breakers/kill switches for abnormal cost, latency, tool-call spikes.
- Monitor usage telemetry near real time; alert on sudden changes in tokens, requests, spend.

### 5. Deployment & Infrastructure

- Harden containers, limit capabilities (distroless images, AppArmor).
- CI/CD pipelines w/ security scanning.
- Least privilege for training + inference jobs.
- Isolate dev, staging, prod environments.

### 6. Runtime & Hardware Isolation

- Separate training, evaluation, prod inference workloads by trust boundary.
- Don't share GPU/accelerator devices between mutually untrusted tenants unless platform gives strong hardware-backed partitioning + memory isolation.
- Clear model inputs, outputs, temp files, caches, accelerator memory between jobs where runtime supports it.
- Run untrusted model evaluation, fine-tuning, conversion jobs in sandboxes/isolated workers w/ restricted network egress.
- microVMs, gVisor, Kata Containers, confidential compute, or dedicated nodes for high-sensitivity models/datasets.
- Disable host paths, container sockets, cloud metadata services, unnecessary device mounts in model-serving containers.
- Per-workload CPU, memory, GPU, disk, process, network limits → prevent noisy-neighbor + DoS impact.
- Scope model-serving credentials to specific model, endpoint, environment; no broad shared platform credentials.
- Validate job teardown removes temp artifacts, local checkpoints, prompt logs, cached embeddings.
- Monitor runtime isolation failures, unexpected device access, cross-namespace network traffic, metadata endpoint access attempts.

### 7. Monitoring & Logging

- Monitor input distribution, output entropy, latency.
- Detect drift via statistical analysis or shadow models.
- Log requests + access w/ traceability (avoid logging sensitive data).
- Alert on unusual usage (e.g., scraping, injection attempts).

### 8. Adversarial Robustness

- Include adversarial examples in testing/evaluation.
- Robust training (e.g., adversarial training, input denoising).
- Monitor model confidence thresholds to spot out-of-distribution inputs.
- Shadow deployments: evaluate candidate model on real prod inputs w/o affecting live outputs.
- Canary releases: route small traffic percentage to new model gradually, rapid rollback on problems.

### 9. Incident Response & Governance

- Escalation procedures for model abuse/drift.
- Rollback mechanisms for model deployments.
- Map threats to OWASP ASVS or Proactive Controls for AI/ML.

## References

- NIST SP 800-218A: Secure Software Development Practices for Generative AI and Dual-Use Foundation Models
- NIST AI 100-2 E2025: Adversarial Machine Learning
- OWASP AI Security Verification Standard
