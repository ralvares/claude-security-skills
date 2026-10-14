# NoSQL Security Cheat Sheet

## Introduction

NoSQL databases (MongoDB, CouchDB, Cassandra etc.) power many modern apps: flexible schemas, horizontal scale.
Guidance to reduce risk using NoSQL systems.

## Threats & Common Failure Modes

- **NoSQL Injection** — unsafe construction of query objects/strings from untrusted input.
- **Exposed Management Interfaces** — admin GUIs, database ports, REST endpoints exposed to internet.
- **Weak/No Authentication & Authorization** — default open access or excessive client privileges.
- **Insecure Network Exposure** — no TLS, open ports, insufficient network segmentation.
- **Insecure Defaults** — default admin accounts/passwords, unsecured configs.
- **Poor Access Control Models** — coarse roles allowing lateral abuse.
- **Insecure Serialization / Deserialization** — remote code execution via unsafe object deserialization.
- **Misconfigured CORS / Public APIs** — APIs accidentally allow cross-origin requests/wide access.
- **Credential & Secret Leaks** — hardcoded DB credentials in code, images, CI logs.
- **Unsafe Backup Exposure** — backups unencrypted or publicly accessible.
- **Supply-chain / Dependency Risks** — vulnerable drivers, ORMs/ODMs, plugins.

## Secure-by-Design Principles

- **Treat all input as untrusted** — validate, sanitize, normalize.
- **Least privilege** — narrow roles for users, services, operators.
- **Defense in depth** — combine network controls, auth, input validation, monitoring.
- **Secure defaults** — change default ports/accounts; enable auth + TLS by default.
- **Automate secrets & rotation** — vaults, short-lived credentials.
- **Monitor & audit** — log access, detect anomalies.

## Practical Defenses & Examples

### Prevent NoSQL Injection

**Unsafe (string-based filter building — Node.js / MongoDB):**

```js
// DANGEROUS: building query from untrusted input
const q = "{ name: '" + req.query.name + "' }";
const filter = eval("(" + q + ")"); // NEVER do this
db.collection('users').find(filter)
```

**Safe (use driver query objects / parameterization):**

Building query object does not prevent operator injection when untrusted value is itself an object. E.g., MongoDB interprets `{ name: { $ne: "" } }` as not-equal query. Validate expected scalar type before constructing filter; never pass client-supplied objects through as field values.

```js
const name = req.query.name;
if (typeof name !== 'string') throw new Error("Invalid name");
const filter = { name };
db.collection('users').find(filter)
```

**Additional pattern rejection:**

```js
// Reject a pattern in the serialized request body.
if (JSON.stringify(req.body).includes('"$')) throw Error("Invalid input");
```

This `JSON.stringify()` check = denylist, not operator allowlist. Also rejects ordinary string values starting with `$`; does not validate allowed fields/types. Use [field-specific validation](Input_Validation.md#input-validation-strategies) before building queries.

Notes:

- Do **not** accept raw JSON fragments from client to execute as queries.
- Disallow client-controlled query operators (like `$where`, `$regex`, `$expr`) unless strictly required + validated.
- Text search params: use safe driver APIs (e.g., `$text` w/ controlled input).

### Use Secure Driver / ODM Patterns

- Prefer high-level APIs (ODM/ORM) building queries safely (e.g., Mongoose, Spring Data, Datastax driver patterns).
- Avoid `.eval()`-like functionality + raw query execution from untrusted data.
- Sanitize + validate any raw expressions before passing to DB.

#### Example — PyMongo safe usage

```python
from pymongo import MongoClient
client = MongoClient(uri, tls=True)
collection = client.mydb.users
if not isinstance(email_input, str):
    raise ValueError("Invalid email")
user = collection.find_one({"email": email_input})
```

### Authentication & Authorization

- **Enable authentication** (never run databases unauthenticated).
- **Role-based access control (RBAC)**, least privilege for service accounts.
- **Separate users** for admin/backup/readonly/application.
- Identity federation or short-lived credentials when supported (e.g., AWS IAM -> DynamoDB).

See: Authentication Cheat Sheet; Authorization Cheat Sheet

### Network & Transport Security

- **Bind services to internal interfaces**, not `0.0.0.0`.
- **Network segmentation / private subnets** + security groups.
- **Enforce TLS** (in transit encryption) for driver connections + admin consoles.
- Turn off remote management or restrict to admin networks/VPNs.

### Configuration Hardening

- Change default ports; disable sample/demo users.
- Turn off/restrict features executing code on server, e.g., MongoDB server-side JavaScript.
- Require TLS for internal replication links where supported.

### Secrets Management

- Do **not** hardcode DB credentials — use secret manager (Vault, AWS Secrets Manager, Azure Key Vault).
- Avoid baking credentials into container images or env vars in CI logs.
- Rotate credentials regularly; ephemeral tokens when possible.

### Logging, Monitoring & Auditing

- Enable audit logging (connection attempts, admin actions, failed auth).
- Send logs to tamper-evident SIEM.
- Alert on anomalous patterns (query spikes, slow queries, large data exports).
- Monitor suspicious commands (e.g., admin actions, `$where`, map-reduce jobs).

### Backups & Snapshots

- Encrypt backups at rest + in transfer.
- Restrict access to backup storage.
- Sanitize backups for PII as policy requires.
- Validate restore procedures regularly.

## Quick NoSQL Security Checklist

- Enable authentication & RBAC
- Enforce TLS for client + node communication
- Bind DB to internal IPs / private networks
- Least privilege service accounts
- Disallow client-controlled query operators unless validated
- Avoid raw query execution / eval on server
- Credentials in secret manager; rotate
- Harden configs (disable unsafe defaults)
- Encrypt + secure backups
- Monitor/audit DB access + admin actions
- Keep DB + drivers patched

## Do’s and Don’ts

**Do**:

- Use driver query objects, not query strings.
- Validate + whitelist user-supplied fields (columns/keys).
- Restrict management interfaces; require MFA for admin access.
- Automate security testing in CI/CD pipelines.

**Don’t**:

- Expose DB ports/admin consoles to public Internet.
- Accept raw JSON queries from clients or eval untrusted strings.
- Use root/admin DB accounts for app connections.
- Rely only on network controls to protect badly written queries.

## Examples of Dangerous Patterns (brief)

- Client-controlled `$where` expressions execute untrusted JavaScript inside MongoDB; can consume excessive resources. Use standard query operators; disable server-side scripting when not needed.
- Concatenating user input into query language strings or shell commands for DB tools.
- MongoDB unsecured (no auth) listening on public IP.

## References

- MongoDB: Security Checklist for Self-Managed Deployments
- Amazon DynamoDB: Preventative Security Best Practices
- WSTG - Testing for NoSQL Injection
