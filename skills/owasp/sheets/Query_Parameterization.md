# Query Parameterization Cheat Sheet

## Introduction

SQL Injection: one of most dangerous web vulnerabilities; OWASP Top 10:2025 A05:2025-Injection.

Attacker code changes structure of app's SQL statement → steal data, modify data, possibly OS command injection.

Derivative of [SQL Injection Prevention Cheat Sheet](SQL_Injection_Prevention.md).

## Parameterized Query Examples

Best SQL Injection prevention: [*parameterized queries*](SQL_Injection_Prevention.md). Samples below show parameterized queries in common web languages.

Many client-side frameworks/libraries offer client-side parameterization; often just string concatenation before sending raw queries to server. Ensure parameterization is server-side!

### Prepared Statement Examples

#### Using Java built-in feature

```java
String custname = request.getParameter("customerName");
String query = "SELECT account_balance FROM user_data WHERE user_name = ? ";  
PreparedStatement pstmt = connection.prepareStatement( query );
pstmt.setString( 1, custname);
ResultSet results = pstmt.executeQuery( );
```

#### Using Java with Hibernate

```java
// HQL
@Entity // declare as entity;
@NamedQuery(
 name="findByDescription",
 query="FROM Inventory i WHERE i.productDescription = :productDescription"
)
public class Inventory implements Serializable {
 @Id
 private long id;
 private String productDescription;
}

// Use case
// This should REALLY be validated too
String userSuppliedParameter = request.getParameter("Product-Description");
// Perform input validation to detect attacks
List<Inventory> list =
 session.getNamedQuery("findByDescription")
 .setParameter("productDescription", userSuppliedParameter).list();

// Criteria API
// This should REALLY be validated too
String userSuppliedParameter = request.getParameter("Product-Description");
// Perform input validation to detect attacks
Inventory inv = (Inventory) session.createCriteria(Inventory.class).add
(Restrictions.eq("productDescription", userSuppliedParameter)).uniqueResult();
```

#### Using .NET built-in feature

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

#### Using ASP .NET built-in feature

```csharp
string sql = "SELECT * FROM Customers WHERE CustomerId = @CustomerId";
SqlCommand command = new SqlCommand(sql);
command.Parameters.Add(new SqlParameter("@CustomerId", System.Data.SqlDbType.Int));
command.Parameters["@CustomerId"].Value = 1;
```

#### Using Ruby with ActiveRecord

```ruby
## Create
Project.create!(:name => 'owasp')
## Read
Project.all(:conditions => "name = ?", name)
Project.all(:conditions => { :name => name })
Project.where("name = :name", :name => name)
## Update
project.update_attributes(:name => 'owasp')
## Delete
Project.delete(:name => 'name')
```

#### Using Ruby built-in feature

```ruby
insert_new_user = db.prepare "INSERT INTO users (name, age, gender) VALUES (?, ? ,?)"
insert_new_user.execute 'aizatto', '20', 'male'
```

#### Using PHP with PHP Data Objects

```php
$stmt = $dbh->prepare("INSERT INTO REGISTRY (name, value) VALUES (:name, :value)");
$stmt->bindParam(':name', $name);
$stmt->bindParam(':value', $value);
```

#### Using Cold Fusion built-in feature

```coldfusion
<cfquery name = "getFirst" dataSource = "cfsnippets">
    SELECT * FROM #strDatabasePrefix#_courses WHERE intCourseID =
    <cfqueryparam value = #intCourseID# CFSQLType = "CF_SQL_INTEGER">
</cfquery>
```

#### Using PERL with Database Independent Interface

```perl
my $sql = "INSERT INTO foo (bar, baz) VALUES ( ?, ? )";
my $sth = $dbh->prepare( $sql );
$sth->execute( $bar, $baz );
```

#### Using Rust with SQLx
<!-- contributed by GeekMasher -->

```rust
// Input from CLI args but could be anything
let username = std::env::args().last().unwrap();

// Using build-in macros (compile time checks)
let users = sqlx::query_as!(
        User,
        "SELECT * FROM users WHERE name = ?",
        username
    )
    .fetch_all(&pool)
    .await 
    .unwrap();

// Using built-in functions
let users: Vec<User> = sqlx::query_as::<_, User>(
        "SELECT * FROM users WHERE name = ?"
    )
    .bind(&username)
    .fetch_all(&pool)
    .await
    .unwrap();
```

### Stored Procedure Examples

App SQL not only place for SQL injection. Stored Procedures that dynamically construct SQL can introduce it too.

Parameterize dynamic SQL w/ bind variables.

Bind variable examples in stored procedures, per database:

#### Oracle using PL/SQL

##### Normal Stored Procedure

No dynamic SQL. Parameters passed to stored procedures bind naturally to query location; nothing special needed:

```sql
PROCEDURE SafeGetBalanceQuery(UserID varchar, Dept varchar) AS BEGIN
   SELECT balance FROM accounts_table WHERE user_ID = UserID AND department = Dept;
END;
```

##### Stored Procedure Using Bind Variables in SQL Run with EXECUTE

Bind variables tell database dynamic SQL inputs are 'data', never code:

```sql
PROCEDURE AnotherSafeGetBalanceQuery(UserID varchar, Dept varchar)
          AS stmt VARCHAR(400); result NUMBER;
BEGIN
   stmt := 'SELECT balance FROM accounts_table WHERE user_ID = :1
            AND department = :2';
   EXECUTE IMMEDIATE stmt INTO result USING UserID, Dept;
   RETURN result;
END;
```

#### SQL Server using Transact-SQL

##### Normal Stored Procedure

No dynamic SQL. Parameters passed to stored procedures bind naturally to query location; nothing special needed:

```sql
PROCEDURE SafeGetBalanceQuery(@UserID varchar(20), @Dept varchar(10)) AS BEGIN
   SELECT balance FROM accounts_table WHERE user_ID = @UserID AND department = @Dept
END
```

##### Stored Procedure Using Bind Variables in SQL Run with EXEC

Bind variables tell database dynamic SQL inputs are 'data', never code:

```sql
PROCEDURE SafeGetBalanceQuery(@UserID varchar(20), @Dept varchar(10)) AS BEGIN
   DECLARE @sql VARCHAR(200)
   SELECT @sql = 'SELECT balance FROM accounts_table WHERE '
                 + 'user_ID = @UID AND department = @DPT'
   EXEC sp_executesql @sql,
                      '@UID VARCHAR(20), @DPT VARCHAR(10)',
                      @UID=@UserID, @DPT=@Dept
END
```

## References

- Oracle JDBC: Using Prepared Statements
- PHP PDO: Prepared Statements and Stored Procedures
