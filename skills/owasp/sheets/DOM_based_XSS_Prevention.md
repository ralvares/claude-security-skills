# DOM based XSS Prevention Cheat Sheet

## Introduction

Common overlapping XSS (Cross-Site Scripting) categories:

- Reflected or Stored
- DOM Based XSS.

[XSS Prevention Cheatsheet](Cross_Site_Scripting_Prevention.md) covers Reflected and Stored XSS. This sheet covers DOM (Document Object Model) based XSS; extends and assumes comprehension of [XSS Prevention Cheatsheet](Cross_Site_Scripting_Prevention.md).

Stored/reflected = how payload reaches victim; server-side/client-side = where untrusted data handled unsafely. Both stored and reflected XSS can occur on client or server, incl. stored and reflected DOM-based XSS.

Server-side XSS: server inserts untrusted data into response w/o making it safe for output context. DOM-based XSS: unsafe client-side processing. Either way injected script executes in browser; choose controls for actual data flow + output context.

Browser rendering HTML and associated content (CSS, JavaScript) identifies rendering contexts per input kind, follows different rules per context. Rendering context associated w/ parsing HTML tags + attributes.

- HTML parser of rendering context dictates data presentation/layout; breaks into standard contexts HTML, HTML attribute, URL, CSS.
- JavaScript or VBScript parser of execution context parses/executes script code. Each parser has distinct semantics for executing script → hard to create consistent mitigation rules across contexts. Compounded by differing meanings/treatment of encoded values within each subcontext (HTML, HTML attribute, URL, CSS) within execution context.

Here, HTML, HTML attribute, URL, CSS contexts = subcontexts, since each can be reached/set within JavaScript execution context.

In JavaScript code main context is JavaScript, but w/ right tags + context closing characters attacker can attack other 4 contexts via equivalent JavaScript DOM methods.

Example vulnerability in JavaScript context + HTML subcontext:

```html
 <script>
 var x = '<%= taintedVar %>';
 var d = document.createElement('div');
 d.innerHTML = x;
 document.body.appendChild(d);
 </script>
```

Individual subcontexts of execution context:

## RULE \#1 - HTML Escape then JavaScript Escape Before Inserting Untrusted Data into HTML Subcontext within the Execution Context

Several methods/attributes directly render HTML content in JavaScript = HTML Subcontext within Execution Context. Untrusted input there → XSS. Example:

### Example Dangerous HTML Methods

#### Attributes

```javascript
 element.innerHTML = "<HTML> Tags and markup";
 element.outerHTML = "<HTML> Tags and markup";
```

#### Methods

```javascript
 document.write("<HTML> Tags and markup");
 document.writeln("<HTML> Tags and markup");
```

### Guideline

Safe dynamic HTML updates in DOM:

 1. HTML encode, then
 2. JavaScript encode all untrusted input, as in examples:

```javascript
 var ESAPI = require('node-esapi');
 element.innerHTML = "<%=ESAPI.encoder().encodeForJavascript(ESAPI.encoder().encodeForHTML(untrustedData))%>";
 element.outerHTML = "<%=ESAPI.encoder().encodeForJavascript(ESAPI.encoder().encodeForHTML(untrustedData))%>";
```

```javascript
 var ESAPI = require('node-esapi');
 document.write("<%=ESAPI.encoder().encodeForJavascript(ESAPI.encoder().encodeForHTML(untrustedData))%>");
 document.writeln("<%=ESAPI.encoder().encodeForJavascript(ESAPI.encoder().encodeForHTML(untrustedData))%>");
```

## RULE \#2 - JavaScript Escape Before Inserting Untrusted Data into HTML Attribute Subcontext within the Execution Context

HTML attribute *subcontext* within *execution* context diverges from standard encoding rules. HTML attribute encoding in HTML attribute rendering context is needed to mitigate attacks exiting HTML attributes or adding attributes → XSS.

In DOM execution context, JavaScript encode only HTML attributes which don't execute code (attributes other than event handler, CSS, URL attributes).

General rule: HTML Attribute encode untrusted data (from database, HTTP request, user, back-end system, etc.) placed in HTML Attribute. Right for rendering context; HTML Attribute encoding in execution context breaks application data display.

### SAFE but BROKEN example

```javascript
 var ESAPI = require('node-esapi');
 var x = document.createElement("input");
 x.setAttribute("name", "company_name");
 // In the following line of code, companyName represents untrusted user input
 // The ESAPI.encoder().encodeForHTMLAttribute() is unnecessary and causes double-encoding
 x.setAttribute("value", '<%=ESAPI.encoder().encodeForJavascript(ESAPI.encoder().encodeForHTMLAttribute(companyName))%>');
 var form1 = document.forms[0];
 form1.appendChild(x);
```

Problem: companyName "Johnson & Johnson" displays in input field as "Johnson &#x26;amp; Johnson". Correct: JavaScript encoding only, stops attacker closing single quotes and in-lining code, or escaping to HTML and opening new script tag.

### SAFE and FUNCTIONALLY CORRECT example

```javascript
 var ESAPI = require('node-esapi');
 var x = document.createElement("input");
 x.setAttribute("name", "company_name");
 x.setAttribute("value", '<%=ESAPI.encoder().encodeForJavascript(companyName)%>');
 var form1 = document.forms[0];
 form1.appendChild(x);
```

Setting non-code-executing HTML attribute: value set directly within object attribute of HTML element → no injecting-up concern.

## RULE \#3 - Be Careful when Inserting Untrusted Data into the Event Handler and JavaScript code Subcontexts within an Execution Context

Dynamic data within JavaScript code especially dangerous: JavaScript encoding has different semantics vs other encodings. Often JavaScript encoding doesn't stop attacks in execution context; JavaScript encoded string still executes.

Primary recommendation: **avoid untrusted data in this context**. If unavoidable, examples of approaches that do/don't work:

```javascript
var x = document.createElement("a");
x.href="#";
// In the line of code below, the encoded data on the right (the second argument to setAttribute)
// is an example of untrusted data that was properly JavaScript encoded but still executes.
x.setAttribute("onclick", "\u0061\u006c\u0065\u0072\u0074\u0028\u0032\u0032\u0029");
var y = document.createTextNode("Click To Test");
x.appendChild(y);
document.body.appendChild(x);
```

`setAttribute(name_string,value_string)` dangerous: implicitly coerces *value_string* into DOM attribute datatype of *name_string*.

Above, attribute name is JavaScript event handler → value implicitly converted to JavaScript code and evaluated. JavaScript encoding doesn't mitigate DOM based XSS here.

Other JavaScript methods interpreting strings as code (`setTimeout`, `setInterval`, `Function`) same risk. HTML event-handler attributes also contain JavaScript function bodies. Escaping every character in one payload may give syntax error, but JavaScript encoding is no defense here: escaped identifiers remain executable when surrounding syntax valid.

```html
<!-- Executes alert(1) when clicked; encoding the identifier does not make it safe. -->
<a id="bb" href="#" onclick="\u0061\u006c\u0065\u0072\u0074(1)">Test Me</a>
```

Setting JavaScript `onclick` property differs from setting HTML attribute. Expects callback; assigning primitive string sets it to null, encoded or not. Type conversion, not JavaScript encoding benefit. Assign trusted function; keep untrusted values as data inside it, never compile as code.

```html
<a id="bb" href="#">Test Me</a>
```

```javascript
// Neither string becomes a handler.
document.getElementById("bb").onclick = "alert(7)";
document.getElementById("bb").onclick = "\u0061\u006c\u0065\u0072\u0074\u0028\u0037\u0029";

// A trusted function is a handler.
document.getElementById("bb").onclick = function () {
    alert("I was called.");
};
```

JavaScript elsewhere accepts JavaScript encoding as valid executable code.

```javascript
 for(var \u0062=0; \u0062 < 10; \u0062++){
     \u0064\u006f\u0063\u0075\u006d\u0065\u006e\u0074
     .\u0077\u0072\u0069\u0074\u0065\u006c\u006e
     ("\u0048\u0065\u006c\u006c\u006f\u0020\u0057\u006f\u0072\u006c\u0064");
 }
 \u0077\u0069\u006e\u0064\u006f\u0077
 .\u0065\u0076\u0061\u006c
 \u0064\u006f\u0063\u0075\u006d\u0065\u006e\u0074
 .\u0077\u0072\u0069\u0074\u0065(111111111);
```

or

```javascript
 var s = "\u0065\u0076\u0061\u006c";
 var t = "\u0061\u006c\u0065\u0072\u0074\u0028\u0031\u0031\u0029";
 window[s](t);
```

JavaScript based on international standard (ECMAScript): JavaScript encoding supports international characters in constructs/variables plus alternate string representations (string escapes).

HTML encoding opposite: HTML tag elements well defined, no alternate representations of same tag. HTML encoding can't give alternate representations of e.g. `<a>` tag.

### HTML Encoding's Disarming Nature

HTML encoding castrates HTML tags placed in HTML and HTML attribute contexts. Working example (no HTML encoding):

```html
<a href="..." >
```

Normally encoded example (Does Not Work – DNW):

```html
&#x3c;a href=... &#x3e;
```

HTML encoded example showing fundamental difference vs JavaScript encoded values (DNW):

```html
<&#x61; href=...>
```

If HTML encoding followed JavaScript encoding semantics, line above could possibly render a link. This difference makes JavaScript encoding less viable vs XSS.

## RULE \#4 - JavaScript Escape Before Inserting Untrusted Data into the CSS Attribute Subcontext within the Execution Context

Normally executing JavaScript from CSS context required passing `javascript:attackCode()` to CSS `url()` method or invoking CSS `expression()` method w/ JavaScript code directly executed.

Author experience: calling `expression()` from execution context (JavaScript) disabled. Mitigate CSS `url()` method: URL encode data passed to it.

```javascript
var ESAPI = require('node-esapi');
document.body.style.backgroundImage = "url(<%=ESAPI.encoder().encodeForJavascript(ESAPI.encoder().encodeForURL(companyName))%>)";
```

## RULE \#5 - URL Escape then JavaScript Escape Before Inserting Untrusted Data into URL Attribute Subcontext within the Execution Context

URL parsing logic same in execution + rendering contexts → little change in URL attribute encoding rules in execution (DOM) context.

```javascript
var ESAPI = require('node-esapi');
var x = document.createElement("a");
x.setAttribute("href", '<%=ESAPI.encoder().encodeForJavascript(ESAPI.encoder().encodeForURL(userRelativePath))%>');
var y = document.createTextElement("Click Me To Test");
x.appendChild(y);
document.body.appendChild(x);
```

Fully qualified URLs break links: colon in protocol identifier (`http:` or `javascript:`) gets URL encoded, preventing `http` and `javascript` protocols from being invoked.

## RULE \#6 - Populate the DOM using safe JavaScript functions or properties

Most fundamental safe way to populate DOM w/ untrusted data: safe assignment property `textContent`.

Safe usage example:

```html
<script>
element.textContent = untrustedData;  //does not execute code
</script>
```

## RULE \#7 - Fixing DOM Cross-site Scripting Vulnerabilities

Best fix for DOM based XSS: right output method (sink). E.g., writing user input into `div tag` element: don't use `innerHtml`; use `innerText` or `textContent`. Solves problem; right way to remediate DOM based XSS.

**Always bad idea to use user-controlled input in dangerous sources such as eval. 99% of time indicates bad/lazy programming practice; don't do it rather than sanitize input.**

To fix initial code: rather than encode output correctly (hassle, easily goes wrong) use `element.textContent` to write into content:

```html
<b>Current URL:</b> <span id="contentholder"></span>
...
<script>
document.getElementById("contentholder").textContent = document.baseURI;
</script>
```

Same result, not vulnerable to DOM based XSS.

## Guidelines for Developing Secure Applications Utilizing JavaScript

DOM based XSS extremely hard to mitigate: large attack surface, no browser standardization.

Guidelines for developers of Web based JavaScript applications (Web 2.0) to avoid XSS.

### GUIDELINE \#1 - Untrusted data should only be treated as displayable text

Avoid treating untrusted data as code or markup in JavaScript code.

### GUIDELINE \#2 - Always JavaScript encode and delimit untrusted data as quoted strings when entering the application when building templated JavaScript

Always JavaScript encode and delimit untrusted data as quoted strings when entering application:

```javascript
var x = "<%= Encode.forJavaScript(untrustedData) %>";
```

### GUIDELINE \#3 - Use document.createElement("..."), element.setAttribute("...","value"), element.appendChild(...) and similar to build dynamic interfaces

`document.createElement("...")`, `element.setAttribute("...","value")`, `element.appendChild(...)` and similar = safe ways to build dynamic interfaces.

`element.setAttribute` safe only for limited attributes.

Dangerous attributes: any command execution context attribute, such as `onclick` or `onblur`.

Safe attribute examples: `align`, `alink`, `alt`, `bgcolor`, `border`, `cellpadding`, `cellspacing`, `class`, `color`, `cols`, `colspan`, `coords`, `dir`, `face`, `height`, `hspace`, `ismap`, `lang`, `marginheight`, `marginwidth`, `multiple`, `nohref`, `noresize`, `noshade`, `nowrap`, `ref`, `rel`, `rev`, `rows`, `rowspan`, `scrolling`, `shape`, `span`, `summary`, `tabindex`, `title`, `usemap`, `valign`, `value`, `vlink`, `vspace`, `width`.

### GUIDELINE \#4 - Avoid sending untrusted data into HTML rendering methods

Avoid untrusted data in:

1. `element.innerHTML = "...";`
2. `element.outerHTML = "...";`
3. `document.write(...);`
4. `document.writeln(...);`

### GUIDELINE \#5 - Avoid the numerous methods which implicitly eval() data passed to it

Avoid numerous methods that implicitly `eval()` passed data.

Ensure untrusted data passed to these methods is:

1. Delimited with string delimiters
2. Enclosed within closure or JavaScript encoded to N-levels based on usage
3. Wrapped in custom function.

Follow step 3 so untrusted data isn't sent to dangerous methods within custom function, or handle by adding extra encoding layer.

#### Utilizing an Enclosure (as suggested by Gaz)

Example uses closures to avoid double JavaScript encoding.

```javascript
 var ESAPI = require('node-esapi');
 setTimeout((function(param) { return function() {
          customFunction(param);
        }
 })("<%=ESAPI.encoder().encodeForJavascript(untrustedData)%>"), y);
```

Alternative: N-levels of encoding.

#### N-Levels of Encoding

For code like following, only double JavaScript encode input data.

```javascript
setTimeout("customFunction('<%=doubleJavaScriptEncodedData%>', y)");
function customFunction (firstName, lastName)
     alert("Hello" + firstName + " " + lastName);
}
```

`doubleJavaScriptEncodedData` has first JavaScript encoding layer reversed (on execution) in single quotes.

Implicit `eval` of `setTimeout` reverses another layer to pass correct value to `customFunction`

Only double encoding needed because `customFunction` didn't itself pass input to another method implicitly/explicitly calling `eval`. If *firstName* passed to another JavaScript method implicitly/explicitly calling `eval()`, change `<%=doubleJavaScriptEncodedData%>` above to `<%=tripleJavaScriptEncodedData%>`.

Implementation note: if JavaScript code uses double/triple encoded data in string comparisons, value may be interpreted as different values depending on number of `evals()` passed through before the if comparison and number of times JavaScript encoded.

If **A** double JavaScript encoded, following **if** check returns false.

``` javascript
 var x = "doubleJavaScriptEncodedA";  //\u005c\u0075\u0030\u0030\u0034\u0031
 if (x == "A") {
    alert("x is A");
 } else if (x == "\u0041") {
    alert("This is what pops");
 }
```

Design point: ideally server-side encode for output context where data enters application.

Then client-side encode (JavaScript encoding library such as node-esapi) for individual subcontext (DOM methods) receiving untrusted data.

Usage examples:

```javascript
//server-side encoding
var ESAPI = require('node-esapi');
var input = "<%=ESAPI.encoder().encodeForJavascript(untrustedData)%>";
```

```javascript
//HTML encoding is happening in JavaScript
var ESAPI = require('node-esapi');
document.writeln(ESAPI.encoder().encodeForHTML(input));
```

Option: use ECMAScript 5 immutable properties in JavaScript library.
Another option from Gaz (Gareth): specific code construct limiting mutability with anonymous closures.

Example:

```javascript
function escapeHTML(str) {
     str = str + "''";
     var out = "''";
     for(var i=0; i<str.length; i++) {
         if(str[i] === '<') {
             out += '&lt;';
         } else if(str[i] === '>') {
             out += '&gt;';
         } else if(str[i] === "'") {
             out += '&#39;';
         } else if(str[i] === '"') {
             out += '&quot;';
         } else {
             out += str[i];
         }
     }
     return out;
}
```

### GUIDELINE \#6 - Use untrusted data on only the right side of an expression

Use untrusted data only on right side of expression, esp. code-like data possibly passed to app (e.g., `location` and `eval()`).

```javascript
window[userDataOnLeftSide] = "userDataOnRightSide";
```

Untrusted data on left side lets attacker subvert internal + external attributes of window object; right side doesn't allow direct manipulation.

### GUIDELINE \#7 - When URL encoding in DOM be aware of character set issues

URL encoding in DOM: beware character set issues; character set in JavaScript DOM not clearly defined (Mike Samuel).

### GUIDELINE \#8 - Limit access to object properties when using object\[x\] accessors

Limit access to object properties when using `object[x]` accessors (Mike Samuel). I.e., add level of indirection between untrusted input and specified object properties.

Problem example w/ map types:

```javascript
var myMapType = {};
myMapType[<%=untrustedData%>] = "moreUntrustedData";
```

Developer tried to add keyed elements to `myMapType` object; attacker can subvert internal + external attributes of `myMapType` object.

Better:

```javascript
if (untrustedData === 'location') {
  myMapType.location = "moreUntrustedData";
}
```

### GUIDELINE \#9 - Keep HTML sanitization separate from JavaScript execution

Use HTML sanitizer such as DOMPurify when app must render untrusted markup; see [HTML sanitization guidance](Cross_Site_Scripting_Prevention.md#html-sanitization). Sanitizers filter markup; no sandbox for executing arbitrary JavaScript. Never pass untrusted code to [`eval()` or `Function()`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/eval#never_use_direct_eval!).

### GUIDELINE \#10 - Don't eval() JSON to convert it to native JavaScript objects

Don't `eval()` JSON to convert to native JavaScript objects. Use built-in `JSON.parse()` to deserialize JSON into JavaScript values, `JSON.stringify()` to serialize. `JSON.parse()` rejects anything not valid JSON → can't execute attacker-supplied code like `eval()`.

> [!WARNING]
> `JSON.stringify()` is **not** an output-encoding function. Output is valid JSON, but embedding in HTML needs protection for destination context. Prefer separate response with `Content-Type: application/json`, parsed client-side with `JSON.parse()`. If JSON must be embedded in inline script, use serializer/encoder documented for that exact placement, protecting both JavaScript syntax and enclosing HTML script context, incl. literal `</script` sequences. HTML entity encoding or JavaScript quote escaping alone insufficient for this placement. Other placements: follow [context-specific XSS encoding rules](Cross_Site_Scripting_Prevention.md#output-encoding).

## Common Problems Associated with Mitigating DOM Based XSS

### Complex Contexts

Context often not straightforward to discern.

```html
<a href="javascript:myFunction('<%=untrustedData%>', 'test');">Click Me</a>
 ...
<script>
Function myFunction (url,name) {
    window.location = url;
}
</script>
```

Above, untrusted data started in rendering URL context (`href` attribute of `a` tag), changed to JavaScript execution context (`javascript:` protocol handler), passed untrusted data to execution URL subcontext (`window.location` of `myFunction`).

Data introduced in JavaScript code and passed to URL subcontext → appropriate server-side encoding:

```html
<a href="javascript:myFunction('<%=ESAPI.encoder().encodeForJavascript(ESAPI.encoder().encodeForURL(untrustedData)) %>', 'test');">
Click Me</a>
 ...
```

Or with ECMAScript 5 and immutable JavaScript client-side encoding libraries:

```html
<!-- server side URL encoding has been removed.  Now only JavaScript encoding on server side. -->
<a href="javascript:myFunction('<%=ESAPI.encoder().encodeForJavascript(untrustedData)%>', 'test');">Click Me</a>
 ...
<script>
Function myFunction (url,name) {
    var encodedURL = ESAPI.encoder().encodeForURL(url);  //URL encoding using client-side scripts
    window.location = encodedURL;
}
</script>
```

### Inconsistencies of Encoding Libraries

Open source encoding libraries:

1. OWASP ESAPI
2. OWASP Java Encoder
3. Apache Commons Text StringEscapeUtils, replaces one from Apache Commons Lang3
4. Jtidy
5. Your company's custom implementation.

Some use denylist; others ignore important characters like "&lt;" and "&gt;".

Java Encoder: active project, supports HTML, CSS, JavaScript encoding.

ESAPI: one of few using allowlist, encodes all non-alphanumeric characters. Use encoding library understanding which characters exploit vulnerabilities in respective contexts. Many misconceptions about proper encoding required.

### Encoding Misconceptions

Many security training curricula/papers advocate blind HTML encoding to resolve XSS.

Seems prudent as JavaScript parser doesn't understand HTML encoding.

But if pages use content type `text/xhtml` or file extension `*.xhtml`, HTML encoding may not mitigate XSS.

Example:

```html
<script>
&#x61;lert(1);
</script>
```

HTML encoded value above still executable. Also encodings lost when retrieved via value attribute of DOM element.

Sample page and script:

```html
<form name="myForm" ...>
  <input type="text" name="lName" value="<%=ESAPI.encoder().encodeForHTML(last_name)%>">
 ...
</form>
<script>
  var x = document.myForm.lName.value;  //when the value is retrieved the encoding is reversed
  document.writeln(x);  //any code passed into lName is now executable.
</script>
```

Also certain usually safe JavaScript methods unsafe in certain contexts.

### Usually Safe Methods

Example of attribute thought safe: `innerText`.

Some papers/guides advocate it as `innerHTML` alternative vs XSS. But depending on tag `innerText` applied to, code can execute.

```html
<script>
 var tag = document.createElement("script");
 tag.innerText = "<%=untrustedData%>";  //executes code
</script>
```

`innerText` originally introduced by Internet Explorer; formally specified in HTML standard in 2016 after adoption by all major browser vendors.

### Detect DOM XSS using variant analysis

**Vulnerable code:**

```
<script>
var x = location.hash.split("#")[1];
document.write(x);
</script>
```

Semgrep rule identifying above dom xss.

## References

- MDN: innerHTML Security Considerations
- DOMPurify: HTML Sanitization
