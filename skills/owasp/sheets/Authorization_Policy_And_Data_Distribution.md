# Authorization Policy and Data Distribution Cheat Sheet

## Introduction

Authorization decision only as reliable as its policy and input data. **Policy Decision Point (PDP)** evaluates rules using attributes supplied by **Policy Enforcement Point (PEP)** or authoritative **Policy Information Point (PIP)**. OPA external data guidance describes common ways to deliver inputs. See [Authorization Patterns](Authorization_Patterns.md) for component placement.

## Define Ownership and Freshness Requirements

Record who may change each policy and attribute, which service is authoritative, max delay before change must affect decisions. Distinguish policy changes (e.g. new restriction) from data changes (e.g. revoking user's membership). Neither organizational ownership nor update frequency determines acceptable delay: central policy can require emergency update, another can have scheduled effective date.

Choose delivery against those requirements. OPA bundles can carry policies and data, but distribution is eventually consistent. Successful publication ≠ every PDP activated update.

| Requirement | Suitable starting point | Security condition |
|-------------|------------------------|--------------------|
| Emergency restriction or revocation | Dynamic updates or authoritative lookup | Measure propagation bound; deny affected operations when it can't be met |
| Scheduled, stable rules | Versioned deployment or dynamic distribution | Activate required revision before effective deadline |
| Frequently changing resource or relationship data | Synchronization or lookup from authoritative source | Account for replication lag and cached decisions |
| Request-specific attributes | Validated context passed by PEP | Authenticate PEP; establish where each security-relevant value came from |

## Deliver Policies and Data

**Policy Administration Point (PAP)** manages policy changes. Distribute approved policies independently of app releases when restrictions must take effect sooner than deployment reliably completes. Delivery may be push or pull; OPA bundle downloads = pull-based updates outside decision request. Embedding policies in release suitable only when deployment process meets required update deadline.

For input data, choose among approaches by source's consistency guarantees and PDP's actual capabilities. Model names alone don't establish which mechanisms product supports.

### Lookup During Evaluation

PDP retrieves required attributes from authoritative PIP.

![On-demand data lookup](../assets/On_demand_data_pull.png)

Use when source can meet decision's availability and freshness requirements. Lookup doesn't guarantee current data if source, replica, or intermediate cache stale. Deny affected operations when required attribute can't be obtained reliably.

### Replicated Data

Updates reach PDP's local data store before evaluation.

![Out-of-band data delivery](../assets/Out_of_band_data_push.png)

Removes PIP from immediate request path but creates revocation delay. Monitor synchronization progress; handle missed, repeated, reordered updates. Don't describe local availability as freshness guarantee.

### Request-Time Data

PEP collects attributes, includes them in decision request.

![Request-time data injection](../assets/Request_time_data_injection.png)

AuthZEN security considerations address PEP authentication and trust. Authenticated PEP must still derive user identity, roles, ownership, tenant membership from trusted sources; copying values from end-user request doesn't make them authoritative. Validate resource identifiers against actual target; distinguish user-supplied context from verified attributes.

### Embedded Data

Stable data packaged with PDP or policy release.

![Embedded data](../assets/Embedded_data.png)

Use only when changing data via deployment meets freshness requirement. Avoid embedding mutable account status or revocation data in releases that can't update promptly.

## Protect Distribution and Administration

Protect network-exposed decision APIs and APIs that read or modify policy and data. Authenticate PEPs and administrators, restrict each to needed tenants and operations, prevent service teams from replacing organization-wide restrictions. OPA API security documentation describes authentication and authorization for these interfaces. In-process PDP shares app's trust boundary; needs no separate network authentication exchange.

Verify policy artifacts before activation. Bundles: require signature from configured trusted publisher, verify all covered files; OPA documents verification and activation rules. Protect transport and signing keys too. Valid signature proves origin and integrity, not policy correctness or currency.

Pin deployments to reviewed policy and schema versions; record which revision each PDP actually activates. Reject unexpected or obsolete revisions; allow rollback only via reviewed release process. Test that service-owned rules can't override mandatory restrictions. Controls needed for embedded releases as well as dynamic delivery.

## Freshness and Outages

Distinguish loss of policy distribution service from loss of usable authorization decision. OPA retains existing bundle when new bundle fails verification; preserves availability but ≠ old bundle still fresh enough.

- Continue evaluating previously verified policy only while its policy, data, decision-cache freshness requirements remain satisfied.
- At startup, don't serve protected operations until required policy and data available and valid.
- Deny affected operations when required inputs missing, invalid, or older than allowed bound. Never turn timeout or undefined result into permit; follow [Deny by Default](Authorization.md#deny-by-default).
- Exercise revocation, delayed updates, invalid artifacts, unavailable sources, recovery. Verify effective decision at PEP, not just delivery to PDP.

Prefer reviewed, versioned policies and explicit freshness budget per security-relevant input. Pick simplest delivery mechanism meeting those limits; stop granting affected access when it can't.

## References

- OPA external data integration
- OPA policy and data bundles
- OpenID AuthZEN security considerations
