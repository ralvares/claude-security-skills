# Web Cache Security Cheat Sheet

## Introduction

HTTP caches reuse stored responses in browsers, reverse proxies, content delivery networks (CDNs), application data stores. Cache = security boundary when it serves response to request other than the one that produced it. RFC 9111 defines private/shared cache behavior; MDN HTTP caching guide has practical directive examples.

Focus: preventing sensitive data exposure, web cache poisoning, web cache deception, cross-tenant leakage. For developers/operators configuring origin apps, reverse proxies, CDNs, application-level caches.

## Key Risks

RFC 9111 security considerations: caches attractive targets, one stored response affects many users. OWASP cache poisoning overview: harmful cached response distributed to other visitors.

- **Sensitive response exposure**: shared cache stores personalized/authenticated response, returns it to another user.
- **Web cache poisoning**: attacker-controlled request input changes response but is excluded from cache key. Harmful response served to other users.
- **Web cache deception**: dynamic/personalized URL made to look like static asset → intermediary caches sensitive content.
- **Cache key confusion**: cache and origin disagree on URL normalization, query parameters, headers, request routing → unrelated requests share entry.
- **Cross-tenant leakage**: app cache key omits tenant or authorization context.
- **Stale security state**: cached content stays accessible after permissions, account state, or underlying resource change.

## Best Practices

Cacheability + cache-key design = part of app authorization model. RFC 9111 specifies how response directives, request inputs, validation control stored response reuse.

### 1. Classify Responses Before Caching

Explicit policy per route. Default: prevent shared caching for authenticated, personalized, tenant-specific, other sensitive responses.

- `Cache-Control: no-store`: response must not be stored by any compliant cache.
- `Cache-Control: private`: may be stored by user's private cache, not shared cache.
- `no-cache` permits storage but requires successful validation before reuse. Does not mean "do not store."
- Cookies ≠ private. `Set-Cookie` header alone doesn't prevent caching.
- Do not mark response influenced by `Authorization` or session cookies as `public`, or give `s-maxage`, unless sharing deliberately designed and reviewed.
- Purge previously stored entries when switching route to `no-store`; directive doesn't delete old entries.

Sensitive data response:

```http
Cache-Control: no-store
```

Non-sensitive content, private cache only, must revalidate:

```http
Cache-Control: private, no-cache
```

### 2. Design a Complete Cache Key

Every request input that can change cacheable response MUST be in cache key or rejected for that route.

- Include request method, scheme, host, normalized path, all relevant query parameters.
- Use `Vary` for representation-selecting headers like `Accept-Encoding`, `Accept-Language`.
- Don't use `Vary: Cookie` as general authorization boundary. Prefer disabling shared caching for personalized responses.
- Derive tenant/user identifiers from trusted authenticated server-side context, not directly from untrusted header or query parameter.
- Same URL normalization + parameter handling at CDN, reverse proxy, origin.
- Reject ambiguous requests: conflicting host info, duplicate parameters w/ inconsistent meanings, malformed path encodings.

App-level cache: structured versioned key:

```text
<environment>:<resource-version>:<tenant-id>:<resource-type>:<resource-id>
```

No session tokens, API keys, other secrets in cache keys; keys often appear in logs and admin interfaces.

### 3. Prevent Web Cache Poisoning

Cloudflare cache poisoning guidance, central rule: untrusted request inputs not in cache key must not influence cacheable response.

- Cache only routes explicitly intended to be shared.
- Unkeyed headers or body on `GET` must not alter cacheable response.
- Trust `Forwarded` and `X-Forwarded-*` only when added/replaced by trusted proxy.
- Canonicalize host + scheme before using them for links, redirects, security-sensitive headers.
- Don't reflect unvalidated request metadata into cached HTML, JSON, redirects, response headers.
- Separate static assets and dynamic routes by hostname or unambiguous path namespace where practical.
- If poisoning occurs, purge every affected cache layer, fix key or origin behavior before re-enabling caching.

### 4. Prevent Web Cache Deception

Attacker makes shared cache store personalized content under URL that appears cacheable. Cache Deception Armor mitigation: verify requested file extension agrees w/ response `Content-Type`.

- Cache eligibility from allowlisted route + response policy, not only file extension.
- Dynamic routes reject unexpected path segments + static-looking suffixes, not silently route them to same handler.
- Request like `/account/profile/image.css` must not resolve to same personalized handler as `/account/profile`.
- Verify URL extension and response `Content-Type` agree before caching static asset.
- Ignore/remove query parameters from cache key only after proving they cannot change routing, authorization, response content.

### 5. Coordinate Origin and Intermediary Policies

Secure origin policy can be weakened by CDN rule, reverse proxy override, framework default. MDN: control caching explicitly, don't rely on heuristics.

- Define browser and shared-cache lifetimes independently w/ appropriate directives.
- Review CDN rules overriding origin `Cache-Control` or caching by status code, path pattern, file extension.
- Explicit cache policies for error pages, redirects, authentication responses.
- Consistent URL normalization at every layer. CDN normalizes cache key → send normalized form to origin too.
- Maintain tested purge mechanism for individual keys, tags, narrowly scoped route groups.
- Fail closed when sensitive route has missing, malformed, conflicting cache policy.

### 6. Protect Application-Level Caches

In-memory, database, distributed caches leak data even w/ HTTP caching disabled. Enforce authorization on every request before returning cached data. See [Authorization Cheat Sheet](Authorization.md), [Multi-Tenant Security Cheat Sheet](Multi_Tenant_Security.md).

- Namespace keys by environment + application to prevent collisions.
- Include tenant identity + every authorization-relevant resource dimension in key.
- Cache hit must not bypass object-level or tenant-level authorization.
- Avoid caching final authorization decisions unless key includes complete subject, object, action, policy version, and tightly bounded lifetime.
- Version key formats so schema/permission-model changes can't reuse incompatible entries.
- Restrict admin access to cache contents, configuration, statistics, purge operations.

### 7. Test the Complete Cache Path

Test through same CDN/proxy path as production. Cloudflare cache-key docs: scheme, host, path, query parameters, headers, cookies can contribute to key.

- Request same URL as two different users and tenants; neither response may contain other's data.
- Change one header, query parameter, cookie, or path component at a time; verify expected cache behavior.
- Append static-looking suffixes + unexpected path segments to authenticated routes; verify rejected and not cached.
- Test authorization changes, logout, content updates, purge operations against already stored entries.
- Monitor unexpected cache hits on authenticated routes, abrupt hit-ratio changes, unusual forwarded headers, repeated purge activity.
- Log enough cache-status + routing metadata to investigate incidents; never log secrets or full sensitive response bodies.

## Do's and Don'ts

Use alongside RFC 9111 HTTP caching requirements and normal app authorization review.

**Do:**

- Set explicit `Cache-Control` policy on every security-relevant response.
- Verify every response-changing input is in cache key or rejected.
- Keep cache and origin routing rules consistent.
- Authorize current request before returning cached app data.
- Test w/ multiple identities + tenants through production caching path.
- Plan and test targeted cache invalidation before incident.

**Don't:**

- Assume authentication, cookies, TLS, or `Set-Cookie` automatically prevents caching.
- Cache every URL w/ static-looking extension.
- Allow unkeyed request metadata to influence shared responses.
- Treat `Vary: Cookie` as substitute for authorization design.
- Include credentials or session identifiers in keys, logs, purge URLs.
- Assume purging poisoned entry fixes underlying vulnerability.

## References

- RFC 9111: HTTP Caching
- MDN: HTTP Caching
- Cloudflare: Avoid Web Cache Poisoning
