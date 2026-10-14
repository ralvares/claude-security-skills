# Application Logging Vocabulary Cheat Sheet

Standard vocabulary for logging security events. Intent: simplify monitoring/alerting; developers trap errors and log using this vocabulary → monitoring/alerting improves by keying on these terms.

## Overview

Each year IBM Security commissions Ponemon Institute to survey companies worldwide on security breaches, mitigation, costs: Cost of a Data Breach Report.

Besides millions of dollars lost, report finds **mean time to identify** a breach still around **200 days**. Better application monitoring + anomaly alerting would improve time to identify and mitigate attacks.

![IBM Cost of Data Breach Report 2025](../assets/cost-of-breach-2025.png)

> IBM Cost of a Data Breach Report 2025, Fig.4, pg.12

Standard defines specific keywords which, applied consistently across software, let groups monitor these event terms across all applications and respond quickly to attack.

## Assumptions

- Observability/SRE groups must support standard, encourage developer use
- Incident Response must ingest this data OR provide means for other monitoring teams to send alert notification, preferably programmatically.
- Architects must support, adopt, contribute to standard
- Developers must embrace standard, begin implementing (requires knowledge + intent to understand potential attacks and trap those errors in code).

## Getting Started

Goal of logging: alert on specific security events. First step is good error handling; untrapped events can't be logged.

### Identifying Events

Good high-level understanding of threat modeling helps, even simple approach:

1. **What could go wrong?**

- Orders: could someone order on behalf of another?
- Authentication: could I log in as someone else?
- Authorization: could I see someone else' account?

2. **What would happen if it did?**

- Orders: I've placed order on behalf of another... to abandoned warehouse in New Jersey. Oops.
- Then I bragged about it on 4Chan.
- Then I told the New York Times about it.

3. **Who might intend to do this?**

- Intentional attacks by hackers.
- Employee "testing" how things work.
- API coded incorrectly doing things author didn't intend.

### Implementation

Libraries easing adoption of this vocabulary:

- Python: lucabello/owasp-logger
- C#/.NET: byteguard-hq/byteguard-security-logger
- Python / Java / Go / Node.js: thatsjet/security_event_logger

## Format

_NOTE: Log all dates in ISO 8601 format **WITH** UTC offset for maximum portability_

```
{
    "datetime": "2021-01-01T01:01:01-0700",
    "appid": "foobar.netportal_auth",
    "event": "AUTHN_login_success:joebob1",
    "level": "INFO",
    "description": "User joebob1 login successfully",
    "useragent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/78.0.3904.108 Safari/537.36",
    "source_ip": "165.225.50.94",
    "host_ip": "10.12.7.9",
    "hostname": "portalauth.foobar.com",
    "protocol": "https",
    "port": "440",
    "request_uri": "/api/v2/auth/",
    "request_method": "POST",
    "region": "AWS-US-WEST-2",
    "geo": "USA"
}
```

## The Vocabulary

Event types to capture. Each has prefix like "authn" and additional data that may be included.

Examples show portions of full logging format; complete event log follows format above.

**Note on Data Privacy:**

All fields logged after event type optional. Weigh value of logged fields vs. responsibility as data steward. E.g. user IP address useful for detection/response, but may be personally identifiable information when combined with other data, subject to regulation or deletion requests.

## Authentication [AUTHN]

### authn_login_success[:userid]

**Description** Record all login events incl. success.

**Level:** INFO

**Example:**

```
{
    "datetime": "2019-01-01 00:00:00,000",
    "appid": "foobar.netportal_auth",
    "event": "authn_login_success:joebob1",
    "level": "INFO",
    "description": "User joebob1 login successfully",
    ...
}
```

### authn_login_successafterfail[:userid,retries]

**Description** User successfully logged in after previously failing.

**Level:** INFO

**Example:**

```
{
    "datetime": "2019-01-01 00:00:00,000",
    "appid": "foobar.netportal_auth",
    "event": "authn_login_successafterfail:joebob1,2",
    "level": "INFO",
    "description": "User joebob1 login successfully",
    ...
}
```

### authn_login_fail[:userid]

**Description** Record all login events incl. failure.

**Level:** WARN

**Example:**

```
{
    "datetime": "2019-01-01 00:00:00,000",
    "appid": "foobar.netportal_auth",
    "event": "authn_login_fail:joebob1",
    "level": "WARN",
    "description": "User joebob1 login failed",
    ...
}
```

### authn_login_fail_max[:userid,maxlimit(int)]

**Description** Record all login events incl. failure.

**Level:** WARN

**Example:**

```
{
    "datetime": "2019-01-01 00:00:00,000",
    "appid": "foobar.netportal_auth",
    "event": "authn_login_fail_max:joebob1,3",
    "level": "WARN",
    "description": "User joebob1 reached the login fail limit of 3",
    ...
}
```

### authn_login_lock[:userid,reason]

**Description** Feature locks account after x retries or other condition → log lock with relevant data.

**Level:** WARN

**Reasons:**

- maxretries: maximum retries reached
- suspicious: suspicious activity observed on account
- customer: customer requested account lock
- other: Other

**Example:**

```
{
    "datetime": "2019-01-01 00:00:00,000",
    "appid": "foobar.netportal_auth",
    "event": "authn_login_lock:joebob1,maxretries",
    "level": "WARN",
    "description": "User joebob1 login locked because maxretries exceeded",
    ...
}
```

### authn_password_change[:userid]

**Description** Log every password change, incl. userid it was for.

**Level:** INFO

**Example:**

```
{
    "datetime": "2019-01-01 00:00:00,000",
    "appid": "foobar.netportal_auth",
    "event": "authn_password_change:joebob1",
    "level": "INFO",
    "description": "User joebob1 has successfully changed their password",
    ...
}
```

### authn_password_change_fail[:userid]

**Description** Failed attempt to change password. May also trigger other events such as `authn_login_lock`.

**Level:** CRITICAL

**Example:**

```
{
    "datetime": "2019-01-01 00:00:00,000",
    "appid": "foobar.netportal_auth",
    "event": "authn_password_change_fail:joebob1",
    "level": "CRITICAL",
    "description": "User joebob1 failed to change their password",
    ...
}
```

### authn_impossible_travel[:userid,region1,region2]

**Description** User logged in from one city suddenly appears in another, too far to travel in reasonable timeframe → often potential account takeover.

**Level:**: CRITICAL

**Example:**

```
{
    "datetime": "2019-01-01 00:00:00,000",
    "appid": "foobar.netportal_auth",
    "event": "authn_impossible_travel:joebob1,US-OR,CN-SH",
    "level": "CRITICAL",
    "description": "User joebob1 has accessed the application in two distant cities at the same time",
    ...
}
```

### authn_token_created[:userid, entitlement(s)]

**Description** Record token creation for service access

**Level:**: INFO

**Example:**

```
{
    "datetime": "2019-01-01 00:00:00,000",
    "appid": "aws.foobar.com",
    "event": "authn_token_created:app.foobarapi.prod,create,read,update",
    "level": "INFO",
    "description": "A token has been created for app.foobarapi.prod with create,read,update",
    ...
}
```

### authn_token_revoked[:userid,tokenid]

**Description** Token revoked for given account.

**Level:**: INFO

**Example:**

```
{
    "datetime": "2019-01-01 00:00:00,000",
    "appid": "aws.foobar.com",
    "event": "authn_token_revoked:app.foobarapi.prod,xyz-abc-123-gfk",
    "level": "INFO",
    "description": "Token ID: xyz-abc-123-gfk was revoked for user app.foobarapi.prod",
    ...
}
```

### authn_token_reuse[:userid,tokenid]

**Description** Attempted reuse of previously revoked token.

**Level:**: CRITICAL

**Example:**

```
{
    "datetime": "2019-01-01 00:00:00,000",
    "appid": "aws.foobar.com",
    "event": "authn_token_reuse:app.foobarapi.prod,xyz-abc-123-gfk",
    "level": "CRITICAL",
    "description": "User app.foobarapi.prod attempted to use token ID: xyz-abc-123-gfk which was previously revoked",
    ...
}
```

### authn_token_delete[:appid]

**Description** Record token deletion

**Level:**: WARN

**Example:**

```
{
    "datetime": "2019-01-01 00:00:00,000",
    "appid": "foobar.netportal_auth",
    "event": "authn_token_delete:foobarapi",
    "level": "WARN",
    "description": "The token for foobarapi has been deleted",
    ...
}
```

## Authorization [AUTHZ]

### authz_fail[:userid,resource]

**Description** Attempt to access unauthorized resource

**Level:**: CRITICAL

**Example:**

```
{
    "datetime": "2019-01-01 00:00:00,000",
    "appid": "foobar.netportal_auth",
    "event": "authz_fail:joebob1,resource",
    "level": "CRITICAL",
    "description": "User joebob1 attempted to access a resource without entitlement",
    ...
}
```

### authz_change[:userid,from,to]

**Description** User or entity entitlements changed

**Level:**: WARN

**Example:**

```
{
    "datetime": "2019-01-01 00:00:00,000",
    "appid": "foobar.netportal_auth",
    "event": "authz_change:joebob1,user,admin",
    "level": "WARN",
    "description": "User joebob1 access was changed from user to admin",
    ...
}
```

### authz_admin[:userid,event]

**Description** Record all activity by privileged users such as admin.

**Level:**: WARN

**Example:**

```
{
    "datetime": "2019-01-01 00:00:00,000",
    "appid": "foobar.netportal_auth",
    "event": "authz_admin:joebob1,user_privilege_change",
    "level": "WARN",
    "description": "Administrator joebob1 has updated privileges of user foobarapi from user to admin",
    ...
}
```

## Encryption/Decryption [CRYPT]

### crypt_decrypt_fail[userid]

**Description** Encryption/decryption failure may be simply system error, or related to authorization failures where user lacks permissions on related data.

**Level:**: WARN

**Example:**

```
{
    "datetime": "2019-01-01 00:00:00,000",
    "appid": "foobar.netportal_auth",
    "event": "crypt_decrypt_fail:joebob1",
    "level": "WARN",
    "description": "User joebob1 was unable to perform decryption" + err,
    ...
}
```

### crypt_encrypt_fail[userid]

**Description** Encryption/decryption failure may be simply system error, or related to authorization failures where user lacks permissions on related data.

**Level:**: WARN

**Example:**

```
{
    "datetime": "2019-01-01 00:00:00,000",
    "appid": "foobar.netportal_auth",
    "event": "crypt_encrypt_fail:joebob1",
    "level": "WARN",
    "description": "User joebob1 was unable to perform encryption" + err,
    ...
}
```

## Excessive Use [EXCESS]

### excess_rate_limit_exceeded[userid,max]

**Description** Establish expected service limit ceilings, alert when exceeded, even if only for managing costs and scaling.

**Level:**: WARN

**Example:**

```
{
    "datetime": "2019-01-01 00:00:00,000",
    "appid": "foobar.netportal_auth",
    "event": "excess_rate_limit_exceeded:app.foobarapi.prod,100000",
    "level": "WARN",
    "description": "User app.foobarapi.prod has exceeded max:100000 requests",
    ...
}
```

### excess_sessions_exceeded[userid,max]

**Description** Log user exceeding maximum concurrent sessions allowed. Unusually high concurrent-session count can indicate credential sharing or account takeover.

**Level:**: WARN

**Example:**

```
{
    "datetime": "2019-01-01 00:00:00,000",
    "appid": "foobar.netportal_auth",
    "event": "excess_sessions_exceeded:app.foobarapi.prod,5",
    "level": "WARN",
    "description": "User app.foobarapi.prod exceeded the max of 5 concurrent sessions",
    ...
}
```

## File Upload [UPLOAD]

### upload_complete[userid,filename,type]

**Description** Successful file upload: first validation step = upload completed.

**Level:**: INFO

**Example:**

```
    {
    "datetime": "2019-01-01 00:00:00,000",
    "appid": "foobar.netportal_auth",
    "event": "upload_complete:joebob1,user_generated_content.png,PNG",
    "level": "INFO",
    "description": "User joebob1 has uploaded user_generated_content.png",
    ...
}
```

### upload_stored[filename,from,to]

**Description** Good file upload validation: move/rename file; when serving content back to end users, never reference original filename in download. Applies to filesystem and block storage.

**Level:**: INFO

**Example:**

```
{
    "datetime": "2019-01-01 00:00:00,000",
    "appid": "foobar.netportal_auth",
    "event": "upload_stored:user_generated_content.png,kjsdhkrjhwijhsiuhdf000010202002",
    "level": "INFO",
    "description": "File user_generated_content.png was stored in the database with key abcdefghijk101010101",
    ...
}
```

### upload_validation[filename,(virusscan|imagemagick|...):(FAILED|incomplete|passed)]

**Description** Validate all file uploads for correctness (is in fact file type x) and safety (no virus).

**Level:**: INFO|CRITICAL

**Example:**

```
{
    "datetime": "2019-01-01 00:00:00,000",
    "appid": "foobar.netportal_auth",
    "event": "upload_validation:filename,virusscan:FAILED",
    "level": "CRITICAL",
    "description": "File user_generated_content.png FAILED virus scan and was purged",
    ...
}
```

### upload_delete[userid,fileid]

**Description** Record file deletion for normal reasons.

**Level:**: INFO

**Example:**

```
{
    "datetime": "2019-01-01 00:00:00,000",
    "appid": "foobar.netportal_auth",
    "event": "upload_delete:joebob1,",
    "level": "INFO",
    "description": "User joebob1 has marked file abcdefghijk101010101 for deletion.",
    ...
}
```

## Input Validation [INPUT]

### input_validation_fail:[(fieldone,fieldtwo...),userid]

**Description** Server-side input validation failure means a) insufficient client validation, or b) client-side validation bypassed. Either way = attack opportunity; mitigate quickly.

**Level:** WARN

**Example:**

```
{
    "datetime": "2019-01-01 00:00:00,000",
    "appid": "foobar.netportal_auth",
    "event": "input_validation_fail:(zip,date_of_birth),joebob1",
    "level": "WARN",
    "description": "User joebob1 submitted data that failed validation.",
    ...
}
```

### input_validation_discrete_fail[:field,userid]

**Description** Server-side validation failure of value against discrete list of options (e.g. drop down list, radio buttons) strongly indicates malicious activity: client-side code tampered with.

**Level:** WARN

**Example:**

```json
{
    "datetime": "2021-02-01T08:30:00-0500",
    "appid": "foobar.netportal_auth",
    "event": "input_validation_discrete_fail:country,joebob1",
    "level": "WARN",
    "description": "User joebob1 submitted an invalid value for the 'country' field.",
    ...
}
```

## Malicious Behavior [MALICIOUS]

### malicious_excess_404:[userid|IP,useragent]

**Description** Numerous requests for nonexistent files often indicate "force-browse" attempts for files that could exist; often malicious intent.

**Level:** WARN

**Example:**

```
{
    "datetime": "2019-01-01 00:00:00,000",
    "appid": "foobar.netportal_auth",
    "event": "malicious_excess404:123.456.789.101,M@l1c10us-Hax0rB0t0-v1",
    "level": "WARN",
    "description": "A user at 123.456.789.101 has generated a large number of 404 requests.",
    ...
}
```

### malicious_extraneous:[userid|IP,inputname,useragent]

**Description** User submits data backend handler didn't expect → can indicate probing for input validation errors. Backend service receiving data it doesn't handle or have input for = likely malicious abuse.

**Level:** CRITICAL

**Example:**

```
{
    "datetime": "2019-01-01 00:00:00,000",
    "appid": "foobar.netportal_auth",
    "event": "malicious_extraneous:dr@evil.com,creditcardnum,Mozilla/5.0 (X11; Linux x86_64; rv:10.0) Gecko/20100101 Firefox/10.0",
    "level": "CRITICAL",
    "description": "User dr@evil.com included field creditcardnum in the request which is not handled by this service.",
    ...
}
```

### malicious_attack_tool:[userid|IP,toolname,useragent]

**Description** Log obvious attack tools identified by signature or user agent.

E.g. tool "Nikto" leaves default user agent string like **_"Mozilla/5.00 (Nikto/2.1.6) (Evasions:None) (Test:Port Check)"_**

**Level:** CRITICAL

**Example:**

```
{
    "datetime": "2019-01-01 00:00:00,000",
    "appid": "foobar.netportal_auth",
    "event": "malicious_attack_tool:127.0.0.1,nikto,Mozilla/5.00 (Nikto/2.1.6) (Evasions:None) (Test:Port Check)",
    "level": "CRITICAL",
    "description": "Attack traffic indicating use of Nikto coming from 127.0.0.1",
    ...
}
```

### malicious_sqli:[userid|IP,parameter,ruleid,useragent]

**Description** Request input matches SQL injection (SQLi) signature or heuristic → log suspected attempt. Configure blocking under tested policy; tune false positives for the application; detection match isn't proof of exploitation. Use [parameterized queries and the other primary SQL injection defenses](SQL_Injection_Prevention.md#primary-defenses) regardless of detection rules.

_NOTE: Logging payload dangerous; may cause log injection. Prefer recording detection rule ID / category and parameter name over full payload._

**Level:** CRITICAL

**Example:**

```
{
    "datetime": "2019-01-01 00:00:00,000",
    "appid": "foobar.netportal_auth",
    "event": "malicious_sqli:127.0.0.1,search,SQLI-UNION,Mozilla/5.0 (X11; Linux x86_64; rv:10.0) Gecko/20100101 Firefox/10.0",
    "level": "CRITICAL",
    "description": "Request from 127.0.0.1 contained a SQL injection pattern (rule SQLI-UNION) in parameter 'search'.",
    ...
}
```

### malicious_cors:[userid|IP,useragent,referer]

**Description** Block attempts from unauthorized origins, and log whenever possible. Even blocked illegal cross-origin request may indicate attack.

_NOTE: "referer" misspelled in original HTTP specification; correct spelling "referrer", but typo persists and used here intentionally._

**Level:** CRITICAL

**Example:**

```
{
    "datetime": "2019-01-01 00:00:00,000",
    "appid": "foobar.netportal_auth",
    "event": "malicious_cors:127.0.0.1,Mozilla/5.0 (X11; Linux x86_64; rv:10.0) Gecko/20100101 Firefox/10.0,attack.evil.com",
    "level": "CRITICAL",
    "description": "An illegal cross-origin request from 127.0.0.1 was referred from attack.evil.com"
    ...
}
```

### malicious_direct_reference:[userid|IP, useragent]

**Description** Common attack on authentication/authorization: directly access object without credentials or appropriate access authority. Failing to prevent this was once OWASP Top Ten item **Insecure Direct Object Reference**. Assuming attack correctly prevented, logging attempt still valuable to identify malicious users.

**Level:** CRITICAL

**Example:**

```
{
    "datetime": "2019-01-01 00:00:00,000",
    "appid": "foobar.netportal_auth",
    "event": "malicious_direct_reference:joebob1, Mozilla/5.0 (X11; Linux x86_64; rv:10.0) Gecko/20100101 Firefox/10.0",
    "level": "CRITICAL",
    "description": "User joebob1 attempted to access an object to which they are not authorized",
    ...
}
```

### malicious_csrf:[userid|IP]

**Description** State-changing request without valid anti-CSRF token (or mismatched token, Origin, or Referer) may indicate cross-site request forgery attempt. Block request, log attempt. See OWASP Cross-Site Request Forgery Prevention Cheat Sheet for token and Origin/Referer validation guidance.

**Level:** WARN

**Example:**

```
{
    "datetime": "2019-01-01 00:00:00,000",
    "appid": "foobar.netportal_auth",
    "event": "malicious_csrf:joebob1",
    "level": "WARN",
    "description": "A state-changing request from joebob1 was missing a valid anti-CSRF token",
    ...
}
```

### malicious_csp_violation:[userid|IP,effective_directive,blocked_uri,useragent]

**Description** Browser reports Content-Security-Policy violation to report endpoint → log violation. Report-Only mode high-noise (browser extensions, injected third-party scripts trigger benign violations) → WARN appropriate; promote to CRITICAL only if enforced-mode blocks treated as attack signal.

_NOTE: CSP report fields such as `document-uri`, `referrer`, `blocked-uri` are URL-valued (W3C Content Security Policy Level 3 violation report definition), routinely contain full URLs whose query strings carry session or reset tokens. Strip query string/fragment before logging; prefer effective-directive + blocked-uri (origin+path) over full report body to avoid secondary sensitive-data or log-injection risk._

**Level:** WARN

**Example:**

```
{
    "datetime": "2019-01-01 00:00:00,000",
    "appid": "foobar.netportal_auth",
    "event": "malicious_csp_violation:203.0.113.7,script-src,https://foobar.com/dashboard,Mozilla/5.0",
    "level": "WARN",
    "description": "A CSP violation for directive script-src was reported by a browser at 203.0.113.7",
    ...
}
```

## MCP Servers [MCP]

Concerns about MCP servers used within productivity applications or at enterprise level.

### mcp_prompt_injection[:userid]

**Description** MCP client/server detects prompt injection indicators (e.g. instructions to ignore system/developer messages, attempts to override tool policies, requests to reveal secrets, attempts to coerce tool calls outside intended task) → block or constrain action, log event for investigation.

_NOTE: Avoid logging full prompt/tool I/O. Prefer logging detection category or rule ID, target tool/server, request identifiers to support triage without secondary sensitive-data or log-injection risk._

**Level:** WARN

**Example:**

```
{
    "datetime": "2019-01-01 00:00:00,000",
    "appid": "foobar.cooldevapp_mcp_toolname",
    "event": "mcp_prompt_injection:joebob1",
    "level": "WARN",
    "description": "A possible prompt injection has occurred",
    ...
}
```

### mcp_resource_exhaustion[:userid]

**Description** MCP client/server detects request pattern intended to exhaust resources (e.g. unusually large prompts, repeated retries, tool-call loops, other behavior driving excessive token usage and cost) → terminate or throttle activity, log attempt.

_NOTE: Avoid logging full prompts or tool inputs/outputs. Prefer logging measured usage (tokens in/out), policy thresholds, request identifiers, tool/model involved._

**Level:** WARN

**Example:**

```
{
    "datetime": "2019-01-01 00:00:00,000",
    "appid": "foobar.cooldevapp_mcp_toolname",
    "event": "mcp_resource_exhaustion:joebob1",
    "level": "WARN",
    "description": "Request blocked due to token budget overrun (tokens_in=18240, tokens_out=0, budget=8000)",
    ...
}
```

### mcp_tool_poisoning[:userid]

**Description** MCP client/server detects tool may be malicious or tampered with (e.g. unexpected tool changes, signature/hash verification failures, suspicious tool metadata, tool sourced from agent/tool marketplace with minimal validation) → block or quarantine tool, log attempt.

_NOTE: Tool ecosystems and agent marketplaces can enable rapid proliferation of third-party tools with relatively low validation. Internal marketplace or hashed allowlist for approved tools highly recommended._

**Level:** WARN

**Example:**

```
{
    "datetime": "2019-01-01 00:00:00,000",
    "appid": "foobar.cooldevapp_mcp_toolname",
    "event": "mcp_tool_poisoning:joebob1",
    "level": "WARN",
    "description": "Tool execution blocked (tool=\"calendar_sync\", source=\"https://marketplace.example/tools/calendar_sync\", version=\"2.4.1\", signature=\"missing\", policy=\"allowlist_required\")",
    ...
}
```

## Privilege Changes [PRIVILEGE]

Object privilege changes such as read/write/execute permissions or objects in database having authorization meta-information changed.

User/account changes covered in User Management section.

### privilege_permissions_changed:[userid,file|object,fromlevel,tolevel]

**Description** Tracking changes to objects with access control restrictions can uncover privilege escalation attempts on those files by unauthorized users.

**Level:** WARN

**Example:**

```
{
    "datetime": "2019-01-01 00:00:00,000",
    "appid": "foobar.netportal_auth",
    "event": "permissions_changed:joebob1, /users/admin/some/important/path,0511,0777",
    "level": "WARN",
    "description": "User joebob1 changed permissions on /users/admin/some/important/path",
    ...
}
```

## Sensitive Data Changes [DATA]

Needn't log/alert on changes to all files, but monitor and alert on changes to highly sensitive files or data.

### sensitive_create:[userid,file|object]

**Description** Log creation of new data marked sensitive or placed in directory/table/repository storing sensitive data; review periodically.

**Level:** WARN

**Example:**

```
{
    "datetime": "2019-01-01 00:00:00,000",
    "appid": "foobar.netportal_auth",
    "event": "sensitive_create:joebob1, /users/admin/some/important/path",
    "level": "WARN",
    "description": "User joebob1 created a new file in /users/admin/some/important/path",
    ...
}
```

### sensitive_read:[userid,file|object]

**Description** Log access to all data marked sensitive or placed in directory/table/repository storing sensitive data; review periodically.

**Level:** WARN

**Example:**

```
{
    "datetime": "2019-01-01 00:00:00,000",
    "appid": "foobar.netportal_auth",
    "event": "sensitive_read:joebob1, /users/admin/some/important/path",
    "level": "WARN",
    "description": "User joebob1 read file /users/admin/some/important/path",
    ...
}
```

### sensitive_update:[userid,file|object]

**Description** Log updates to all data marked sensitive or placed in directory/table/repository storing sensitive data; review periodically.

**Level:** WARN

**Example:**

```
{
    "datetime": "2019-01-01 00:00:00,000",
    "appid": "foobar.netportal_auth",
    "event": "sensitive_update:joebob1, /users/admin/some/important/path",
    "level": "WARN",
    "description": "User joebob1 modified file /users/admin/some/important/path",
    ...
}
```

### sensitive_delete:[userid,file|object]

**Description** Log + periodically review deletion events for sensitive files/data. Record action and object identifier without copying sensitive contents into log. Retain underlying data per applicable information-retention requirements (NIST SI-12), then securely dispose of it and retained copies when no longer needed (SI-12(3)). Keep deletion audit record per [log retention and disposal requirements](Logging.md#disposal-of-logs); recording deletion event doesn't itself require archiving deleted file.

**Level:** WARN

**Example:**

```
{
    "datetime": "2019-01-01 00:00:00,000",
    "appid": "foobar.netportal_auth",
    "event": "sensitive_delete:joebob1, /users/admin/some/important/path",
    "level": "WARN",
    "description": "User joebob1 deleted file /users/admin/some/important/path",
    ...
}
```

## Sequence Errors [SEQUENCE]

Aka **_business logic attack_**: expected path through system, attempt to skip or change path order → could indicate malicious intent.

### sequence_fail:[userid]

**Description** User reaches part of application out of sequence → may indicate intentional business logic abuse; track.

**Level:** CRITICAL

**Example:**

```
{
    "datetime": "2019-01-01 00:00:00,000",
    "appid": "foobar.netportal_auth",
    "event": "sequence_fail:joebob1",
    "level": "CRITICAL",
    "description": "User joebob1 has reached a part of the application out of the normal application flow.",
    ...
}
```

## Session Management [SESSION]

### session_created:[userid]

**Description** New authenticated session created → may log and monitor activity.

**Level:** INFO

**Example:**

```
    {
    "datetime": "2019-01-01 00:00:00,000",
    "appid": "foobar.netportal_auth",
    "event": "session_created:joebob1",
    "level": "INFO",
    "description": "User joebob1 has started a new session",
    ...
}
```

### session_renewed:[userid]

**Description** User warned session will expire/be revoked and chooses to extend → log activity. System with highly confidential data: extending session may require additional verification.

**Level:** INFO

**Example:**

```
{
    "datetime": "2019-01-01 00:00:00,000",
    "appid": "foobar.netportal_auth",
    "event": "session_renewed:joebob1",
    "level": "INFO",
    "description": "User joebob1 was warned of expiring session and extended.",
    ...
}
```

### session_expired:[userid,reason]

**Description** Session expires, esp. authenticated session or one with sensitive data → may log expiry with clarifying data. Reason code may be e.g. logout, timeout, revoked. Never delete sessions; expire them on revocation requirement.

**Level:** INFO

**Example:**

```
{
    "datetime": "2019-01-01 00:00:00,000",
    "appid": "foobar.netportal_auth",
    "event": "session_expired:joebob1,revoked",
    "level": "INFO",
    "description": "User joebob1 session expired due to administrator revocation.",
    ...
}
```

### session_logout:[userid]

**Description** User explicitly logs out (not timeout or administrative revocation) → event may be logged. More explicit alternative to `session_expired:[userid,logout]` for systems distinguishing user-initiated logout. Don't include raw session ID or bearer token. Session correlation needed: follow [Session Management logging guidance](Session_Management.md#logging-sessions-life-cycle-monitoring-creation-usage-and-destruction-of-session-ids).

**Level:** INFO

**Example:**

```
{
    "datetime": "2019-01-01 00:00:00,000",
    "appid": "foobar.netportal_auth",
    "event": "session_logout:joebob1",
    "level": "INFO",
    "description": "User joebob1 logged out",
    ...
}
```

### session_use_after_expire:[userid]

**Description** User attempts access with expired session → may help to log, esp. with subsequent login failure. Could identify malicious user attempting session hijack or directly accessing another person's machine/browser.

**Level:** CRITICAL

**Example:**

```
{
    "datetime": "2019-01-01 00:00:00,000",
    "appid": "foobar.netportal_auth",
    "event": "session_use_after_expire:joebob1",
    "level": "CRITICAL",
    "description": "User joebob1 attempted access after session expired.",
    ...
}
```

## System Events [SYS]

### sys_startup:[userid]

**Description** System first started: valuable to log startup, even if serverless or container, esp. if user who initiated system loggable.

**Level:** WARN

**Example:**

```
{
    "datetime": "2019-01-01 00:00:00,000",
    "appid": "foobar.netportal_auth",
    "event": "sys_startup:joebob1",
    "level": "WARN",
    "description": "User joebob1 spawned a new instance",
    ...
}
```

### sys_shutdown:[userid]

**Description** System shut down: valuable to log event, even if serverless or container, esp. if user who initiated loggable.

**Level:** WARN

**Example:**

```
{
    "datetime": "2019-01-01 00:00:00,000",
    "appid": "foobar.netportal_auth",
    "event": "sys_shutdown:joebob1",
    "level": "WARN",
    "description": "User joebob1 stopped this instance",
    ...
}
```

### sys_restart:[userid]

**Description** System restarted: valuable to log event, even if serverless or container, esp. if user who initiated loggable.

**Level:** WARN

**Example:**

```
{
    "datetime": "2019-01-01 00:00:00,000",
    "appid": "foobar.netportal_auth",
    "event": "sys_restart:joebob1",
    "level": "WARN",
    "description": "User joebob1 initiated a restart",
    ...
}
```

### sys_crash[:reason]

**Description** If possible to catch unstable condition causing system crash, log event; helpful esp. if triggered by attack.

**Level:** WARN

**Example:**

```
{
    "datetime": "2019-01-01 00:00:00,000",
    "appid": "foobar.netportal_auth",
    "event": "sys_crash:outofmemory,
    "level": "WARN",
    "description": "The system crashed due to Out of Memory error.",
    ...
}
```

### sys_monitor_disabled:[userid,monitor]

**Description** Systems with agents for file integrity, resources, logging, virus, etc.: esp. valuable to know if halted, and by whom.

**Level:** WARN

**Example:**

```
{
    "datetime": "2019-01-01 00:00:00,000",
    "appid": "foobar.netportal_auth",
    "event": "sys_monitor_disabled:joebob1,crowdstrike",
    "level": "WARN",
    "description": "User joebob1 has disabled CrowdStrike",
    ...
}
```

### sys_monitor_enabled:[userid,monitor]

**Description** Systems with agents for file integrity, resources, logging, virus, etc.: esp. valuable to know if started again after being stopped, and by whom.

**Level:** WARN

**Example:**

```
{
    "datetime": "2019-01-01 00:00:00,000",
    "appid": "foobar.netportal_auth",
    "event": "sys_monitor_enabled:joebob1,crowdstrike",
    "level": "WARN",
    "description": "User joebob1 has enabled CrowdStrike",
    ...
}
```

## User Management [USER]

### user_created:[userid,newuserid,attributes[one,two,three]]

**Description** Creating new users: log specifics of creation event, esp. if new users can get administration privileges.

**Level:** WARN

**Example:**

```
{
    "datetime": "2019-01-01 00:00:00,000",
    "appid": "foobar.netportal_auth",
    "event": "user_created:joebob1,user1,admin:create,update,delete",
    "level": "WARN",
    "description": "User joebob1 created user1 with admin:create,update,delete privilege attributes",
    ...
}
```

### user_updated:[userid,onuserid,attributes[one,two,three]]

**Description** Updating users: log specifics of update event, esp. if users can be updated with administration privileges.

**Level:** WARN

**Example:**

```
{
    "datetime": "2019-01-01 00:00:00,000",
    "appid": "foobar.netportal_auth",
    "event": "user_updated:joebob1,user1,admin:create,update,delete",
    "level": "WARN",
    "description": "User joebob1 updated user1 with attributes admin:create,update,delete privilege attributes",
    ...
}
```

### user_archived:[userid,onuserid]

**Description** Best to archive users rather than delete, except where required. Archiving users: log specifics of archive event. Malicious user could use feature to deny service to legitimate users.

**Level:** WARN

**Example:**

```
{
    "datetime": "2019-01-01 00:00:00,000",
    "appid": "foobar.netportal_auth",
    "event": "user_archived:joebob1,user1",
    "level": "WARN",
    "description": "User joebob1 archived user1",
    ...
}
```

### user_deleted:[userid,onuserid]

**Description** Best to archive users rather than delete, except where required. Deleting users: log specifics of delete event. Malicious user could use feature to deny service to legitimate users.

**Level:** WARN

**Example:**

```
{
    "datetime": "2019-01-01 00:00:00,000",
    "appid": "foobar.netportal_auth",
    "event": "user_deleted:joebob1,user1",
    "level": "WARN",
    "description": "User joebob1 has deleted user1",
    ...
}
```

## Exclusions

What you DON'T log matters as much as what you DO log. Never log private or secret information, source code, keys, certs, etc.

Comprehensive list of items to exclude from logging: [OWASP Logging Cheat Sheet](../cheatsheets/Logging.md#data-to-exclude).

## References

- RFC 5424: The Syslog Protocol
- NIST SP 800-92: Guide to Computer Security Log Management
