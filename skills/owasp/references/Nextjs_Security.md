# Next.js Security Cheat Sheet

## Introduction

Underlying runtime + secret handling: [Node.js Security Cheat Sheet](Nodejs_Security.md), [Secrets Management Cheat Sheet](Secrets_Management.md).

Next.js apps have several server entry points; render/cache data on both sides of server/client boundary. Framework authentication guidance: place authorization close to data source, not routing/UI checks.

Principles for relevant framework surfaces:

- Classify every server entry point; enforce controls appropriate to audience + effects.
- Return only data browser is authorized to receive + app needs.
- Include intended audience in every cache decision.
- Treat routing + image configuration as security-sensitive code.
- Test controls by calling entry points directly, bypassing UI.

Covers App Router + Pages Router. General JavaScript, authentication, Cross-Site Scripting (XSS), Cross-Site Request Forgery (CSRF), Server-Side Request Forgery (SSRF) guidance linked, not repeated.

## Classify and Protect Server Entry Points

Multiple server entry points; check in one does not protect another independently callable path. Protected operations: enforce authorization at boundary every applicable path traverses. Next.js Data Security guide recommends server-only Data Access Layer (DAL) doing authorization + returning minimal Data Transfer Objects (DTOs). Equivalent service-layer policy enforcement point or database control can also be boundary when all protected paths necessarily traverse it.

| Entry point | Secure use |
|-------------|------------|
| Proxy (`proxy.ts` in Next.js 16+; deprecated `middleware.ts` remains available during migration) | Optimistic redirects + request filtering. Never sole authorization layer. |
| Server Action | Each reachable action = client-callable POST entry point. Validate input, then apply authentication + resource authorization when protected. |
| Route Handler (`route.ts`) or Pages API Route (`pages/api`) | HTTP endpoint w/ explicit audience. Apply controls for public endpoint, authenticated API, service endpoint, or webhook. |
| Server Component, page, or data loader | Authorize before reading protected data. Return narrow DTO, not database record. |
| Layout or Client Component | Layout can enforce render-time access but does not protect independently callable descendants. Client Component checks only control what UI shows. |

### Do not rely on Proxy or middleware alone

Proxy can redirect unauthenticated users early, but `matcher` may omit a route; routing changes can silently move operation outside coverage. Next.js: Proxy should not be only line of defense. Re-authorize protected operations at handler or data source.

Also defends against framework defects. CVE-2025-29927 let affected self-hosted Next.js versions bypass authorization implemented only in middleware. Patch framework, but keep authorization behind routing layer so one bypass cannot expose data.

### Secure Server Actions as endpoints

Referenced Server Action can receive client-originated POST independently of page rendering its form. Rendering form only on protected page does not authenticate action request. Page-level authentication does not extend to Server Actions.

Classify each action public or protected, apply controls:

- Validate all arguments as untrusted input.
- Protected action: derive current authentication context on server; never accept identity claims in arguments.
- Check permission on exact protected object read/changed; client-submitted user/tenant identifier = selector, not authorization proof.
- Return only authorized result fields: Server Action return values serialized to client.
- Rate limits or stronger re-authentication for expensive/high-impact operations.

Next.js compares request `Origin` with host for Server Actions. Keep `serverActions.allowedOrigins` narrow when trusted proxy requires additional origins. Self-hosted: ensure only trusted infrastructure can establish canonical `Host` or `X-Forwarded-Host` value seen by app. Historical Server Action SSRF advisory, fixed in Next.js 14.1.1, shows patching + trustworthy host handling both matter. Built-in Origin check does not replace authentication, authorization, or general controls in [CSRF Prevention Cheat Sheet](Cross-Site_Request_Forgery_Prevention.md).

### Protect Route Handlers and Pages API Routes separately

Protecting page does not protect Route Handler/API Route serving related data. Next.js: treat Route Handlers as public-facing API endpoints. Classify each handler's audience: intentionally public endpoint may need input validation + abuse controls; webhook may authenticate signature; protected API needs applicable authentication plus object-level/tenant-level authorization per [Authorization Cheat Sheet](Authorization.md).

Never infer handler private because only Server Component calls it. If no browser, service, webhook, or external client needs HTTP API, call DAL directly from Server Component, remove extra entry point.

### Protect Draft Mode as a privileged state change

If app uses Draft Mode, treat handler enabling it as protected entry point. `enable()` on value returned by `await draftMode()` sets `__prerender_bypass` cookie; does not authenticate caller or validate secret itself. Draft Mode guide recommends validating shared secret + confirming requested content exists before enabling.

- Authenticate CMS/other caller; high-entropy secret when shared-secret integration appropriate.
- Validate requested content identifier against trusted content source before enabling Draft Mode.
- Redirect to server-established path returned by that source, not directly to untrusted query parameter.
- Test unauthenticated caller cannot obtain `__prerender_bypass` cookie or use Draft Mode entry point to expose unpublished content.

## Control Data Crossing into the Browser

Server-only code can still send return values to browser. App Router serializes values passed to Client Components; Pages Router exposes page props in initial HTML. Pages Router docs warn `getServerSideProps` values visible to client.

- Construct explicit DTO w/ only fields browser authorized to receive. Selecting only required columns at data source adds defense in depth.
- Never pass ORM records, session objects, or configuration merely because available. Never send secrets to Client Components. Any token intentionally sent to browser must be narrowly scoped + treated as exposed; configuration must be explicitly classified public.
- Keep Server Action return values authorized + minimal; server-side function does not make returned value secret.
- Values in `props` from `getStaticProps`, `getServerSideProps`, `getInitialProps` visible to that page's browser.
- Prefix env var with `NEXT_PUBLIC_` only when value intentionally public. Value included in client JavaScript per Next.js env var guide.

Importing `server-only` in sensitive module = useful build-time guard: prevents import into Client Component. Does not stop server code explicitly returning sensitive data. React taint APIs add another guard; Next.js: tainting = defense in depth, not replacement for shaping data.

Browser rendering sinks + React-specific client concerns: [XSS Prevention Cheat Sheet](Cross_Site_Scripting_Prevention.md), [DOM-based XSS Prevention Cheat Sheet](DOM_based_XSS_Prevention.md).

## Scope Caches to Their Audiences

Before caching response/function result, classify audience: public, tenant-scoped, user-scoped, permission-set, locale, cohort, request-specific. Cache entry must not be reusable by broader audience than data permits. With `use cache`, Next.js includes serializable arguments + captured closure values in generated cache key. Include verified user, tenant, or other audience dimension when it changes cached value or cached authorization decision. When content identical across authorized callers and authorization enforced separately before return, do not duplicate cache by identity.

- Establish + verify required authorization context before returning protected cached data. Per design: user identity, service identity, or validated capability.
- Include only verified dimensions changing cached value/authorization decision (user ID, tenant ID, permission version, locale). Never use raw cookie or bearer token as cache key.
- Never put user-specific data in `use cache` function w/o user-specific input.
- Caches that can serve response before per-request app authorization (Incremental Static Regeneration (ISR), `getStaticProps`, shared CDN caching): only for data full cache audience may read. Next.js: `getStaticProps` data must be publicly cacheable.
- Server-side data/`fetch` cache may hold protected content shared by authorized callers when every return path authorizes access + key separates every content variant.
- Never add shared `Cache-Control` directives to personalized `getServerSideProps` responses.
- After authorization/tenancy changes, prevent reuse under stale permissions: invalidate affected keys/tags, advance permission version in key, or use another bounded expiration strategy.

Cache invalidation = mutation capability. `revalidatePath` and `revalidateTag` callable from server entry points; `updateTag` limited to Server Actions. Authenticate + authorize callers; derive invalidation target from authorized object or validate against constrained app-owned path/tag patterns; abuse controls on externally reachable invalidation handlers. Deliberately global purge requires correspondingly privileged operation.

`use cache: private` can read request-time values, but results cached in browser memory and still delivered to that browser. Directive docs: does not make over-broad data safe to return.

User-/tenant-/permission-scoped caches: test representative identities w/ different entitlements: fill cache as identity A, request same route + object identifiers as identity B. Repeat after changing role or tenant membership. Catches missing audience keys positive-path cache test misses.

## Treat Next.js Configuration as Security Code

Review `next.config.*`, Proxy matchers, route configuration as carefully as handlers. Next.js rewrites act as URL proxy; matcher values can flow into destinations.

- Resolve external rewrite hosts from fixed allowlist or server-controlled registry. Untrusted header, host, cookie, query capture must not select upstream scheme, authority, port.
- Protected destination: ensure direct requests cannot bypass equivalent authentication + authorization. Enforcement may live at destination or trusted gateway whose network policy blocks direct access. Rewrite masks destination URL; not authorization boundary.
- Untrusted captures must not select scheme/authority of external redirect. Validate interpolated path/query component per [Unvalidated Redirects and Forwards Cheat Sheet](Unvalidated_Redirects_and_Forwards.md).
- Define every `images.remotePatterns` restriction app can enforce. Next.js warns omitted fields imply broad wildcards; allow port, pathname, query variation only when use case requires + trust model accounts for broader match.
- Keep `images.dangerouslyAllowLocalIP` disabled unless reviewed private-network use case requires. Next.js warns enabling can let users access content on internal network. Apply [SSRF Prevention Cheat Sheet](Server_Side_Request_Forgery_Prevention.md) to any server-side fetch destination.
- Keep `serverActions.allowedOrigins` restricted to trusted app + proxy origins.
- Leave `productionBrowserSourceMaps` disabled unless operational need justifies publicly serving original browser source maps. Enabling makes Next.js emit + auto-serve those files.
- Deploy optimized production build w/ appropriate production server/adapter. Never expose `next dev` (dev-mode hot reloading + error reporting) as production service.

Security-sensitive config assembled from env vars is still code. Validate hosts/origins against allowlist at startup; fail closed when required value missing/invalid. Validate other config w/ appropriate schema, type, or range constraint.

### Choose a CSP compatible with the rendering model

Use Content Security Policy (CSP) appropriate to app's script, style, third-party resource requirements; see [Content Security Policy Cheat Sheet](Content_Security_Policy.md). Next.js can generate fresh nonce in Proxy, apply during rendering. Nonce must be unpredictable + unique per response; never cache HTML in way reusing it for another response.

Nonce-based CSP cost: Next.js requires dynamic rendering, disables static optimization + ISR for those pages, no Partial Prerendering (PPR) w/ request-specific nonces. Apps retaining static rendering can use CSP w/o nonces when resource policy permits. Never weaken production policy w/ development-only directives such as `'unsafe-eval'` merely to make dev server work.

## Verify the Boundaries

Framework controls need direct negative-path tests. Next.js production checklist recommends checking authorization inside protected Server Actions, not relying on Proxy, layouts, pages.

- Inventory app-defined Server Actions, Route Handlers, Pages API Routes, Draft Mode entry points, server-side data loaders, Proxy matchers, cached functions, cache-invalidation call sites, rewrites, redirects, CSP configuration, source map settings, remote image patterns. Classify each applicable audience + effect.
- Call actions/handlers directly without loading their page. Protected operations: verify applicable unauthenticated, unauthorized, wrong-owner, wrong-tenant requests fail. Public operations: verify intended public behavior + abuse controls.
- Protected route families using Proxy for early filtering: exercise unmatched/bypassed-Proxy path; prove handler/data boundary still denies unauthorized access.
- Inspect applicable rendered HTML, React Server Component payloads, Pages Router data responses, Server Action responses for fields that should stay server-only.
- Cross-user + cross-tenant tests for audience-scoped caches, incl. after permission changes + revalidation.
- Call Draft Mode + cache-invalidation handlers directly; prove unauthorized callers cannot enable preview state or invalidate content.
- Keep Next.js on supported patched release. CVE-2024-46982: affected Pages Router response could be cached when app intended otherwise.

Security tests should fail when new app entry point/cache added without explicit classification. Fixed hand-maintained list can miss new file for same reason control omitted → derive inventory from route + source tree where practical.

## References

- Next.js Authentication Guide
- Next.js Data Security Guide
- Next.js Proxy Reference
