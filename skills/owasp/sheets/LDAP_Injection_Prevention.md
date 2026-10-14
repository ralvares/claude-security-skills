# LDAP Injection Prevention Cheat Sheet

## Introduction

Lightweight Directory Access Protocol (LDAP) lets application remotely search/modify directory records. LDAP injection: inadequate input sanitization/validation lets malicious users glean restricted info via directory service. General LDAP info: lightweight directory access protocol (LDAP).

LDAP Injection exploits web apps constructing LDAP statements from user input. Unsanitized input → LDAP statements modifiable via techniques similar to SQL Injection.

Cheatsheet gives actionable guidance preventing LDAP Injection. LDAP injection attacks common due to two factors:

1. Lack of safer, parameterized LDAP query interfaces
2. Widespread use of LDAP to authenticate users to systems.

LDAP injection can grant permissions to unauthorized queries, modify content inside LDAP tree.

Primary Defenses:

- Escape all variables using right LDAP encoding function
- Use framework that escapes automatically.

Additional Defenses:

- Least Privilege
- Allow-List Input Validation

## Primary Defenses

### Defense Option 1: Escape all variables using the right LDAP encoding function

#### Distinguished Name Escaping

LDAP stores names mainly by DN (distinguished name), like unique identifier. Sometimes used to access resources, like username.

DN examples

`cn=Richard Feynman, ou=Physics Department, dc=Caltech, dc=edu`

or

`uid=inewton, ou=Mathematics Department, dc=Cambridge, dc=com`

Allowlist restricts input to valid characters. Characters/sequences excluded from allowlists, incl. Java Naming and Directory Interface (JNDI) metacharacters and LDAP special characters, listed below.

Exhaustive list: `\ # + < > , ; " =` and leading or trailing spaces.

"Special" characters allowed in Distinguished Names, no escaping needed:

```text
* ( ) . & - _ [ ] ` ~ | @ $ % ^ ? : { } ! '
```

#### Search Filter Escaping

Each DN points to exactly 1 entry (like RDBMS row). Each entry has 1 or more attributes (like RDBMS columns). Search LDAP for users with certain attributes via search filters.

Search filter uses standard boolean logic to list users matching arbitrary constraint. Written in Polish notation AKA prefix notation.

Example:

```text
(&(ou=Physics)(|
(manager=cn=Freeman Dyson,ou=Physics,dc=Caltech,dc=edu)
(manager=cn=Albert Einstein,ou=Physics,dc=Princeton,dc=edu)
))
```

Building LDAP queries in application code: MUST escape any untrusted data added to any LDAP query. Two forms of LDAP escaping: Encoding for LDAP Search, Encoding for LDAP DN (distinguished name). Proper escaping depends on whether sanitizing input for search filter, or using DN as username-like credential to access resource.

"Special" characters allowed in search filters that must be escaped:

```text
* ( ) \ NUL
```

Search filter escaping: RFC4515 section 3.

#### Safe Java Escaping Example

Example validates `userSN` with allowlist. Java's default predefined character classes: accepts ASCII letters, digits, underscores, whitespace (incl. tabs, line breaks); `*` also permits empty string. Illustrative rule, not general validation policy for personal names. Choose allowlist matching application requirements; apply appropriate LDAP escaping for values outside restricted set.

```java
// String userSN = "Sherlock Holmes"; // Valid
// ... beginning of LDAPInjection.searchRecord()...
sc.setSearchScope(SearchControls.SUBTREE_SCOPE);
String base = "dc=example,dc=com";

if (!userSN.matches("[\\w\\s]*")) {
 throw new IllegalArgumentException("Invalid input");
}

String filter = "(sn = " + userSN + ")";
// ... remainder of LDAPInjection.searchRecord()... 
```

Database field must include special characters: critical to store authentic data in sanitized form and normalize any user input before validation/comparison. Using characters with special meanings in JNDI and LDAP w/o comprehensive normalization + allowlisting-based routine discouraged. Transform special characters to sanitized, safe values before adding to allowlist expression validating input. Normalize user input before validation step (source: Prevent LDAP injection).

OWASP ESAPI `Encoder` API provides `encodeForLDAP(String)` for search-filter values, `encodeForDN(String)` for distinguished-name values. Choose method for LDAP context where value used.

#### Insecure vs Secure Java LDAP Query Construction

❌ **Insecure Example (vulnerable to LDAP Injection)**

```java
// User input directly concatenated into the filter
String filter = "(&(uid=" + userInput + ")(objectClass=person))";
NamingEnumeration<SearchResult> results =
    ctx.search("ou=users,dc=example,dc=com", filter, controls);


✅ Secure Example (using parameterized filter)

// User input safely passed as a parameter
String filter = "(&(uid={0})(objectClass=person))";
NamingEnumeration<SearchResult> results =
    ctx.search("ou=users,dc=example,dc=com", filter, new Object[]{ userInput }, controls);
```

#### Safe C Sharp .NET TBA Example

.NET AntiXSS (now Encoder class) has LDAP encoding functions incl. `Encoder.LdapFilterEncode(string)`, `Encoder.LdapDistinguishedNameEncode(string)` and `Encoder.LdapDistinguishedNameEncode(string, bool, bool)`.

`Encoder.LdapFilterEncode` encodes input per RFC4515; unsafe values converted to `\XX` where `XX` = representation of unsafe character.

Use `Encoder.LdapDistinguishedNameEncode` for distinguished-name attribute values. In DN string escaping (RFC 4514 section 2.4), `\XX` = escaped byte as two hexadecimal digits; selected special characters can instead be prefixed with backslash. Escape leading spaces or `#` and trailing spaces. Leading `#` followed by hexadecimal pairs = entire attribute value encoded using Basic Encoding Rules (BER), not individual character escapes.

`LdapDistinguishedNameEncode(string, bool, bool)` also lets you turn off initial/final character escaping rules, e.g. when concatenating escaped DN fragment into middle of complete DN.

### Defense Option 2: Use Frameworks that Automatically Protect from LDAP Injection

#### Safe .NET Example

Recommended: LINQ to LDAP (for .NET Framework 4.5 or lower until updated) in DotNet. Automatic LDAP encoding when building LDAP queries. See project repository Readme file.

## Additional Defenses

Besides one of two primary defenses, adopt all additional defenses for defense in depth:

- **Least Privilege**
- **Allow-List Input Validation**

### Least Privilege

Minimize privileges of LDAP binding account to limit damage of successful LDAP injection.

### Enabling Bind Authentication

Authenticated LDAP bind establishes authenticated authorization state (RFC 4513 section 5.1.3); doesn't prevent user input changing search filter constructed by application. Keep applying [primary injection defenses](#primary-defenses), incl. search-filter escaping (RFC 4515 section 3), even when application binds with valid credentials.

Name/password authentication: reject empty passwords before binding. Nonempty name with empty password can perform unauthenticated bind (RFC 4513 section 5.1.2) establishing anonymous authorization; success then doesn't prove user identity. Require authenticated access to protected directory data; use least-privileged binding account.

### Allow-List Input Validation

Input validation detects unauthorized input before it reaches LDAP query. See [Input Validation Cheat Sheet](Input_Validation.md).

## References

- RFC 4515: LDAP String Representation of Search Filters
- RFC 4514: LDAP String Representation of Distinguished Names
