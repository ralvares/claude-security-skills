# REST Assessment Cheat Sheet

## About RESTful Web Services

Web Services: web technology for machine-to-machine communication; used for inter-application communication, Web 2.0, Mashups, desktop/mobile apps calling a server.

RESTful web services (REST): light-weight Web Services variant based on RESTful design pattern. Use HTTP requests similar to regular HTTP calls, unlike SOAP's complex protocol.

## Key relevant properties of RESTful web services

- HTTP methods (`GET`, `POST`, `PUT`, `DELETE`) as primary verb for requested operation.
- Non-standard parameter specification:
    - In URL.
    - In headers.
- Structured parameters/responses as JSON or XML in parameter values, request body, response body; needed to communicate machine-useful info.
- Custom authentication + session management, often custom security tokens: machine-to-machine communication allows no login sequences.
- No formal documentation. WADL proposed by Sun Microsystems as standard for describing RESTful web services; never officially adopted.

## The challenge of security testing RESTful web services

- Inspecting application does not reveal attack surface (URLs, parameter structure). Reasons:
    - No application uses all functions/parameters service exposes
    - Used ones often activated dynamically by client-side code, not page links.
    - Client often not a web application; no inspection of activating link or relevant code.
- Non-standard parameters: hard to tell URL part or constant header from parameter worth [fuzzing](https://owasp.org/www-community/Fuzzing).
- Machine interface → parameter count can be large (e.g. JSON w/ dozens of parameters). [fuzzing](https://owasp.org/www-community/Fuzzing) each significantly lengthens testing.
- Custom authentication needs reverse engineering; popular tools useless as they cannot track login session.

## How to pentest a RESTful web service

Determine attack surface via documentation; RESTful pen testing better if some clear-box testing allowed and service info obtainable.

Info ensures fuller coverage. Look for:

- Formal service description: SOAP usually has WSDL; seldom for REST. WSDL 2.0 or WADL can describe REST, sometimes used.
- Developer guide: less detailed but commonly found; might even count as *opaque-box* testing.
- Application source or configuration: many frameworks, incl. dotNet, expose REST service definition in configuration files rather than code.

Collect full requests using a proxy (e.g. ZAP). Always important in pen testing; more so for REST since application UI may not hint at actual attack surface.

Proxy must collect full requests, not just URLs: REST services use more than GET parameters.

Analyze collected requests to determine attack surface:

- Look for non-standard parameters:
    - Abnormal HTTP headers: often header-based parameters.
    - URL segment repeating pattern across URLs (date, number, ID-like string) → URL-embedded parameter.
        - E.g. `http://server/srv/2013-10-21/use.php`
    - Structured parameter values: JSON, XML, or non-standard structure.
    - Last URL element without extension may be parameter. Esp. if application technology normally uses extensions or previous segment has one.
        - E.g. `http://server/svc/Grid.asmx/GetRelatedListItems`
    - Highly varying URL segments: single segment with many values may be parameter, not physical directory.
        - E.g. `http://server/src/XXXX/page` repeating with hundreds of `XXXX` values → `XXXX` likely parameter.

Verify non-standard parameters: sometimes (not always), set suspected URL segment to value expected invalid to tell path element from parameter. Path element → web server returns *404*; invalid parameter value → application-level message (value legal at web server level).

Analyze collected requests to optimize [fuzzing](https://owasp.org/www-community/Fuzzing): per potential parameter, determine:

- Valid vs. invalid values → fuzzing focuses on marginal invalid values.
    - E.g. send *0* for value always positive integer.
- Sequences allowing fuzzing beyond range presumably allocated to current user.

When [fuzzing](https://owasp.org/www-community/Fuzzing), emulate the authentication mechanism used.

## Assessing OpenAPI and Swagger-Based REST APIs

Modern REST APIs commonly publish machine-readable description in OpenAPI (formerly Swagger). Unlike WADL, widely adopted; fastest route to attack surface in assessment.

- Probe common description locations first: `/openapi.json`, `/swagger.json`, `/docs`; before relying only on traffic captured through a proxy. Description lists paths, methods, parameters, schemas, security requirements in one place.
- Reconcile description with observed behavior. Call endpoints description omits; send fields schema does not define. Undocumented accepted field = discrepancy to investigate, not proof of contract violation: additional properties may be valid depending on intended schema + documentation. Compare observation with intended schema + authorization policy before treating field as violation (see mass assignment below).
- Fuzz from schema: start with valid request satisfying declared types, required fields, `enum` values; mutate one constraint at a time, same [fuzzing](https://owasp.org/www-community/Fuzzing) approach as above.
- Build per-operation security test matrix from effective OpenAPI `security` requirements: root-level requirements unless operation declares own `security`, which replaces (not combines with) them. Cases: no credentials, valid token, token lacking declared requirement (see next section). `securitySchemes` only define reusable security mechanisms those requirements refer to.

## JWT and OAuth2 Assessment

REST API only as strong as token checks in front of it → test token handling before endpoints behind it.

- Tamper with token: change payload claim, re-sign with key you control, or remove signature; confirm API rejects. Also try `alg: none` and algorithm confusion. Server-side rules: [JSON Web Token Cheat Sheet](JSON_Web_Token.md), [REST Security Cheat Sheet](REST_Security.md#jwt); threat background: RFC 8725.
- Send token expired (`exp`), not yet valid (`nbf`), or issued for another issuer (`iss`) or audience (`aud`). These standard claims (RFC 7519 section 4) must be checked against API configuration, not trusted as presented.
- Send malformed tokens (truncated or extra parts, invalid Base64 or JSON); confirm API returns authentication failure, not server error or partially parsed token.
- Check scope + role enforcement: call each operation with valid token whose OAuth 2.0 (RFC 6749) scope does not grant it, and with valid token of lower-privileged role lacking permission. Both denied the result, on read and write alike, with status code the API's documented response policy prescribes for such denial: e.g. `401 Unauthorized` or `403 Forbidden` as described for bearer requests in RFC 6750 Section 3.1 (RFC 9110 sections 15.5.2, 15.5.4), or `404 Not Found` when API conceals resource existence (RFC 9110 section 15.5.4).

## Broken Object Level Authorization (BOLA)

Broken Object Level Authorization (OWASP API Security 2023 API1) = API form of IDOR: endpoint uses request identifier without checking caller may access the object it points at.

- Swap test: create same kind of object with two accounts/tenants, replay each request under other session's identifiers. Cover reads and writes (`GET`, `PUT`, `PATCH`, `DELETE`); ownership check on `GET` next to unchecked `PUT` on same resource is common.
- Prefer identifiers other session can already observe (list responses, error messages, notification links) over guessing; include nested routes such as `/users/{id}/orders/{id}`, where authorization often enforced only for outer resource.
- Test vertical escalation too: low-privilege token against owner-only or administrator-only operations of same API. Whether a role may call such operation at all = Broken Function Level Authorization (API5:2023), separate check from BOLA per-object access.
- Repeat for every object type the API exposes; object is wherever a request identifier ends up, not only obvious profile/order endpoints.

Prevention: [Insecure Direct Object Reference Prevention Cheat Sheet](Insecure_Direct_Object_Reference_Prevention.md), [Authorization Cheat Sheet](Authorization.md); test methodology: WSTG IDOR test.

## Mass Assignment in JSON APIs

Frameworks binding JSON request body directly to internal object make [mass assignment](Mass_Assignment.md) testable with single request: anything client sends may be written, incl. unadvertised fields.

- Take normal create/update request, add fields outside contract (role, verification flag, internal identifier), read object back to see whether stored. Repeat for nested objects, arrays, each update verb, incl. partial-update endpoints.
- Confirm effect, not just reflection: echoed field means little until following request shows it persisted and changed behavior.
- Treat every field server accepts but schema does not define as candidate (see OpenAPI section above).

Weakness classification: CWE-915.

## Rate Limiting and Throttling Assessment

Missing/weak limits let attacker guess credentials, harvest data, consume capacity at will; API4:2023 Unrestricted Resource Consumption.

- Drive authentication, token, account recovery endpoints; check throttling engages. Without it, password guessing and [credential stuffing](Credential_Stuffing_Prevention.md) stay cheap. Compare with [login throttling](Authentication.md#login-throttling) expectations for web apps.
- Exercise expensive operations (search, export, bulk writes); note whether any limit applies. Request-frequency throttling does not bound work within single request → check what one request can cost.
- Identify limit key: per-IP limit worked around by changing address, so per-account or per-API-key limits must still hold; authenticated session must not disable them.
- Record observed limit, trigger point, response returned → each finding states missing control precisely.

## Related Resources

[REST Security Cheat Sheet](REST_Security.md): implementation guidance matching these assessment topics.

## References

- RFC 8725: JSON Web Token Best Current Practices
- RFC 6750: OAuth 2.0 Bearer Token Usage
