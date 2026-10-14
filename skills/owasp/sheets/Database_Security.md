# Database Security Cheat Sheet

## Introduction

Guidance for securely configuring SQL databases e.g. MySQL, PostgreSQL, MariaDB, Microsoft SQL Server. Audience: app developers + sysadmins managing relational databases.

App-layer injection defenses: [SQL Injection Prevention Cheat Sheet](SQL_Injection_Prevention.md).
Non-relational (e.g., MongoDB, Redis, Cassandra, DynamoDB): [NoSQL Security Cheat Sheet](NoSQL_Security.md)

## Protecting the Backend Database

Isolate backend database from other servers; connect with as few hosts as possible. Depends on system/network architecture. Options:

- Disable network (TCP) access; require local socket file or named pipe.
- Bind only on localhost.
- Restrict network port to specific hosts via firewall rules.
- Put database server on dedicated internal network segment isolated from app server.
- Protect web-based management tools (e.g., phpMyAdmin, pgAdmin) w/ authentication, HTTPS, network restrictions.

App on untrusted system (e.g., thick-client): always connect to backend via API enforcing access control + restrictions. **Never** connect directly from thick client to backend database.

### Implementing Transport Layer Protection

Most database defaults use unencrypted network connections; some encrypt only initial authentication (e.g., Microsoft SQL Server). Rest of traffic then cleartext, exposing sensitive info. Prevent:

- Configure database to allow only encrypted connections.
- Install trusted digital certificate on server.
- Client connects w/ TLSv1.2+ and modern ciphers (e.g, AES-GCM or ChaCha20).
- Client verifies certificate is correct.

TLS configuration: [Transport Layer Security Cheat Sheet](Transport_Layer_Security.md).

## Configuring Secure Authentication

Database always requires authentication, incl. local server connections. Accounts:

- Strong, unique passwords.
- Used by single application/service.
- Minimum permissions required, see [permissions section below](#creating-secure-permissions).

Usual account management:

- Regularly review accounts still required.
- Regularly review permissions.
- Remove accounts when application decommissioned.
- Change passwords when staff leave or on suspected compromise.

Microsoft SQL Server: consider Windows or Integrated-Authentication; uses existing Windows accounts, no credentials stored in app (connects as running Windows user). Windows Native Authentication Plugins give similar functionality for MySQL.

### Storing Database Credentials Securely

Never store credentials in app source code, esp. unencrypted. Store in configuration file that:

- Is outside web root.
- Has permissions so only required user(s) can read.
- Is not checked into source code repositories.

Where possible also encrypt/protect via built-in functionality e.g. `web.config` encryption in ASP.NET.

## Creating Secure Permissions

Apply least privilege (accounts have only minimal permissions app needs), at increasingly granular levels depending on database functionality. In all environments:

- Don't use built-in `root`, `sa` or `SYS` accounts.
- Don't grant administrative rights over database instance.
- Account connects only from allowed hosts, often `localhost` or app server address.
- Account accesses only specific databases needed. Development, UAT, Production use separate databases + accounts.
- Grant only required permissions. Most apps need only `SELECT`, `UPDATE`, `DELETE`. Account must not own database (privilege escalation).
- Avoid database links/linked servers. If required, use account w/ access to only minimum databases, tables, system privileges.

Most security-critical apps apply more granular permissions:

- Table-level permissions.
- Column-level permissions.
- Row-level permissions
- Block access to underlying tables; require all access through restricted views.

## Database Configuration and Hardening

Harden database server OS from secure baseline e.g. CIS Benchmarks or Microsoft Security Baselines.

Also configure/harden database application. For any database app/platform:

- Install required security updates/patches.
- Run database services under low privileged user account.
- Remove default accounts + databases.
- Store transaction logs on separate disk from main database files.
- Configure regular backups; protect w/ appropriate permissions, ideally encrypted.

Further software-specific recommendations below, in addition to general ones.

### Hardening a Microsoft SQL Server

- Disable `xp_cmdshell`, `xp_dirtree` and other unneeded stored procedures.
- Disable Common Language Runtime (CLR) execution.
- Disable SQL Browser service.
- Disable Mixed Mode Authentication unless required.
- Remove sample Northwind and AdventureWorks databases.
- See Microsoft articles on securing SQL Server.

### Hardening a MySQL or a MariaDB Server

- Run `mysql_secure_installation` script to remove default databases + accounts.
- Disable FILE privilege for all users (prevents reading/writing files).
- See Oracle MySQL and MariaDB hardening guides.

### Hardening a PostgreSQL Server

- See PostgreSQL Server Setup and Operation documentation and older Security documentation.

### MongoDB

- General NoSQL guidance: [NoSQL Security Cheat Sheet](NoSQL_Security.md).
- See MongoDB security checklist.

### Redis

- See Redis security guide.

## References

- Microsoft: Securing SQL Server
- PostgreSQL: Secure TCP/IP Connections with SSL
