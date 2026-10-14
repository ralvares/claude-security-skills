# Logging Cheat Sheet

## Introduction

Concentrated guidance for developers building application logging mechanisms, esp. security logging.

Many systems enable network device, OS, web server, mail server, database server logging, but custom application event logging often missing, disabled, poorly configured. Gives much greater insight than infrastructure logging alone. Web application (web site or web service) logging = much more than web server logs enabled (e.g. Extended Log File Format).

Application logging should be consistent within application and across organization's application portfolio, use industry standards where relevant, so logged event data can be consumed, correlated, analyzed, managed by wide variety of systems.

## Purpose

Always include application logging for security events. Application logs invaluable for security + operational use cases.

### Operational use cases

- General debugging
- Establishing baselines
- Business process monitoring e.g. sales process abandonment, transactions, connections
- Information about problems + unusual conditions
- Performance monitoring e.g. data load time, page timeouts
- Other business-specific requirements

### Security use cases

Also record other event types:

- Anti-automation monitoring
- Identifying security incidents
- Monitoring policy violations
- Assisting non-repudiation controls (non-repudiation hard to achieve for logs: trustworthiness often rests only on logging party being audited properly; mechanisms like digital signatures hard to use here)
- Audit trails e.g. data addition, modification, deletion, data exports
- Compliance monitoring
- Data for subsequent requests for information e.g. data subject access, freedom of information, litigation, police and other regulatory investigations
- Legally sanctioned interception of data e.g. application-layer wire-tapping
- Additional application-specific data for incident investigation lacking in other log sources
- Helping defend against vulnerability identification + exploitation through attack detection

Process monitoring, audit, transaction logs/trails etc. usually collected for different purposes than security event logging; often keep separate.

Event types + details collected tend to differ.

E.g. PCIDSS audit log = chronological record of activities giving independently verifiable trail permitting reconstruction, review, examination to determine original sequence of attributable transactions. Don't log too much or too little.

Use intended purposes to guide what, when, how much. Rest of sheet mainly covers security event logging.

## Design, implementation, and testing

### Event data sources

Application itself has wide range of information events for log entries → primary event data source = application code.

Application has most info about user (identity, roles, permissions) and event context (target, action, outcomes); often unavailable to infrastructure devices or even closely-related applications.

Other sources of application usage info:

- Client software e.g. actions on desktop software and mobile devices in local logs or via messaging technologies, JavaScript exception handler via AJAX, web browser e.g. Content Security Policy (CSP) reporting mechanism
- Embedded instrumentation code
- Network firewalls
- Network and host intrusion detection systems (NIDS and HIDS)
- Closely-related applications e.g. filters built into web server software, web server URL redirects/rewrites to scripted custom error pages and handlers
- Application firewalls e.g. filters, guards, XML gateways, database firewalls, web application firewalls (WAFs)
- Database applications e.g. automatic audit trails, trigger-based actions
- Reputation monitoring services e.g. uptime or malware monitoring
- Other applications e.g. fraud monitoring, CRM
- Operating system e.g. mobile platform

Consider confidence in event info from systems in different trust zone. Data may be missing, modified, forged, replayed, malicious – always treat as untrusted.

Consider how source can be verified, how integrity + non-repudiation enforced.

### Where to record event data

Applications commonly write event log data to file system or database (SQL or NoSQL). Desktop/mobile applications may use local storage + local databases, plus sending to remote storage.

Selected framework may limit choices. All application types may send event data to remote systems (instead of or besides local storage).

Could be centralized log collection/management system (e.g. SIEM or SEM) or another application elsewhere. Consider simply sending event stream, unbuffered, to stdout, managed by execution environment.

- File system: preferably separate partition from OS, other application files, user generated content
    - File-based logs: strict permissions on which users access directories, and permissions of files within
    - Web applications: logs not in web-accessible locations; if so, restricted access + plain text MIME type (not HTML)
- Database: preferably separate database account used only for writing log data, with very restrictive database, table, function, command permissions
- Use standard event format supported by receiving system + secure transport, e.g. syslog message format (RFC 5424 section 6) over TLS (RFC 5425 section 3), to ease integration with centralized logging services

Consider separate files/tables for extended event info such as error stack traces or record of HTTP request/response headers and bodies.

### Which events to log

Set level + content of security monitoring, alerting, reporting at requirements/design stage; proportionate to information security risks. Defines what to log.

No one size fits all; blind checklist can cause unnecessary "alarm fog" so real problems go undetected.

Where possible, always log:

- Input validation failures e.g. protocol violations, unacceptable encodings, invalid parameter names and values
    - Log failures to validate value against discrete, finite list of valid values (e.g. country from dropdown), such as `input_validation_fail[:field,userid]`. Treat as suspicious events, not proof of attack: unexpected input can also result from misuse or client defects. Evaluate severity + alerting using repetition, correlation, request context.
- Output validation failures e.g. database record set mismatch, invalid data encoding
- Authentication successes and failures
   Failed authentication attempts = critical early indicators of credential‑based attacks such as brute‑force, credential‑stuffing, password‑spraying. Monitoring repeated failures for same account, failures from multiple IP addresses, rapid bursts of login attempts helps detect account takeover attempts before success. "Authentication successes and failures" must always be logged: essential for identifying security incidents + supporting incident investigation. See OWASP ASVS 7.1.1 for authentication failure logging requirements.
- Authorization (access control) failures
- Session management failures e.g. cookie session identification value modification or suspicious JWT validation failures
- Application errors and system events e.g. syntax and runtime errors, connectivity problems, performance issues, third party service error messages, file system errors, file upload virus detection, configuration changes
- Application and related systems start-ups and shut-downs, logging initialization (starting, stopping, pausing)
- Use of higher-risk functionality incl.:
    - User administration actions such as addition/deletion of users, privilege changes, assigning users to tokens, adding/deleting tokens
    - Use of systems administrative privileges or access by application administrators incl. all actions by those users
    - Use of default or shared accounts or "break-glass" account.
    - Access to sensitive data such as payment cardholder data,
    - Encryption activities such as use or rotation of cryptographic keys
    - Creation and deletion of system-level objects
    - Data import and export incl. screen-based reports
    - Submission + processing of user-generated content - esp. file uploads
    - Deserialization failures
    - Network connections + associated failures such as backend TLS failures (incl. certificate validation failures), or requests with unexpected HTTP verb
- Legal and other opt-ins e.g. permissions for mobile phone capabilities, terms of use, terms & conditions, personal data usage consent, permission to receive marketing communications
- Suspicious business logic activities such as:
    - Attempts to perform set actions out of order/bypass flow control
    - Actions that don't make sense in business context
    - Attempts to exceed limitations for particular actions

Optionally consider logging, if desirable:

- Sequencing failure
- Excessive use
- Data changes
- Fraud and other criminal activities
- Suspicious, unacceptable, or unexpected behavior
- Modifications to configuration
- Application code file and/or memory changes

### Event attributes

Each log entry needs sufficient info for intended monitoring/analysis. Could be full content data, more likely extract or summary properties.

Application logs must record "when, where, who and what" for each event.

Properties differ by architecture, application class, host system/device, but often include:

- When
    - Log date and time (international format)
    - Event date and time - event timestamp may differ from logging time e.g. server logging where client application hosted on remote device only periodically/intermittently online
    - Interaction identifier `Note A`
- Where
    - Application identifier e.g. name and version
    - Application address e.g. cluster/hostname or server IPv4 or IPv6 address and port number, workstation identity, local device identifier
    - Service e.g. name and protocol
    - Geolocation
    - Window/form/page e.g. entry point URL and HTTP method for web application, dialogue box name
    - Code location e.g. script name, module name
- Who (human or machine user)
    - Source address e.g. user's device/machine identifier, user's IP address, cell/RF tower ID, mobile telephone number
    - User identity (if authenticated or otherwise known) e.g. user database table primary key-value, username, license number
- What
    - Type of event `Note B`
    - Severity of event `Note B` e.g. `{0=emergency, 1=alert, ..., 7=debug}, {fatal, error, warning, info, debug, trace}`
    - Security relevant event flag (if logs contain non-security event data too)
    - Description

Also consider recording:

- Secondary time source (e.g. GPS) event date and time
- Action - original intended purpose of request e.g. Log in, Refresh session ID, Log out, Update profile
- Object e.g. affected component or other object (user account, data resource, file) e.g. URL, Session ID, User account, File
- Result status - whether ACTION aimed at OBJECT succeeded e.g. Success, Fail, Defer
- Reason - why status occurred e.g. User not authenticated in database check ..., Incorrect credentials
- HTTP Status Code (web applications only) - status code returned to user (often 200 or 301)
- Request HTTP headers or HTTP User Agent (web applications only)
- User type classification e.g. public, authenticated user, CMS user, search engine, authorized penetration tester, uptime monitor (see "Data to exclude" below)
- Analytical confidence in event detection `Note B` e.g. low, medium, high or numeric value
- Responses seen by user and/or taken by application e.g. status code, custom text messages, session termination, administrator alerts
- Extended details e.g. stack trace, system error messages, debug information, HTTP request body, HTTP response headers and body
- Internal classifications e.g. responsibility, compliance references
- External classifications e.g. NIST Security Content Automation Protocol (SCAP), Mitre Common Attack Pattern Enumeration and Classification (CAPEC)

More: "other" related articles at end, esp. comprehensive article by Anton Chuvakin and Gunnar Peterson.

**Note A:** "Interaction identifier" links all (relevant) events of single user interaction (e.g. desktop application form submission, web page request, mobile app button click, web service call). Application knows these events relate to same interaction; record it instead of losing info and forcing later correlation techniques to re-construct separate events. E.g. single SOAP request may have multiple input validation failures spanning small range of times. Another: output validation failure may occur much later than input submission for long-running "saga request" submitted by application to database server.

**Note B:** Each organization ensures consistent, documented approach to classification of events (type, confidence, severity), syntax of descriptions, field lengths and data types incl. date/time format.

### Data to exclude

Never log data unless legally sanctioned. E.g. intercepting some communications, monitoring employees, collecting some data without consent may be illegal.

Never exclude events from "known" users such as other internal systems, "trusted" third parties, search engine robots, uptime/process and other remote monitoring systems, pen testers, auditors. May include classification flag for each in recorded data.

Usually don't record directly in logs; remove, mask, sanitize, hash, or encrypt:

- Application source code
- Session identification values (consider replacing with hashed value if needed to track session specific events)
- Access tokens
- Sensitive personal data and some forms of personally identifiable information (PII) e.g. health, government identifiers, vulnerable people
- Authentication passwords
- Database connection strings
- Encryption keys and other primary secrets
- Bank account or payment card holder data
- Data of higher security classification than logging system allowed to store
- Commercially-sensitive information
- Information illegal to collect in relevant jurisdictions
- Information user opted out of collection, or didn't consent to e.g. use of do not track, or where consent to collect expired

Sometimes following data exists; useful for investigation but may need special treatment before recording:

- File paths
- Database connection strings
- Internal network names and addresses
- Non sensitive personal data (e.g. personal names, telephone numbers, email addresses)

Consider personal data de-identification (deletion, scrambling, pseudonymization of direct/indirect identifiers) where individual's identity not required or risk too great.

Some systems: sanitization post log collection, prior to log display.

### Customizable logging

Altering logging level (event types by severity/threat level, detail amount) may be desirable. If implemented:

- Default level must provide sufficient detail for business needs
- Must not be possible to completely deactivate application logging or logging of events necessary for compliance
- Alterations to level/extent must be intrinsic to application (e.g. automatic by approved algorithm) or follow change management processes (e.g. changes to configuration data, source code modification)
- Verify logging level periodically

### Event collection

Framework supports suitable logging mechanisms → use or build on them. Else implement application-wide log handler callable from other modules/components.

Document interface referencing organization-specific event classification + description syntax requirements.

If possible create log handler as standard module: thoroughly tested, deployed in multiple applications, added to list of approved/recommended modules.

- Validate event data from other trust zones before logging. Malformed field: omit or safely replace that field, record validation failure with bounded, safe context; don't discard entire security event. Preserves evidence while following OWASP guidance to log validation failures and encode log data safely
- Sanitize all event data to prevent log injection attacks e.g. carriage return (CR), line feed (LF), delimiter characters (and optionally remove sensitive data)
- Encode data correctly for output (logged) format
- Writing to databases: read, understand, apply SQL injection cheat sheet
- Ensure logging process/system failures don't prevent application otherwise running or allow information leakage
- Synchronize time across all servers and devices `Note C`

**Note C:** Not always possible where application runs on device under another party's control (e.g. individual's mobile phone, remote customer's workstation on another corporate network). Then attempt to measure time offset, or record confidence level in event timestamp.

Where possible record data in standard format, or at least ensure exportable/broadcastable in industry-standard format.

Events may be relayed or collected at intermediate points. In the latter, some data may be aggregated/summarized before forwarding to central repository and analysis system.

### Verification

Include logging functionality/systems in code review, application testing, security verification:

- Ensure logging works correctly and as specified
- Check events classified consistently; field names, types, lengths defined correctly to agreed standard
- Ensure logging implemented + enabled during application security, fuzz, penetration, performance testing
- Test mechanisms not susceptible to injection attacks
- Ensure no unwanted side-effects when logging occurs
- Check effect on logging mechanisms when external network connectivity lost (if usually required)
- Ensure logging can't deplete system resources, e.g. filling disk space or exceeding database transaction log space → denial of service
- Test effect on application of logging failures such as simulated database connectivity loss, lack of file system space, missing write permissions, runtime errors in logging module itself
- Verify access controls on event log data
- Log data used in any action against users (e.g. blocking access, account lock-out): ensure can't cause denial of service (DoS) of other users

### Network architecture

Example: diagram shows service providing business functionality to customers. Recommended: centralized system for collecting logs. May be many such services; all must securely collect logs in centralized system.

Applications of this business service sit in network segments:

- FRONTEND 1 aka DMZ (UI)
- MIDDLEWARE 1 (business application - service core)
- BACKEND 1 (service database)

Service collecting IT events, incl. security events, sits in segments:

- BACKEND 2 (log storage)
- MIDDLEWARE 3 - 2 applications:
    - log loader application: downloads log from storage, pre-processes, transfers to UI
    - log collector: accepts logs from business applications, other infrastructure, cloud applications; saves in log storage
- FRONTEND 2 (UI for viewing business service event logs)
- FRONTEND 3 (applications receiving logs from cloud applications, transferring logs to log collector)
    - Allowed to combine functionality of two applications in one

E.g. all external user requests go through API management service, see application in MIDDLEWARE 2 segment.

Diagram (image omitted): MIDDLEWARE.

At network level, saving and downloading logs require opening different network accesses (ports), arrows highlighted in different colors. Saving and downloading done by different applications.

Full network segmentation cheat sheet by sergiomarotco (GitHub: Network-segmentation-cheat-sheet)

## Deployment and operation

### Release

- Provide security configuration info: add logging mechanism details to release documentation
- Brief application/process owner on application logging mechanisms
- Ensure monitoring outputs (see below) integrated with incident response processes

### Operation

Enable processes detecting whether logging stopped, identifying tampering or unauthorized access and deletion (see protection below).

### Protection

Protect logging mechanisms + collected event data from mis-use such as tampering in transit, and unauthorized access, modification, deletion once stored. Logs may contain personal and other sensitive info, or info on application's code and logic.

Logged info may itself have business value (to competitors, gossip-mongers, journalists, activists) e.g. allowing revenue estimates or employee performance info.

Data may be held on end devices, intermediate points, centralized repositories, archives, backups.

Consider whether parts of data need exclusion, masking, sanitizing, hashing, or encryption during examination or extraction.

At rest:

- Build in tamper detection to know if record modified/deleted
- Store/copy log data to read-only media as soon as possible
- Record + monitor all access to logs (may need prior approval)
- Restrict privileges to read log data; review periodically

In transit:

- Log data over untrusted networks (e.g. collection, dispatch elsewhere, analysis, reporting): use secure transmission protocol
- Consider whether event data origin needs verification
- Perform due diligence checks (regulatory and security) before sending event data to third parties

See `NIST SP 800-92` Guide to Computer Security Log Management.

### Monitoring of events

Logged event data must be available to review; processes for monitoring, alerting, reporting in place:

- Incorporate application logging into existing log management systems/infrastructure e.g. centralized logging/analysis systems
- Ensure event info available to appropriate teams
- Enable alerting; signal responsible teams immediately about more serious events
- Share relevant event info with other detection systems, related organizations, centralized intelligence gathering/sharing systems

### Disposal of logs

Log data, temporary debug logs, backups/copies/extractions: not destroyed before required data retention period ends, not kept beyond it.

Legal, regulatory, contractual obligations may affect periods.

## Attacks on Logs

Logs may be attack targets given usefulness as defense. See also OWASP Log Injection and CWE-117.

### Confidentiality

Who should read what? Confidentiality attack lets unauthorized party access sensitive info in logs.

- Logs contain user PII. Attackers gather PII, release it or use as stepping stone for further attacks on users.
- Logs contain technical secrets such as passwords. Attackers use as stepping stone for deeper attacks.

### Integrity

Which info modifiable by whom?

- Attacker with log read access uses it to exfiltrate secrets.
- Attack leverages logs to reach exploitable facets of logging platforms, e.g. sending payload over syslog to cause out-of-bounds write.

### Availability

What downtime acceptable?

- Attacker floods log files to exhaust disk space for non-logging system functions. E.g. same disk for log files might hold SQL storage of application data.
- Attacker floods log files to exhaust disk space for further logging.
- Attacker uses one log entry to destroy other log entries.
- Attacker leverages poor logging code performance to reduce application performance

### Accountability

Who responsible for harm?

- Attacker prevents writes to cover tracks.
- Attacker damages log to cover tracks.
- Attacker causes wrong identity logged to conceal responsible party.

## References

- NIST SP 800-92: Guide to Computer Security Log Management
- RFC 5424: The Syslog Protocol
- W3C: Extended Log File Format (Working Draft)
