# Server-Side Request Forgery Prevention Cheat Sheet

## Introduction

Advice for protecting vs Server Side Request Forgery (SSRF).

Defensive view only; attack not explained. Attack techniques: [talk](../assets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet_Orange_Tsai_Talk.pdf) by researcher Orange Tsai, and [document](../assets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet_SSRF_Bible.pdf).

## Context

SSRF abuses application to interact with internal/external network or the machine itself. Enabler: URL mishandling, e.g.:

- Image on external server (*e.g.* user enters avatar image URL for application to download/use).
- Custom WebHook (users specify Webhook handlers or Callback URLs).
- Internal requests to another service for specific functionality. User data often sent along for processing; if poorly handled, enables specific injection attacks.

## Overview of a SSRF common flow

![SSRF Common Flow](../assets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet_SSRF_Common_Flow.png)

*Notes:*

- SSRF not limited to HTTP. First request generally HTTP, but when application itself makes second request, it could use other protocols (*e.g.* FTP, SMB, SMTP, etc.) and schemes (*e.g.* `file://`, `phar://`, `gopher://`, `data://`, `dict://`, etc.).
- Application vulnerable to XML eXternal Entity (XXE) injection can be exploited for SSRF attack; see [XXE cheat sheet](XML_External_Entity_Prevention.md) to prevent XXE exposure.

## Cases

By functionality/requirements, 2 basic SSRF cases:

- Application sends requests only to **identified and trusted applications**: allowlist approach available.
- Application sends requests to **ANY external IP address or domain name**: allowlist approach unavailable.

Very different cases → defenses described separately.

### Case 1 - Application can send request only to identified and trusted applications

Application sometimes requests another application, often on another network, for specific task. Per business case, user input required.

#### Example

 > Web application receives/uses user personal info (first name, last name, birth date etc.) to create profile in internal HR system. By design, web application communicates using protocol HR system understands.
 > User can't reach HR system directly, but if web application receiving user info is SSRF-vulnerable, user can use it to access HR system.
 > User leverages web application as proxy to HR system.

Allowlist viable: internal application called by *VulnerableApplication* clearly identified in technical/business flow; required calls only target identified and trusted applications.

#### Available protections

Protective measures at **Application** and **Network** layers. **Defense in depth**: harden both.

##### Application layer

First protection: [Input validation](Input_Validation.md).

How to validate? Per Orange Tsai's [talk](../assets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet_Orange_Tsai_Talk.pdf), parsers can be abused depending on language. Countermeasure: [allowlist approach](Input_Validation.md#allowlist-vs-denylist) when validating input; expected user info format usually globally known.

Request to internal application based on:

- String containing business data.
- IP address (V4 or V6).
- Domain name.
- URL.

**Note:** Disable redirection following in web client to prevent bypassing input validation (see `Exploitation tricks > Bypassing restrictions > Input validation > Unsafe redirect` in [document](../assets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet_SSRF_Bible.pdf)).

###### String

Validate input string matches expected business/technical format.

Regex OK for simple formats (*e.g.* token, zip code, etc.). Otherwise use `string` object library functions; regex for complex formats hard to maintain, highly error-prone.

User input assumed non-network related, consisting of user's personal info.

Example:

```java
//Regex validation for a data having a simple format
if(Pattern.matches("[a-zA-Z0-9\\s\\-]{1,50}", userInput)){
    //Continue the processing because the input data is valid
}else{
    //Stop the processing and reject the request
}
```

###### IP address

2 validations for SSRF:

1. Data is valid IP V4 or V6 address.
2. IP address belongs to one of identified and trusted applications' IPs.

First layer: libraries ensuring IP format security per technology (delegates format handling, leverages battle-tested validation):

> Proposed libraries verified for exposure to bypasses (Hex, Octal, Dword, URL and Mixed encoding) described in article by Vickie Li.

- **JAVA:** Method `InetAddressValidator.isValid` from Apache Commons Validator library.
    - **NOT exposed** to bypass using Hex, Octal, Dword, URL and Mixed encoding.
- **.NET**: Method `IPAddress.TryParse` from SDK.
    - **Exposed** to bypass using Hex, Octal, Dword and Mixed encoding but **NOT** URL encoding.
    - Allowlisting used here → any bypass attempt blocked at comparison vs allowed IP list.
- **JavaScript**: Library `ip-address`.
    - **NOT exposed** to bypass using Hex, Octal, Dword, URL and Mixed encoding.
- **Ruby**: Class `IPAddr` from SDK.
    - **NOT exposed** to bypass using Hex, Octal, Dword, URL and Mixed encoding.

> **Use method/library output value as IP address to compare against allowlist.**

After validity check, second layer: allowlist of all IP addresses (v4 and v6 to avoid bypasses) of identified and trusted applications. Cross-check valid IP vs list to permit communication with internal application (strict, case-sensitive string comparison).

###### Domain name

Validating domain names by DNS resolution to verify existence seems natural, generally fine, but opens application to attacks depending on DNS server configuration:

- Can disclose info to external DNS resolvers.
- Attacker can bind legit domain name to internal IP address (see `Exploitation tricks > Bypassing restrictions > Input validation > DNS pinning` in [document](../assets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet_SSRF_Bible.pdf)).
- Attacker can deliver malicious payload to internal DNS resolvers and the API (SDK or third-party) used for DNS communication, potentially triggering vulnerability in these components.

2 validations for SSRF:

1. Data is valid domain name.
2. Domain name belongs to identified and trusted applications' domain names (allowlisting).

Like IP validation, first layer: libraries ensuring domain name format security per technology (delegates format handling, battle tested):

> Proposed libraries verified to perform no DNS resolution query.

- **JAVA:** Method `DomainValidator.isValid` from Apache Commons Validator library.
- **.NET**: Method `Uri.CheckHostName` from SDK.
- **JavaScript**: Library `is-valid-domain`.
- **Python**: Module `validators.domain`.
- **Ruby**: No valid dedicated gem found.
    - domainator, public_suffix, addressable tested; all consider `<script>alert(1)</script>.owasp.org` valid domain name.
    - Usable regex (from StackOverflow): `^(((?!-))(xn--|_{1,1})?[a-z0-9-]{0,61}[a-z0-9]{1,1}\.)*(xn--)?([a-z0-9][a-z0-9\-]{0,60}|[a-z0-9-]{1,30}\.[a-z]{2,})$`

Example execution of proposed regex for Ruby:

```ruby
domain_names = ["owasp.org","owasp-test.org","doc-test.owasp.org","doc.owasp.org",
                "<script>alert(1)</script>","<script>alert(1)</script>.owasp.org"]
domain_names.each { |domain_name|
    if ( domain_name =~ /^(((?!-))(xn--|_{1,1})?[a-z0-9-]{0,61}[a-z0-9]{1,1}\.)*(xn--)?([a-z0-9][a-z0-9\-]{0,60}|[a-z0-9-]{1,30}\.[a-z]{2,})$/ )
        puts "[i] #{domain_name} is VALID"
    else
        puts "[!] #{domain_name} is INVALID"
    end
}
```

```bash
$ ruby test.rb
[i] owasp.org is VALID
[i] owasp-test.org is VALID
[i] doc-test.owasp.org is VALID
[i] doc.owasp.org is VALID
[!] <script>alert(1)</script> is INVALID
[!] <script>alert(1)</script>.owasp.org is INVALID
```

After validity check, second layer:

1. Build allowlist of all domain names of every identified and trusted application.
2. Verify received domain name is in allowlist (strict, case-sensitive string comparison).

Domain allowlisting alone doesn't prevent DNS rebinding. Validate resolved destination IP addresses vs application's permitted networks, then ensure HTTP client connects only to validated addresses. Second, unchecked DNS lookup between validation and connection can bypass checks; see GitLab's URL blocker guidance.

Use HTTP client mechanism connecting to validated IP while preserving original hostname for HTTP `Host` header, TLS Server Name Indication (SNI), certificate verification, as in curl's custom address resolution. Apply destination policy to retries and fallback connections too. DNS configuration/monitoring below = additional detection, not substitute for connection-time enforcement:

1. Domains of your organization resolved by internal DNS server first in DNS resolver chain.
2. Monitor domains allowlist to detect any resolving to:
   - Local IP address (V4 + V6).
   - Internal IP of your organization (expected in private IP ranges) for domains not part of your organization.

Python3 script as starting point for monitoring:

```python
# Dependencies: pip install ipaddress dnspython
import ipaddress
import dns.resolver

# Configure the allowlist to check
DOMAINS_ALLOWLIST = ["owasp.org", "labslinux"]

# Configure the DNS resolver to use for all DNS queries
DNS_RESOLVER = dns.resolver.Resolver()
DNS_RESOLVER.nameservers = ["1.1.1.1"]

def verify_dns_records(domain, records, type):
    """
    Verify if one of the DNS records resolve to a non public IP address.
    Return a boolean indicating if any error has been detected.
    """
    error_detected = False
    if records is not None:
        for record in records:
            value = record.to_text().strip()
            try:
                ip = ipaddress.ip_address(value)
                # See https://docs.python.org/3/library/ipaddress.html#ipaddress.IPv4Address.is_global
                if not ip.is_global:
                    print("[!] DNS record type '%s' for domain name '%s' resolve to
                    a non public IP address '%s'!" % (type, domain, value))
                    error_detected = True
            except ValueError:
                error_detected = True
                print("[!] '%s' is not valid IP address!" % value)
    return error_detected

def check():
    """
    Perform the check of the allowlist of domains.
    Return a boolean indicating if any error has been detected.
    """
    error_detected = False
    for domain in DOMAINS_ALLOWLIST:
        # Get the IPs of the current domain
        # See https://en.wikipedia.org/wiki/List_of_DNS_record_types
        try:
            # A = IPv4 address record
            ip_v4_records = DNS_RESOLVER.query(domain, "A")
        except Exception as e:
            ip_v4_records = None
            print("[i] Cannot get A record for domain '%s': %s\n" % (domain,e))
        try:
            # AAAA = IPv6 address record
            ip_v6_records = DNS_RESOLVER.query(domain, "AAAA")
        except Exception as e:
            ip_v6_records = None
            print("[i] Cannot get AAAA record for domain '%s': %s\n" % (domain,e))
        # Verify the IPs obtained
        if verify_dns_records(domain, ip_v4_records, "A")
        or verify_dns_records(domain, ip_v6_records, "AAAA"):
            error_detected = True
    return error_detected

if __name__== "__main__":
    if check():
        exit(1)
    else:
        exit(0)
```

###### URL

Don't accept complete URLs from user: hard to validate, parser can be abused depending on technology (see Orange Tsai [talk](../assets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet_Orange_Tsai_Talk.pdf)).

If network info truly needed, accept only valid IP address or domain name.

**Match host against allowlist, build request yourself.** Input here = IP address or domain name, not whole URL: compare it vs explicit [allowlist](Input_Validation.md#allowlist-vs-denylist) of permitted destinations, build request from matching entry plus scheme, port, path fixed by application. Host extracted from user-supplied URL: don't copy other URL components across either; carrying its path/query through, rather than rebuilding, hands next component something to parse again.

**Treat parser disagreement as rejection.** URL crossing service boundary as string and reparsed at other end: two implementations can read different hosts from same bytes. `http://example.com\@evil.com` is such a string: parser following WHATWG URL Standard treats backslash under special scheme as path separator, reads host `example.com`; `userinfo` grammar in RFC 3986 admits no backslash, so string isn't URI that RFC defines. Implementation not enforcing grammar still returns host, taking everything before final `@` as userinfo: CPython's `urllib.parse` derives host with `netloc.rpartition('@')`, so `urlsplit("http://example.com\@evil.com").hostname` returns `evil.com`. Reject URL whose host isn't read identically by every parser in play; don't reconcile readings.

##### Network layer

Goal: prevent *VulnerableApplication* calling arbitrary applications. Only allowed *routes* available, limiting network access to what it should communicate with.

Firewall component (specific device or OS-provided) defines legitimate flows.

Schema: Firewall limits application's access, limiting impact of SSRF-vulnerable application:

![Case 1 for Network layer protection about flows that we want to prevent](../assets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet_Case1_NetworkLayer_PreventFlow.png)

Network segregation (see implementation advice from Australian Cyber Security Centre) also usable, **highly recommended to block illegitimate calls directly at network level**.

### Case 2 - Application can send requests to ANY external IP address or domain name

Happens when user controls URL to **External** resource and application requests it (e.g. WebHooks). Allow lists unusable: IP/domain list often unknown upfront, dynamically changing.

*External* = any IP not in internal network, reached over public internet.

Call from *Vulnerable Application*:

- **Is NOT** targeting IP/domain *located inside* company's global network.
- Uses convention between *VulnerableApplication* and expected IP/domain to *prove* call legitimately initiated.

#### Challenges in blocking URLs at application layer

Per business requirements, allowlist isn't valid. Block-list not impenetrable but best here; tells application what it should **not** do.

Why URL filtering hard at Application layer:

- Application must detect at code level that provided IP (V4 + V6) isn't in official private network ranges, incl. *localhost* and *IPv4/v6 Link-Local* addresses. Not every SDK has built-in verification; developer must understand pitfalls and possible values → demanding.
- Same for domain names: company must maintain list of all internal domain names and centralized service letting application verify if domain is internal. Application can query internal DNS resolver for this, but it must not resolve external domain names.

#### Available protections

Same assumption as [example](Server_Side_Request_Forgery_Prevention.md#example) for following sections.

##### Application layer

As in case [n°1](Server_Side_Request_Forgery_Prevention.md#case-1---application-can-send-request-only-to-identified-and-trusted-applications), `IP Address` or `domain name` required to create request to *TargetApplication*.

First validation on the 3 data types from case [n°1](Server_Side_Request_Forgery_Prevention.md#application-layer) same here, **BUT second validation differs**: use block-list approach.

> **Proof of request legitimacy**: *TargetedApplication* receiving request must generate random token (ex: alphanumeric of 20 characters) expected from caller (in body via parameter whose name also defined by application itself, allowing only character set `[a-z]{1,10}`) for valid request. Receiving endpoint accepts only HTTP POST.

**Validation flow (any validation step fails → reject request):**

1. Application receives IP address/domain name of *TargetedApplication*; applies first validation using libraries/regex from this [section](Server_Side_Request_Forgery_Prevention.md#application-layer).
2. Second validation against IP address/domain name of *TargetedApplication* using block-list:
   - IP address:
     - Verify it is public (hint: python code sample in next paragraph).
   - Domain name:
        1. Verify public by resolving domain name against DNS resolver resolving only internal domain names. Must return response indicating it doesn't know the domain, since expected value is public domain.
        2. Retrieve all IP addresses behind domain name (records *A* + *AAAA* for IPv4 + IPv6) and apply same public-address verification. Bind connection to validated address as in [domain name validation](#domain-name); separately checking DNS answers doesn't prevent DNS rebinding.
3. Application receives protocol via dedicated input parameter; verify value vs allowed protocol list (`HTTP` or `HTTPS`).
4. Application receives token parameter name via dedicated input parameter; allow only character set `[a-z]{1,10}`.
5. Application receives token itself via dedicated input parameter; allow only character set `[a-zA-Z0-9]{20}`.
6. Application receives and validates (security-wise) any business data needed for valid call.
7. Application builds HTTP POST request **using only validated information** and connects only to IP address validated in step 2 (*disable [redirection](https://developer.mozilla.org/en-US/docs/Web/HTTP/Redirections) support in web client used*).

##### Network layer

Similar to this [section](Server_Side_Request_Forgery_Prevention.md#network-layer).

## IMDSv2 in AWS

In cloud, SSRF often used to steal credentials + access tokens from metadata services (e.g. AWS Instance Metadata Service, Azure Instance Metadata Service, GCP metadata server).

IMDSv2 = additional AWS defense-in-depth mechanism mitigating some SSRF instances.

Migrate to IMDSv2, disable old IMDSv1. See AWS documentation.

## Deny-list (Last Resort)

**Deny-lists are bypass-prone. Prefer allow-lists.**

**When unavoidable, block these minimum ranges:**

| Service | Block IPs/Domains |
|---------|-------------------|
| **AWS IMDS** | `169.254.169.254`, `metadata.amazonaws.com` |
| **GCP Metadata** | `metadata.google.internal`, `169.254.169.254` |
| **Azure IMDS** | `169.254.169.254` |
| **Localhost** | `127.0.0.0/8`, `0.0.0.0/8`, `::1/128` |
| **RFC1918 Private** | `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16` |
| **IPv6 Unique Local** | `fc00::/7` (RFC 4193) |
| **IPv6 Link-Local** | `fe80::/10` (RFC 4291) |
| **Multicast** | `224.0.0.0/4`, `ff00::/8` |

**Full production example:** ComputerCraft SSRF deny-list

**Sources:**

- IANA IPv4 Special Registry
- IANA IPv6 Special Registry

## Semgrep Rules

Semgrep = command-line tool for offline static analysis. Pre-built or custom rules enforce code/security standards. Explore Semgrep rules for SSRF to identify potential SSRF vulnerabilities.

## Tools and code used for schemas

- Mermaid Online Editor and Mermaid documentation.
- Draw.io Online Editor.

Mermaid code for SSRF common flow (printscreen captures PNG image inserted into this cheat sheet):

```text
sequenceDiagram
    participant Attacker
    participant VulnerableApplication
    participant TargetedApplication
    Attacker->>VulnerableApplication: Crafted HTTP request
    VulnerableApplication->>TargetedApplication: Request (HTTP, FTP...)
    Note left of TargetedApplication: Use payload included<br>into the request to<br>VulnerableApplication
    TargetedApplication->>VulnerableApplication: Response
    VulnerableApplication->>Attacker: Response
    Note left of VulnerableApplication: Include response<br>from the<br>TargetedApplication
```

Draw.io schema XML code for "[case 1 for network layer protection about flows that we want to prevent](../assets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet_Case1_NetworkLayer_PreventFlow.xml)" schema (printscreen captures PNG image inserted into this cheat sheet).

## References

- CWE-918: Server-Side Request Forgery (SSRF)
- WHATWG URL Standard: URL Parsing
- Amazon EC2: Access Instance Metadata
