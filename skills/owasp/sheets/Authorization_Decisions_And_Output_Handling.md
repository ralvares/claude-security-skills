# Authorization Decisions and Output Handling Cheat Sheet

## Introduction

**Policy Decision Point (PDP)** evaluates access; **Policy Enforcement Point (PEP)** applies result before releasing data or performing action. OpenID AuthZEN Authorization API 1.0 defines single and multiple evaluations, plus search interfaces. Sheet covers enforcing individual decisions, authorized resource lists, query filters. See [Authorization Patterns](Authorization_Patterns.md) for placement, [Policy and Data Distribution](Authorization_Policy_And_Data_Distribution.md) for trustworthy inputs.

## Single and Batch Decisions

Bind each decision to authenticated subject, action, resource, tenant, relevant context. AuthZEN evaluation interfaces carry info used to evaluate access. Supplying verified role or relationship attributes legitimate when policy requires them; accepting client's assertion of own privileges is not.

Batch = separate access checks grouped. Match each response to its request via API-defined ordering or identifiers; deny item whose result is missing, invalid, or error. Never apply one item's permit to whole batch. UI checks can decide which buttons to show; operation itself still requires [server-side authorization](Authorization.md#validate-the-permissions-on-every-request).

## Enforcing Access to Collections

Choose by PDP's documented output semantics and data store's supported integration, not labels such as relationship-based access control (ReBAC). OpenFGA ListObjects and Cerbos query-plan API illustrate different contracts.

### Check Each Candidate

PEP retrieves bounded candidate set, evaluates each item, individually or batched.

![PDP as a filter](../assets/PDP_as_filter.png)

Use for small sets when list or filter interface unavailable. Keep candidate data inside trusted service until checks complete; exclude denied and unresolved items. Apply same restriction to counts, exports, other outputs that could reveal protected data.

### Retrieve Authorized Resource Identifiers

PDP returns identifiers subject may access for given action. Application restricts data retrieval to those identifiers plus own tenant and business predicates.

![Authorized data set](../assets/Authorized_data_set.png)

Treat result as complete only when API guarantees completion. OpenFGA documents deadline and result-count limits for ListObjects; don't assume every implementation offers pagination cursor or unlimited streaming. Truncated authorized subset can be shown as partial when API guarantees each returned item permitted, but can't establish complete authorized set. Never read empty or incomplete list as permission to remove restriction. Recheck authorization for subsequent operations or when relevant state changes.

### Apply an Authorization Filter

PDP returns predicate or query plan; data layer enforces it while retrieving resources.

![Authorization filter](../assets/Authorization_filter.png)

Use maintained adapter for exact PDP and data store. Cerbos PlanResources distinguishes always-allowed, always-denied, conditional plans; OPA Compile API supports partial evaluation. Capabilities depend on implementation and policy language; no universal restriction on ReBAC or other model families.

## Security Considerations

Output useful only if PEP enforces full meaning. AuthZEN response-integrity and trust requirements apply to channel and components carrying decisions.

- **Cover every data path.** Enforce restriction on list, search, export, count, aggregate, direct-object reads. Authorized list ≠ authorized later update or delete.
- **Intersect predicates.** Combine authorization restrictions w/ application and tenant predicates via logical AND. Always-allowed authorization result doesn't remove other restrictions; always-denied must return no protected data.
- **Preserve query semantics.** Reject unsupported operators or incomplete translations. Check adapter behavior for nulls, missing attributes, joins, collection membership against policy meaning. Never silently omit untranslatable expression.
- **Keep values separate from syntax.** Bind filter values as parameters; allow-list structural choices e.g. field names, operators. Never execute returned debug string as query. See [SQL Injection Prevention](SQL_Injection_Prevention.md#defense-option-1-prepared-statements-with-parameterized-queries).
- **Fail closed.** Deny protected operations on PDP errors, timeouts, unusable output. Apply [Deny by Default](Authorization.md#deny-by-default), incl. when filter absent; missing filter ≠ unrestricted result.
- **Bound reuse.** Cache only for same subject, action, resource scope, tenant, relevant policy/input state, within approved freshness limit. Account for changes between evaluation and use; cached permit must not outlive required revocation deadline.

Verify integrations w/ permitted and denied resources, tenant boundaries, each explicit filter result kind, incomplete batches or lists, PDP failure. Compare filter's selected resources against individual decisions for representative policy cases. Checks validate adapter and enforcement paths, not just successful PDP communication.

Batching and filtering can reduce work; don't trade away enforcement or freshness for latency target. Prefer documented query-filter integration for large queryable collections; use bounded per-item checks when that integration unavailable or can't preserve policy meaning.

## References

- OpenID AuthZEN Authorization API 1.0
- OpenFGA relationship queries and ListObjects limitations
- Cerbos resource query plans
