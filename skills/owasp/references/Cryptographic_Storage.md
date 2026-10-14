# Cryptographic Storage Cheat Sheet

## Introduction

Simple model for protecting data at rest.

Passwords: no reversible encryption; use secure password hashing algorithms. See [Password Storage Cheat Sheet](Password_Storage.md).

## Architectural Design

Consider overall system architecture first; big impact on technical implementation.

Start w/ application [threat model](Threat_Modeling.md) (i.e, who you protect data against).

Dedicated secret/key management systems add protection layer + ease secrets management, but cost extra complexity + admin overhead; may be infeasible for some apps. Many cloud environments provide these; use where possible. See [Secrets Management Cheat Sheet](Secrets_Management.md).

### Where to Perform Encryption

Encryption levels in app stack:

- Application level.
- Database level (e.g, SQL Server TDE)
- Filesystem level (e.g, BitLocker or LUKS)
- Hardware level (e.g, encrypted RAID cards or SSDs)

Appropriate layer(s) depend on threat model. E.g., hardware level encryption protects vs physical server theft, none if attacker compromises server remotely.

### Minimize the Storage of Sensitive Information

Best protection: don't store sensitive information. Applies to all info, most often credit card details (highly desirable to attackers; PCI DSS has stringent storage requirements). Avoid storing sensitive information wherever possible.

## Algorithms

Symmetric encryption: preferred **AES** w/ key at least **128 bits** (ideally **256 bits**) and secure [mode](#cipher-modes).

Public-key encryption: use maintained library implementing established hybrid encryption scheme e.g. Hybrid Public Key Encryption (HPKE) (combines key establishment, key derivation, authenticated symmetric encryption). **X25519 on Curve25519** = key-agreement primitive; does not encrypt stored data itself. Select appropriate HPKE authentication mode if sender authentication required; base mode does not authenticate sender.

If **RSA** must be used, key at least **2048 bits**.

### Post-Quantum Consideration

RSA and ECC-based public-key crypto (incl. Curve25519) not post-quantum secure. Future cryptographically relevant quantum computer could break them; matters for data confidential over long periods.

Where post-quantum key establishment required, use supported protocol/library integration of standardized mechanism e.g. **ML-KEM (NIST FIPS 203)**, typically hybrid w/ classical algorithm during migration. ML-KEM establishes shared secret for symmetric encryption; does not replace AES for encrypting stored data. Include public-key protection of stored encryption keys in migration plan.

Migration guidance: [Post-Quantum Cryptography Cheat Sheet](Post_Quantum_Cryptography.md).

Algorithm selection criteria:

- Key size.
- Known attacks + weaknesses.
- Maturity.
- Third-party approval e.g. NIST's algorithmic validation program.
- Performance (encryption + decryption).
- Quality of available libraries.
- Portability (i.e, how widely supported).

Regulatory requirements may limit algorithms, e.g. FIPS 140-3 or PCI DSS.

### Custom Algorithms

Don't.

### Cipher Modes

[Modes](https://en.wikipedia.org/wiki/Block_cipher_mode_of_operation) let block ciphers (e.g. AES) encrypt arbitrary amounts of data like stream cipher. Differ in security/performance; full discussion out of scope. Some need secure initialization vectors (IVs) and other attributes; library should handle automatically.

Use authenticated modes always where available: guarantee integrity + authenticity plus confidentiality. Most common: **GCM** and **CCM**; first preference.

If GCM/CCM unavailable, use CTR or CBC. These give no authenticity guarantees; implement separate authentication e.g. Encrypt-then-MAC. Care w/ variable length messages.

ECB: not outside very specific circumstances.

### Random Padding

RSA encryption: use maintained library's RSAES-OAEP (Optimal Asymmetric Encryption Padding) implementation per RFC 8017, Section 7.1. OAEP uses randomized encoding + mask generation functions; prepending random bytes to message is no substitute. Never use RSA without encryption padding scheme.

### Secure Random Number Generation

Random numbers/strings needed for security critical functionality e.g. encryption keys, IVs, session IDs, CSRF tokens, password reset tokens. Generate securely; attacker must not guess/predict.

Computers generally can't generate truly random numbers (w/o special hardware); systems/languages provide two types.

Pseudo-Random Number Generators (PRNG): low-quality randomness, much faster; OK for non-security functionality (e.g. ordering results, randomizing UI elements). **Must not** be used for anything security critical; attackers often can guess/predict output.

Cryptographically Secure PRNGs (CSPRNG): much higher quality (more entropy); safe for security-sensitive functionality. Slower, more CPU intensive, can block when large amounts of random data requested. May be inappropriate for large amounts of non-security randomness.

Recommended algorithms per language + insecure functions to avoid:

| Language    | Unsafe Functions                                                                                                                   | Cryptographically Secure Functions                                                                                                                                                                                                                                                                                                                                         |
|-------------|------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| C           | `random()`, `rand()`                                                                                                               | getrandom(2) |
| Java        | `Math.random()`, `StrictMath.random()`, `java.util.Random`, `java.util.SplittableRandom`, `java.util.concurrent.ThreadLocalRandom` | java.security.SecureRandom, java.util.UUID.randomUUID() |
| PHP         | `array_rand()`, `lcg_value()`, `mt_rand()`, `rand()`, `uniqid()`                                                                   | Random\Engine\Secure in PHP 8.2, random_bytes(), random_int() in PHP 7, openssl_random_pseudo_bytes() in PHP 5 |
| .NET/C#     | `Random()`                                                                                                                         | RandomNumberGenerator |
| Objective-C | Subclasses of `GKRandomSource`, `rand()`, `random()` | SecRandomCopyBytes, `arc4random` family on current Apple platforms |
| Python      | `random()`                                                                                                                         | secrets() |
| Ruby        | `rand()`, `Random`                                                                                                                 | SecureRandom |
| Go          | `rand` using `math/rand` package                                                                                                   | crypto.rand package |
| Rust        | `rand::prng::XorShiftRng`                                                                                                          | rand::prng::chacha::ChaChaRng and rest of Rust library CSPRNGs. |
| Node.js     | `Math.random()`                                                                                                                    | crypto.randomBytes(), crypto.randomInt(), crypto.randomUUID() |

#### UUIDs and GUIDs

UUIDs/GUIDs sometimes used as quick random strings. Randomness depends on UUID [type or version](https://en.wikipedia.org/wiki/Universally_unique_identifier#Versions).

Version 1 UUIDs = high precision timestamp + generating system's MAC address → **not random** (may be hard to guess, timestamp to nearest 100ns). Type 4 UUIDs randomly generated; whether via CSPRNG depends on implementation. Don't rely on UUID randomness unless known secure in specific language/framework.

### Defense in Depth

Design app to stay secure even if cryptographic controls fail. Protect encrypted info w/ additional security layers. Don't rely on security of encrypted URL parameters; enforce strong access control against unauthorized access.

## Key Management

### Processes

Implement (and test) formal processes for all key management aspects, incl.:

- Generating + storing new keys.
- Distributing keys to required parties.
- Deploying keys to application servers.
- Rotating + decommissioning old keys

### Key Generation

Generate keys randomly w/ cryptographically secure function, e.g. those in [Secure Random Number Generation](#secure-random-number-generation). Keys **should not** be based on common words/phrases or "random" characters from mashing keyboard.

Multiple keys (e.g. separate data-encrypting and key-encrypting keys): fully independent from each other.

### Key Lifetimes and Rotation

Change (rotate) encryption keys per criteria:

- Previous key known (or suspected) compromised.
    - Also when someone with key access leaves organization.
- Specified time elapsed (cryptoperiod).
    - Appropriate cryptoperiod depends on key size, data sensitivity, system threat model. See section 5.3 of NIST SP 800-57 Part 1 Rev. 5.
- Before reaching usage limits of selected encryption mode.
    - Enforce mode's limits on message size, encryption operations, initialization vector (IV) uniqueness across all instances sharing key. Block size alone doesn't determine safe data-volume limit. E.g., AES-GCM has separate requirements for input lengths + IV construction in NIST SP 800-38D, Sections 5.2.1.1 and 8. Usage-based rotation: [Key Management: Cryptoperiods and Rotation](Key_Management.md#cryptoperiods-and-rotation).
- Significant change to algorithm's security (e.g. new attack announced).

Once criterion met, generate new key; use for encrypting new data. Two approaches for existing data encrypted w/ old key(s):

1. Decrypt + re-encrypt w/ new key.
2. Mark each item w/ ID of key used to encrypt; store multiple keys to decrypt old data.

Prefer first option generally: greatly simplifies application code + key management; may not always be feasible. Store old keys generally for certain period after retirement, in case old backups/copies need decrypting.

Have code + processes for key rotation in place **before** needed, so keys rotate quickly on compromise. Also implement processes to change encryption algorithm/library if new vulnerability found.

## Key Storage

Secure key storage = one of hardest problems; app always needs some key access to decrypt data. May not fully protect keys from attacker who fully compromised app, but steps make obtaining keys harder.

Use secure storage mechanisms from OS, framework, or cloud provider where available:

- Physical Hardware Security Module (HSM).
- Virtual HSM.
- Key vaults e.g. Amazon KMS or Azure Key Vault.
- External secrets management service e.g. Conjur or HashiCorp Vault.
- Secure storage APIs: ProtectedData class in .NET framework.

Advantages over keys in configuration files (vary by solution):

- Central key management, esp. containerised environments.
- Easy key rotation + replacement.
- Secure key generation.
- Simpler compliance w/ regulatory standards e.g. FIPS 140 or PCI DSS.
- Harder for attacker to export/steal keys.

Sometimes none available (e.g. shared hosting) → no high protection for keys. Still follow basic rules:

- Don't hard-code keys in source code.
- Don't check keys into version control.
- Protect configuration files containing keys w/ restrictive permissions.
- Avoid keys in environment variables; accidentally exposed via functions like phpinfo() or `/proc/self/environ` file.

More: [Secrets Management Cheat Sheet](Secrets_Management.md).

### Separation of Keys and Data

Store encryption keys separately from encrypted data where possible. E.g., data in database → keys in filesystem. Attacker with access to only one (e.g. directory traversal or SQL injection) can't access both.

Architecture permitting, store keys and data on separate systems for greater isolation.

### Encrypting Stored Keys

Store keys themselves encrypted where possible. Needs at least two separate keys:

- Data Encryption Key (DEK) encrypts data.
- Key Encryption Key (KEK) encrypts DEK.

Effective only if KEK stored separately from DEK. Encrypted DEK can be stored w/ data; usable only if attacker also obtains KEK from another system.

KEK should be at least as strong as DEK. Google's envelope encryption guidance details DEK/KEK management.

Simpler architectures (e.g. shared hosting) where KEK and DEK can't be stored separately: limited value, attacker likely obtains both at once; still extra barrier to unskilled attackers.

Key derivation function (KDF) can generate KEK from user-supplied input (e.g. passphrase), which encrypts randomly generated DEK. KEK easily changed (user changes passphrase) w/o re-encrypting data (DEK unchanged).

## References

- NIST SP 800-57 Part 1 Rev. 5: Recommendation for Key Management
- NIST FIPS 203: Module-Lattice-Based Key-Encapsulation Mechanism Standard
- NIST: Post-Quantum Cryptography FAQ
