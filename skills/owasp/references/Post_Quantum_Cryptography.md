# Post-Quantum Cryptography Cheat Sheet

## Introduction

Post-quantum cryptography (PQC): algorithms resisting classical and quantum attacks. Sufficiently powerful quantum computer could break RSA, Diffie-Hellman, elliptic curve crypto (RFC 9794 section 1) → public-key encryption, key exchange, digital signatures affected. Sheet turns NCSC PQC migration planning into stages for app developers: inventory dependencies, prioritize, adopt supported implementations, test, roll out. Start preparation stages even if dependency cannot yet migrate.

## Stage 1: Inventory cryptographic dependencies

Create cryptographic inventory (NIST NCCoE): one entry per crypto use. Include platform/service-provider-managed dependencies, not just direct app code calls.

| Record | Include |
| --- | --- |
| Purpose and lifetime | Transport, stored data, key protection, signatures; how long confidentiality/trust must last. |
| Implementation | Protocol, algorithms + parameters, library/service version, key + certificate identifiers. Store metadata, never secret key material. |
| Dependencies | Clients, servers, proxies, signing + verification services, key management services, HSMs, backups. |
| Ownership | Responsible team/supplier, supported upgrade path, components that cannot be updated. |

- Map each transport connection separately, incl. gateway → application.
- Trace how stored-data encryption keys are protected and recovered.
- Inventory signature verifiers as well as signers.

**Complete when:** each dependency has owner + identified migration path or recorded blocker.

## Stage 2: Prioritize migration work

Prioritize data needing confidentiality for years and systems hard to update later (NCSC migration planning guidance). Assign owner + target date per migration item.

- **Long-lived confidentiality:** prioritize exposed connections and stored data whose keys depend on RSA or elliptic curve crypto. Later encryption updates cannot protect copies adversary already collected.
- **Long-lived trust:** plan early for software/firmware verification, trust anchors, signed records trustworthy for years. Include time to update every verifier.
- **Blocked dependencies:** request supported release + migration plan from supplier. Record remaining exposure, review date, whether replacement necessary.

Prefer AES-256 for extra quantum security margin, per [Cryptographic Storage Cheat Sheet](Cryptographic_Storage.md#algorithms). Use secure encryption mode. AES-128 remains permitted: NIST PQC FAQ allows AES-128, AES-192, AES-256. Check public-key protection of encryption keys even when data uses AES.

**Complete when:** backlog separates confidentiality and signature work; explicit decisions for dependencies that cannot yet migrate.

## Stage 3: Adopt supported implementations

Upgrade maintained libraries/platform services to standardized-algorithm implementations. Select parameters via supported protocol + security requirements. Algorithm support alone ≠ protocol interoperability.

| Use case | Developer action |
| --- | --- |
| Key establishment | Use supported integration of Module-Lattice-Based Key-Encapsulation Mechanism, [ML-KEM (FIPS 203)](https://csrc.nist.gov/pubs/fips/203/final). Establishes shared secret for symmetric crypto; does not directly encrypt app data or authenticate peer. |
| Transport | Pilot supported classical + PQC hybrid exchange, e.g. [X25519MLKEM768](https://www.rfc-editor.org/rfc/rfc10024.html), per [Transport Layer Security (TLS) Cheat Sheet](Transport_Layer_Security.md#set-the-appropriate-diffie-hellman-groups). Keep certificate + hostname validation enabled. |
| Signatures | Plan separate migration w/ supported signature format + verifier, e.g. Module-Lattice-Based Digital Signature Algorithm, [ML-DSA (FIPS 204)](https://csrc.nist.gov/pubs/fips/204/final). Coordinate signer + verifier upgrades; follow [JSON Web Token (JWT) guidance](JSON_Web_Token.md#public-key-signatures) for tokens. |
| Stored data | Use provider's supported migration process for public-key protection of data keys, incl. existing wrapped keys. Follow [key rotation and existing-data guidance](Key_Management.md#cryptoperiods-and-rotation); retain recovery access during migration. |

- Hybrid construction = classical + post-quantum algorithms combined. Use protocol's implementation; never build own combination. RFC 9794 section 5 distinguishes hybrid confidentiality from authentication: hybrid TLS key exchange does not make classical certificate signatures quantum-resistant.
- Supported dual-signature scheme requiring both signatures: enforce both verifications. Accepting either permits classical-only acceptance; NIST: dual-signature verification requires all component signatures succeed. Never append custom signature field to existing token/certificate format.
- Signed records needing long-term proof: validate them and preserve evidence via supported archive timestamp and renewal process (RFC 4998 section 1.1) before protecting algorithms weaken. Retaining old verifier alone does not preserve proof.

**Complete when:** supported migration works in test environment; team documented which security properties it provides.

## Stage 4: Test the full application path

Test w/ actual algorithms + parameter sets to deploy. NIST crypto agility guidance (CSWP 39-upd1, sections 3.2 and 6.2) flags larger crypto objects and protecting algorithm negotiation.

- Exercise real clients, proxies, gateways, backend connections. Verify negotiated key exchange for new connections. For resumed TLS sessions (RFC 9846 section 4.3.9), check resumption mode and how original connection + resumption secrets were protected.
- Measure handshake + verification costs under expected load. Check certificate, signature, message, database field limits. Keep size limits explicit when increasing.
- Test rejection of invalid signatures, untrusted certificates, disallowed algorithms. If both signatures required, missing or invalid signature must cause rejection.
- Decide where classical fallback temporarily allowed. Paths requiring PQC: verify failures cannot silently trigger classical-only retry.
- Test existing data, older signed artifacts, backup restoration, key recovery before retiring old keys/formats.

**Complete when:** compatibility, rejection behavior, recovery, rollback tests pass for intended deployment policy.

## Stage 5: Roll out and retire temporary exceptions

Deploy to small group of services/clients, expand using test + monitoring results. Keep approved rollback plan + explicit criteria for ending classical-only support (NCSC migration guidance).

- Record negotiated algorithms + verification outcomes w/o logging secrets. Alert on unexpected classical-only use and verification failures.
- Treat rollback to classical-only protection as security exception w/ owner + expiry date. Where PQC required, pause affected operation instead of silently weakening policy.
- Track library security updates + applicable standards. Remove temporary fallback only after required peers + recovery workflows migrated. Preserve required access to older data/signed records under explicit legacy policy. Once PQC verification required, restrict classical-only exceptions to identified legacy artifacts; never use them to accept new artifacts.

**Complete when:** required paths demonstrably use intended protection; remaining exceptions have owners + retirement dates. Keep inventory current as dependencies change.

## References

- NCSC: Timelines for migration to post-quantum cryptography
- NIST CSWP 39-upd1: Considerations for Achieving Crypto Agility
- RFC 9794: Terminology for Post-Quantum Traditional Hybrid Schemes
