# Java Security Cheat Sheet

## Injection Prevention in Java

Tips for handling *Injection* in Java app code.


### What is Injection

Injection in OWASP Top 10 defined as:

*Consider anyone who can send untrusted data to the system, including external users, internal users, and administrators.*

### General advice to prevent Injection

General prevention:

1. Apply **Input Validation** (allowlist approach) + **Output Sanitizing+Escaping** on user input/output.
2. System interaction → use tech stack API features (Java / .Net / PHP...) instead of building command.

More advice: [cheatsheet](Input_Validation.md).

## Specific Injection types

*Java examples (see Maven project); advice applies to other tech: .Net / PHP / Ruby / Python...*

### SQL

#### Symptom

Occurs when app builds SQL query from untrusted user input via String and executes it.

#### How to prevent

Use *Query Parameterization*.

#### Example

``` java
/*No DB framework used here in order to show the real use of
  Prepared Statement from Java API*/
/*Open connection with H2 database and use it*/
Class.forName("org.h2.Driver");
String jdbcUrl = "jdbc:h2:file:" + new File(".").getAbsolutePath() + "/target/db";
try (Connection con = DriverManager.getConnection(jdbcUrl)) {

    /* Sample A: Select data using Prepared Statement*/
    String query = "select * from color where friendly_name = ?";
    List<String> colors = new ArrayList<>();
    try (PreparedStatement pStatement = con.prepareStatement(query)) {
        pStatement.setString(1, "yellow");
        try (ResultSet rSet = pStatement.executeQuery()) {
            while (rSet.next()) {
                colors.add(rSet.getString(1));
            }
        }
    }

    /* Sample B: Insert data using Prepared Statement*/
    query = "insert into color(friendly_name, red, green, blue) values(?, ?, ?, ?)";
    int insertedRecordCount;
    try (PreparedStatement pStatement = con.prepareStatement(query)) {
        pStatement.setString(1, "orange");
        pStatement.setInt(2, 239);
        pStatement.setInt(3, 125);
        pStatement.setInt(4, 11);
        insertedRecordCount = pStatement.executeUpdate();
    }

   /* Sample C: Update data using Prepared Statement*/
    query = "update color set blue = ? where friendly_name = ?";
    int updatedRecordCount;
    try (PreparedStatement pStatement = con.prepareStatement(query)) {
        pStatement.setInt(1, 10);
        pStatement.setString(2, "orange");
        updatedRecordCount = pStatement.executeUpdate();
    }

   /* Sample D: Delete data using Prepared Statement*/
    query = "delete from color where friendly_name = ?";
    int deletedRecordCount;
    try (PreparedStatement pStatement = con.prepareStatement(query)) {
        pStatement.setString(1, "orange");
        deletedRecordCount = pStatement.executeUpdate();
    }

}
```

#### References

- [SQL Injection Prevention Cheat Sheet](SQL_Injection_Prevention.md)

### JPA

#### Symptom

Occurs when app builds JPA query from untrusted user input via String and executes it. Like SQL injection, but altered language = JPA QL.

#### How to prevent

Use Java Persistence Query Language **Query Parameterization**.

#### Example

``` java
EntityManager entityManager = null;
try {
    /* Get a ref on EntityManager to access DB */
    entityManager = Persistence.createEntityManagerFactory("testJPA").createEntityManager();

    /* Define parameterized query prototype using named parameter to enhance readability */
    String queryPrototype = "select c from Color c where c.friendlyName = :colorName";

    /* Create the query, set the named parameter and execute the query */
    Query queryObject = entityManager.createQuery(queryPrototype);
    Color c = (Color) queryObject.setParameter("colorName", "yellow").getSingleResult();

} finally {
    if (entityManager != null && entityManager.isOpen()) {
        entityManager.close();
    }
}
```

#### References


### Operating System

#### Symptom

Occurs when app builds OS command from untrusted user input via String and executes it.

#### How to prevent

Use tech stack **API**.

#### Example

``` java
/* The context taken is, for example, to perform a PING against a computer.
* The prevention is to use the feature provided by the Java API instead of building
* a system command as String and execute it */
InetAddress host = InetAddress.getByName("localhost");
var reachable = host.isReachable(5000);
```

#### References


### XML: XPath Injection

#### Symptom

Occurs when app builds XPath query from untrusted user input via String and executes it.

#### How to prevent

Use **XPath Variable Resolver**.

#### Example

**Variable Resolver** implementation.

``` java
/**
 * Resolver in order to define parameter for XPATH expression.
 *
 */
public class SimpleVariableResolver implements XPathVariableResolver {

    private final Map<QName, Object> vars = new HashMap<QName, Object>();

    /**
     * External methods to add parameter
     *
     * @param name Parameter name
     * @param value Parameter value
     */
    public void addVariable(QName name, Object value) {
        vars.put(name, value);
    }

    /**
     * {@inheritDoc}
     *
     * @see javax.xml.xpath.XPathVariableResolver#resolveVariable(javax.xml.namespace.QName)
     */
    public Object resolveVariable(QName variableName) {
        return vars.get(variableName);
    }
}
```

Code using it for XPath query.

``` java
/*Create a XML document builder factory*/
DocumentBuilderFactory dbf = DocumentBuilderFactory.newInstance();

/*Disable External Entity resolution for different cases*/
//Do not performed here in order to focus on variable resolver code
//but do it for production code !

/*Load XML file*/
DocumentBuilder builder = dbf.newDocumentBuilder();
Document doc = builder.parse(new File("src/test/resources/SampleXPath.xml"));

/* Create and configure parameter resolver */
String bid = "bk102";
SimpleVariableResolver variableResolver = new SimpleVariableResolver();
variableResolver.addVariable(new QName("bookId"), bid);

/*Create and configure XPATH expression*/
XPath xpath = XPathFactory.newInstance().newXPath();
xpath.setXPathVariableResolver(variableResolver);
XPathExpression xPathExpression = xpath.compile("//book[@id=$bookId]");

/* Apply expression on XML document */
Object nodes = xPathExpression.evaluate(doc, XPathConstants.NODESET);
NodeList nodesList = (NodeList) nodes;
Element book = (Element)nodesList.item(0);
var containsRalls = book.getTextContent().contains("Ralls, Kim");
```

#### References


### HTML/JavaScript/CSS

#### Symptom

Occurs when app builds HTTP response from untrusted user input and sends it to browser.

#### How to prevent

Use context-specific output encoding when displaying untrusted text. App intentionally accepts HTML markup → use HTML sanitization policy for permitted elements/attributes. Input validation enforces business rules; ≠ replacement for these XSS controls. See [XSS Prevention Cheat Sheet](Cross_Site_Scripting_Prevention.md) for HTML, attribute, JavaScript, CSS context requirements.

#### Example

``` java
// Illustrative business validation; output still needs the appropriate XSS control.
String userInput = "You user login is owasp-user01";

/* First we check that the value contains only expected character*/
if (!Pattern.matches("[a-zA-Z0-9\\s\\-]{1,50}", userInput))
{
    return false;
}

// Plain text for an ordinary HTML body position, such as the content of a div.
String encodedText = Encode.forHtml(userInput);

// Allowed markup for an HTML body position; not for attributes, script, or style.
String outputToUser = "You <p>user login</p> is <strong>owasp-user01</strong>";
outputToUser += "<script>alert(22);</script><img src='#' onload='javascript:alert(23);'>";

/* Create a sanitizing policy that only allow tag '<p>' and '<strong>'*/
PolicyFactory policy = new HtmlPolicyBuilder().allowElements("p", "strong").toFactory();

/* Sanitize the output that will be sent to user*/
String safeOutput = policy.sanitize(outputToUser);

/* Keep the permitted markup: encoding this whole fragment would display tags as text. */
String finalSafeOutputExpected = "You <p>user login</p> is <strong>owasp-user01</strong>";
if (!finalSafeOutputExpected.equals(safeOutput))
{
    return false;
}
```

#### References


### LDAP

Dedicated [cheatsheet](LDAP_Injection_Prevention.md) exists.

### NoSQL

#### Symptom

Occurs when app builds NoSQL API call expression from untrusted user input.

#### How to prevent

Validate expected input type, length, business format; then use driver's structured query API. NEVER concatenate untrusted values into query strings or accept client-supplied query/operator objects. MongoDB's driver guidance distinguishes literal values built via typed APIs from JSON/JavaScript parsed as query syntax. Punctuation blacklist not needed for string equality query below. Broader controls: [NoSQL Security Cheat Sheet](NoSQL_Security.md#prevent-nosql-injection).

#### Example - MongoDB

Assume `collection` = app-configured `MongoCollection<Document>`. Example uses Java driver's equality filter builder w/ string value; 50-character limit = illustrative business rule, ≠ injection defense.

```java
String userInput = "Brooklyn";
if (userInput == null || userInput.length() > 50) {
    throw new IllegalArgumentException("Invalid borough");
}

// Keep the field name fixed and the input as a string value.
Bson expression = Filters.eq("borough", userInput);
FindIterable<Document> restaurants = collection.find(expression);
```

#### References


### Log Injection

#### Symptom

Log Injection occurs when app includes untrusted data in log message (e.g., attacker injecting CRLF causes extra log entry looking like it came from completely different user). More: OWASP Log Injection page.

#### How to prevent

Defenses:

- Use structured log formats (e.g. JSON) over unstructured text. Unstructured formats susceptible to **C**arriage **R**eturn (CR) and **L**ine **F**eed (LF) injection (see CWE-93).
- Limit size of user input value used in log message.
- Apply [all XSS defenses](Cross_Site_Scripting_Prevention.md) when viewing log files in browser.

#### Example using Log4j Core 2

Recommended production logging policy: send logs to network socket using structured JSON Template Layout (introduced in Log4j 2.14.0); truncate string values longer than 500 characters via `maxStringLength` configuration attribute. Truncation suffix appended after limit; does not cap encoded byte size or total JSON document size:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Configuration xmlns="https://logging.apache.org/xml/ns"
               xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
               xsi:schemaLocation="
                   https://logging.apache.org/xml/ns
                   https://logging.apache.org/xml/ns/log4j-config-2.xsd">
  <Appenders>
    <Socket name="SOCKET"
            host="localhost"
            port="12345">
      <!-- Truncate strings longer than 500 characters, then append the truncation suffix -->
      <JsonTemplateLayout maxStringLength="500"
                          nullEventDelimiterEnabled="true"/>
    </Socket>
  </Appenders>
  <Loggers>
    <Root level="DEBUG">
      <AppenderRef ref="SOCKET"/>
    </Root>
  </Loggers>
</Configuration>
```

See Integration with service-oriented architectures on Log4j website for more tips.

Logger usage in code:

``` java
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
...
// Most common way to declare a logger
private static final Logger logger = LogManager.getLogger();
// GOOD!
//
// Use parameterized logging to add user data to a message
// The pattern should be a compile-time constant
logger.warn("Login failed for user {}.", username);
// BAD!
//
// Don't mix string concatenation and parameters
// If `username` contains `{}`, the exception will leak into the message
logger.warn("Failure for user " + username + " and role {}.", role, ex);
...
```

See Log4j API Best Practices for more info.

#### Example using Logback

Recommended production logging policy: structured JsonEncoder (introduced in Logback 1.3.8). Example below: Logback rolls on 10 log files of 5 MiB each:

``` xml
<?xml version="1.0" encoding="UTF-8" ?>
<!DOCTYPE configuration>
<configuration>
  <import class="ch.qos.logback.classic.encoder.JsonEncoder"/>
  <import class="ch.qos.logback.core.rolling.FixedWindowRollingPolicy"/>
  <import class="ch.qos.logback.core.rolling.RollingFileAppender"/>
  <import class="ch.qos.logback.core.rolling.SizeBasedTriggeringPolicy"/>

  <appender name="RollingFile" class="RollingFileAppender">
    <file>app.log</file>
    <rollingPolicy class="FixedWindowRollingPolicy">
      <fileNamePattern>app-%i.log</fileNamePattern>
      <minIndex>1</minIndex>
      <maxIndex>10</maxIndex>
    </rollingPolicy>
    <triggeringPolicy class="SizeBasedTriggeringPolicy">
      <maxFileSize>5MB</maxFileSize>
    </triggeringPolicy>
    <encoder class="JsonEncoder"/>
  </appender>

  <root level="DEBUG">
    <appender-ref ref="RollingFile"/>
  </root>
</configuration>
```

Logger usage in code:

``` java
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
...
// Most common way to declare a logger
Logger logger = LoggerFactory.getLogger(MyClass.class);
// GOOD!
//
// Use parameterized logging to add user data to a message
// The pattern should be a compile-time constant
logger.warn("Login failed for user {}.", username);
// BAD!
//
// Don't mix string concatenation and parameters
// If `username` contains `{}`, the exception will leak into the message
logger.warn("Failure for user " + username + " and role {}.", role, ex);
...
```

#### References


## Cryptography

### General cryptography guidance

- **Never, ever write your own cryptographic functions.**
- Avoid writing crypto code where possible. Use existing secret management solutions or cloud provider's. See [OWASP Secrets Management Cheat Sheet](Secrets_Management.md).
- No existing secret management solution → use trusted, well-known implementation library over built-in JCA/JCE; far too easy to make crypto errors there.
- App/protocol must easily support future change of cryptographic algorithms.
- Use package manager to keep all packages up to date. Watch updates on dev setup; plan app updates accordingly.
- Examples below use Google Tink, library by cryptography experts for safe crypto use (minimizes common mistakes made with standard crypto libraries).

### Encryption for storage

Follow algorithm guidance in [OWASP Cryptographic Storage Cheat Sheet](Cryptographic_Storage.md#algorithms).

#### Symmetric example using Google Tink

Tink documents common tasks, e.g. how to perform simple symmetric encryption.

Snippet shows encapsulated use:

<details>
  <summary>Click here to view the "Tink symmetric encryption" code snippet.</summary>

``` java
import static java.nio.charset.StandardCharsets.UTF_8;

import com.google.crypto.tink.Aead;
import com.google.crypto.tink.InsecureSecretKeyAccess;
import com.google.crypto.tink.KeysetHandle;
import com.google.crypto.tink.TinkJsonProtoKeysetFormat;
import com.google.crypto.tink.aead.AeadConfig;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Base64;

// AesGcmSimpleTest
public class App {

    // Based on example from:
    // https://github.com/tink-crypto/tink-java/tree/main/examples/aead

    public static void main(String[] args) throws Exception {

        // Key securely generated using:
        // tinkey create-keyset --key-template AES128_GCM --out-format JSON --out aead_test_keyset.json



        // Register all AEAD key types with the Tink runtime.
        AeadConfig.register();

        // Read the keyset into a KeysetHandle.
        KeysetHandle handle =
        TinkJsonProtoKeysetFormat.parseKeyset(
            new String(Files.readAllBytes( Paths.get("/home/fredbloggs/aead_test_keyset.json")), UTF_8), InsecureSecretKeyAccess.get());

        String message = "This message to be encrypted";
        System.out.println(message);

        // Add some relevant context about the encrypted data that should be verified
        // on decryption
        String metadata = "Sender: fredbloggs@example.com";

        // Encrypt the message
        byte[] cipherText = AesGcmSimple.encrypt(message, metadata, handle);
        System.out.println(Base64.getEncoder().encodeToString(cipherText));

        // Decrypt the message
        String message2 = AesGcmSimple.decrypt(cipherText, metadata, handle);
        System.out.println(message2);
    }
}

class AesGcmSimple {

    public static byte[] encrypt(String plaintext, String metadata, KeysetHandle handle) throws Exception {
        // Get the primitive.
        Aead aead = handle.getPrimitive(Aead.class);
        return aead.encrypt(plaintext.getBytes(UTF_8), metadata.getBytes(UTF_8));
    }

    public static String decrypt(byte[] ciphertext, String metadata, KeysetHandle handle) throws Exception {
        // Get the primitive.
        Aead aead = handle.getPrimitive(Aead.class);
        return new String(aead.decrypt(ciphertext, metadata.getBytes(UTF_8)),UTF_8);
    }

}

```

</details>

#### Symmetric example using built-in JCA/JCE classes

Separate library impossible → built-in JCA/JCE classes usable, but strongly recommended: cryptography expert reviews full design + code; even most trivial error severely weakens encryption.

Snippet shows AES-GCM encryption/decryption of data.

Constraints/pitfalls:

- No key rotation/management (whole topic itself).
- Use different nonce for every encryption operation, esp. if same key reused. See [this answer on Cryptography Stack Exchange](https://crypto.stackexchange.com/a/66500).
- Store key securely.

<details>
  <summary>Click here to view the "JCA/JCE symmetric encryption" code snippet.</summary>

```java
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import javax.crypto.spec.*;
import javax.crypto.*;
import java.util.Base64;


// AesGcmSimpleTest
class Main {

    public static void main(String[] args) throws Exception {
        // Key of 32 bytes / 256 bits for AES
        KeyGenerator keyGen = KeyGenerator.getInstance(AesGcmSimple.ALGORITHM);
        keyGen.init(AesGcmSimple.KEY_SIZE, new SecureRandom());
        SecretKey secretKey = keyGen.generateKey();

        // Nonce of 12 bytes / 96 bits and this size should always be used.
        // It is critical for AES-GCM that a unique nonce is used for every cryptographic operation.
        byte[] nonce = new byte[AesGcmSimple.IV_LENGTH];
        SecureRandom random = new SecureRandom();
        random.nextBytes(nonce);

        var message = "This message to be encrypted";
        System.out.println(message);

        // Encrypt the message
        byte[] cipherText = AesGcmSimple.encrypt(message, nonce, secretKey);
        System.out.println(Base64.getEncoder().encodeToString(cipherText));

        // Decrypt the message
        var message2 = AesGcmSimple.decrypt(cipherText, nonce, secretKey);
        System.out.println(message2);
    }
}

class AesGcmSimple {

    public static final String ALGORITHM = "AES";
    public static final String CIPHER_ALGORITHM = "AES/GCM/NoPadding";
    public static final int KEY_SIZE = 256;
    public static final int TAG_LENGTH = 128;
    public static final int IV_LENGTH = 12;

    public static byte[] encrypt(String plaintext, byte[] nonce, SecretKey secretKey) throws Exception {
        return cryptoOperation(plaintext.getBytes(StandardCharsets.UTF_8), nonce, secretKey, Cipher.ENCRYPT_MODE);
    }

    public static String decrypt(byte[] ciphertext, byte[] nonce, SecretKey secretKey) throws Exception {
        return new String(cryptoOperation(ciphertext, nonce, secretKey, Cipher.DECRYPT_MODE), StandardCharsets.UTF_8);
    }

    private static byte[] cryptoOperation(byte[] text, byte[] nonce, SecretKey secretKey, int mode) throws Exception {
        Cipher cipher = Cipher.getInstance(CIPHER_ALGORITHM);
        GCMParameterSpec gcmParameterSpec = new GCMParameterSpec(TAG_LENGTH, nonce);
        cipher.init(mode, secretKey, gcmParameterSpec);
        return cipher.doFinal(text);
    }

}
```

</details>

### Encryption for transmission

Again follow algorithm guidance in [OWASP Cryptographic Storage Cheat Sheet](Cryptographic_Storage.md#algorithms).

#### Asymmetric example using Google Tink

Tink documents common tasks, e.g. how to perform hybrid encryption where two parties share data based on asymmetric key pair.

Snippet shows sharing secrets between Alice and Bob:

<details>
  <summary>Click here to view the "Tink hybrid encryption" code snippet.</summary>

``` java
import static java.nio.charset.StandardCharsets.UTF_8;

import com.google.crypto.tink.HybridDecrypt;
import com.google.crypto.tink.HybridEncrypt;
import com.google.crypto.tink.InsecureSecretKeyAccess;
import com.google.crypto.tink.KeysetHandle;
import com.google.crypto.tink.TinkJsonProtoKeysetFormat;
import com.google.crypto.tink.hybrid.HybridConfig;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Base64;

// HybridReplaceTest
class App {
    public static void main(String[] args) throws Exception {
        /*

        Generated public/private keypairs for Bob and Alice using the
        following tinkey commands:

        ./tinkey create-keyset \
        --key-template DHKEM_X25519_HKDF_SHA256_HKDF_SHA256_AES_256_GCM \
        --out-format JSON --out alice_private_keyset.json

        ./tinkey create-keyset \
        --key-template DHKEM_X25519_HKDF_SHA256_HKDF_SHA256_AES_256_GCM \
        --out-format JSON --out bob_private_keyset.json

        ./tinkey create-public-keyset --in alice_private_keyset.json \
        --in-format JSON --out-format JSON --out alice_public_keyset.json

        ./tinkey create-public-keyset --in bob_private_keyset.json \
        --in-format JSON --out-format JSON --out bob_public_keyset.json
        */

        HybridConfig.register();

        // Generate ECC key pair for Alice
        var alice = new HybridSimple(
                getKeysetHandle("/home/alicesmith/private_keyset.json"),
                getKeysetHandle("/home/alicesmith/public_keyset.json")

        );

        KeysetHandle alicePublicKey = alice.getPublicKey();

        // Generate ECC key pair for Bob
        var bob = new HybridSimple(
                getKeysetHandle("/home/bobjones/private_keyset.json"),
                getKeysetHandle("/home/bobjones/public_keyset.json")

        );

        KeysetHandle bobPublicKey = bob.getPublicKey();

        // This keypair generation should be reperformed every so often in order to
        // obtain a new shared secret to avoid a long lived shared secret.

        // Alice encrypts a message to send to Bob
        String plaintext = "Hello, Bob!";

        // Add some relevant context about the encrypted data that should be verified
        // on decryption
        String metadata = "Sender: alicesmith@example.com";

        System.out.println("Secret being sent from Alice to Bob: " + plaintext);
        var cipherText = alice.encrypt(bobPublicKey, plaintext, metadata);
        System.out.println("Ciphertext being sent from Alice to Bob: " + Base64.getEncoder().encodeToString(cipherText));


        // Bob decrypts the message
        var decrypted = bob.decrypt(cipherText, metadata);
        System.out.println("Secret received by Bob from Alice: " + decrypted);
        System.out.println();

        // Bob encrypts a message to send to Alice
        String plaintext2 = "Hello, Alice!";

        // Add some relevant context about the encrypted data that should be verified
        // on decryption
        String metadata2 = "Sender: bobjones@example.com";

        System.out.println("Secret being sent from Bob to Alice: " + plaintext2);
        var cipherText2 = bob.encrypt(alicePublicKey, plaintext2, metadata2);
        System.out.println("Ciphertext being sent from Bob to Alice: " + Base64.getEncoder().encodeToString(cipherText2));

        // Bob decrypts the message
        var decrypted2 = alice.decrypt(cipherText2, metadata2);
        System.out.println("Secret received by Alice from Bob: " + decrypted2);
    }

    private static KeysetHandle getKeysetHandle(String filename) throws Exception
    {
        return TinkJsonProtoKeysetFormat.parseKeyset(
                new String(Files.readAllBytes( Paths.get(filename)), UTF_8), InsecureSecretKeyAccess.get());
    }
}
class HybridSimple {

    private KeysetHandle privateKey;
    private KeysetHandle publicKey;


    public HybridSimple(KeysetHandle privateKeyIn, KeysetHandle publicKeyIn) throws Exception {
        privateKey = privateKeyIn;
        publicKey = publicKeyIn;
    }

    public KeysetHandle getPublicKey() {
        return publicKey;
    }

    public byte[] encrypt(KeysetHandle partnerPublicKey, String message, String metadata) throws Exception {

        HybridEncrypt encryptor = partnerPublicKey.getPrimitive(HybridEncrypt.class);

        // return the encrypted value
        return encryptor.encrypt(message.getBytes(UTF_8), metadata.getBytes(UTF_8));
    }
    public String decrypt(byte[] ciphertext, String metadata) throws Exception {

        HybridDecrypt decryptor = privateKey.getPrimitive(HybridDecrypt.class);

        // return the encrypted value
        return new String(decryptor.decrypt(ciphertext, metadata.getBytes(UTF_8)),UTF_8);
    }


}
```

</details>

#### Asymmetric example using built-in JCA/JCE classes

Separate library impossible → built-in JCA/JCE classes usable, but strongly recommended: cryptography expert reviews full design + code; even most trivial error severely weakens encryption.

Java 25+ example: Elliptic Curve Diffie-Hellman (ECDH), then HKDF-SHA-256 and AES-GCM. NEVER use raw ECDH output directly as AES key: [RFC 5869](https://www.rfc-editor.org/rfc/rfc5869.html#section-3.3) explains why Diffie-Hellman values need extraction. Java KDF API does both extraction and expansion here. Primitive demonstration, ≠ authenticated communication protocol.

Code relies on AesGcmSimple class from [previous section](#symmetric-example-using-built-in-jcajce-classes).

Constraints/pitfalls:

- No key rotation/management (whole topic itself).
- Code deliberately enforces new nonce per encryption operation; nonce must be managed as separate data item alongside ciphertext.
- Store private keys securely.
- No public key validation before use.
- Authenticate public keys independently before use. HKDF doesn't authenticate peer; example omits that protocol + identity/context binding.

<details>
  <summary>Click here to view the "JCA/JCE hybrid encryption" code snippet.</summary>

```java
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import javax.crypto.spec.*;
import javax.crypto.*;
import java.util.*;
import java.security.*;
import java.security.spec.*;
import java.util.Arrays;

// ECDHSimpleTest
class Main {
    public static void main(String[] args) throws Exception {

        // Generate ECC key pair for Alice
        var alice = new ECDHSimple();
        Key alicePublicKey = alice.getPublicKey();

        // Generate ECC key pair for Bob
        var bob = new ECDHSimple();
        Key bobPublicKey = bob.getPublicKey();

        // This keypair generation should be reperformed every so often in order to
        // obtain a new shared secret to avoid a long lived shared secret.

        // Alice encrypts a message to send to Bob
        String plaintext = "Hello"; //, Bob!";
        System.out.println("Secret being sent from Alice to Bob: " + plaintext);

        var retPair = alice.encrypt(bobPublicKey, plaintext);
        var nonce = retPair.getKey();
        var cipherText = retPair.getValue();

        System.out.println("Both cipherText and nonce being sent from Alice to Bob: " + Base64.getEncoder().encodeToString(cipherText) + " " + Base64.getEncoder().encodeToString(nonce));


        // Bob decrypts the message
        var decrypted = bob.decrypt(alicePublicKey, cipherText, nonce);
        System.out.println("Secret received by Bob from Alice: " + decrypted);
        System.out.println();

        // Bob encrypts a message to send to Alice
        String plaintext2 = "Hello"; //, Alice!";
        System.out.println("Secret being sent from Bob to Alice: " + plaintext2);

        var retPair2 = bob.encrypt(alicePublicKey, plaintext2);
        var nonce2 = retPair2.getKey();
        var cipherText2 = retPair2.getValue();
        System.out.println("Both cipherText2 and nonce2 being sent from Bob to Alice: " + Base64.getEncoder().encodeToString(cipherText2) + " " + Base64.getEncoder().encodeToString(nonce2));

        // Bob decrypts the message
        var decrypted2 = alice.decrypt(bobPublicKey, cipherText2, nonce2);
        System.out.println("Secret received by Alice from Bob: " + decrypted2);
    }
}
class ECDHSimple {
    private KeyPair keyPair;

    public class AesKeyNonce {
        public SecretKey Key;
        public byte[] Nonce;
    }

    public ECDHSimple() throws Exception {
        KeyPairGenerator keyPairGenerator = KeyPairGenerator.getInstance("EC");
        ECGenParameterSpec ecSpec = new ECGenParameterSpec("secp256r1"); // Using secp256r1 curve
        keyPairGenerator.initialize(ecSpec);
        keyPair = keyPairGenerator.generateKeyPair();
    }

    public Key getPublicKey() {
        return keyPair.getPublic();
    }

    public AbstractMap.SimpleEntry<byte[], byte[]> encrypt(Key partnerPublicKey, String message) throws Exception {

        // Generate the AES Key and Nonce
        AesKeyNonce aesParams = generateAESParams(partnerPublicKey);

        // return the encrypted value
        return new AbstractMap.SimpleEntry<>(
            aesParams.Nonce,
            AesGcmSimple.encrypt(message, aesParams.Nonce, aesParams.Key)
            );
    }
    public String decrypt(Key partnerPublicKey, byte[] ciphertext, byte[] nonce) throws Exception {

        // Generate the AES Key and Nonce
        AesKeyNonce aesParams = generateAESParams(partnerPublicKey, nonce);

        // return the decrypted value
        return AesGcmSimple.decrypt(ciphertext, aesParams.Nonce, aesParams.Key);
    }

    private AesKeyNonce generateAESParams(Key partnerPublicKey, byte[] nonce) throws Exception {

        // Derive the secret based on this side's private key and the other side's public key
        KeyAgreement keyAgreement = KeyAgreement.getInstance("ECDH");
        keyAgreement.init(keyPair.getPrivate());
        keyAgreement.doPhase(partnerPublicKey, true);
        byte[] secret = keyAgreement.generateSecret();

        AesKeyNonce aesKeyNonce = new AesKeyNonce();

        // Illustrative domain label; a real protocol defines its full context binding.
        byte[] info = "OWASP Java ECDH example: AES-256-GCM v1".getBytes(StandardCharsets.UTF_8);
        var derivation = HKDFParameterSpec.ofExtract().addIKM(secret)
                .thenExpand(info, AesGcmSimple.KEY_SIZE / 8);
        aesKeyNonce.Key = KDF.getInstance("HKDF-SHA256").deriveKey("AES", derivation);
        Arrays.fill(secret, (byte) 0);

        // Passed in nonce will be used.
        aesKeyNonce.Nonce = nonce;
        return aesKeyNonce;

    }

    private AesKeyNonce generateAESParams(Key partnerPublicKey) throws Exception {

        // Nonce of 12 bytes / 96 bits and this size should always be used.
        // It is critical for AES-GCM that a unique nonce is used for every cryptographic operation.
        // Therefore this is not generated from the shared secret
        byte[] nonce = new byte[AesGcmSimple.IV_LENGTH];
        SecureRandom random = new SecureRandom();
        random.nextBytes(nonce);
        return generateAESParams(partnerPublicKey, nonce);

    }
}
```

</details>

## References

