# Secrets Management Cheat Sheet

## 1 Introduction

Secrets used everywhere, esp. with DevOps: Application Programming Interface (API) keys, database credentials, Identity and Access Management (IAM) permissions, Secure Shell (SSH) keys, certificates, etc. Many organizations hardcode them in plaintext source code, scatter them through configuration files and configuration management tools.

Growing need to centralize storage, provisioning, auditing, rotation, management of secrets: control access, prevent leaks/compromise. Services often share same secrets → hard to identify compromise/leak source.

Best practices/guidelines for proper secrets management.

## 2 General Secrets Management

Main secrets management concepts.

### 2.1 High Availability

Select technology robust enough to service traffic reliably:

- Users (e.g., SSH keys, root account passwords). Incident response: users expect rapid credential provisioning to recover offline services. Waiting for credentials can hurt operations team responsiveness.
- Applications (e.g., database credentials and API keys). Poorly performing service can degrade dependent application availability or increase startup times.

Such a service could receive considerable request volume in large organization.

### 2.2 Centralize and Standardize

Secrets used by DevOps teams for applications may be consumed differently than secrets stored by marketeers or SRE team. Poorly maintained secrets often result where consumer/producer needs mismatch → standardize and centralize with care. Can mean multiple secret management solutions. E.g.: cloud-native teams use cloud provider's solution, private cloud uses third-party solution, everybody has account in selected password manager.
Teams standardizing interaction with these solutions keeps them maintainable and usable during incidents.
Even with one centralized solution, primary secret of that solution often must be secured in secondary secrets management solution. E.g. cloud provider facilities store secrets, but that provider's root/management credentials stored elsewhere.

Standardization includes Secrets life cycle management, Authentication, Authorization, Accounting of the secrets management solution, and life cycle management. Organization should immediately see what a secret is used for and where to find it. More solutions → more documentation.

### 2.3 Access Control

Users able to read/update secret in secret management system → secret can leak through that user and system used to touch it.
Engineers should not access all secrets in system; apply Least Privilege. System must support fine-grained access controls on each object and component to achieve Least Privilege.

### 2.4 Automate Secrets Management

Manual maintenance increases leakage risk, introduces human error, can be wasteful.
Limit/remove human interaction with actual secrets:

- **Secrets pipeline:** pipeline handling large parts of secret management (e.g., creation, rotation, etc.)
- **Using dynamic secrets:** application requests database credentials at start; dynamically generated → new credentials per session. Use dynamic secrets where possible to reduce credential reuse surface. Configure short lease duration; revoke credentials when no longer needed. Restarting application doesn't itself revoke stolen credentials; remain usable until backing service expires/revokes them.
- **Automated rotation of static secrets:** manual key rotation challenging, error-prone. Automate key rotation or at least ensure IT sufficiently supports process.

Rotating some keys (e.g. encryption keys) might trigger full/partial data re-encryption. Rotation strategies:

- Gradual rotation
- Introducing new keys for Write operations
- Leaving old keys for Read operations
- Rapid rotation
- Scheduled rotation
- and more...

#### 2.4.1 Architectural Patterns for Automated Rotation

Architectural patterns supporting automated secret rotation:

##### Example 1: Kubernetes with a Sidecar Container

Kubernetes common pattern: sidecar container retrieves secrets from secrets manager, makes them available to main application container. Decouples application from secrets management specifics.

- **Architecture:**
    - Pod contains main application container + sidecar container (e.g., HashiCorp Vault Agent, CyberArk Conjur Secrets Provider).
    - Sidecar authenticates with secrets manager (e.g., via Kubernetes Service Account).
    - Retrieves secret, writes to shared in-memory volume.
    - Application container reads secret from shared volume.
    - Sidecar can periodically refresh secret → application always has valid, short-lived credential.
- **Kubernetes Manifest Snippet:**

    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: my-app
    spec:
      serviceAccountName: my-app-sa
      containers:
      - name: my-app-container
        image: my-app-image
        volumeMounts:
        - name: secrets-volume
          mountPath: "/mnt/secrets"
          readOnly: true
      - name: vault-agent-sidecar
        image: vault:latest
        args: ["agent", "-config=/etc/vault/vault-agent-config.hcl"]
        volumeMounts:
        - name: secrets-volume
          mountPath: "/mnt/secrets"
      volumes:
      - name: secrets-volume
        emptyDir:
          medium: "Memory"
    ```

##### Example 2: Serverless Function for Database Credential Rotation

Cloud-native secret managers often support automated rotation via serverless functions (e.g., AWS Lambda, Azure Functions).

- **Architecture:**
    - Secret stored in cloud secrets manager (e.g., AWS Secrets Manager).
    - Secrets manager triggers rotation Lambda function on schedule.
    - Lambda function has permissions to update database password and secret value in secrets manager.
    - Rotation typically multi-step (create new secret, set new secret, test new secret, finish rotation) for safe transition.

AWS: start from rotation function templates. Secrets Manager invokes function separately for each rotation step; retrieve pending credential from secret version identified by `ClientRequestToken`, not from local variable of earlier invocation.

Follow rotation function security checks and template validation: ensure rotation enabled and request token identifies known secret version. Return safely if version already `AWSCURRENT`; otherwise require `AWSPENDING`. Before changing credentials, validate current credential and confirm pending version targets intended database and user under chosen rotation strategy. Prevents privileged function being redirected to another resource. Test pending credential before promoting its version to `AWSCURRENT`.

Examples show architectures that manage secrets securely and automate rotation, significantly reducing compromised credential risk.

### 2.5 Handling Secrets in Memory

Extra security: minimize time window secret is in memory; limit access to its memory space.

Hard to implement ensuring memory security, depending on circumstances. First develop threat model to surface implicit assumptions about deployment environment and adversary capabilities.

Protecting secrets in memory often overkill: evaluated threat actors lack capabilities for such attacks, or defense cost far exceeds likely compromise impact. Also, attacker with memory access to secret-handling process may mean breach already occurred. Attacks like Rowhammer, Meltdown and Spectre show OS alone insufficient to protect process memory; esp. important in cloud. Only foolproof approach: fully physically isolate process memory from all other untrusted processes.

Despite difficulty, in highly sensitive environments protecting secrets in memory can be valuable extra layer. E.g., advanced attacker causing crash and gaining memory dump may extract secrets. Carefully safeguard secrets in memory for untrusted environments or when tight security paramount.

In lower-level languages like C/C++, protecting secrets in memory relatively easy → worthwhile even if memory access risk low. Garbage-collected languages: generally much harder.

- **Structures and Classes:** .NET and Java: don't use immutable structures such as Strings for secrets (can't force garbage collection). Use primitive types like byte arrays or char arrays, memory directly overwritable.

- **Zeroing Memory:** zero out memory after secret use to prevent lingering where potentially accessible.

- **Memory Encryption:** sometimes hardware/OS features can encrypt whole memory space of secret-handling process. Extra layer.

Goal: minimize time secret is plaintext in memory.

More: Testing Memory for Sensitive Data from OWASP MAS project.

### 2.6 Auditing

Auditing essential given nature of application. Implement securely, resilient vs tampering/deletion of audit logs. At minimum audit:

- Who requested secret, for what system and role.
- Whether secret request approved or rejected.
- When secret used and by whom/what.
- When secret expired.
- Any attempts to reuse expired secrets.
- Any authentication or authorization errors.
- When secret updated and by whom/what.
- Any administrative actions and possible user activity on underlying supporting infrastructure stack.

All auditing needs correct timestamps. Secret management solution should have proper time sync protocols on supporting infrastructure. Monitor stack for clock-skew and manual time adjustments.

### 2.7 Secret Lifecycle

Lifecycle stages:

- Creation
- Rotation
- Revocation
- Expiration

#### 2.7.1 Creation

New secrets must be securely generated, cryptographically robust enough for purpose. Assign minimum privileges needed for required use/role.

Transmit credentials securely: ideally don't send password with username when requesting user accounts. Send password via secure channel (e.g., mutually authenticated connection) or side-channel such as push notification, SMS, email. Channel pros/cons: [Multi-Factor Authentication Cheat Sheet](Multifactor_Authentication.md).

Applications may not benefit from multiple communication channels → provision credentials securely.

More technical recommendations on secret creation: Open CRE project on secrets lookup.

#### 2.7.2 Rotation

Rotate secrets regularly so stolen credentials work only briefly. Also reduces tendency to fall back on bad habits like credential reuse.

Lifetime depends on function and what it protects: minutes (e.g. end-to-end encrypted chats with perfect forward secrecy) to years (hardware secrets).

User credentials excluded from regular rotation; rotate only on suspicion/evidence of compromise, per NIST recommendations.

#### 2.7.3 Revocation

Securely revoke secrets when no longer required or potentially compromised, to restrict access. (TLS) certificates: also certificate revocation.

#### 2.7.4 Expiration

Create secrets to expire after defined time where possible. Active expiration by secret consuming system, or expiration date set at secrets management system forcing supporting processes to trigger, resulting in rotation.
Apply policies via secrets management solution so credentials available only for limited time appropriate to credential type. Applications should verify secret still active before trusting it.

### 2.8 Transport Layer Security (TLS) Everywhere

Never transmit secrets via plaintext. No excuse given ubiquitous TLS adoption.

Secrets management solutions can also provision TLS certificates effectively.

### 2.9 Downtime, Break-glass, Backup and Restore

Secrets management service may become unavailable (e.g. scheduled maintenance downtime). Credentials needed to restore service may be unretrievable if not previously acquired. Choose maintenance windows carefully using earlier metrics and audit logs.

Regularly test and audit backup/restore procedures for security. Ensure:

- Automated backup procedure in place, executed periodically; base backup/snapshot frequency on number of secrets and their lifecycle.
- Frequently test restore procedures to guarantee backups intact.
- Encrypt backups, put on secure storage with reduced access rights. Monitor backup location for (unauthorized) access and administrative actions.

Implement emergency ("break-glass") processes to restore service if system unavailable for reasons other than regular maintenance. Regularly back up emergency break-glass credentials securely in secondary secrets management system; test routinely.

### 2.10 Policies

Consistently enforce organization-wide policies defining minimum password complexity and approved encryption algorithms. Centralized secrets management solution helps implement them.

Organization-wide secrets management policy helps enforce best practices in this cheat sheet.

### 2.11 Metadata: prepare to move the secret

Secret management solution should store at least this metadata about a secret:

- When it was created/consumed/archived/rotated/deleted
- Who created/consumed/archived/rotated/deleted it (e.g., both actual producer and engineer using production method)
- What created/consumed/archived/rotated/deleted it
- Who to contact for trouble or questions about secret
- What secret is used for (e.g., designated intended consumers and purpose)
- Type of secret (e.g., AES Key, HMAC key, RSA private key)
- When to rotate it, if done manually

Note: no secret metadata and no preparation to move → higher vendor lock-in probability.

### 2.12 Passwordless Authentication and Token Security

OpenID Connect (OIDC) lets application delegate user authentication to identity provider (IdP), not store/verify user's password itself. Doesn't require passwordless authentication: OpenID Connect Core Section 3.1.2.3 leaves IdP's authentication method, including passwords, outside protocol scope.

OIDC alone doesn't eliminate phishing, credential stuffing, or weak passwords at IdP. Choose IdP enforcing appropriate authentication controls; for phishing resistance require phishing-resistant authentication (NIST SP 800-63B-4), e.g. WebAuthn. See [Multifactor Authentication Cheat Sheet](Multifactor_Authentication.md).

Federation still requires protecting issued tokens and any client credentials. Follow [OAuth2 Cheat Sheet](OAuth2.md) for token transmission, storage, validation, expiration, refresh-token protection. OIDC doesn't replace other application secrets, e.g. database credentials or API keys.

## 3 Continuous Integration (CI) and Continuous Deployment (CD)

Building, testing, deploying changes generally needs access to many systems. Continuous Integration (CI) and Continuous Deployment (CD) tools typically store secrets for application configuration or deployment, or interact heavily with secrets management system. Best practices smooth secret management in CI/CD; some below.

### 3.1 Hardening your CI/CD pipeline

CI/CD tooling regularly consumes (high-privilege) credentials. Ensure pipeline can't easily be hacked or misused by employees. Guidelines:

- Treat CI/CD tooling as production environment: harden and patch it and underlying infrastructure/services.
- Security Event Monitoring in place.
- Least-privilege access: developers needn't administer projects; only execute required functions (set up pipelines, run them, work with code). Administrative tasks via configuration-as-code in separate repository used by CI/CD system to update its configuration. No need for privileged roles with possible access to secrets.
- Pipeline output must not leak secrets; no listening in on production pipelines with debugging tools.
- No exec into any runners/workers of CI/CD system.
- Proper authentication, authorization, accounting.
- Only approved process creates pipelines, incl. MR/PR steps ensuring created pipeline is security-reviewed.

### 3.2 Where should a secret be?

Places to store secret for CI/CD actions:

- In CI/CD tooling: store secret in GitLab/GitHub/Jenkins. Not same as committing to code.
- In secrets-management system: e.g. cloud provider facilities (AWS Secrets Manager, Azure Key Vault, Google Secret Manager) or third-party (Hashicorp Vault, Conjur, Keeper). CI/CD pipeline tooling then needs credentials to connect to these systems to get secrets in place. See [Cloud Providers](#4-cloud-providers) for cloud provider secret management.

Alternative: CI/CD pipeline uses Encryption as a Service from secrets management systems to encrypt secret. CI/CD tooling commits encrypted secret to git; consuming service fetches it on deployment and decrypts. See section 3.6.

Note: not all secrets must go through CI/CD pipeline to deployment. Deployed services should handle part of their secrets management in own lifecycle (e.g., deployment, runtime, destruction).

#### 3.2.1 As part of your CI/CD tooling

Secrets in CI/CD tooling are exposed to CI/CD jobs. CI/CD tooling can include GitHub secrets, GitLab repository secrets, ENV Vars/Var Groups in Microsoft Azure DevOps, Kubernetes Secrets, etc.
Often configurable/viewable by authorized people (e.g., maintainer in GitHub, project owner in GitLab, admin in Jenkins), giving these best practices:

- No "big secret": CI/CD tooling secrets should not be long-term, wide blast radius, or high value. Limit shared secrets (e.g., never one password for all administrative users).
- As is / To be: clear overview of which users can view/alter secrets. Maintainers of GitLab/GitHub project can often see or otherwise extract its secrets.
- Reduce number of people able to perform administrative tasks on project to limit exposure.
- Log & Alert: collect all CI/CD tooling logs; rules detecting secret extraction or misuse, whether via web interface or dumping while double Base64 encoding or encrypting with OpenSSL.
- Rotation: regularly rotate secrets.
- Forking should not leak: validate fork of repository or copy of job definition doesn't copy secret.
- Document: document which secrets stored in CI/CD tooling and why, for easy migration.

#### 3.2.2 Storing it in a secrets management system

Store secrets in designated secrets management solution. E.g. solution from (cloud) infrastructure provider: AWS Secrets Manager, Google Secrets Manager, Azure Key Vault (see [section 4](#4-cloud-providers)). Or dedicated system: Hashicorp Vault, Keeper, Conjur.
Do's and don'ts for CI/CD interaction with these systems. Ensure:

- Rotation/Temporality: credentials CI/CD tooling uses to authenticate to secret management system rotated frequently, expire after job completes.
- Scope of authorization: scope credentials used by CI/CD tooling (e.g., roles, users, etc.) to authorize only secrets and services of secret management system needed for job.
- Attribution of the caller: credentials used by CI/CD tooling still hold attribution of one calling secrets management solution. Attribute any calls by CI/CD tooling to person/service that requested actions. If not possible via default secrets manager configuration, set up correlation via request parameters.
- All of the above: still follow section 3.2.1 do's and don'ts: log & alert, forking, etc.
- Backup: back up secrets for product-critical operations in separate storage (e.g., cold storage), esp. encryption keys.

#### 3.2.3 Not touched by CI/CD at all

Secrets needn't be brought to consumer by CI/CD pipeline. Better when consumer retrieves secret. CI/CD pipeline still instructs orchestrating system (e.g., Kubernetes) to schedule specific service with given service account that consumer uses to retrieve required secret. CI/CD tooling then has credentials for orchestrating platform but no access to secrets themselves. Do's and don'ts for these credential types similar to section 3.2.2.

### 3.3 Authentication and Authorization of CI/CD tooling

CI/CD tooling should have designated service accounts operating only within scope of required secrets or orchestration of secret consumers. CI/CD pipeline run should be easily attributable to who defined or triggered job, to detect who tried to exfiltrate/manipulate secrets. Certificate-based auth: caller of pipeline identity should be part of certificate. Token auth toward these systems: set principal requesting actions (e.g., user or job creator).

Periodically verify this remains true, for effective logging, attribution, security alerting on suspicious actions.

### 3.4 Logging and Accounting

Attackers can use CI/CD tooling to extract secrets, e.g. via administrative interfaces or job creation exfiltrating secret using encryption or double Base64 encoding. Log every action in CI/CD tool. Define security alerting rules at every non-standard manipulation of pipeline tool and its administrative interface to monitor secret usage.
Logs queryable for at least 90 days, stored longer in cold storage. Security teams may need time to understand how attackers exfiltrate/manipulate secret via CI/CD tooling.

### 3.5 Rotation vs Dynamic Creation

CI/CD tooling can rotate secrets or instruct other components to rotate. E.g., CI/CD tool requests secrets management system or another application to rotate secret. Alternatively, CI/CD tool or another component sets up dynamic secret: secret a consumer uses as long as it lives. Tie invalidation to provider's lease expiry or explicit revocation; stopping consumer alone doesn't revoke secret. Reduces possible leakage and allows easy misuse detection: attacker using secret from anywhere other than consumer's IP is easily detected.

### 3.6 Pipeline Created Secrets

Pipeline tooling can generate secrets and offer them directly to service deployed by tooling, or to secrets management solution. Alternatively, store secret encrypted in git so secret and metadata are as close to developer's daily workplace as possible. Git-stored secret requires developers can't decrypt secrets themselves and every consumer has its own encrypted variant. E.g.: secret differs per DTAP environment, encrypted with different key. Per environment, only designated consumer in that environment can decrypt specific secret. Secret doesn't leak cross-environment and can be stored next to code.
Consumers could decrypt secret via sidecar, as in section 5.2. Instead of retrieving secrets, consumer leverages sidecar to decrypt.

Pipeline creating secret itself: ensure scripts/binaries follow best practices for secret generation: secure randomness, proper secret length, etc., and secret created from well-defined metadata stored in git or elsewhere.

## 4 Cloud Providers

At least four essential cloud provider topics:

- Designated secret storage/management solutions. Which service(s) to use?
- Envelope & client-side encryption
- Identity and access management: decreasing blast radius
- API quotas or service limits

### 4.1 Services to Use

Best: designated secret management solution in any environment. Most cloud providers have at least one secret management service. Can also run different solution (e.g., HashiCorp Vault or Conjur) on cloud compute resources. This section covers cloud provider offerings.

Secret rotation sometimes automatic via cloud provider service or (custom-built) function. Generally prefer cloud provider's solution: lower barrier of entry and misconfiguration risk. Custom solution: ensure function's rotation role can only be assumed by that function.

#### 4.1.1 AWS

AWS recommended solution: AWS Secrets Manager.

Permissions granted at secret level. See Secrets Manager best practices.

Systems Manager Parameter Store also possible, cheaper, with downsides:

- must specify encryption yourself (secrets manager does by default)
- fewer auto-rotation capabilities (likely need custom function)
- cross-account sharing limited to advanced parameters; sharing encrypted `SecureString` values also requires customer managed AWS KMS key and separately granting access to that key
- no cross-region replication
- fewer Security Hub Controls available

##### 4.1.1.1 AWS Nitro Enclaves

AWS Nitro Enclaves: isolated compute environments further protecting/securely processing highly sensitive data such as secrets. Enclaves hardened, restrict operator access, give trusted execution environment. Key feature: cryptographic attestation verifies enclave identity and that only authorized code runs before provisioning secrets. Strong choice for high-assurance secret handling.

##### 4.1.1.2 AWS CloudHSM

Highly confidential applications may need more control over key encryption/storage. AWS CloudHSM lets you bring your own key (BYOK) for AWS services → more control over key creation, lifecycle, durability. Scale CloudHSM cluster by adding or removing HSMs; service makes periodic encrypted backups of cluster users, keys, configuration. Amazon has no access to key material stored in **AWS CloudHSM**.

#### 4.1.2 GCP

GCP recommended service: Secret Manager.

Permissions granted at secret level.

See Secret Manager best practices.

##### 4.1.2.1 Google Cloud Confidential Computing

GCP Confidential Computing encrypts data in-use, while processed. Via **Confidential VMs** and **Confidential GKE Nodes**, using AMD Secure Encrypted Virtualization (SEV). Even Google personnel can't view VM memory contents → high protection for secrets held in memory.

#### 4.1.3 Azure

Azure recommended service: Key Vault.

Azure role-based access control (RBAC) supports role assignments for individual secrets, keys, certificates. Follow [Identity and Access Management guidance](#43-identity-and-access-management-iam) for access scopes and vault boundaries.

See Key Vault best practices.

##### 4.1.3.1 Azure Confidential Computing

Azure Confidential Computing creates trusted execution environments. Isolates sensitive data in protected container, encrypted at rest, in transit, in use. **Azure Confidential Virtual Machines** and **Confidential Containers on ACI** use Intel SGX and AMD SEV-SNP to create secure enclaves. Prevents unauthorized access from cloud administrators, malware, other tenants → robust for secret management.

##### 4.1.3.2 Azure Dedicated HSM

Azure environments needing special security: Azure Dedicated HSM. More control over secrets stored on it, incl. enhanced administrative and cryptographic control. Microsoft has no access to key material stored in Azure Dedicated HSM.

#### 4.1.4 Other clouds, Multi-cloud, and Cloud agnostic

Multiple cloud providers: consider cloud-agnostic secret management solution → same solution across all providers (possibly on-premises too). Avoids vendor lock-in; usable on any cloud provider.

Open-source and commercial solutions, e.g.:

- CyberArk Conjur
- HashiCorp Vault
- Pulumi ESC

### 4.2 Envelope & client-side encryption

How secret is encrypted and how to manage encryption keys in cloud.

#### 4.2.1 Client-side encryption versus server-side encryption

Server-side encryption: cloud provider encrypts secret in storage. Protects vs compromise at rest. Often needs no extra work besides selecting key (see section 4.2.2). But when submitting secret to another service, it's no longer encrypted: decrypted before sharing with intended service or human user.

Client-side encryption: secret stays encrypted until you actively decrypt it; decrypted only on arrival at consumer. Needs proper crypto system, e.g. PGP in safe configuration or other more scalable, relatively easy systems. Can provide end-to-end encryption of secret, producer to consumer.

#### 4.2.2 Bring Your Own Key versus Cloud Provider Key

Encrypting secret at rest: which key? Less trust in cloud provider → manage more yourself.

Often either encrypt secret with key managed at secrets management service, or use cloud provider's key management solution. Provider's key can be managed by provider or by yourself; latter = "bring your own key" (BYOK) in industry standards. Import or generate key directly at key management solution, or use provider-supported cloud HSM.
Then use your key or provider's customer main key to encrypt secrets management solution's data key; data key encrypts secret. Managing CMK gives control over data key at secrets management solution.

Importing own key material generally possible with all providers (AWS, Azure, GCP), but not recommended unless you know what you're doing and threat model/policy require it, due to complexity and difficulty of use.

### 4.3 Identity and Access Management (IAM)

IAM applies on-premises and cloud: effective secrets management needs suitable access policies and roles. Goes beyond secrets policies; harden full IAM setup, else privilege escalation attacks possible. Never allow open "pass role" privileges or unrestricted IAM creation privileges: can use/create credentials with access to secrets. Tightly control what can impersonate service account: are machine roles accessible to attacker exploiting server? Can data-pipeline tooling service roles access secrets easily? Include IAM for every cloud component in threat model (e.g., ask: how can elevation of privileges happen with this component?). See blog entry on ten AWS IAM pitfalls for do's and don'ts with examples.

Use temporality of IAM principals effectively: only specific roles/service accounts that need it access secrets. Monitor these accounts to tell who/what used them to access secrets.

Scope access to secrets: no one allowed to access all secrets. GCP and AWS: create fine-grained access policies so principal can't access all secrets at once. Azure Key Vault: use recommended Azure RBAC permission model with least-privilege roles. Azure RBAC supports role assignments at scope of individual keys, secrets, certificates for limited sharing scenarios, but Microsoft recommends separate vaults per application and environment as primary security boundary.

### 4.4 API limits

Cloud services generally allow limited API calls per period; you could (D)DoS yourself hitting limits. Most limits apply per account, project, or subscription → spread workloads to limit blast radius. Some services support data key caching, preventing load on key management service API (e.g., AWS data key caching). Some leverage built-in data key caching; S3 is one example.

## 5 Containers & Orchestrators

Enrich containers with secrets at build time (not recommended) or during orchestration/deployment.

### 5.1 Injection of Secrets (file, in-memory)

Three ways to get secrets to app inside Docker container.

- Mounted volumes (file): keep secrets in config/secret file mounted to instance as volume. Orchestrator must mount these in, never built-in (leaks secret with container definition). Orchestrator mounts volume when required.
- Fetch from the secret store (in-memory): sidecar app/container fetches needed secrets directly from secret manager service without docker config. Allows dynamically constructed secrets without exposure via file system or Docker container's environment variables.
- Environment variables: provide secrets directly in Docker container configuration. Note: never hardcode secrets via docker ENV or docker ARG; easily leak with container definitions. See Docker challenges at WrongSecrets. Let orchestrator overwrite environment variable with actual secret; ensure not hardcoded. Environment variables generally accessible to all processes, may appear in logs or system dumps. Not recommended unless other methods impossible.

### 5.2 Short-Lived Sidecar Containers

To inject secrets: short-lived sidecar containers fetch secrets from remote endpoint, store on shared volume mounted to original container, which uses secrets from mounted volume. Benefit: no third-party tool/code integration needed to get secrets. Sidecar terminates once secrets fetched. Examples: Vault Agent Sidecar Injector, Conjur Secrets Provider. Mounting secrets to volume shared with pod lets containers consume secrets unaware of secrets manager.

### 5.3 Internal vs External Access

Expose secrets only to communication mechanisms between container and deployment representation (e.g., Kubernetes Pod). Never expose secrets via external access mechanisms shared among deployments or orchestrators (e.g., shared volume).

Orchestrator stores secrets (e.g., Kubernetes Secrets): ensure orchestrator storage backend encrypted and keys well managed. See [Kubernetes Security Cheat Sheet](Kubernetes_Security.md).

## 6 Implementation Guidance

Always refer to official documentation of chosen secrets management system for actual implementation; more up to date than secondary documents like this cheat sheet.

### 6.1 Key Material Management Policies

See [Key Management Cheat Sheet](Key_Management.md)

### 6.2 Dynamic vs Static Use Cases

Dynamic secret use cases, among others:

- short-lived secrets (e.g., credentials or API keys) for secondary service expressing intent to connect primary service (e.g., consumer) to the service.
- short-lived integrity/encryption controls guarding in-memory and runtime communication processes, e.g. encryption keys living only for single session or single deployment lifetime.
- short-lived credentials for building stack during service deployment, for interacting with deployers and supporting infrastructure.

Dynamic secrets often must be created with the service to connect to; creating them usually needs long-term static secrets. Other static use cases:

- key material living longer than single deployment due to usage in interaction with other instances of same service (e.g., storage encryption keys, TLS PKI keys)
- key material or credentials to connect to services not supporting temporal roles or credentials.

### 6.3 Ensure limitations are in place

Secrets never retrievable by everyone and everything. Put guardrails in place:

- Can create access policies? Ensure policies limit entities reading/writing secret. Write policies easy to extend and not too complicated to understand.
- No way to reduce access to certain secrets within solution? Consider separating production and development secrets with separate secret management solutions; reduce access to production solution.

### 6.4 Security Event Monitoring is Key

Continually monitor who/what, from which IP, by what methodology accesses secret. Patterns to look for (not limited to):

- Monitor who accesses secret at secret management system: normal behavior? CI/CD credentials used to access secret management solution from different IP than CI/CD system's → security alert; assume secret compromised.
- Monitor service requiring secret (if possible), e.g. whether secret user comes from expected IP, with expected user agent. If not, alert and assume secret compromised.

### 6.5 Usability and Ease of Onboarding

Solution must be easy for developers to adopt and use. Too complex → developers resort to insecure practices. Usability and smooth onboarding critical.

- **Clear and Comprehensive Documentation:**
    - Clear, concise, easy-to-find documentation: tutorials for common use cases, detailed API references, practical examples.
    - "Getting started" guide walking new users through obtaining first secret.
- **Developer-Friendly Tooling and SDKs:**
    - Well-maintained SDKs for various programming languages to simplify integration.
    - Command-line interface (CLI) letting developers manage secrets from local development environment.
    - Plugins for common IDEs, CI/CD systems, infrastructure-as-code (IaC) tools like Terraform and Pulumi.
- **Streamlined Workflows:**
    - Self-service workflows letting developers request/receive secrets with minimal manual intervention.
    - GitOps principles to manage secrets as code: developers define secret needs declaratively alongside application code.
    - Automate approval for low-risk secrets while keeping appropriate controls for more sensitive ones.
- **Actionable Feedback and Support:**
    - Clear error messages helping developers troubleshoot independently.
    - Dedicated support channels (e.g., Slack channel, ticketing system) with security/platform team help.
- **Easy Integration:**
    - Easy integration with existing applications. Sidecar containers, such as Vault Agent Sidecar Injector or Conjur Secrets Provider, help decouple applications from secrets management system.

## 7 Encryption

Secrets Management goes hand in hand with encryption: secrets must be stored encrypted to protect confidentiality and integrity.

### 7.1 Encryption Types to Use

Various encryption types OK if sufficiently secure, incl. adequate resistance vs quantum computing-based attacks. Moving field: consult sources like keylength.com (up-to-date recommendations on encryption types and key lengths for existing standards) and NSA's Commercial National Security Algorithm Suite 2.0 (quantum resistant algorithms).

In all cases, preferably select algorithm providing encryption and confidentiality simultaneously, such as AES-256 using GCM (Galois Counter Mode), or mixture of ChaCha20 and Poly1305 per field best practices.

### 7.2 Convergent Encryption

Convergent Encryption: given plaintext and key always yields same ciphertext. Helps detect possible secret reuse (same ciphertext).
Challenge: lets attackers use system to generate set of cryptographic strings that might end up as same secret, allowing derivation of plaintext secret. Given algorithm and key, mitigate if convergent crypto system has sufficient resource challenges during encryption. Also reduce risk by ensuring secret has adequate length, hampering guess-iteration time.

### 7.3 Where to store the Encryption Keys?

Don't store keys next to secrets they encrypt, except if keys themselves encrypted (see envelope encryption). Start with [Key Management Cheat Sheet](Key_Management.md) on where/how to store encryption and possible HMAC keys.

### 7.4 Encryption as a Service (EaaS)

EaaS: users subscribe to cloud-based encryption service without installing encryption on own systems. Benefits:

- Encryption at rest
- Encryption in transit (TLS)
- Key handling and cryptographic implementations handled by Encryption Service, not developers
- Provider could add more services to interact with sensitive data

## 8 Detection

Many secrets detection approaches; useful open-source projects exist. Yelp Detect Secrets mature, signature matching for around 20 secrets. Other tools: Secrets Detection topic on GitHub.

### 8.1 General detection approaches

Shift-left and DevSecOps principles apply to secrets detection. Approaches below consider secrets earlier, evolve practice over time.

- Create standard test secrets, use universally across organization → fewer false positives (track single test secret per secret type).
- Consider developer-level secrets detection to avoid checking secrets into code before commit/PR: in IDE, as part of test-driven development, or via pre-commit hook.
- Make secrets detection part of threat model; consider secrets part of attack surface in threat modeling exercises.
- Evaluate detection utilities and signatures often to ensure they meet expectations.
- Consider more than one detection utility; correlate/de-dupe results to identify detection weakness areas.
- Balance entropy and ease of detection. Consistent-format secrets easier to detect with lower false-positive rates, but don't miss human-created password just because it doesn't match detection rules.

### 8.2 Types of secrets to be detected

Many secret types; consider signatures for each for accurate detection. Common types:

- High availability secrets (Tokens that are difficult to rotate)
- Application configuration files
- Connection strings
- API keys
- Credentials
- Passwords
- 2FA keys
- Private keys (e.g., SSH keys)
- Session tokens
- Platform-specific secret types (e.g., Amazon Web Services, Google Cloud)

Learning and practice rooting secrets out: Wrong Secrets project.

### 8.3 Detection lifecycle

Secrets = authorization tokens like any other. They should:

- Exist only as long as necessary (rotate often)
- Have method for automatic rotation
- Be visible only to those who need them (least privilege)
- Be revocable (incl. logging attempts to use revoked secret)
- Never be logged (implement encryption or masking to avoid logging plaintext secrets)

Create detection rules for each secret lifecycle stage.

### 8.4 Documentation for how to detect secrets

Create and regularly update documentation informing developer community of procedures/systems available, expected secrets management types, how to test for secrets, what to do on detected secrets.

Documentation should:

- Exist and be updated often, esp. after an incident
- Include:
    - Who has access to secret
    - How it gets rotated
    - Upstream/downstream dependencies potentially broken during secret rotation
    - Point of contact during incident
    - Security impact of exposure

- Identify when secrets may be handled differently depending on threat risk, data classification, etc.

## 9 Incident Response

Quick response to secret exposure = perhaps most critical secrets management consideration.

### 9.1 Documentation

Incident response for secret exposure must ensure everyone in chain of custody is aware and understands how to respond: application creators (every development team member), information security, technology leadership.

Documentation must include:

- How to test for secrets and secrets handling, esp. during business continuity reviews.
- Whom to alert when secret detected.
- Containment steps
- Information to log during event

### 9.2 Remediation

Primary incident response goal: rapid response and containment.

Containment procedures:

1. Revocation: immediately revoke exposed keys. Secret must be quickly de-authorizable; systems must identify revocation status.
2. Rotation: new secret must be quickly creatable and implementable, preferably via automated process ensuring repeatability, low implementation error rate, least-privilege (not directly human-readable).
3. Deletion: immediately remove revoked/rotated secrets from exposed system, incl. secrets found in code or logs. Secrets in code: commit history could be squashed to before secret introduction, but rewrites git history, breaks other links to given commit; if chosen, know consequences and plan accordingly. Secrets in logs need process for removing secret while maintaining log integrity.
4. Logging: incident response teams need info on secret lifecycle for containment/remediation, incl.:
    - Who had access?
    - When did they use it?
    - When was it previously rotated?

### 9.3 Logging

Additional considerations for logging secrets usage:

- Incident response logging to single location accessible by incident response (IR) teams
- Ensure logging fidelity during purple team exercises:
    - What should have been logged?
    - What was actually logged?
    - Adequate alerts in place?

Consider standardized logging format and vocabulary such as [Logging Vocabulary Cheat Sheet](Logging_Vocabulary.md) to ensure all necessary info logged.

## 10 Secrets Management in a Multi-Cloud Environment

### 10.1 Introduction

Multi-cloud secrets management has unique challenges from provider/service diversity. Challenges and best practices for managing secrets across multiple cloud providers.

### 10.2 Challenges

1. **Diverse APIs and Interfaces**: each provider has own API/interface for secrets → integration/management complexity across providers.
2. **Inconsistent Security Policies**: providers' security policies/practices vary → hard to enforce consistent standards across environments.
3. **Key Rotation**: consistent, secure key rotation across providers difficult, esp. with different rotation mechanisms.
4. **Access Control**: access control for secrets across providers complex; each has different mechanisms/policies.
5. **Auditing and Monitoring**: comprehensive auditing/monitoring of secret access and usage across providers challenging due to differing logging/monitoring capabilities.

### 10.3 Best Practices

1. **Use a Centralized Secrets Management Solution**: centralized solution integrating with multiple cloud providers; standardizes secrets management, enforces consistent security policies across environments. Examples: HashiCorp Vault, CyberArk Conjur.
2. **Standardize Security Policies**: define/enforce standardized secrets security policies across all providers: key rotation, access control, auditing.
3. **Automate Key Rotation**: automated rotation ensures consistent, secure rotation across all providers. Use tools/scripts to automate, reducing human error.
4. **Implement Fine-Grained Access Control**: fine-grained access control restricting secrets by least privilege. Ensure consistent enforcement of access control policies across all providers.
5. **Enable Comprehensive Auditing and Monitoring**: comprehensive auditing/monitoring of secret access and usage across all providers. Centralized logging/monitoring to aggregate and analyze logs from multiple providers.

### 10.4 References

- HashiCorp Vault
- CyberArk Conjur
- AWS Secrets Manager
- Azure Key Vault
- Google Cloud Secret Manager

## 11 Related Cheat Sheets & further reading

- [Key Management Cheat Sheet](Key_Management.md)
- [Logging Cheat Sheet](Logging.md)
- [Password Storage Cheat Sheet](Password_Storage.md)
- [Cryptographic Storage Cheat Sheet](Cryptographic_Storage.md)
- OWASP WrongSecrets project

## References

- NIST SP 800-57 Part 1 Rev. 5: Recommendation for Key Management
- AWS Secrets Manager: Best practices
- Azure Key Vault: Secure your secrets
