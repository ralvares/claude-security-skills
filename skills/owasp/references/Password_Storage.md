# Password Storage Cheat Sheet

## Introduction

Proper methods for storing passwords for authentication. Stored passwords must stay protected even if app or database compromised. Most modern languages/frameworks provide built-in functionality for safe storage.

Never store passwords in plain text. Protect with strong, slow hashing algorithms: Argon2id, bcrypt, PBKDF2. Add unique salt per password → defeats precomputed lookup tables (rainbow tables). Fast hashes such as SHA‑256 unsuitable: attackers guess quickly. Slow, memory‑hard algorithms make brute‑force harder, costlier, slower.

Summary:

- **Use [Argon2id](#argon2id) with minimum configuration of 19 MiB memory, iteration count of 2, 1 degree of parallelism.**
- **If [Argon2id](#argon2id) unavailable, use [scrypt](#scrypt) with minimum CPU/memory cost parameter (2^17), minimum block size 8 (1024 bytes), parallelization parameter 1.**
- **Legacy systems using [bcrypt](#bcrypt): work factor 10 or more, password limit 72 bytes.**
- **FIPS-140 compliance required: [PBKDF2](#pbkdf2) with work factor 600,000 or more, internal hash function HMAC-SHA-256.**
- **Consider [pepper](#peppering) for defense in depth (alone, adds no secure characteristics).**

## Background

### Hashing vs Encryption

**Passwords should be securely hashed with modern, adaptive hashing algorithms (e.g., Argon2id, bcrypt, PBKDF2), not encrypted or stored in plaintext**, in almost all circumstances.

**Hashing = one-way function** (impossible to "decrypt" hash to original plaintext) → most appropriate for password validation. Attacker with hashed password cannot log in as victim.

**Encryption = two-way**: attackers can retrieve plaintext from encrypted data. Suits data like user's address, shown plaintext on profile. Hashing address → garbled mess.

Encrypt passwords only in edge cases needing original plaintext, e.g. app must use password to authenticate with other system lacking modern programmatic access grant such as OpenID Connect (OIDC). Wherever possible use alternative architecture avoiding encrypted password storage.

Encryption guidance: [Cryptographic Storage Cheat Sheet](Cryptographic_Storage.md).

### When Password Hashes Can Be Cracked

**Strong passwords stored with modern hashing algorithms + best practices should be effectively impossible to crack.** App owner responsible for selecting modern hashing algorithm.

Attackers can still "crack" hashes in some circumstances by:

- Selecting password victim might have chosen (e.g.`password1!`)
- Calculating hash
- Comparing to victim's hash. Match → plaintext password known.

Usually repeated over large candidate lists:

- Passwords from other compromised sites
- Brute force (every possible candidate)
- Dictionaries/wordlists of common passwords

Permutations enormous, but high-speed hardware (GPUs) and rentable cloud servers make cracking cost relatively small, esp. when hashing best practices not followed.

## Methods for Enhancing Password Storage

### Salting

Salt = unique, randomly generated string added to each password during hashing. Unique per user → attacker cracks hashes one at a time with respective salt, not hash once and compare against all stored hashes. Time required grows in direct proportion to number of hashes.

Also defeats pre-computed hashes via rainbow tables or database lookups. Also: impossible to tell whether two users share password without cracking, since different salts → different hashes.

Modern password hashing functions ([Argon2id](#argon2id), [bcrypt](#bcrypt), [PBKDF2](#pbkdf2)) require caller to provide salt at algorithm/spec level. Most widely used implementations/libraries auto-generate and manage salts internally; developers typically need not handle salt generation manually when using libraries correctly.

### Peppering

Peppering (IETF kitten password-storage draft section 4.2) = class of strategies used in addition to salting. Prevents attacker with only database access (e.g. SQL injection, database backup) from cracking any hashes.

#### Common requirements for peppering strategies

- Pepper **shared between stored passwords**, not *unique* per password like salt.
- Unlike salt, pepper not public and **not stored along with generated hash**. Store separately from password database.
- Peppers = secrets; store in "secrets vaults" or HSMs (Hardware Security Modules). See [Secrets Management Cheat Sheet](Secrets_Management.md).
- Pepper compromise → pepper must change. Peppers cannot change without user's password → changing pepper requires forcing all users whose passwords used previous pepper to reset passwords.

#### Pre-hashing peppers

Pepper added to password before password hashing algorithm; computed hash stored in database. Pepper = securely generated random value. See [Cryptographic_Storage_Cheat_Sheet](Cryptographic_Storage.md#secure-random-number-generation) for secure random generation.

#### Post-hashing peppers

Password hashed as usual; resulting hash hashed again using HMAC (e.g., HMAC-SHA256, HMAC-SHA512, depending on desired output length) before storing. Pepper = HMAC key; generate per HMAC algorithm requirements.

### Using Work Factors

Work factor = number of hashing iterations per password (usually `2^work` iterations). Typically stored in hash output. Makes hash computation costlier → reduces attacker guess speed and/or raises cost.

Balance security vs performance. Higher work factor → harder cracking but slower login verification. Too high → app performance degrades; attacker can DoS by exhausting server CPU w/ many login attempts.

No golden rule; depends on server performance and user count. Determine optimal value by experimentation on app's server(s). General rule: hash calculation should take less than one second.

#### Upgrading the Work Factor

Work factor can increase over time as hardware gets more powerful/cheaper.

Common approach: wait until user next authenticates, then re-hash password with new work factor. Hashes then have different work factors; may never upgrade if user doesn't return. Depending on app, may remove older hashes and require password reset at next login to avoid storing older, less secure hashes.

## Password Hashing Algorithms

Some modern algorithms designed specifically for password storage: slow (unlike MD5, SHA-1, designed fast); slowness adjustable via work factor.

No need to hide which password hashing algorithm app uses. Modern algorithm with proper parameters → safe to state publicly (and be listed in Michal Spacek's password storage list).

Prefer modern algorithms resisting GPU-based and memory-based attacks. Choose newer algorithms for new apps; older algorithms may remain acceptable for legacy systems with appropriate configuration.

Three algorithms to consider.

### Argon2id

Argon2: winner of 2015 Password Hashing Competition. Of three Argon2 versions use Argon2id: balanced resistance to side-channel and GPU-based attacks.

Three main cost parameters: total memory in KiB (m), number of passes (t), degree of parallelism (p). Parallelism = number of lanes memory is divided over; increasing p does not multiply total memory or act as iteration count. Parameter definitions: RFC 9106 Section 3.1.

Tune memory + iteration costs to make cracking expensive while keeping authentication practical under expected load. Benchmark chosen parameters on target system (RFC 9106 section 4); increasing parallelism does not guarantee slower guessing. Use one of these minimum configurations:

- m=47104 (46 MiB), t=1, p=1 (Do not use with Argon2i)
- m=19456 (19 MiB), t=2, p=1 (Do not use with Argon2i)
- m=12288 (12 MiB), t=3, p=1
- m=9216 (9 MiB), t=4, p=1
- m=7168 (7 MiB), t=5, p=1

Equal defense level; only trade-off is CPU vs RAM usage.

### scrypt

scrypt: password-based key derivation function by Colin Percival. [Argon2id](#argon2id) best choice; use [scrypt](#scrypt) when Argon2id unavailable.

Like Argon2id, three parameters: minimum memory cost (N), blocksize (r), degree of parallelism (p). Use one of:

- N=2^17 (128 MiB), r=8 (1024 bytes), p=1
- N=2^16 (64 MiB), r=8 (1024 bytes), p=2
- N=2^15 (32 MiB), r=8 (1024 bytes), p=3
- N=2^14 (16 MiB), r=8 (1024 bytes), p=5
- N=2^13 (8 MiB), r=8 (1024 bytes), p=10

Similar minimal defense level; main trade-off parallelism vs RAM usage.

### bcrypt

bcrypt **only** for password storage in legacy systems where Argon2 and scrypt unavailable.

Work factor as large as verification server performance allows, minimum 10.

#### Input Limits of bcrypt

bcrypt max input length 72 bytes for most implementations → enforce max password length of 72 bytes (or less if implementation limit smaller).

#### Pre-Hashing Passwords with bcrypt

Alternative: pre-hash user password with fast algorithm (SHA-2, HMAC, BLAKE3), then bcrypt the hash (i.e., `bcrypt(H($password)), $salt, $cost)`).
**Dangerous**: null bytes in hash output and password shucking.

Original bcrypt expects null-terminated password string → hash value used only up to first null byte. (`bcrypt(H($password)), $salt, $cost) == bcrypt("", $salt, $cost)` if `H($password)[0] == 0`)
Raises collision chance when combining bcrypt with other hash functions; avoid by encoding hash to printable string e.g. base64.
base64 can push length above 72 characters → some truncation for large hashes like SHA-512; negligible.

Password shucking: easy to check `bcrypt(base64(H($password))), $salt, $cost) == bcrypt(base64($leaked_hash), $salt, $cost)`.
If inner hash `H` used with same password elsewhere and known to attacker, cracking reduces to breaking `H`.
Pure SHA-512 (i.e. `bcrypt(base64(sha512($password))), $salt, $cost)`) = **dangerous practice**, only as secure as pure SHA-512.
Shucking works only if leaked hash known to attacker (breach database or rainbow tables).
Mitigate with [pepper](#peppering).

Summary: if bcrypt must be used and password pre-hashed: `bcrypt(base64(hmac-sha384(data:$password, key:$pepper)), $salt, $cost)`; store pepper outside database.

### PBKDF2

PBKDF2 permitted by NIST SP 800-63B-4 and has FIPS-140 validated implementations → preferred algorithm when these required.

Requires internal hashing algorithm such as HMAC or other hashes. HMAC-SHA-256 widely supported, NIST-recommended.

Work factor = iteration count; set per internal hashing algorithm.

- PBKDF2-HMAC-SHA256: 600,000 iterations (recommended)
- PBKDF2-HMAC-SHA512: 220,000 iterations
- PBKDF2-HMAC-SHA1: 1,400,000 iterations — **legacy only**, do not select for new systems.

### Parallel PBKDF2

- PPBKDF2-SHA512: cost 2
- PPBKDF2-SHA256: cost 5
- PPBKDF2-SHA1: cost 10

Equivalent defense. (Numbers as of december 2022, based on testing of RTX 4000 GPUs, tobtu.com)

#### PBKDF2 Pre-Hashing

PBKDF2 with HMAC: password longer than hash function block size (64 bytes for SHA-256) auto pre-hashed. E.g. password "This is a password longer than 512 bits which is the block size of SHA-256" → hash (hex): `fa91498c139805af73f7ba275cca071e78d78675027000c99a9925e2ec92eedd`.

Good implementations pre-hash before expensive iterated phase. Some convert on each iteration → long passwords significantly costlier than short ones. Very long user passwords → potential DoS, e.g. Django vulnerability published 2013. Manual pre-hashing reduces risk but requires adding [salt](#salting) to pre-hash step.

## Upgrading Legacy Hashes

Apps using weak algorithms (MD5, SHA-1) can upgrade to modern ones. When user enters password (usually authenticating), re-hash input with new algorithm. Defenders should expire user's current password and require new one → older, weaker hashes useless to attacker.

Old hashes stay in database until user logs in. Two approaches:

Upgrade Method One: expire and delete password hashes of long-inactive users; require reset to log in. Secure but not user-friendly. Mass expiry may burden support staff or be read by users as breach indication.

Upgrade Method Two: use existing hashes as inputs for stronger algorithm. E.g. `md5($password)` → `bcrypt(md5($password))`. Layering needs no original password; can make hashes easier to crack. Replace with direct hashes of user passwords at next login.

Selected hashing method will need upgrading later → make upgrade easy. Allow mix of old and new algorithms during transition. Easier if algorithm + work factor stored with password in standard format, e.g. modular PHC string format.

### International Characters

Hashing library must accept wide range of characters, compatible with all Unicode codepoints, so users can use full character range of modern devices (esp. mobile keyboards): passwords from various languages, pictograms. Do not reduce entropy of user's entry before hashing; hashing libraries must handle input possibly containing NULL byte.

## References

- NIST SP 800-63B-4: Password Verifiers
- RFC 9106: Argon2 Inputs and Outputs
- RFC 7914: scrypt Parameters
