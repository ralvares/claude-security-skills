# Key Management Cheat Sheet

## Introduction

Guidance for secure implementation of cryptographic key management in an application. Document and harmonize rules/practices for:

1. Key life cycle management (generation, distribution, destruction)
2. Key compromise, recovery and zeroization
3. Key storage
4. Key agreement

## General Guidelines and Considerations

Formulate organization-wide cryptographic strategy guiding developers across applications; ensure each application's crypto capability meets minimum requirements + best practices.

Identify application's cryptographic + key management requirements; map all components processing/storing key material.

## Key Selection

Start algorithm selection from application objectives. E.g. secure data storage → algorithm suite supporting data-at-rest protection; transmit/receive data → suite supporting data-in-transit protection.

Developers often start crypto/key management by examining what a library offers. Instead analyze real application needs to determine optimal approach. Understand security objectives first; they drive protocol selection. Application may require:

1. Confidentiality of data at rest and in transit.
2. Authenticity of end device.
3. Authenticity of data origin.
4. Integrity of data in transit.
5. Keys to create data encryption keys.

Once security needs understood, determine protocols + algorithms, then define key types supporting objectives.

Key types and certificates, e.g.:

1. **Encryption:** Symmetric encryption keys, Asymmetric encryption keys (public and private).
2. **Authentication of End Devices:** Pre-shared symmetric keys, Trusted certificates, Trust Anchors.
3. **Data Origin Authentication:** HMAC.
4. **Integrity Protection:** Message Authentication Codes (MACs).
5. **Key Encryption Keys**.

### Algorithms and Protocols

Per `NIST SP 800-57 Part 1`, many algorithms/schemes providing a security service use a hash function as component.

Hash functions appear in digital signature algorithms (`FIPS186`), Keyed-Hash Message Authentication Codes (HMAC) (`FIPS198`), key-derivation functions/methods (`NIST Special Publications (SP) 800-56A, 800-56B, 800-56C and 800-108`), random number generators (`NIST SP 800-90A`). Approved hash functions defined in `FIPS180`.

`NIST SP 800-57 Part 1` recognizes three basic classes of approved cryptographic algorithms: hash functions, symmetric- key algorithms, asymmetric-key algorithms. Classes defined by number of keys used with algorithm.

NSA report Commercial National Security Algorithm Suite 2.0 lists algorithms expected to stay strong despite quantum computing advances.

#### Cryptographic hash functions

No keys required. Generate relatively small digest (hash value) from (possibly) large input; fundamentally hard to reverse (hard to find input producing given output). Building blocks for key management, e.g.:

1. Data authentication + integrity services (Section 4.2.3) – hash function used with key to generate message authentication code.
2. Compress messages for digital signature generation/verification (Section 4.2.4).
3. Derive keys in key-establishment algorithms (Section 4.2.5).
4. Generate deterministic random numbers (Section 4.2.7).

#### Symmetric-key algorithms

Aka secret-key algorithms. Transform data in way fundamentally hard to undo w/o secret key. "Symmetric": same key for cryptographic operation and its inverse (e.g., encryption and decryption).

Symmetric keys often known by more than one entity; key shall not be disclosed to entities not authorized for data protected by that algorithm + key. Uses, e.g.:

1. Data confidentiality (Section 4.2.2); same key encrypts + decrypts.
2. Authentication + integrity services (Section 4.2.3) as Message Authentication Codes (MACs); same key generates + validates MAC. MACs normally use symmetric key-encryption algorithm or cryptographic hash function as primitive.
3. Part of key-establishment process (Section 4.2.5).
4. Generate deterministic random numbers (Section 4.2.7).

#### Asymmetric-key algorithms

Aka public-key algorithms. Use two related keys (key pair): public + private. Public key may be known by anyone; private key under sole control of entity "owning" pair. Despite relation, public key doesn't reveal private key. Uses, e.g.:

1. Compute digital signatures (Section 4.2.4).
2. Establish cryptographic keying material (Section 4.2.5).
3. Generate random numbers (Section 4.2.7).

#### Message Authentication Codes (MACs)

MACs provide data authentication + integrity. MAC = cryptographic checksum on data assuring data unchanged and MAC computed by expected entity.

Message integrity often provided by non-cryptographic error detection codes, but adversary can alter these to own benefit. Approved cryptographic mechanism such as MAC alleviates this.

MAC also assures recipient originator is key holder (entity authorized to have key). Often used to authenticate originator to recipient when only those two share MAC key.

#### Digital Signatures

Digital signatures provide authentication, integrity, non-repudiation. Used with hash functions; computed on data of any length (up to limit set by hash function).

`FIPS186` specifies approved algorithms for digital signature computation.

#### Key Encryption Keys

Symmetric key-wrapping keys encrypt other keys using symmetric-key algorithms. Aka key encrypting keys.

### Key Strength

Review `NIST SP 800-57` (Recommendation for Key Management) for key strength guidelines per algorithm implementation. Also:

1. Establish application's minimum computational resistance to attack. Consider adversary sophistication, how long data needs protection, where data stored, whether exposed. Informs minimum key length needed over data's life. Consult `NIST SP 800-131a` for key lengths per algorithm.
2. When encrypting keys for storage/distribution, always encrypt key with another key of equal or greater cryptographic strength.
3. Moving to Elliptic Curve-based algorithms: choose key length meeting or exceeding comparative strength of other algorithms in system. See `NIST SP 800-57 Table 2`.
4. Formulate strategy for organization-wide cryptographic strategy guiding developers across applications; ensure each application's crypto capability meets minimum requirements + best practices.

### Memory Management Considerations

Keys in memory for long time can become "burned in". Mitigate by splitting key into frequently updated components. `NIST SP 800-57`).

Loss/corruption of memory media storing keys and/or certificates, and recovery planning, per `NIST SP 800-57`.

Plan recovery from possible corruption of memory media needed for key/certificate generation, registration, and/or distribution systems, subsystems, components, as recommended in `NIST SP 800-57`.

### Perfect Forward Secrecy

Ephemeral keys provide perfect forward secrecy: compromise of server's long term signing key doesn't compromise confidentiality of past sessions. See [TLS cheat sheet](Transport_Layer_Security.md).

### Key Usage

Per NIST, generally single key for only one purpose (e.g., encryption, authentication, key wrapping, random number generation, digital signatures).

Reasons:

1. Same key for two cryptographic processes may weaken security of one or both.
2. Limiting key use limits damage if key compromised.
3. Some key uses interfere, e.g. length of time key required per use/purpose. Data retention requirements may differ per data type.

### Cryptographic Module Topics

Per `NIST SP 800-133`, cryptographic modules = hardware, software, and/or firmware implementing security functions (incl. cryptographic algorithms + key generation), contained within cryptographic module boundary protecting keys.

Perform all cryptographic operations (key generation, encryption, decryption, digital signing) inside isolated cryptographic security module boundary so plaintext key material never exposed outside module (OWASP ASVS 5.0 §13.3.3). Higher-assurance deployments (e.g. OWASP ASVS 5.0 Level 3): use hardware-backed modules such as Hardware Security Module (HSM) or Trusted Platform Module (TPM) to significantly reduce risk of key extraction/compromise in software memory.

## Key Management Lifecycle Best Practices

### Generation

Keys shall be generated within cryptographic module with at least `FIPS 140-2 or 140-3` compliance (the key-generating module).

Any random value needed by key-generating module shall be generated within that module; Random Bit Generator must be implemented within cryptographic module with at least `FIPS 140-2 or 140-3` compliance that generates the key.

Hardware cryptographic modules preferred over software for protection.

### Distribution

Generated keys shall be transported (when necessary) over secure channels, used by associated cryptographic algorithm within at least `FIPS 140-2 or 140-3` compliant cryptographic modules. Details: `NIST Special Paper 800-133`.

### Storage

1. Cryptographic keys, secrets, API keys **never** committed to source code repositories or embedded in build artifacts (binaries, container images, configuration files). Store secrets/keys in dedicated secrets-management solution or key vault (OWASP ASVS 5.0 §13.3.1).
2. Developers must understand where keys are stored in application, and on what memory devices.
3. Protect keys on both volatile and persistent memory, ideally processed within secure cryptographic modules.
4. Never store keys in plaintext.
5. Store all keys in cryptographic vault such as hardware security module (HSM) or isolated cryptographic service.
6. Storing keys in offline devices/databases: encrypt keys with Key Encryption Keys (KEKs) before export of key material. KEK length (and algorithm) equal or greater in strength than protected keys.
7. Apply integrity protections to stored keys (consider dual purpose algorithms supporting encryption + Message Code Authentication (MAC)).
8. Standard application-level code never reads/uses raw cryptographic keys in any way; use key management libraries.
9. Keys and cryptographic operations done inside sealed vault.
10. All work done in vault (key access, encryption, decryption, signing, etc).

More complete guide to storing sensitive info such as keys: [Secrets Management Cheat Sheet](Secrets_Management.md).

### Cryptoperiods and Rotation

Cryptoperiod = time span during which specific key is authorized for use. Limiting cryptoperiods restricts data protected by single key, reduces exposure window on compromise (NIST SP 800-57 Part 1 Rev. 5 Section 5.3). Storage-level rotation fundamentals/criteria: [Cryptographic Storage Cheat Sheet](Cryptographic_Storage.md#key-lifetimes-and-rotation).

Representative cryptoperiods vary by algorithm, key strength, operational environment, threat model, protected data sensitivity. Organizations define cryptoperiods through risk assessment per NIST SP 800-57 Part 1 Rev. 5.

- **Rotation Schedule**: Establish + document key rotation schedule based on system's threat model and risk assessment (OWASP ASVS 5.0 §13.1.4, §13.3.4).
- **Representative Cryptoperiod Examples**:
    - **Symmetric Data Encryption Keys**: Originator usage (encrypting new data) capped at up to 2 years for general low-volume applications, or order of a day or a week for high-volume or link-encryption systems (NIST SP 800-57 Part 1 Rev. 5 §5.3.6, item 6(b)). Recipient usage (decryption) typically limited to no more than 3 years beyond originator usage period.
    - **TLS/HTTPS Server Keys and Certificates**: Plan certificate renewal around validity limits in CA/Browser Forum Baseline Requirements §6.3.2. Set key-replacement schedules separately; renewing certificate doesn't necessarily replace its key pair.
    - **Asymmetric Key Pairs**: Operational cryptoperiods depend on key usage (NIST SP 800-57 Part 1 Rev. 5 Table 1 & §5.3.6):
        - **Digital Signature Keys**: Private signing keys typically originator cryptoperiod 1 to 3 years; public signature verification keys may be retained longer to verify archived signed data.
        - **Key Establishment Keys**: Static key-agreement pairs typically originator cryptoperiod up to 1 to 2 years; ephemeral pairs used for single key-agreement transaction.
- **Usage-Based Rotation Limits**: Rotation must account for usage volume besides calendar time. E.g. Advanced Encryption Standard in Galois/Counter Mode (AES-GCM) with random 96-bit initialization vectors (IVs): limit each key to at most `2^32` (4,294,967,296) encryption operations across all devices sharing key, limiting IV-collision risk (NIST SP 800-38D §8.3).
- **Handling Existing Encrypted Data (Envelope Encryption)**: To retire Key Encryption Key (KEK), re-wrap stored Data Encryption Keys (DEKs) under replacement KEK before destroying old one. Rewrapping leaves DEKs unchanged, doesn't reset their cryptoperiods or usage limits. Replacing DEK for existing ciphertext requires re-encrypting that data. Managed services may retain old wrapping-key versions automatically; check provider's rotation behavior. Key IDs + data-migration choices: [Cryptographic Storage Cheat Sheet](Cryptographic_Storage.md#key-lifetimes-and-rotation).
- **Automated Rotation**: Prefer automated rotation via Key Management Services (KMS) or automated certificate management protocols (e.g. Automated Certificate Management Environment (ACME)) to reduce operational error, ensure timely updates.
- **Manual Rotation Logging**: Manual rotation required → log rotation events with timestamp, operator identity, management authorization reference.

### Escrow and Backup

Data encrypted with lost keys never recovered. Application must incorporate secure key backup capability, esp. for data-at-rest encryption of long-term data stores.

Backing up keys: encrypt key-storage database using at least `FIPS 140-2 or 140-3` validated module. Sometimes useful to escrow key material for investigations and re-provisioning to users when key lost/corrupted.

Never escrow keys used for digital signatures; consider need to escrow encryption keys. Escrow often performed by Certificate Authority (CA) or key management system provisioning certificates/keys; sometimes separate APIs must be implemented so system can escrow for application.

### Accountability and Audit

Accountability = identifying those with access to/control of keys throughout lifecycles. Helps prevent compromises, reduces impact once detected.

Enforce least privilege for all key and secret assets (OWASP ASVS 5.0 §13.3.2). Restrict access to keys, key management interfaces, secret material strictly to authorized roles, services, workloads with verified operational need.

Preferably no humans can view keys; minimum: key management system accounts for all individuals able to view plaintext keys.

More sophisticated systems may account for all individuals authorized to access/control any keys, plaintext or ciphertext.

Accountability gives three advantages:

1. Helps determine when compromise could have occurred, which individuals involved.
2. Tends to protect against compromise: individuals know their access is known.
3. Very useful recovering from detected compromise: know where key used, what data/other keys it protected.

Principles useful for enforcing accountability; may not apply to all systems/key types.

Principles for long-term keys controlled by humans:

1. Uniquely identifying keys.
2. Identifying key user.
3. Identifying dates/times of key use, along with protected data.
4. Identifying other keys protected by a symmetric or private key.

Two audit types for key management systems:

1. Periodically audit security plan + supporting procedures to ensure continued support of Key Management Policy (`NIST SP 800-57 Part 2`).
2. Periodically reassess protective mechanisms for level of security provided and expected in future, and that mechanisms correctly/effectively support appropriate policies.

Consider new technology developments + attacks. More frequently, review actions of humans using, operating, maintaining system to verify they follow established security procedures.

Strong cryptographic systems can be compromised by lax/inappropriate human actions. Note + review highly unusual events as possible indicators of attempted attacks.

### Key Compromise and Recovery

Implications of key compromise:

1. Unauthorized disclosure of confidentiality key (encryption) → all information encrypted by it could be exposed to unauthorized entities. Disclosure of Certificate of Authorities's private signature key → adversary creates fraudulent certificates and Certificate Revocation Lists (CRLs).
2. Compromised key integrity = key incorrect: modified (deliberately or accidentally), or another key substituted; incl. deletion (non-availability). Substitution/modification of integrity key calls into question integrity of all information it protects; info could have been provided/changed by unauthorized entity knowing key. Substituting public or secret key later used to encrypt data could let unauthorized entity (knowing decryption key) decrypt data encrypted with encryption key.
3. Compromised key usage/application association → key could be used for wrong purpose (e.g., key establishment instead of digital signatures) or wrong application; could compromise information protected by key.
4. Compromised association with owner/other entity → identity of other entity can't be assured (unknown who they really are) or info can't be processed correctly (e.g., decrypted with correct key).
5. Compromised association with other information → no association at all, or association with wrong "information". Could cause cryptographic services to fail, information lost, or information security compromised. Certain protective measures may minimize likelihood/consequences of compromise. Similar effect as ransomware, except can't pay ransom and get key back.

Procedures usually involved:

1. Limiting time symmetric/private key is in plaintext.
2. Preventing humans viewing plaintext symmetric + private keys.
3. Restricting plaintext symmetric + private keys to physically protected containers: key generators, key-transport devices, key loaders, cryptographic modules, key-storage devices.
4. Integrity checks ensuring key or its association with other data not compromised. E.g. wrap (encrypt) keys so unauthorized modifications to wrapping or associations are detected.
5. Key confirmation (see NIST SP 800-57 Part 1 Section 4.2.5.5) to help ensure proper key was established.
6. Accountability system tracking each access to symmetric + private keys in plaintext.
7. Cryptographic integrity check on key (e.g., MAC or digital signature).
8. Trusted timestamps for signed data. i. Destroying keys as soon as no longer needed.
9. Compromise-recovery plan, esp. for CA compromise.

Compromise-recovery plan essential for restoring cryptographic security services after key compromise. Shall be documented and easily accessible.

Plan should contain:

1. Identification + contact info of personnel to notify.
2. Identification + contact info of personnel performing recovery actions.
3. Re-key method.
4. Inventory of all keys and their use (e.g., location of all certificates in system).
5. Education of all appropriate personnel on recovery procedures.
6. Identification + contact info of all personnel needed to support recovery procedures.
7. Policies enforcing key-revocation checking (minimize compromise effect).
8. Monitoring of re-keying operations (ensure all required operations performed for all affected keys).
9. Any other recovery procedures, may include:
    1. Physical inspection of equipment.
    2. Identification of all information possibly compromised by incident.
    3. Identification of all signatures possibly invalid due to signing key compromise.
    4. Distribution of new keying material, if required.

### Zeroization and Destruction

Destruction = final state in key lifecycle. Key management policies should account for lifecycle key states in NIST SP 800-57 Part 1 Rev. 5 Section 7 (pre-activation, active, suspended, deactivated, compromised, destroyed).

Revoke compromised keys promptly; stop using them to protect new data. Retain only tightly controlled access needed for recovery/migration of previously protected data. Destroy all copies of secret + private keys (backup, archived, escrowed, memory copies) as soon as no longer needed for decryption/recovery and retention requirements satisfied. Public verification keys may be retained to verify archived signatures (NIST SP 800-57 Part 1 Rev. 5 Sections 7.5 and 8.3.4–8.3.5).

- **Cryptographic Erasure**: For encrypted key material at rest, consider cryptographic erasure only when all copies of protecting keys can be destroyed and no recoverable plaintext copies of target material remain (NIST SP 800-88 Rev. 2 Section 3.2). Destroying wrapping key doesn't erase plaintext copies of keys it protected.
- **Software Memory**: Overwriting key material is best-effort in managed runtimes: copies can survive in garbage-collected memory, immutable strings, swapped-out pages. Use platform secure-memory/zeroization APIs where available; see [Protecting Secrets in Memory](Secrets_Management.md#25-handling-secrets-in-memory).
- **Hardware Security Modules (HSMs)**: Use vendor-supplied zeroize/destroy commands for key material in volatile memory and non-volatile HSM storage.
- **Physical Media**: Physically destroy obsolete storage media/cryptographic tokens containing key material per organizational sanitization standards.

## Trust Stores

1. Design controls securing trust store against injection of third-party root certificates. Access controls managed + enforced per entity and application.
2. Implement integrity controls on objects in trust store.
3. No export of keys held in trust store without authentication + authorization.
4. Strict policies/procedures for exporting key material from applications to network applications and other components.
5. Secure process for updating trust store.

## Cryptographic Key Management Libraries

Use only reputable crypto libraries, well maintained/updated, tested + validated by third-party organizations (e.g., `NIST`/`FIPS`).

## References

- NIST SP 800-57 Part 1 Rev. 5: Recommendation for Key Management
- NIST SP 800-38D: Galois/Counter Mode (GCM) and GMAC
- NIST SP 800-88 Rev. 2: Guidelines for Media Sanitization
