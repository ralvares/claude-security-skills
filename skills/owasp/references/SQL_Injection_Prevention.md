# SQL Injection Prevention Cheat Sheet

## Introduction

Prevent SQL injection flaws: what it is, where flaws occur, four defense options. SQL Injection attacks are common because:

1. SQL Injection vulnerabilities very common.
2. Application database frequent target; typically holds sensitive/critical data.

## What Is a SQL Injection Attack?

Attackers exploit dynamic database queries using string concatenation + user-supplied input. Developers must:

1. Stop writing dynamic queries w/ string concatenation.
2. Prevent malicious SQL input from entering executed queries.

Simple techniques work for practically any language and database. XML databases have similar problems (e.g., XPath and XQuery injection); same techniques protect them.

## Anatomy of a Typical SQL Injection Vulnerability

Common Java flaw below. Unvalidated "customerName" parameter appended to query → attacker enters SQL code, application executes it on database.

```java
String query = "SELECT account_balance FROM user_data WHERE user_name = "
             + request.getParameter("customerName");
try {
    Statement statement = connection.createStatement( ... );
    ResultSet results = statement.executeQuery( query );
}

...
```

## Primary Defenses

- **Option 1: Use of Prepared Statements (with Parameterized Queries)**
- **Option 2: Use of Properly Constructed Stored Procedures**
- **Option 3: Allow-list Input Validation**
- **Option 4: STRONGLY DISCOURAGED: Escaping All User Supplied Input**

### Defense Option 1: Prepared Statements (with Parameterized Queries)

Teach developers prepared statements w/ variable binding (aka parameterized queries). Simpler to write, easier to understand than dynamic queries; force developer to define all SQL code first, pass each parameter later.

Database always distinguishes code from data regardless of user input. Attacker cannot change query intent even if SQL commands inserted.

#### Safe Java Prepared Statement Example

Attacker enters userID `tom' or '1'='1` → parameterized query looks for username literally matching entire string `tom' or '1'='1`; database protected.

`PreparedStatement` = Java's parameterized query implementation, same query:

```java
// This should REALLY be validated too
String custname = request.getParameter("customerName");
// Perform input validation to detect attacks
String query = "SELECT account_balance FROM user_data WHERE user_name = ? ";
PreparedStatement pstmt = connection.prepareStatement( query );
pstmt.setString( 1, custname);
ResultSet results = pstmt.executeQuery( );
```

#### Safe C\# .NET Prepared Statement Example

.NET: query creation/execution unchanged; pass parameters via `Parameters.Add()`.

```csharp
String query = "SELECT account_balance FROM user_data WHERE user_name = ?";
try {
  OleDbCommand command = new OleDbCommand(query, connection);
  command.Parameters.Add(new OleDbParameter("customerName", CustomerName.Text));
  OleDbDataReader reader = command.ExecuteReader();
  // …
} catch (OleDbException se) {
  // error handling
}
```

Practically all other languages (incl. Cold Fusion, Classic ASP) support parameterized query interfaces. SQL abstraction layers like Hibernate Query Language (HQL), w/ same injection problems (HQL Injection), support them too:

#### Hibernate Query Language (HQL) Prepared Statement (Named Parameters) Example

```java
// This is an unsafe HQL statement
Query unsafeHQLQuery = session.createQuery("from Inventory where productID='"+userSuppliedParameter+"'");
// Here is a safe version of the same query using named parameters
Query safeHQLQuery = session.createQuery("from Inventory where productID=:productid");
safeHQLQuery.setParameter("productid", userSuppliedParameter);
```

#### Other Examples of Safe Prepared Statements

More languages (Ruby, PHP, Cold Fusion, Perl, Rust): [Query Parameterization Cheat Sheet](Query_Parameterization.md) or bobby-tables.com.

Developers like prepared statements: all SQL stays in application → relatively database independent.

### Defense Option 2: Stored Procedures

Stored procedures not always safe from SQL injection, but standard stored procedure constructs have same effect as parameterized queries if implemented safely (norm for most stored procedure languages).

#### Safe Approach to Stored Procedures

Safest: build SQL statements w/ parameters automatically parameterized, unless developer does something largely out of norm. Difference vs prepared statements: stored procedure SQL defined/stored in database itself, called from application. Prepared statements and safe stored procedures equally effective; choose what suits organization.

#### When Stored Procedures Can Increase Risk

Stored procedures can sometimes increase risk under attack. E.g. MS SQL Server has 3 main default roles: `db_datareader`, `db_datawriter`, `db_owner`. Before stored procedures, DBAs gave webservice user `db_datareader` or `db_datawriter` per requirements.

Stored procedures need execute rights, role not available by default. Where user management centralized but limited to those 3 roles, web apps must run as `db_owner` for stored procedures to work → server breach gives attacker full database rights, where previously maybe read-only.

#### Safe Java Stored Procedure Example

`CallableStatement` = Java's stored procedure interface, same query. `sp_getAccountBalance` must be predefined in database w/ same functionality as query above.

```java
// This should REALLY be validated
String custname = request.getParameter("customerName");
try {
  CallableStatement cs = connection.prepareCall("{call sp_getAccountBalance(?)}");
  cs.setString(1, custname);
  ResultSet results = cs.executeQuery();
  // … result set handling
} catch (SQLException se) {
  // … logging and error handling
}
```

#### Safe VB .NET Stored Procedure Example

`SqlCommand` = .NET's stored procedure interface, same query. `sp_getAccountBalance` must be predefined in database w/ same functionality as query above.

```vbnet
 Try
   Dim command As SqlCommand = new SqlCommand("sp_getAccountBalance", connection)
   command.CommandType = CommandType.StoredProcedure
   command.Parameters.Add(new SqlParameter("@CustomerName", CustomerName.Text))
   Dim reader As SqlDataReader = command.ExecuteReader()
   '...
 Catch se As SqlException
   'error handling
 End Try
```

### Defense Option 3: Allow-list Input Validation

SQL parts that can't use bind variables (table names, column names, sort order indicators ASC/DESC): input validation or query redesign = most appropriate defense. Table/column names ideally come from code, not user parameters.

#### Sample Of Safe Table Name Validation

WARNING: user parameter values targeting table/column names = poor design symptom; consider full rewrite if time allows. Otherwise map parameter values to legal/expected table/column names so unvalidated user input never enters query.

Below, `tableName` identified as legal/expected value → can be appended directly. Generic table validation functions can cause data loss if table names used in queries where unexpected.

```text
String tableName;
switch(PARAM):
  case "Value1": tableName = "fooTable";
                 break;
  case "Value2": tableName = "barTable";
                 break;
  ...
  default      : throw new InputValidationException("unexpected value provided"
                                                  + " for table name");
```

#### Safest Use Of Dynamic SQL Generation (DISCOURAGED)

Stored procedure "implemented safely" = no unsafe dynamic SQL generation. Developers don't usually generate dynamic SQL in stored procedures; possible, but avoid.

If unavoidable: stored procedure must use input validation or proper escaping so no user input injects SQL into dynamically generated query. Auditors: always look for `sp_execute`, `execute`, `exec` in SQL Server stored procedures. Similar audit guidelines for similar functions in other vendors.

#### Sample of Safer Dynamic Query Generation (DISCOURAGED)

Simple case like sort order: convert user input to boolean, use boolean to select safe value to append. Very standard need.

For example:

```java
public String someMethod(boolean sortOrder) {
 String SQLquery = "some SQL ... order by Salary " + (sortOrder ? "ASC" : "DESC");
 ...
```

User input converted to non-String (date, numeric, boolean, enumerated type, etc.) before appending, or used to select value to append → safe.

Input validation also recommended as secondary defense in ALL cases, even w/ bind variables. Techniques: [Input Validation Cheat Sheet](Input_Validation.md).

### Defense Option 4: STRONGLY DISCOURAGED: Escaping All User-Supplied Input

Developer escapes all user input before putting in query. Very database specific. Fragile vs other defenses; CANNOT guarantee prevention of all SQL injections in all situations.

New apps or low risk tolerance: build/rewrite w/ parameterized queries, stored procedures, or Object Relational Mapper (ORM) building queries.

## Additional Defenses

Beyond one of four primary defenses, adopt all of these for defense in depth:

- **Least Privilege**
- **Allow-list Input Validation**

### Least Privilege

Minimize privileges of every database account to limit damage of successful SQL injection. Start from ground up determining access rights application accounts need, not figuring what to take away.

Read-only accounts: read access only to needed tables. DO NOT ASSIGN DBA OR ADMIN TYPE ACCESS TO APPLICATION ACCOUNTS. Easy, everything "works", but very dangerous.

#### Minimizing Application and OS Privileges

SQL injection not only threat to database data. Attackers can change parameter values from legal ones to values unauthorized for them but authorized for application. Minimizing application privileges reduces such attempts even w/o SQL injection.

Also minimize privileges of OS account DBMS runs under. Don't run DBMS as root or system! Most DBMSs default to very powerful system account; e.g. MySQL runs as system on Windows by default. Change DBMS's OS account to appropriate restricted one.

#### Details Of Least Privilege When Developing

Account needs only part of table → create view limiting access to that portion; grant account access to view, not underlying table. Rarely, if ever, grant create or delete access to database accounts.

Policy of stored procedures everywhere, application accounts not allowed own queries: restrict accounts to executing only needed stored procedures. No direct table rights.

#### Least Admin Privileges For Multiple DBs

Web application designers should avoid same owner/admin account for connecting to database. Different DB users for different web applications.

Each separate web application needing database access gets designated DB user account → good access-control granularity, minimal privileges. Each DB user: select access only to what needed, write-access as needed.

Example: login page needs read access to username + password fields, no write (no insert, update, delete). Sign-up page needs insert privilege on that table; restriction enforceable only if web apps use different DB users.

#### Enhancing Least Privilege with SQL Views

SQL views increase granularity: limit read access to specific fields of table or joins. Additional benefits possible.

E.g., product catalog view exposes product names + retail prices, omits supplier costs. Grant application's DB account only `SELECT` on that view, no access to underlying table or other objects exposing omitted fields. Verify database's view privilege rules; e.g., PostgreSQL normally checks underlying table access using view owner's privileges.

Limits data exposed via compromised application account. Queries against views still need parameterization.

### Allow-list Input Validation

Primary defense when nothing else possible (e.g., bind variable illegal); also secondary defense detecting unauthorized input before it reaches SQL query. See [Input Validation Cheat Sheet](Input_Validation.md). Caution: validated data not necessarily safe to insert into SQL via string building.

## Related Articles

Language-specific examples of prepared statements and stored procedures: [Query Parameterization Cheat Sheet](Query_Parameterization.md).

## References

- Oracle JDBC: Using Prepared Statements
- PHP PDO: Prepared Statements and Stored Procedures
