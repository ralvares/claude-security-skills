# XML External Entity Prevention Cheat Sheet

## Introduction

XML External Entity (XXE) injection: XML processor resolves external entity from untrusted input. Can expose local files, cause server-side request forgery (SSRF), exhaust resources. CWE-611 describes weakness; this sheet gives parser-specific controls.

## General Guidance

**Disable document type definitions (DTDs) whenever possible.** Reject DOCTYPE declarations if parser supports it. If app needs DTDs: disable external entity resolution + external DTD loading, limit entity expansion.

- Keep XInclude disabled unless explicitly required; loads resources independently of DTDs.
- Restrict external access during schema validation and style sheet processing, not only XML parsing.
- Unsupported security setting = configuration failure. Don't continue processing untrusted XML w/ partial hardening.

Controls/defaults vary by parser; see language sections below and, for Java, JAXP Security Guide. Preventing XXE doesn't prevent every XML denial-of-service attack. See [XML Security Cheat Sheet](XML_Security.md#xml-entity-expansion) for entity expansion + other XML resource risks.

## C/C++

### libxml2

Enum xmlParserOption should not define:

- `XML_PARSE_NOENT`: expands entities, substitutes replacement text
- `XML_PARSE_DTDLOAD`: loads external DTD

Note:

libxml2 version 2.9+: XXE disabled by default.

Search for these APIs; ensure no `XML_PARSE_NOENT` and `XML_PARSE_DTDLOAD` in parameters:

- `xmlCtxtReadDoc`
- `xmlCtxtReadFd`
- `xmlCtxtReadFile`
- `xmlCtxtReadIO`
- `xmlCtxtReadMemory`
- `xmlCtxtUseOptions`
- `xmlParseInNodeContext`
- `xmlReadDoc`
- `xmlReadFd`
- `xmlReadFile`
- `xmlReadIO`
- `xmlReadMemory`

### libxerces-c

`XercesDOMParser`:

``` cpp
XercesDOMParser *parser = new XercesDOMParser;
parser->setCreateEntityReferenceNodes(true);
parser->setDisableDefaultEntityResolution(true);
```

SAXParser:

``` cpp
SAXParser* parser = new SAXParser;
parser->setDisableDefaultEntityResolution(true);
```

`SAX2XMLReader`: configure reader that parses document. Xerces-C++ feature docs: `fgXercesDisableDefaultEntityResolution` prevents fallback resolution when `resolveEntity` returns `NULL`. Custom resolver must also reject unapproved resources.

``` cpp
SAX2XMLReader* reader = XMLReaderFactory::createXMLReader();
reader->setFeature(XMLUni::fgXercesDisableDefaultEntityResolution, true);
```

## ColdFusion

Adobe ColdFusion and Lucee both have built-in mechanisms to disable external XML entities.

### Adobe ColdFusion

ColdFusion 2018 Update 14 and ColdFusion 2021 Update 4+: all native functions processing XML have XML parser argument disabling external XML entities. No global setting → developers MUST ensure every XML function call uses correct security options.

Per XmlParse() docs, disable XXE:

```
<cfset parseroptions = structnew()>
<cfset parseroptions.ALLOWEXTERNALENTITIES = false>
<cfscript>
a = XmlParse("xml.xml", false, parseroptions);
writeDump(a);
</cfscript>
```

Use "parseroptions" structure as argument to secure other XML-processing functions too:

```
XxmlSearch(xmldoc, xpath,parseroptions);

XmlTransform(xmldoc,xslt,parseroptions);

isXML(xmldoc,parseroptions);
```

### Lucee

Lucee 5.3.4.51+: disable external XML entities by adding to Application.cfc:

```
this.xmlFeatures = {
     externalGeneralEntities: false,
     secure: true,
     disallowDoctypeDecl: true
};
```

External XML entities disabled by default as of Lucee 5.4.2.10 and Lucee 6.0.0.514.

## Java

Examples use built-in Java API for XML Processing (JAXP) implementations on Java 9+. `newDefaultInstance()` (`newDefaultFactory()` for StAX) selects built-in implementation, not provider chosen via JAXP lookup mechanism. Other providers: see [implementation differences](#other-providers-and-required-dtds).

Illustrative configuration fragments. App opens/closes input streams, supplies trusted schemas and style sheets, handles exceptions. **Stop processing if any required security setting fails; don't catch exception and continue parsing.** Pass streams, not untrusted filenames/URLs: external-entity controls don't restrict access to initial resource passed directly to parsing/processing API.

### Secure configuration by API

| API | Recommended approach |
| --- | --- |
| [`DocumentBuilderFactory`](#documentbuilderfactory-dom) | Reject DOCTYPE declarations before building document tree |
| [`SAXParserFactory` / `XMLReader`](#saxparserfactory-and-xmlreader) | Reject DOCTYPE declarations; parse through configured reader |
| [`XMLInputFactory`](#xmlinputfactory-stax) | Disable DTD processing + external entities |
| [`TransformerFactory`](#transformerfactory-xslt) | Deny external access before compiling style sheet |
| [`SchemaFactory` / `Validator`](#schemafactory-and-validator) | Deny external access during compilation + validation |
| [`XPath`](#xpath) | Evaluate against document parsed w/ hardened builder |
| [`Unmarshaller`](#jaxb-unmarshaller) | Supply hardened StAX reader |

#### DocumentBuilderFactory (DOM)

Document Object Model (DOM) parsing: reject DOCTYPE declarations, leave XInclude disabled.

``` java
DocumentBuilderFactory dbf = DocumentBuilderFactory.newDefaultInstance();
dbf.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true);
dbf.setFeature(XMLConstants.FEATURE_SECURE_PROCESSING, true);

DocumentBuilder builder = dbf.newDocumentBuilder();
Document doc = builder.parse(untrustedStream);
```

`setExpandEntityReferences(false)` controls entity reference representation in tree. Not a substitute for blocking external resources.

#### SAXParserFactory and XMLReader

Simple API for XML (SAX) parsing: reject DOCTYPE declarations on factory before creating reader.

``` java
SAXParserFactory spf = SAXParserFactory.newDefaultInstance();
spf.setNamespaceAware(true);
spf.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true);
spf.setFeature(XMLConstants.FEATURE_SECURE_PROCESSING, true);

XMLReader reader = spf.newSAXParser().getXMLReader();
reader.setContentHandler(handler);  // application's SAX content handler
reader.parse(new InputSource(untrustedStream));
```

#### XMLInputFactory (StAX)

Streaming API for XML (StAX): set both DTD and external-entity properties. DTD processing defaults enabled; external-entity default unspecified.

``` java
XMLInputFactory xif = XMLInputFactory.newDefaultFactory();
xif.setProperty(XMLInputFactory.SUPPORT_DTD, false);
xif.setProperty(XMLInputFactory.IS_SUPPORTING_EXTERNAL_ENTITIES, false);
xif.setXMLResolver((publicId, systemId, baseURI, namespace) -> {
    throw new XMLStreamException("External references are not allowed");
});
XMLStreamReader xsr = xif.createXMLStreamReader(untrustedStream);
```

Disabling DTD processing doesn't necessarily reject DOCTYPE declaration. StAX doesn't support `FEATURE_SECURE_PROCESSING`; use provider's processing limits when DTDs required.

#### TransformerFactory (XSLT)

XSL Transformations (XSLT) can load resources via style sheet imports, includes, `document()`, independently of external entities. Trusted app-owned style sheet needing no external resources: set both external-access restrictions before compilation:

``` java
TransformerFactory factory = TransformerFactory.newDefaultInstance();
factory.setFeature(XMLConstants.FEATURE_SECURE_PROCESSING, true);
factory.setAttribute(XMLConstants.ACCESS_EXTERNAL_DTD, "");
factory.setAttribute(XMLConstants.ACCESS_EXTERNAL_STYLESHEET, "");

Transformer transformer =
        factory.newTransformer(new StreamSource(trustedStylesheetStream));
transformer.transform(new StreamSource(untrustedStream), result);
```

Limits internal entity expansion but not a sandbox for untrusted style sheets. Choose style sheet in app code; don't trust style sheet reference from input document. Other providers or required dependencies: apply [resource policy](#external-resources-for-transformations-and-validation) below.

#### SchemaFactory and Validator

Schema compilation and validation can each load external resources. Trusted app-owned schema needing no external resources: restrict access on factory before compiling schema; restrictions also apply during validation:

``` java
SchemaFactory sf = SchemaFactory.newDefaultInstance();
sf.setFeature(XMLConstants.FEATURE_SECURE_PROCESSING, true);
sf.setProperty(XMLConstants.ACCESS_EXTERNAL_DTD, "");
sf.setProperty(XMLConstants.ACCESS_EXTERNAL_SCHEMA, "");
Schema schema = sf.newSchema(new StreamSource(trustedSchemaStream));

Validator validator = schema.newValidator();
validator.validate(new StreamSource(untrustedStream));
```

Installing resolver: configure on factory **and each validator**; validators don't inherit factory's resolver. Same for `ValidatorHandler`.

#### XPath

Avoid `InputSource` overloads of `XPath.evaluate` (parse document internally). Use [hardened DOM builder](#documentbuilderfactory-dom), evaluate against resulting document:

``` java
Document doc = builder.parse(untrustedStream);
XPath xpath = XPathFactory.newDefaultInstance().newXPath();
NodeList nodes = (NodeList) xpath.evaluate("//user/name", doc, XPathConstants.NODESET);
```

#### JAXB Unmarshaller

Java Architecture for XML Binding (JAXB): pass reader from [StAX example](#xmlinputfactory-stax) to `Unmarshaller.unmarshal`. Passing raw XML delegates parser configuration to JAXB provider.

``` java
Object result = jaxbContext.createUnmarshaller().unmarshal(xsr);
```

### Other providers and required DTDs

`newInstance()` can select third-party provider w/ different settings. Verify provider's documented controls; fail if required setting unsupported. Boolean features: `setFeature`; external-access properties: `setAttribute` on DOM factory, `setProperty` on SAX parser/reader.

Internal DTDs required: install `EntityResolver` on DOM builder or SAX reader that throws `SAXException` for external references. Returning `null` delegates resolution to parser. Set these Xerces/SAX features to `false` instead of rejecting DOCTYPE:

- `http://xml.org/sax/features/external-general-entities`
- `http://xml.org/sax/features/external-parameter-entities`
- `http://apache.org/xml/features/nonvalidating/load-external-dtd`

Keep XInclude disabled. Last feature controls only non-validating parsing; DTD validation needs explicit policy for any required external DTD. Set applicable `ACCESS_EXTERNAL_*` properties to `""` when supported. Resolver doesn't limit internal entity expansion: enable `FEATURE_SECURE_PROCESSING` where supported, configure provider's processing limits. Secure processing alone not portable replacement for external-access restrictions.

SAX resolver: call `reader.parse(...)` directly. `SAXParser.parse(source, DefaultHandler)` replaces reader's resolver w/ supplied handler.

### External resources for transformations and validation

Other transformation/validation providers: supply XML, schemas, style sheets via `SAXSource` w/ hardened namespace-aware `XMLReader`. Separately install rejecting `URIResolver` (transformations) or `LSResourceResolver` (schemas). Input parser's settings don't control style sheet or schema dependencies.

External dependencies required: use catalog w/ `RESOLVE=strict` mapping approved identifiers to local resources, or allowlisting resolver. Reject unapproved identifiers; returning `null` delegates to default resolution. External-access properties restrict protocols, not individual resources: allowing `https` ≠ resource allowlist. Resources returned by your resolver remain your responsibility.

Apply policy before compilation and during processing. Set `URIResolver` on transformer factory before `newTransformer`; transformers use it by default. Validation: install resolver on factory and every validator as above.

### Parsers that wrap a JAXP parser

Supply wrappers w/ hardened parser; check whether they replace its resolver:

| Library | Configuration |
| --- | --- |
| dom4j | Supply reader w/ `SAXReader.setXMLReader`, set rejecting resolver w/ `SAXReader.setEntityResolver`; dom4j replaces reader's resolver |
| JDOM | Supply reader via `SAXBuilder(XMLReaderJDOMFactory)` |
| Commons Digester | Supply hardened reader, call `Digester.setEntityResolver` before parsing; Digester replaces reader's resolver |

### Oracle DOM Parser

Oracle XML Developer's Kit (`oracle.xml.parser.v2`): call `setSecureProcessing()` on DOM or SAX parser. Disables entity resolution, limits expansion. JAXP binding: enable `FEATURE_SECURE_PROCESSING`.

### java.beans.XMLDecoder

Don't use `XMLDecoder` w/ untrusted input. Blocking external entities doesn't remove its [deserialization risk](Deserialization.md#other-deserialization-libraries-and-formats).

### Secure JAXP factory sources

Apache Commons Secure XML provides preconfigured factories. Check its threat model for supported runtimes and limits. Protections don't cover URIs passed directly to parsing APIs, parsers created outside library, or untrusted resources your resolver supplies. Don't loosen its reserved security settings.

## .NET

**Up-to-date .NET XXE info comes from web application of unit tests by Dean Fleming, covering all currently supported .NET XML parsers, w/ test cases showing when safe from XXE and when not; tests only cover injection from file, not direct DTD (used by DoS attacks).**

DoS via direct DTD (e.g. Billion laughs attack): separate testing application from Josh Grossman at Bounce Security verifies .NET >=4.5.2 safe.

Previously based on older articles, possibly not 100% accurate:

- James Jardine's .NET XXE article.
- Microsoft guidance on preventing XXE and XML Denial of Service in .NET.

### Overview of .NET Parser Safety Levels

**Overview of supported .NET XML parsers + default safety levels. Details per parser below.**

#### XDocument (LINQ to XML) default safety levels

Protected from external entities at .NET Framework version 4.5.2, protected from Billion Laughs at version 4.5.2 or greater; uncertain whether protected from Billion Laughs before 4.5.2.

#### XmlDocument, XmlTextReader, XPathNavigator default safety levels

Vulnerable to external entity attacks and Billion Laughs below version 4.5.2; protected at versions equal or greater than 4.5.2.

#### XmlDictionaryReader, XmlNodeReader, XmlReader default safety levels

Not vulnerable to external entity attacks or Billion Laughs before or after version 4.5.2. At ≥4.5.2, these libraries don't process in-line DTD by default. Even if default changed to allow DTD processing, DoS attempt still throws exception as documented above.

### ASP.NET

ASP.NET apps ≥ .NET 4.5.2 MUST set `<httpRuntime targetFramework="..." />` in `Web.config` to ≥4.5.2 or be vulnerable regardless of actual .NET version. Omitting tag also gives unsafe-by-default behavior.

Effective .NET Framework version for ASP.NET app = .NET version app built with or httpRuntime `targetFramework` (Web.config), **whichever is lower**.

Don't confuse w/ similar tag `<compilation targetFramework="..." />` or assemblies/projects targetFramework: **not** sufficient for secure-by-default behavior.

### LINQ to XML

**Both `XElement` and `XDocument` in `System.Xml.Linq` safe from XXE injection from external file and DoS by default.** `XElement` parses only elements within XML file; DTDs ignored. `XDocument` has XmlResolver disabled by default → safe from SSRF. DTDs enabled by default, but Framework ≥4.5.2 **not** vulnerable to DoS as noted; may be vulnerable in earlier versions. See Microsoft's guidance on preventing XXE and XML Denial of Service in .NET.

### XmlDictionaryReader

**`System.Xml.XmlDictionaryReader` safe by default: parsing DTD throws exception "CData elements not valid at top level of an XML document". Unsafe if constructed with different unsafe XML parser.**

### XmlDocument

**Before .NET Framework 4.5.2, `System.Xml.XmlDocument` unsafe by default. Its `XmlResolver` must be set to null in versions prior to 4.5.2. 4.5.2 and up: `XmlResolver` null by default.**

Making it safe:

``` csharp
 static void LoadXML()
 {
   string xxePayload = "<!DOCTYPE doc [<!ENTITY win SYSTEM 'file:///C:/Users/testdata2.txt'>]>"
                     + "<doc>&win;</doc>";
   string xml = "<?xml version='1.0' ?>" + xxePayload;

   XmlDocument xmlDoc = new XmlDocument();
   // Setting this to NULL disables DTDs - Its NOT null by default.
   xmlDoc.XmlResolver = null;
   xmlDoc.LoadXml(xml);
   Console.WriteLine(xmlDoc.InnerText);
   Console.ReadLine();
 }
```

**.NET Framework ≥4.5.2: safe by default**.

`XmlDocument` becomes unsafe if you create own nonnull `XmlResolver` w/ default or unsafe settings. Enabling DTD processing safely: see MSDN article.

### XmlNodeReader

`System.Xml.XmlNodeReader` safe by default; ignores DTDs even when constructed with unsafe parser or wrapped in another unsafe parser.

### XmlReader

`System.Xml.XmlReader` safe by default.

Default: ProhibitDtd property false in .NET Framework 4.0 and earlier, or `DtdProcessing` property Prohibit in .NET 4.0 and later.

.NET 4.5.2 and later: `XmlReaderSettings` of `XmlReader` has `XmlResolver` null by default, extra safety layer.

So `XmlReader` unsafe in 4.5.2+ only if both `DtdProcessing` set to Parse and `XmlReaderSetting`'s `XmlResolver` set to nonnull XmlResolver w/ default or unsafe settings. Enabling DTD processing safely: see MSDN article.

### XmlTextReader

`System.Xml.XmlTextReader` **unsafe** by default in .NET Framework versions prior to 4.5.2. Making it safe per .NET version:

#### Prior to .NET 4.0

.NET Framework before 4.0: DTD parsing for `XmlReader` objects like `XmlTextReader` controlled by Boolean `ProhibitDtd` property in `System.Xml.XmlReaderSettings` and `System.Xml.XmlTextReader`.

Set true to disable inline DTDs completely.

``` csharp
XmlTextReader reader = new XmlTextReader(stream);
// NEEDED because the default is FALSE!!
reader.ProhibitDtd = true;  
```

#### .NET 4.0 - .NET 4.5.2

**.NET Framework 4.0 changed DTD parsing: `ProhibitDtd` deprecated for new `DtdProcessing` property.**

**Default settings unchanged → `XmlTextReader` still vulnerable to XXE by default.**

**Setting `DtdProcessing` to `Prohibit` makes runtime throw exception if `<!DOCTYPE>` element present in XML.**

Set it:

``` csharp
XmlTextReader reader = new XmlTextReader(stream);
// NEEDED because the default is Parse!!
reader.DtdProcessing = DtdProcessing.Prohibit;  
```

Alternatively `DtdProcessing` = `Ignore`: no exception on `<!DOCTYPE>`, skipped unprocessed. `Parse` allows and processes inline DTDs.

#### .NET 4.5.2 and later

.NET Framework 4.5.2+: `XmlTextReader`'s internal `XmlResolver` null by default → ignores DTDs by default. Becomes unsafe if you create own nonnull `XmlResolver` w/ default or unsafe settings.

### XPathNavigator

`System.Xml.XPath.XPathNavigator` **unsafe** by default in .NET Framework versions prior to 4.5.2.

Because it implements `IXPathNavigable` objects like `XmlDocument`, also unsafe by default before 4.5.2.

Make safe by giving it safe parser like `XmlReader` (safe by default) in `XPathDocument`'s constructor.

Example:

``` csharp
XmlReader reader = XmlReader.Create("example.xml");
XPathDocument doc = new XPathDocument(reader);
XPathNavigator nav = doc.CreateNavigator();
string xml = nav.InnerXml.ToString();
```

.NET Framework ≥4.5.2: XPathNavigator **safe by default**.

### XslCompiledTransform

`System.Xml.Xsl.XslCompiledTransform` (XML transformer) safe by default as long as given parser is safe.

Safe by default because default parser of `Transform()` methods is `XmlReader`, safe by default (above).

Some `Transform()` methods accept `XmlReader` or `IXPathNavigable` (e.g., `XmlDocument`) input; passing unsafe XML parser makes `Transform` unsafe too.

## iOS

### libxml2

**iOS includes C/C++ libxml2 described above; that guidance applies if using libxml2 directly.**

**libxml2 provided up through iOS6 is prior to version 2.9 (which protects against XXE by default).**

### NSXMLDocument

**iOS also provides `NSXMLDocument` type, built on libxml2.**

**`NSXMLDocument` provides additional XXE protections unavailable in libxml2 directly.**

Per 'NSXMLDocument External Entity Restriction API' section of Foundation iOS5 release notes:

- iOS4 and earlier: all external entities loaded by default.
- iOS5 and later: only entities not requiring network access loaded (safer).

**To completely disable XXE in `NSXMLDocument` on any iOS version, specify `NSXMLNodeLoadExternalEntitiesNever` when creating it.**

## PHP

libxml 2.9.0+: entity substitution disabled by default. Don't enable `LIBXML_NOENT`, `LIBXML_DTDLOAD`, or `LIBXML_DTDVALID` for untrusted XML without explicitly blocking external resources; these options can require additional protection against external entity loading.

To reject external entity resolution, install resolver callback returning `null` before processing untrusted XML, keep installed for that operation:

``` php
libxml_set_external_entity_loader(function () {
    return null;
});
```

Passing `null` directly to `libxml_set_external_entity_loader()` ≠ returning `null` from callback; doesn't block external entity loading, as PHP security advisory's mitigation demonstrates.

SensePost article describes abusing this in PHP (XXE vulnerability fixed in Facebook).

## Python

Follow Python's current XML security guidance. Built-in parsers rely on Expat, bundled with Python or supplied by OS. Check `pyexpat.EXPAT_VERSION` in deployed interpreter; keep Python and Expat updated. Expat below 2.7.2 may be affected by entity-expansion, large-token, dynamic-memory DoS vulnerabilities; Python version alone doesn't establish linked Expat version.

Expat itself doesn't access files or network by default. Higher-level APIs and custom handlers still need external-resource policy. Independently bound input size and decompressed data: standard-library `xmlrpc` module vulnerable to decompression bombs.

Untrusted XML: use defusedxml parsing interfaces in place of corresponding standard-library parsing functions. Keep entity and external-resource rejection enabled; set `forbid_dtd=True` on APIs offering it when DTDs unnecessary. Interfaces reject prohibited constructs; don't sanitize XML or replace app resource limits.

## Semgrep Rules

Semgrep = command-line offline static analysis tool. Pre-built or custom rules enforce code/security standards.

### Java

Rules for Java XML parsers

#### DocumentBuilderFactory

Identifies XXE vulnerability in `javax.xml.parsers.DocumentBuilderFactory`.
Official registry rule: documentbuilderfactory-disallow-doctype-decl-missing.

#### SAXParserFactory

Identifies XXE vulnerability in `javax.xml.parsers.SAXParserFactory`.
Official registry rule: saxparserfactory-disallow-doctype-decl-missing.

#### XMLInputFactory

Identifies XXE vulnerability in `javax.xml.stream.XMLInputFactory`.
Official registry rule: xmlinputfactory-possible-xxe.

## References

- Oracle Java 25: JAXP Security Guide
- Python: XML Security
- Morgan and Al Ibrahim: XML Schema, DTD, and Entity Attacks
