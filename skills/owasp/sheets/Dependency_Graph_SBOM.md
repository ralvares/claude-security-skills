# Dependency Graph & SBOM Best Practices Cheat Sheet

## Introduction

SBOM = inventory of software components; dependency graph = their relationships. Use both to locate vulnerable components in releases/deployments. See CycloneDX SBOM guide.

## Capture components and relationships

Use standard machine-readable format e.g. CycloneDX. Capture:

- Component names, versions, suppliers, package identifiers, hashes where available.
- Direct + transitive dependency relationships (used directly vs brought in by other components).
- Product described, SBOM author, generation time, generator identity/version.

Record incomplete/unknown coverage explicitly. Component missing from SBOM ≠ evidence absent from software. CycloneDX guide covers metadata + completeness declarations.

## Generate for each release

Automate generation after dependency resolution; reconcile inventory w/ final package or container image. Include bundled libraries + OS packages where applicable; manifests alone can misrepresent shipped contents. Record generation scope + known gaps. CycloneDX generation guidance: compare build artifacts w/ SBOM, correct discrepancies.

Validate document against format schema before publication/ingestion; separately check metadata + relationships above. Passing checks ≠ inventory completeness.

Keep each release's inventory distinct. Pipeline hardening: [CI/CD Security Cheat Sheet](CI_CD_Security.md).

## Bind and verify release evidence

Bind SBOM to final artifact's cryptographic digest via signed attestation (signed statement identifying artifact + its SBOM). Signing artifact and SBOM separately does not establish that relationship. SBOM attestation describes inventory; build provenance separately records how artifact was produced.

Model on SLSA provenance verification checks to verify release evidence before install/deploy: validate signatures, allowed signer identities, artifact digest, expected attestation type. Build provenance: also check expected builder identity, source repository, build type, parameters. Reject missing, invalid, unexpected evidence when trust policy requires.

Valid signatures authenticate claims + protect integrity. They do not prove SBOM accurate/complete, software safe, or trusted builder uncompromised.

Preserve original SBOMs + signed evidence alongside each release, even when importing inventory into another system. Restrict write access; limit sharing of sensitive metadata. CISA SBOM consumption guidance covers validation + original-document retention. Broader controls: [Software Supply Chain Security Cheat Sheet](Software_Supply_Chain_Security.md).

## Use inventory for vulnerability response

Map release SBOMs to deployed systems; reassess components when new advisories arrive. Prioritize direct + transitive dependencies by exploitability, exposure, impact; dependency depth alone does not determine risk. Use graph to identify which parent dependency brings in affected component.

Vulnerability Exploitability eXchange (VEX) documents state whether vulnerability affects a particular product. Before accepting "not affected" claim: authenticate issuer, verify document integrity, assess justification against exact product version + deployment conditions. CISA consumption guidance: check VEX veracity, reassess risk over time.

Select/verify remediation w/ [Vulnerable Dependency Management Cheat Sheet](Vulnerable_Dependency_Management.md). After rebuild, compare new SBOM w/ previous release; update deployment mappings. Updated inventory alone ≠ proof vulnerability fixed or mitigations work.

## References

- OWASP CycloneDX: Authoritative Guide to SBOM
- CISA: Recommended Practices for Software Bill of Materials Consumption
