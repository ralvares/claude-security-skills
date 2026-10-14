# GraphQL Cheat Sheet

## Introduction

GraphQL = open source query language, originally by Facebook, for building APIs as alternative to REST and SOAP. Popular since 2012 launch for native flexibility to API builders/callers. Servers and clients exist in many languages. Used by many companies incl. GitHub, Credit Karma, Intuit, PayPal.

Areas to consider:

- Apply proper [input validation](Input_Validation.md) on all incoming data.
- Expensive queries → [Denial of Service (DoS)](Denial_of_Service.md); add checks to limit/prevent too-expensive queries.
- Ensure API has proper [access control](Authorization.md) checks.
- Disable insecure default configurations (_e.g._ excessive errors, introspection, GraphiQL, etc.).

## Common Attacks

- Injection (OWASP API Security 2019 A8) - usually incl. but not limited to:
    - SQL and NoSQL injection
    - OS Command injection
    - SSRF and CRLF injection/Request Smuggling
- DoS (Denial of Service)
- Abuse of broken authorization: improper or excessive access (OWASP API Security 2019 A1, A3), incl. IDOR
- Batching Attacks, GraphQL-specific brute force method
- Abuse of insecure default configurations

## Best Practices and Recommendations

Original security analysis: Doyensec's GraphQL security overview.

### Input Validation

Strict input validation helps prevent injection and DoS. GraphQL design: user supplies identifiers; backend data fetchers make HTTP, DB, other calls using them. User input thus lands in HTTP requests, DB queries, other calls → opportunity for injection attacks or DoS.

Full details: OWASP Cheat Sheets [Input Validation](Input_Validation.md) and general [injection prevention](Injection_Prevention.md).

#### General Practices

Validate all incoming data, allow only valid values (i.e. allowlist).

- Use specific GraphQL data types: scalars, enums. Write custom GraphQL validators for complex validations. Custom scalars may help.
- Define schemas for mutations input.
- [List allowed characters](Input_Validation.md#allowlist-vs-denylist) - no denylist
    - Stricter allowed list = better. Good start: alphanumeric, non-unicode only; disallows many attacks.
- Handle unicode input w/ [single internal character encoding](Input_Validation.md#validating-free-form-unicode-text)
- Gracefully [reject invalid input](Error_Handling.md); don't reveal excessive info on how API and validation work.

#### Injection Prevention

Input passed to another interpreter (_e.g._ SQL/NoSQL/ORM, OS, LDAP, XML):

- Always choose libraries/modules/packages w/ safe APIs, e.g. parameterized statements.
    - Follow documentation to use tool properly
    - ORMs and ODMs good option but must be used properly to avoid flaws like ORM injection.
- No such tools: always escape/encode input per best practices of target interpreter
    - Choose well-documented, actively maintained escaping/encoding library. Many languages/frameworks built-in.

More:

- [SQL Injection Prevention](SQL_Injection_Prevention.md)
- NoSQL Injection Prevention
- [LDAP Injection Prevention](LDAP_Injection_Prevention.md)
- [OS Command Injection Prevention](OS_Command_Injection_Defense.md)
- [XML Security](XML_Security.md) and [XXE Injection Prevention](XML_External_Entity_Prevention.md)

#### Process Validation

User input, even sanitized/validated, must not give user control over data flow. E.g. no HTTP/resource request to host user supplies (unless absolute business need).

### DoS Prevention

DoS attacks API availability/stability: slow, unresponsive, or fully unavailable. Methods below limit DoS at application level and other stack layers. See also [DoS](Denial_of_Service.md) CS.

GraphQL-specific DoS limits:

- Add depth limiting to incoming queries
- Add amount limiting to incoming queries
- Add pagination to limit data returned per response
- Add reasonable timeouts at application layer, infrastructure layer, or both
- Consider query cost analysis; enforce max allowed cost per query
- Enforce rate limiting on incoming requests per IP or user (or both) against basic DoS
- Implement batching and caching technique server-side (Facebook's DataLoader usable)

#### Query Limiting (Depth & Amount)

Each query has depth (_e.g._ nested objects); each requested object can have amount (_e.g._ 99999999 of an object). Both unlimited by default → DoS. Set depth and amount limits; usually needs small custom implementation, not native to GraphQL. Adding pagination also helps performance.

graphql-java APIs: built-in MaxQueryDepthInstrumentation for depth limiting. JavaScript APIs: graphql-depth-limit for depth, graphql-input-number for amount limiting.

Example query with depth N:

```javascript
query evil {            # Depth: 0
  album(id: 42) {       # Depth: 1
    songs {             # Depth: 2
      album {           # Depth: 3
        ...             # Depth: ...
        album {id: N}   # Depth: N
      }
    }
  }
}
```

Example query requesting 99999999 of an object:

```javascript
query {
  author(id: "abc") {
    posts(first: 99999999) {
      title
    }
  }
}
```

#### Timeouts

Timeouts simply limit resources one request can consume. Not always effective: may not activate until malicious query already consumed excessive resources. Requirements differ by API and data fetching mechanism; no single value works everywhere.

Application level: timeouts on queries and resolver functions. Usually more effective: query/resolution stops at timeout. GraphQL has no native query timeouts; custom code required. Two examples below.

_**JavaScript Timeout Example**_

Snippet from SO answer:

```javascript
request.incrementResolverCount =  function () {
    var runTime = Date.now() - startTime;
    if (runTime > 10000) {  // a timeout of 10 seconds
      if (request.logTimeoutError) {
        logger('ERROR', `Request ${request.uuid} query execution timeout`);
      }
      request.logTimeoutError = false;
      throw 'Query execution has timeout. Field resolution aborted';
    }
    this.resolverCount++;
  };
```

_**Java Timeout Example using Instrumentation**_

```java
public class TimeoutInstrumentation extends SimpleInstrumentation {
    @Override
    public DataFetcher<?> instrumentDataFetcher(
            DataFetcher<?> dataFetcher, InstrumentationFieldFetchParameters parameters
    ) {
        return environment ->
            Observable.fromCallable(() -> dataFetcher.get(environment))
                .subscribeOn(Schedulers.computation())
                .timeout(10, TimeUnit.SECONDS)  // timeout of 10 seconds
                .blockingFirst();
    }
}
```

_**Infrastructure Timeout**_

Easier option: timeout on HTTP server (Apache/httpd, nginx), reverse proxy, or load balancer. Infrastructure timeouts often inaccurate, bypassed more easily than application-level.

#### Query Cost Analysis

Assign costs to resolution of fields/types in incoming queries; server rejects queries costing too much or consuming too many resources. Hard to implement, not always necessary, but most thorough DoS prevention. See "Query Cost Analysis" in Apollo blog post on securing GraphQL API.

Apollo recommends:

> **Before you go ahead and spend a ton of time implementing query cost analysis be certain you need it.** Try to crash or slow down your staging API with a nasty query and see how far you get — maybe your API doesn’t have these kinds of nested relationships, or maybe it can handle fetching thousands of records at a time perfectly fine and doesn’t need query cost analysis!

graphql-java APIs: built-in MaxQueryComplexityInstrumentationto enforces max query complexity. JavaScript APIs: graphql-cost-analysis or graphql-validation-complexity enforce max query cost.

#### Rate Limiting

Limit incoming HTTP requests per client w/ request-rate control, e.g. Nginx's `limit_req` module. Apache's `mod_ratelimit` limits transfer bandwidth of each response; does not limit incoming request counts or aggregate traffic per client.

HTTP request counts alone miss expensive queries and multiple operations per request. Apply GraphQL rate limits in business logic layer, together w/ [query cost limits](#query-cost-analysis) and [batching limits](#mitigating-batching-attacks).

#### Server-side Batching and Caching

Batching and caching technique prevents duplicate requests for same data within small time frame → more efficient, fewer resources. Facebook's DataLoader implements.

#### System Resource Management

Not limiting API resources (_e.g._ CPU, memory) compromises responsiveness/availability → DoS vulnerable. Some limiting at OS level.

Linux: combine Control Groups(cgroups), User Limits (ulimits), Linux Containers (LXC).

Containerization platforms usually much easier. See resource limiting section in [Docker Security Cheat Sheet](Docker_Security.md#rule-7---limit-resources-memory-cpu-file-descriptors-processes-restarts) for DoS prevention w/ containers.

### Access Control

Proper GraphQL API access control:

- Always validate requester authorized to view or mutate/modify requested data. Use [RBAC](Authorization.md#prefer-attribute-and-relationship-based-access-control-over-rbac) or other access control mechanisms.
    - Prevents [IDOR](Insecure_Direct_Object_Reference_Prevention.md) issues, incl. BOLA and BFLA.
- Enforce authorization on both edges and nodes (example bug report: nodes lacked authorization checks, edges had them).
- Use Interfaces and Unions for structured, hierarchical data types returning more/fewer object properties per requester permissions.
- Query and Mutation Resolvers can perform access control validation, possibly via RBAC middleware.
- Disable introspection queries system-wide in production or publicly accessible environments.
- Disable GraphiQL and similar schema exploration tools in production or publicly accessible environments.

#### General Data Access

GraphQL requests commonly include direct object IDs to fetch/modify them. E.g. picture request may include ID = DB primary key. Server must verify caller has access to requested object. Common developer mistake: assuming possessing ID means access. Failing to verify = Broken Object Level Authentication, aka [IDOR](Insecure_Direct_Object_Reference_Prevention.md).

GraphQL API may support object access by ID unintentionally. Query object may have `node` or `nodes` or both fields, usable to access objects directly by `ID`. Check schema for these fields on command-line (assuming `schema.json` holds GraphQL schema): `cat schema.json | jq ".data.__schema.types[] | select(.name==\"Query\") | .fields[] | .name" | grep node`. Removing fields from schema should disable functionality, but always apply proper authorization checks verifying caller access to requested object.

#### Query Access (Data Fetching)

Detectify's New Relic disclosure shows why field access must respect account permissions.

GraphQL APIs return various data fields. Consider different access levels per field: e.g. only certain consumers fetch certain fields rather than all consumers retrieving all fields. Add code check that requester may read field they fetch.

#### Mutation Access (Data Manipulation)

Original case study: Pen Test Partners' WordPress GraphQL disclosure.

GraphQL supports mutation (data manipulation) besides common data fetching. If API allows mutation, may need access controls restricting which consumers, if any, modify data. Needed where requesters intended read-only or only certain parties modify certain fields.

### Batching Attacks

GraphQL supports batching requests (query batching). Callers batch multiple queries or requests for multiple object instances in single network call → batching attack. GraphQL-specific brute force form, usually faster and less detectable. Most common query batching way:

```javascript
[
  {
    query: < query 0 >,
    variables: < variables for query 0 >,
  },
  {
    query: < query 1 >,
    variables: < variables for query 1 >,
  },
  {
    query: < query n >
    variables: < variables for query n >,
  }
]
```

Example single batched call requesting multiple instances of `droid` object:

```javascript
query {
  droid(id: "2000") {
    name
  }
  second:droid(id: "2001") {
    name
  }
  third:droid(id: "2002") {
    name
  }
}
```

Can enumerate every `droid` object stored on server in very few network requests, vs standard REST API needing separate request per `droid` ID. Attack can lead to:

- Application-level DoS - many queries/object requests in one call can hang database or exhaust other resources (_e.g._ memory, CPU, downstream services).
- Enumeration of objects on server, e.g. users, emails, user IDs.
- Brute forcing passwords, 2 factor authentication codes (OTPs), session tokens, other sensitive values.
- WAFs, RASPs, IDS/IPS, SIEMs, other security tooling likely miss: appears as single request, not massive network traffic.
- Likely bypasses existing rate limits in Nginx or other proxies/gateways: they count raw requests.

#### Mitigating Batching Attacks

Put limits on incoming requests at code level, applied per request. 3 main options:

- Add object request rate limiting in code
- Prevent batching for sensitive objects
- Limit number of queries running at one time

Option 1: code-level rate limit on objects callers can request. Backend tracks how many object instances caller requested; blocks after too many even if batched in one network call. Replicates network-level rate limit of WAF or similar.

Option 2: prevent batching for sensitive objects not to be brute forced (usernames, emails, passwords, OTPs, session tokens, etc.). Attacker forced to attack like REST API: separate network call per object instance. Not native; needs custom solution. Once in place, other standard controls work normally against brute forcing.

Option 3: limit number of operations batched/run at once to mitigate batching DoS. Not silver bullet; use with other methods.

### Secure Configurations

Most GraphQL implementations have insecure defaults to change:

- Don't return excessive error messages (_e.g._ disable stack traces and debug mode).
- Disable or restrict Introspection and GraphiQL per needs.
- Suggestion of mis-typed fields if introspection disabled

#### Introspection + GraphiQL

GraphQL often defaults to introspection and/or GraphiQL enabled, no authentication. Consumer learns everything about API, schemas, mutations, deprecated fields, sometimes unwanted "private fields".

May be intended if API designed for external clients; issue if internal-only. Security by obscurity not recommended, but consider removing introspection to avoid leaks.
Publicly consumed API: consider disabling for unauthenticated/unauthorized users.

Internal API: easiest = disable introspection system-wide. See Wallarm page or implementation docs. If implementation lacks native disable, or some consumers/roles need access, build filter in service allowing only approved consumers to introspection.

Even with introspection disabled, attackers can brute force field guesses. GraphQL also has built-in hint when requested field name similar (but incorrect) to existing field (_e.g._ request has `usr` and response asks `Did you mean "user?"`). Consider disabling this if introspection disabled, reducing exposure; not all implementations support it. Shapeshifter is one tool that should be able to do this.

_**Disable Introspection - Java**_

```Java
GraphQLSchema schema = GraphQLSchema.newSchema()
    .query(StarWarsSchema.queryType)
    .fieldVisibility( NoIntrospectionGraphqlFieldVisibility.NO_INTROSPECTION_FIELD_VISIBILITY )
    .build();
```

_**Disable Introspection & GraphiQL - JavaScript**_

Existing apps using deprecated `express-graphql` middleware; illustration assumes `NoIntrospection` is imported introspection-denying validation rule. Use maintained server implementation for new apps.

```javascript
app.use('/graphql', graphqlHTTP({
  schema: MySessionAwareGraphQLSchema,
  validationRules: [NoIntrospection],
  graphiql: process.env.NODE_ENV === 'development',
}));
```

#### Don't Return Excessive Errors

Production GraphQL APIs: no stack traces, no debug mode. Implementation specific; middleware popular for better control over returned errors. Apollo Server: pass `includeStacktraceInErrorResponses: false` to constructor to omit stack traces. When unspecified, `NODE_ENV=production` or `NODE_ENV=test` suppresses stack traces by default; error messages still need separate masking. To log stack trace internally without returning it to user, see Apollo docs on masking and logging errors (available to developers, not API callers).

## References

- GraphQL: Security
- GraphQL: Authorization
