# Injection Prevention Cheat Sheet

## Introduction

Clear, actionable guidance to prevent entire category of Injection flaws. Injection attacks, esp. [SQL Injection](https://owasp.org/www-community/attacks/SQL_Injection), very common.

Application accessibility key factor in protection. Minority of enterprise apps developed in house; most from external sources. Open source apps at least allow fixing; closed source needs different approach.

Injection flaws = app sends untrusted data to interpreter. Very prevalent, esp. legacy code: SQL queries, LDAP queries, XPath queries, OS commands, program arguments, etc. Easy to discover in code review, harder via testing. Scanners and fuzzers help attackers find them.

Actions depend on accessibility. Best: fix in source code or redesign parts of app. Source unavailable or fixing legacy software uneconomical: only virtual patching makes sense.

## Application Types

Three classes of app in a company; types determine actions to prevent/fix injection flaws.

### A1: New Application

New web app in design phase or early development.

### A2: Productive Open Source Application

Productive app easily adapted. Model-View-Controller (MVC) app = one example of easily accessible architecture.

### A3: Productive Closed Source Application

Productive app that cannot, or only with difficulty, be modified.

## Forms of Injection

Several forms target different technologies: SQL queries, LDAP queries, XPath queries, OS commands.

### Query languages

Most famous: SQL Injection, attacker modifies existing database queries. See [SQL Injection Prevention Cheat Sheet](SQL_Injection_Prevention.md).

LDAP, SOAP, XPath, REST based queries also susceptible: data retrieval or control bypass.

#### SQL Injection

SQL injection = insertion/"injection" of partial or complete SQL query via data input or transmitted from client (browser) to web app.

Successful attack can: read sensitive DB data, modify DB data (insert/update/delete), execute DB administration operations (e.g. shutdown DBMS), recover content of given file on DBMS file system or write files to it, in some cases issue OS commands. Type of injection attack: SQL commands injected into data-plane input to affect execution of predefined SQL commands.

Three classes:

- **Inband:** data extracted via same channel used to inject SQL. Most straightforward; retrieved data shown directly in app web page.
- **Out-of-band:** data retrieved via different channel (e.g., email with query results sent to tester).
- **Inferential or Blind:** no actual data transfer; tester reconstructs info by sending particular requests and observing DB Server behavior.

##### How to test for the issue

###### During code review

Check for DB queries not done via prepared statements.

Dynamic statements: check whether data sanitized before use in statement.

Auditors always look for sp_execute, execute or exec in SQL Server stored procedures. Similar audit guidelines needed for similar functions of other vendors.

###### Automated Exploitation

Most situations/techniques below can be automated with tools. See article on automated auditing using SQLMap.

Static Code Analysis Data flow rules can also detect unsanitized user controlled input able to change SQL query.

###### Stored Procedure Injection

Dynamic SQL in stored procedure: app must properly sanitize user input to eliminate code injection risk. Unsanitized → user enters malicious SQL executed in stored procedure.

###### Time delay Exploitation technique

Very useful in Blind SQL Injection, where outcome of operation unknown. Tester sends injected query; if conditional true, monitors server response time. Delay → conditional query result true. Technique varies by DBMS (check DBMS specific section).

```text
http://www.example.com/product.php?id=10 AND IF(version() like '5%', sleep(10), 'false'))--
```

Example: tester checks whether MySql version is 5.x, making server delay answer 10 seconds. Tester can increase delay and monitor responses. Needn't wait for response: can set very high value (e.g. 100), cancel request after some seconds.

###### Out of band Exploitation technique

Very useful in Blind SQL Injection, where outcome unknown. Uses DBMS functions to make out of band connection and deliver injected query results in request to tester's server. Like error based techniques, each DBMS has own functions. Check specific DBMS section.

##### Remediation

###### Defense Option 1: Prepared Statements (with Parameterized Queries)

Prepared statements ensure attacker can't change query intent, even if SQL commands inserted. In safe example below, attacker entering userID `tom' or '1'='1` → parameterized query not vulnerable; looks for username literally matching entire string `tom' or '1'='1`.

###### Defense Option 2: Stored Procedures

Difference from prepared statements: stored procedure SQL code defined and stored in DB itself, then called from app.

Both equally effective against SQL injection; organization chooses approach. Stored procedures not always safe from SQL injection. But certain standard stored procedure constructs have same effect as parameterized queries when implemented safely* (norm for most stored procedure languages).

*Note:* 'Implemented safely' = stored procedure includes no unsafe dynamic SQL generation.

###### Defense Option 3: Allow-List Input Validation

Various query parts can't use bind variables: table/column names, sort order indicator (ASC or DESC). Then input validation or query redesign most appropriate. Table/column names ideally come from code, not user parameters.

If user parameter values select table/column names, map them to legal/expected names so unvalidated user input never reaches query. Symptom of poor design; consider full rewrite if time allows.

###### Defense Option 4: Escaping All User-Supplied Input

Last resort only, when none above feasible. Input validation probably better: this method frail vs other defenses; no guarantee of preventing all SQL Injection in all situations.

Escape user input before putting in query. Usually recommended only to retrofit legacy code when input validation not cost effective.

##### Example code - Java

###### Safe Java Prepared Statement Example

Code uses `PreparedStatement`, Java's parameterized query implementation, for same DB query.

```java
// This should REALLY be validated too
String custname = request.getParameter("customerName");
// Perform input validation to detect attacks
String query = "SELECT account_balance FROM user_data WHERE user_name = ?";
PreparedStatement pstmt = connection.prepareStatement(query);
pstmt.setString(1, custname);
ResultSet results = pstmt.executeQuery();
```

Examples in Java, but practically all other languages, incl. Cold Fusion and Classic ASP, support parameterized query interfaces.

###### Safe Java Stored Procedure Example

Code uses `CallableStatement`, Java's stored procedure interface, for same DB query. `sp_getAccountBalance` stored procedure must be predefined in DB, implementing same functionality as query above.

```java
// This should REALLY be validated
String custname = request.getParameter("customerName");
try {
 CallableStatement cs = connection.prepareCall("{call sp_getAccountBalance(?)}");
 cs.setString(1, custname);
 ResultSet results = cs.executeQuery();
 // Result set handling...
} catch (SQLException se) {
 // Logging and error handling...
}
```

#### LDAP Injection

LDAP Injection exploits web apps constructing LDAP statements from user input. Unsanitized input → modify LDAP statements similar to [SQL Injection](https://owasp.org/www-community/attacks/SQL_Injection). Can grant permissions to unauthorized queries, modify content inside LDAP tree. More: LDAP injection (OWASP).

[LDAP injection](https://owasp.org/www-community/attacks/LDAP_Injection) common due to two factors:

1. Lack of safer, parameterized LDAP query interfaces
2. Widespread use of LDAP to authenticate users to systems.

##### How to test for the issue

###### During code review

Check LDAP queries escape special characters, see [here](LDAP_Injection_Prevention.md#defense-option-1-escape-all-variables-using-the-right-ldap-encoding-function).

###### Automated Exploitation

Scanner modules of tools like OWASP ZAP detect LDAP injection.

##### Remediation

###### Use the right LDAP encoding function

LDAP distinguished names and search filters need different escaping rules: RFC 4514 and RFC 4515 respectively. Avoid custom escaping code; use library encoder for correct context. See [LDAP Injection Prevention Cheat Sheet](LDAP_Injection_Prevention.md) for defenses and examples.

#### XPath Injection

See [XPath Injection Prevention Cheat Sheet](XPath_Injection_Prevention.md) for defenses and parameterized query example.

### Scripting languages

All scripting languages in web apps have `eval` call receiving code at runtime and executing it. Code crafted from unvalidated, unescaped user input → code injection: subverts app logic, eventually local access.

'Higher' scripting language implemented in 'lower' language like C. Flaw in scripting language's data handling code → 'Null Byte Injection' attack vectors reach other memory areas → successful attack.

### Operating System Commands

OS command injection: executes OS commands on web server via web interface; user supplies OS commands through it.

Any unsanitized web interface vulnerable. Able to execute OS commands, user can upload malicious programs or obtain passwords. Preventable when security emphasized in design and development.

#### How to test for the issue

##### During code review

Check whether command execute methods called and unvalidated user input taken as data for command.

Also: appending semicolon to end of URL query parameter followed by OS command executes command. `%3B` is URL encoded semicolon. `;` interpreted as command separator.

Example: `http://sensitive/something.php?dir=%3Bcat%20/etc/passwd`

App responds with `/etc/passwd` output → attack successful. Many web app scanners test this by injecting command injection variations and testing response.

Static Code Analysis tools check data flow of untrusted user input into web app, check whether data enters dangerous method executing input as command.

#### Remediation

If call to system command with user-supplied data unavoidable, use two defense layers:

1. **Parameterization** - If available, use structured mechanisms auto-enforcing separation between data and command; provide relevant quoting, encoding.
2. **Input validation** - validate both command values and relevant arguments, with different degrees:
    - **Commands**: validate against list of allowed commands.
    - **Arguments**: validate using:
        - Positive or allowlist input validation - explicitly defined allowed arguments
        - Allow-list Regular Expression - explicitly defined list of good characters and max string length. Ensure metacharacters like `& | ; $ > < \` \ !` and whitespaces not in Regular Expression. E.g. following regex allows only lowercase letters and numbers, no metacharacters; length limited to 3-10 characters:

`^[a-z0-9]{3,10}$`

#### Example code - Java

##### Incorrect Usage

```java
ProcessBuilder b = new ProcessBuilder("C:\\DoStuff.exe -arg1 -arg2");
```

Creates builder with one command-list element, not program followed by two arguments. `ProcessBuilder` represents executable and arguments as list. Snippet does not start process or demonstrate shell-command injection.

##### Correct Usage

Illustrative example: starts process with modified working directory, passes executable and each argument separately. Keep executable and working directory trusted; validate any untrusted arguments for invoked program. Argument separation does not replace [argument validation](OS_Command_Injection_Defense.md#layer-2).

```java
ProcessBuilder pb = new ProcessBuilder("TrustedCmd", "TrustedArg1", "TrustedArg2");
Map<String, String> env = pb.environment();
pb.directory(new File("TrustedDir"));
Process p = pb.start();
```

### Network Protocols

Web apps often talk to network daemons (like SMTP, IMAP, FTP) where user input becomes part of communication stream. Command sequences can be injected to abuse established session.

## Injection Prevention Rules

### Rule \#1 (Perform proper input validation)

Perform proper input validation. Positive/allowlist input validation with appropriate canonicalization also recommended, but **is not a complete defense**: many apps require special characters in input.

### Rule \#2 (Use a safe API)

Preferred: safe API avoiding interpreter entirely or providing parameterized interface. Beware APIs, e.g. stored procedures, that are parameterized but can still introduce injection under the hood.

### Rule \#3 (Contextually escape user data)

No parameterized API: carefully escape special characters using interpreter's specific escape syntax.

## Other Injection Cheatsheets

[SQL Injection Prevention Cheat Sheet](SQL_Injection_Prevention.md)

[OS Command Injection Defense Cheat Sheet](OS_Command_Injection_Defense.md)

[LDAP Injection Prevention Cheat Sheet](LDAP_Injection_Prevention.md)

[Injection Prevention Cheat Sheet in Java](Java_Security.md)

## References

- RFC 4514: LDAP Distinguished Names
- RFC 4515: LDAP Search Filters
- Oracle JDBC: Using Prepared Statements
