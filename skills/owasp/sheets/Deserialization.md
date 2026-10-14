# Deserialization Cheat Sheet

## Introduction

Clear, actionable guidance for safely deserializing untrusted data.

## What is Deserialization

**Serialization** = turning object into data format restorable later; used for storage or communications.

**Deserialization** = reverse: rebuild object from structured data. Most popular serialization format today: JSON. Before: XML.

Many languages have native serialization with more features than JSON/XML, incl. customization of serialization process.

Native deserialization features can be repurposed maliciously on untrusted data. Deserializer attacks found to allow denial-of-service, access control, or remote code execution (RCE) attacks.

## Guidance on Deserializing Objects Safely

Language-specific safe methodologies for deserializing untrusted data.

### PHP

#### Clear-box Review

Check use of `unserialize()` and how external parameters accepted. To pass serialized data to user, use safe standard interchange format such as JSON (via `json_decode()` and `json_encode()`).

### Python

#### Opaque-box Review

Traffic data ending w/ dot `.` very likely serialized; true only if not Base64 or Hexadecimal encoded. If encoded, check starting characters of parameter value. E.g. Base64 encoded likely starts `gASV`.

#### Clear-box Review

Review APIs for untrusted input:

1. Uses of `pickle.load()` or `pickle.loads()`. Unpickling can execute arbitrary code; never unpickle untrusted data. `pickle.loads()` expects bytes-like input, not Python 3 string.

2. Uses of PyYAML's unsafe loaders, e.g. `yaml.unsafe_load()` or `yaml.load()` w/ `Loader=yaml.Loader` or `Loader=yaml.UnsafeLoader`. Untrusted YAML: use `yaml.safe_load()`; don't register custom constructors allowing arbitrary object creation. Current PyYAML requires explicit `Loader` argument for `yaml.load()`.

3. Uses of `jsonpickle.decode()` w/ untrusted input.

### Java

Historical research on Java deserialization + defensive allowlisting: Java Deserialization Attacks — German OWASP Day 2016 (../assets/Deserialization_Cheat_Sheet_GOD16Deserialization.pdf).

Techniques reducing risk w/ Java's Serializable format.

Implementation advice:

- Configure serialization filters w/ application-specific class allowlist + resource limits before reading objects.
- If maintaining `resolveClass()` override, account for its [limitations below](#harden-your-own-javaioobjectinputstream); class checks alone don't bound resource consumption.

#### Clear-box Review

Watch Java API uses for potential serialization vulnerability.

1. `XMLdecoder` w/ external user defined parameters

2. `XStream` w/ `fromXML` method (xstream version <= v1.4.6 vulnerable to serialization issue)

3. `ObjectInputStream` w/ `readObject`

4. Uses of `readObject`, `readObjectNoData`, `readResolve` or `readExternal`

5. `ObjectInputStream.readUnshared`

6. `Serializable`

#### Opaque-box Review

Captured traffic with these patterns may indicate Java serialization streams:

- `AC ED 00 05` in Hex
- `rO0` in Base64
- `Content-type` header of HTTP response set to `application/x-java-serialized-object`

#### Prevent Data Leakage and Trusted Field Clobbering

Data members never controlled by end users during deserialization or exposed to users during serialization: declare with `transient` keyword (section *Protecting Sensitive Information*).

Class defined as Serializable: declare sensitive variable `private transient`.

Example: class `myAccount`, variables 'profit' and 'margin' declared transient to prevent serialization.

```java
public class myAccount implements Serializable
{
    private transient double profit; // declared transient

    private transient double margin; // declared transient
    ....
```

#### Prevent Deserialization of Domain Objects

Some app objects may be forced to implement `Serializable` due to hierarchy. To guarantee they can't be deserialized, declare `readObject()` method (with `final` modifier) that always throws exception:

```java
private final void readObject(ObjectInputStream in) throws java.io.IOException {
    throw new java.io.IOException("Cannot be deserialized");
}
```

#### Harden Your Own java.io.ObjectInputStream

`java.io.ObjectInputStream` deserializes objects. Custom class-resolution allowlist may help if:

- you can change deserialization code;
- you know which classes to expect.

Idea: override `ObjectInputStream.resolveClass()` to restrict ordinary class resolution during deserialization.

Doesn't check every object: serialization specification handles strings separately and resolves dynamic proxy class descriptors through `resolveProxyClass()`.

Example allows only `Bicycle` through `resolveClass()`. Illustrative class check, not complete deserialization defense:

```java
public class LookAheadObjectInputStream extends ObjectInputStream {

    public LookAheadObjectInputStream(InputStream inputStream) throws IOException {
        super(inputStream);
    }

    /**
    * Restrict ordinary class resolution to our expected Bicycle class
    */
    @Override
    protected Class<?> resolveClass(ObjectStreamClass desc) throws IOException, ClassNotFoundException {
        if (!desc.getName().equals(Bicycle.class.getName())) {
            throw new InvalidClassException("Unauthorized deserialization attempt", desc.getName());
        }
        return super.resolveClass(desc);
    }
}
```

Use serialization filtering to combine class allowlist w/ limits on graph depth, references, array lengths, stream bytes. Also bound serialized input size separately: filters not called for concretely encoded strings or primitives. Filtering doesn't make arbitrary untrusted deserialization safe.

More complete implementations from community:

- NibbleSec - library for creating lists of classes allowed to be deserialized
- IBM - seminal protection, written years before most devastating exploitation scenarios envisioned.
- Apache Commons IO classes

#### Harden All java.io.ObjectInputStream Usage with an Agent

`java.io.ObjectInputStream` hardenable by subclassing. If you don't own code or can't wait for patch, best solution: agent weaving hardening into `java.io.ObjectInputStream`.

Globally changing `ObjectInputStream` safe only for block-listing known malicious types; can't know expected classes for all applications. Very few classes needed in denylist to be safe from all known attack vectors today.

More "gadget" classes will inevitably be discovered. Incredible amount of vulnerable software exposed, needs fix. "Fixing" may involve re-architecting messaging systems + breaking backwards compatibility as developers stop accepting serialized objects.

Enable agents by adding JVM parameter:

```text
-javaagent:name-of-agent.jar
```

Agents released by community:

- rO0 by Contrast Security

Similar, less scalable: manually patch + bootstrap JVM's ObjectInputStream (paranoid-java-serialization guidance).

#### Other Deserialization Libraries and Formats

Advice above targets Java's Serializable format; other libraries using other formats may have similar security issues if misconfigured. Libraries + recommended configuration for deserializing untrusted data:

**Can be used safely with default configuration:**

- **fastjson2** (JSON) - safe as long as **autotype** option not turned on
- **jackson-databind** (JSON) - safe as long as polymorphism not used (see blog post)
- **Kryo v5.0.0+** (custom format) - safe as long as class registration not turned **off** (see documentation and issue)
- **YamlBeans v1.16+** (YAML) - safe as long as **UnsafeYamlConfig** class not used (see commit)
    - *NOTE: these versions not available in Maven Central; a fork exists to use instead (Contrast-Security-OSS/yamlbeans).*
- **XStream v1.4.17+** (JSON and XML) - safe as long as allowlist + other security controls not relaxed (see documentation)

**Requires configuration before can be used safely:**

- **fastjson v1.2.68+** (JSON) - unsafe unless **safemode** option turned on, disabling deserialization of any class (see documentation). Previous versions not safe.
- **json-io** (JSON) - unsafe since **@type** property in JSON allows deserialization of any class. Safe only:
    - In non-typed mode using **JsonReader.USE_MAPS** setting, turning off generic object deserialization
    - With custom deserializer controlling which classes get deserialized
- **Kryo < v5.0.0** (custom format) - unsafe unless class registration turned **on**, disabling deserialization of any class (see documentation and issue)
    - *NOTE: other wrappers around Kryo such as Chill may also not require class registration by default regardless of underlying Kryo version*
- **SnakeYAML** (YAML) - unsafe unless **org.yaml.snakeyaml.constructor.SafeConstructor** class used, disabling deserialization of any class (see docs)

**Cannot be used safely:**

Libraries unmaintained or unsafe w/ untrusted input:

- **Castor** (XML) - appears abandoned, no commits since 2016
- **fastjson < v1.2.68** (JSON) - these versions allow deserialization of any class (see documentation)
- **XMLDecoder in the JDK** (XML) - *"close to impossible to securely deserialize Java objects in this format from untrusted inputs"* ("Red Hat Defensive Coding Guide", end of section 2.6.5)
- **XStream < v1.4.17** (JSON and XML) - these versions allow deserialization of any class (see documentation)
- **YamlBeans < v1.16** (YAML) - these versions allow deserialization of any class (see SECURITY.md)

### .Net CSharp

#### Clear-box Review

Search source for terms:

1. `TypeNameHandling`
2. `JavaScriptTypeResolver`

Look for serializers where type set by user controlled variable.

#### Opaque-box Review

Search for base64 encoded content starting:

```text
AAEAAAD/////
```

Search content with text:

1. `TypeObject`
2. `$type:`

#### General Precautions

Microsoft: `BinaryFormatter` type dangerous, cannot be secured; don't use. Details: BinaryFormatter security guide.

Don't let datastream define object type to deserialize to. Prevent e.g. by using `DataContractSerializer` or `XmlSerializer` if at all possible.

`JSON.Net`: set `TypeNameHandling` only to `None`.

```csharp
TypeNameHandling = TypeNameHandling.None
```

`JavaScriptSerializer`: don't use with `JavaScriptTypeResolver`.

If you must deserialize data streams defining own type, restrict allowed types. Still risky: many native .Net types potentially dangerous in themselves. e.g.

```csharp
System.IO.FileInfo
```

`FileInfo` objects referencing files actually on server can, when deserialized, change those files' properties e.g. to read-only → potential denial of service.

Even w/ limited types, some types have risky properties. `System.ComponentModel.DataAnnotations.ValidationException`, e.g., has property `Value` of type `Object`. If this type allowed for deserialization, attacker can set `Value` to any object type.

Prevent attackers steering instantiated type. Otherwise even `DataContractSerializer` or `XmlSerializer` can be subverted e.g.

```csharp
// Action below is dangerous if the attacker can change the data in the database
var typename = GetTransactionTypeFromDatabase();

var serializer = new DataContractJsonSerializer(Type.GetType(typename));

var obj = serializer.ReadObject(ms);
```

Execution can occur within certain .Net types during deserialization. Control like below ineffective.

```csharp
var suspectObject = myBinaryFormatter.Deserialize(untrustedData);

//Check below is too late! Execution may have already occurred.
if (suspectObject is SomeDangerousObjectType)
{
    //generate warnings and dispose of suspectObject
}
```

`JSON.Net`: safer allow-list control possible via custom `SerializationBinder`.

Keep up-to-date on known .Net insecure deserialization gadgets; pay special attention where deserialization can create such types. **A deserializer can only instantiate types that it knows about**.

Keep code that might create gadgets separate from code with internet connectivity. E.g. `System.Windows.Data.ObjectDataProvider` (WPF) = known gadget allowing arbitrary method invocation; risky to reference this assembly in REST service project deserializing untrusted data.

#### Known .NET RCE Gadgets

- `System.Configuration.Install.AssemblyInstaller`
- `System.Activities.Presentation.WorkflowDesigner`
- `System.Windows.ResourceDictionary`
- `System.Windows.Data.ObjectDataProvider`
- `System.Windows.Forms.BindingSource`
- `Microsoft.Exchange.Management.SystemManager.WinForms.ExchangeSettingsProvider`
- `System.Data.DataViewManager, System.Xml.XmlDocument/XmlDataDocument`
- `System.Management.Automation.PSObject`

## Language-Agnostic Methods for Deserializing Safely

### Using Alternative Data Formats

Avoiding native (de)serialization formats greatly reduces risk. Pure data format like JSON or XML lessens chance custom deserialization logic repurposed maliciously.

Many apps use data-transfer object pattern: separate domain of objects purely for data transfer. App can still make security mistakes after pure data object parsed.

### Only Deserialize Signed Data

If app knows before deserialization which messages need processing, sign them during serialization. App then refuses to deserialize any message lacking authenticated signature.

## Mitigation Tools/Libraries

- Java secure deserialization library (SerialKiller)
- SWAT - tool for creating allowlists
- NotSoSerial

## Detection Tools

- Java deserialization cheat sheet aimed at pen testers
- ysoserial: proof-of-concept payload generator exploiting unsafe Java object deserialization
- Java De-serialization toolkits
- Java de-serialization tool (ysoserial)
- .Net payload generator (ysoserial.net)
- Burp Suite extension
- Java secure deserialization library (SerialKiller)
- Serianalyzer: static bytecode analyzer for deserialization
- Payload generator (marshalsec)
- Android Java Deserialization Vulnerability Tester (modjoda)
- Burp Suite Extension
    - JavaSerialKiller
    - Java Deserialization Scanner
    - Burp-ysoserial
    - SuperSerial
    - SuperSerial-Active

## References

- Oracle Java 17: Serialization Filtering
- Microsoft: Deserialization Risks in Use of BinaryFormatter and Related Types
- Python: pickle Security Warning
