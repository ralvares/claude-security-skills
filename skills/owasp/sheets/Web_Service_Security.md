# Web Service Security Cheat Sheet

## Introduction

Guidance for securing web services, preventing web-service-related attacks. High level; frameworks implement differently.

## Transport Confidentiality

Protects web service communications to/from server against eavesdropping and man-in-the-middle.

**Rule**: All communication with/between web services containing sensitive features, authenticated session, or sensitive data transfer MUST be encrypted w/ well-configured TLS. Recommended even if messages themselves encrypted: TLS adds integrity protection, replay defenses, server authentication. See [Transport Layer Security Cheat Sheet](Transport_Layer_Security.md).

## Server Authentication

**Rule**: TLS MUST authenticate service provider to service consumer. Consumer SHOULD verify server certificate issued by trusted provider, not expired, not revoked, matches service domain name, and server proved private key ownership for public key certificate (properly signing something or successfully decrypting something encrypted w/ public key).

## User Authentication

Verifies identity of user/system connecting to service. Usually function of web service container.

**Rule**: Basic Authentication, if used, MUST run over TLS; not recommended (discloses secrets in plain text, base64 encoded, in HTTP Headers).

**Rule**: Client Certificate Authentication via Mutual-TLS = common form, recommended where appropriate. See [Authentication Cheat Sheet](Authentication.md).

## Transport Encoding

SOAP encoding styles move data between software objects and XML.

**Rule**: Enforce same encoding style between client and server.

## Message Integrity

Concerns data at rest. Integrity in transit easily provided by TLS.

Public key cryptography: encryption guarantees confidentiality, not integrity (receiver's public key is public). Same reason: encryption doesn't ensure sender identity.

**Rule**: XML data: use XML digital signatures for message integrity w/ sender's private key. Recipient validates w/ sender's digital certificate (public key).

## Message Confidentiality

Confidential data elements MUST be encrypted w/ strong cipher, adequate key length to deter brute-forcing.

**Rule**: Messages w/ sensitive data MUST be encrypted w/ strong cipher. Transport encryption or message encryption.

**Rule**: Messages w/ sensitive data that must stay encrypted at rest after receipt MUST use strong data encryption, not just transport encryption.

## Authorization

Authorize web service clients like web apps authorize users: client authorized for certain action (coarse-grained) on requested data (fine-grained).

**Rule**: Service SHOULD authorize clients for method in question. After authentication challenge, check requesting entity's privileges for requested resource. Do on every request; add challenge-response Authorization mechanism to sensitive resources: password changes, primary contact details such as email, physical address, payment or delivery instructions.

**Rule**: Limit access to administration/management functions to web service administrators. Ideally admin capabilities in application completely separate from managed web services, separating normal users from sensitive functions.

## Schema Validation

Enforces constraints and syntax defined by schema.

**Rule**: Web services MUST validate SOAP payloads against associated XML schema definition (XSD).

**Rule**: XSD for SOAP web service SHOULD at minimum define max length and character set of every parameter passing into/out of service.

**Rule**: XSD for SOAP web service SHOULD define strong (ideally allow-list) validation patterns for all fixed format parameters (e.g., zip codes, phone numbers, list values).

## Content Validation

**Rule**: Validate input before consuming, like any web app. XML input content validation includes:

- Validation against malformed XML entities.
- Validation against XML Bomb attacks.
- Validating inputs using strong allowlist.
- Validating against external entity attacks.

## Output Encoding

Encode output sent to clients so it's consumed as data, not scripts. Important when clients render HTML from output, directly or indirectly via AJAX objects.

**Rule**: All output encoding rules per [Cross Site Scripting Prevention Cheat Sheet](Cross_Site_Scripting_Prevention.md) apply.

## Virus Protection

SOAP can attach files/documents to messages → attackers can attach viruses and malware.

**Rule**: Install Virus Scanning technology, preferably inline, so files/attachments checked before saved to disk.

**Rule**: Regularly update Virus Scanning technology w/ latest virus definitions/rules.

## Message Size

Web services can be DOS targets: automatically sending thousands of large SOAP messages cripples app (can't respond to legitimate messages) or takes it down.

**Rule**: Limit SOAP message size to appropriate limit. Larger limit (or none) raises DoS success chance.

## Availability

### Resources Limiting

Normal operation needs CPU cycles and memory. Malfunction or attack → service may require too much, destabilizing host.

**Rule**: Limit CPU cycles per expected service rate for stable system.

**Rule**: Limit memory to avoid host running out of memory (host may start killing processes to free memory).

**Rule**: Limit number of simultaneous open files, network connections, started processes.

### Message Throughput

Throughput = number of requests served in given time.

**Rule**: Enforce request-rate and execution-time limits from tested service capacity and per-operation cost. Stricter limits for expensive operations, per OWASP's resource-consumption guidance. Maximizing throughput alone doesn't prevent resource exhaustion.

### XML Denial of Service Protection

XML Denial of Service = probably most serious attack on web services. Service MUST provide validation:

**Rule**: Validation against recursive payloads.

**Rule**: Validation against oversized payloads.

**Rule**: Protection against XML entity expansion.

**Rule**: Reject XML element names exceeding configured length limits. SOAP action identifiers separate from XML element names; e.g., SOAP 1.2 Action feature uses URI value that can guide message dispatch/routing.

Protection should come from XML parser/schema validator. Verify w/ test cases that parser resists these attacks.

## Endpoint Security Profile

**Rule**: Treat Web Services Interoperability (WS-I) Basic Profile conformance as interoperability requirement, not security baseline. Its security section permits conformant services without security countermeasures. Independently enforce transport security, authentication, authorization, resource limits above.

## References

- NIST SP 800-95: Guide to Secure Web Services
- W3C XML Encryption Syntax and Processing Version 1.1
