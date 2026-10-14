# Cross Site Scripting Prevention Cheat Sheet

## Introduction

Helps developers prevent XSS vulnerabilities.

Cross-Site Scripting (XSS) = misnomer. Term derived from early attack versions focused on stealing data cross-site. Now includes injection of basically any content. XSS serious: account impersonation, observing user behavior, loading external content, stealing sensitive data, more.

**Techniques to prevent or limit XSS impact. No single technique solves XSS; use right combination of defensive techniques.**

## Framework Security

Apps built w/ modern web frameworks have fewer XSS bugs: frameworks steer developers to good practices, mitigate XSS via templating, auto-escaping, more. But problems occur if frameworks used insecurely, such as:

- _escape hatches_ frameworks use to directly manipulate DOM
- React’s `dangerouslySetInnerHTML` w/o sanitizing HTML
- Unvalidated URL values: React 19 blocks `javascript:` URLs in `src` and `href`, but doesn't replace application-specific [URL validation](#xss-prevention-rules-summary)
- Angular’s `bypassSecurityTrustAs*` functions
- Lit's `unsafeHTML` function
- Polymer's `inner-h-t-m-l` attribute and `htmlLiteral` function
- Template injection
- Out of date framework plugins or components
- and more

Know how framework prevents XSS and where gaps are. Sometimes need to act outside framework protection → Output Encoding and HTML Sanitization critical. OWASP will produce framework specific cheatsheets for React, Vue, Angular.

## XSS Defense Philosophy

Successful XSS: attacker inserts and executes malicious content in webpage. So protect all variables in web app. Ensuring **all variables** pass validation then escaping or sanitizing = **perfect injection resistance**. Any variable skipping this = potential weakness. Frameworks make it easy to ensure variables correctly validated and escaped or sanitized.

No framework perfect; security gaps exist in popular frameworks like React and Angular. Output encoding and HTML sanitization address gaps.

## Output Encoding

Safely displaying data exactly as user typed: output encoding recommended. Variables must not be interpreted as code instead of text. Section covers each output encoding form, where to use, when not to use dynamic variables at all.

First, start with framework’s default output encoding protection. Automatic encoding and escaping built into most frameworks.

No framework, or gaps in framework → use output encoding library. Pass each variable used in user interface through output encoding function. List of output encoding libraries in appendix.

Many encoding methods: browsers parse HTML, JS, URLs, CSS differently. Wrong encoding method may introduce weaknesses or harm functionality.

### Output Encoding for “HTML Contexts”

“HTML Context” = inserting variable between two basic HTML tags like `<div>` or `<b>`. E.g.:

```HTML
<div> $varUnsafe </div>
```

Attacker could modify data rendered as `$varUnsafe` → attack added to webpage. E.g.:

```HTML
<div> <script>alert`1`</script> </div> // Example Attack
```

To add variable to HTML context safely in web template, use HTML entity encoding.

Examples of encoded values for specific characters:

Displaying text w/ JavaScript: assign to `textContent` property of ordinary element such as `<div>`. Creates text node w/o parsing HTML; doesn't HTML-encode value. Pass original text w/o pre-encoding. Don't use for untrusted script or style content; `HTMLScriptElement.textContent` sets executable code.

```HTML
&    &amp;
<    &lt;
>    &gt;
"    &quot;
'    &#x27;
```

### Output Encoding for “HTML Attribute Contexts”

HTML attribute encoding for data inserted into ordinary text attributes, such as `title` or `value`. Keep element and attribute names fixed. Attributes containing URLs, CSS, HTML, or JavaScript need controls for those additional contexts.

Placeholder below = data already encoded for quoted HTML attribute:

```html
<input value="ENCODED DATA">
```

**Always surround attribute values with double (`"`) or single (`'`) quotation marks.** Use framework's or library's attribute encoder to protect surrounding quotes and other HTML syntax. Spaces don't end quoted value → encoding every space or every non-alphanumeric character unnecessary. HTML parsing rules distinguish quoted from unquoted values, where whitespace ends value.

HTML attribute encoding alone doesn't protect JavaScript in event-handler attribute: HTML parser decodes character references before JavaScript interpreted. Encoding more characters as HTML entities doesn't remove that second context. Prefer `addEventListener()` w/ trusted handler functions; pass user values as data. Unavoidable legacy templates: follow library's documented JavaScript-in-HTML context for data inside quoted JavaScript string within quoted HTML attribute; encoder can't make untrusted handler code safe.

Updating existing element from JavaScript: `element.setAttribute("title", value)` assigns value directly; doesn't HTML-encode. Don't pre-encode runtime value for ordinary text attribute. Keep attribute name fixed and safe: event-handler attributes and `srcdoc` can interpret values as code or HTML.

### Output Encoding for “JavaScript Contexts”

Server template inserting string data into inline script: use encoder documented for both JavaScript string and enclosing HTML script. Placeholder below = data already encoded for that location; template supplies quotes:

```html
<script>const message = "ENCODED DATA";</script>
```

Don't insert untrusted code, identifiers, or expressions. Use maintained encoder, follow its context contract; no manual quote escaping or generic `\xHH` rule. OWASP Java Encoder context guide distinguishes script blocks, quoted event-handler strings, standalone JavaScript. Ordinary template literal support depends on library and version; doesn't imply support for tagged templates or `${...}` expression bodies.

Encoders protect string placement, not later use: passing result to `eval()` or other code-interpreting sink remains unsafe.

JSON: verify `Content-Type` header is `application/json`, not `text/html`, to prevent XSS.

### Output Encoding for “CSS Contexts”

“CSS Contexts” = variables placed into inline CSS, common when users customize look and feel. CSS surprisingly powerful, used for many attack types. **Variables only in CSS property value. Other “CSS Contexts” unsafe; no variable data in them.**

```HTML
<style> selector { property : $varUnsafe; } </style>
<style> selector { property : "$varUnsafe"; } </style>
<span style="property : $varUnsafe">Oh no</span>
```

Changing styles w/ JavaScript: fixed property such as `element.style.color` w/ value from application-defined allowlist. CSS property assignment sets CSS value; doesn't automatically CSS-encode. Don't let untrusted input choose property or supply entire declaration block. Properties accepting URLs also need URL validation.

### Output Encoding for “URL Contexts”

“URL Contexts” = variables placed into URL. Most commonly parameter or URL fragment added to URL base then displayed or used. Use URL Encoding.

```HTML
<a href="http://www.owasp.org?test=$varUnsafe">link</a >
```

Encode all characters w/ `%HH` encoding format. Fully quote attributes, same as JS and CSS.

#### Common Mistake

URL used in different contexts; most common: `href` or `src` attribute of `<a>` tag. Do URL encoding, then HTML attribute encoding.

```HTML
url = "https://site.com?data=" + urlencode(parameter)
<a href='attributeEncode(url)'>link</a>
```

JavaScript constructing URL: use `encodeURIComponent()` for each untrusted query parameter value. Encodes URL component; doesn't validate complete URL.

Base64url represents bytes using URL-safe alphabet. Protocols such as [JSON Web Tokens (JWTs)](JSON_Web_Token.md) use unpadded form that `encodeURIComponent()` leaves unchanged. Use base64url only when receiver expects it. After decoding, apply output encoding or sanitization required by destination context.

### Dangerous Contexts

Output encoding not perfect; won't always prevent XSS. These locations = **dangerous contexts**:

```HTML
<script>Directly in a script</script>
<!-- Inside an HTML comment -->
<style>Directly in CSS</style>
<div ToDefineAnAttribute=test />
<ToDefineATag href="/test" />
```

Other areas to be careful with:

- Callback functions
- Where URLs handled in code such as this CSS { background-url : “javascript:alert(xss)”; }
- Untrusted JavaScript event-handler code (e.g., entire `onclick` value). Prefer trusted functions registered with `addEventListener()`; see HTML Attribute Contexts section for legacy string interpolation.
- Unsafe JS functions like `eval()`, `setInterval()`, `setTimeout()`

Don't place variables into dangerous contexts: even w/ output encoding, won't fully prevent XSS.

## HTML Sanitization

Users authoring HTML (e.g. WYSIWYG editor changing styling or structure): output encoding prevents XSS but breaks intended functionality (styling not rendered). Use HTML Sanitization.

HTML Sanitization strips dangerous HTML from variable, returns safe HTML string. OWASP recommends DOMPurify.

```js
let clean = DOMPurify.sanitize(dirty);
```

Further considerations:

- Sanitize then modify afterwards → can easily void security efforts.
- Sanitize then send to library for use: check it doesn’t mutate string. Otherwise security efforts void.
- Regularly patch DOMPurify or other HTML Sanitization libraries used. Browsers change functionality; bypasses discovered regularly.

## Safe Sinks

Security professionals talk in sources and sinks. Pollute a river, it flows downstream. Same in computer security. XSS sinks = places where variables placed into webpage.

Many sinks safe: treat variable as text, never execute. Refactor to remove references to unsafe sinks like innerHTML; use textContent or value.

```js
elem.textContent = dangerVariable;
elem.insertAdjacentText("beforeend", dangerVariable);
elem.className = dangerVariable;
elem.setAttribute(safeName, dangerVariable);
formfield.value = dangerVariable;
document.createTextNode(dangerVariable);
document.createElement(dangerVariable);
elem.innerHTML = DOMPurify.sanitize(dangerVar);
```

`insertAdjacentText()` requires position and text value. In example, `"beforeend"` appends text node inside element. Use text sinks on ordinary elements, not script or style elements.

**Safe HTML Attributes include:** `align`, `alink`, `alt`, `bgcolor`, `border`, `cellpadding`, `cellspacing`, `class`, `color`, `cols`, `colspan`, `coords`, `dir`, `face`, `height`, `hspace`, `ismap`, `lang`, `marginheight`, `marginwidth`, `multiple`, `nohref`, `noresize`, `noshade`, `nowrap`, `ref`, `rel`, `rev`, `rows`, `rowspan`, `scrolling`, `shape`, `span`, `summary`, `tabindex`, `title`, `usemap`, `valign`, `value`, `vlink`, `vspace`, `width`.

Attributes not listed: ensure JavaScript code provided as value can't execute.

## Other Controls

Framework Security Protections, Output Encoding, HTML Sanitization = best protection. OWASP recommends in all circumstances.

Consider additionally:

- Cookie Attributes - change how JavaScript and browsers interact with cookies. Try limiting XSS impact but don’t prevent malicious content execution or address root cause.
- Content Security Policy - allowlist preventing content loading. Easy to make implementation mistakes → not primary defense. Use CSP as additional defense layer; see [Content Security Policy cheatsheet](Content_Security_Policy.md).
- Trusted Types - Chromium-based browsers: enable Trusted Types by adding `Content-Security-Policy: require-trusted-types-for 'script'`. DOM XSS sinks (`innerHTML`, `outerHTML`, `document.write`, `script.src`, etc.) then reject plain strings, forcing all assignments through vetted policy. One of few controls eliminating entire classes of DOM XSS rather than mitigating. Combine w/ default policy delegating to sanitizer (e.g. DOMPurify) for legacy code paths.
- Web Application Firewalls - look for known attack strings, block them. WAF’s unreliable; new bypass techniques discovered regularly. Don't address root cause. Also miss class of XSS operating exclusively client-side. WAFs not recommended for preventing XSS, esp. DOM-Based XSS.

### XSS Prevention Rules Summary

HTML snippets showing how to render untrusted data safely in various contexts.

Data Type: String
Context: HTML Body
Code: `<span>UNTRUSTED DATA </span>`
Sample Defense: HTML Entity Encoding (rule \#1)

Data Type: String
Context: Safe HTML Attributes
Code: `<input type="text" name="fname" value="UNTRUSTED DATA ">`
Sample Defense: Quote value, use HTML attribute encoding. Keep attribute names fixed, use ordinary text attributes; apply additional controls for URL, CSS, HTML, or JavaScript values.

Data Type: String
Context: GET Parameter
Code: `<a href="/site/search?value=UNTRUSTED DATA ">clickme</a>`
Sample Defense: URL Encoding (rule \#5).

Data Type: String
Context: Untrusted URL in a SRC or HREF attribute
Code: `<a href="UNTRUSTED URL ">clickme</a> <iframe src="UNTRUSTED URL " />`
Sample Defense: Canonicalize input, URL Validation, Safe URL verification, Allow-list http and HTTPS URLs only (Avoid the JavaScript Protocol to Open a new Window), Attribute encoder.

Data Type: String
Context: CSS Value
Code: `HTML <div style="width: UNTRUSTED DATA ;">Selection</div>`
Sample Defense: Strict structural validation (rule \#4), CSS hex encoding, Good design of CSS features.

Data Type: String
Context: JavaScript Variable
Code: `<script>var currentValue='UNTRUSTED DATA ';</script> <script>someFunction('UNTRUSTED DATA ');</script>`
Sample Defense: Insert string data only inside quoted string, using encoder that also protects enclosing HTML script context. Don't rely on quote escaping alone.

Data Type: HTML
Context: HTML Body
Code: `<div>UNTRUSTED HTML</div>`
Sample Defense: HTML validation (JSoup, AntiSamy, HTML Sanitizer...).

Data Type: String
Context: DOM XSS
Code: `<script>document.write("UNTRUSTED INPUT: " + document.location.hash );<script/>`
Sample Defense: [DOM based XSS Prevention Cheat Sheet](DOM_based_XSS_Prevention.md) |

### Output Encoding Rules Summary

Output encoding (for XSS) converts untrusted input into safe form: input displayed as **data** to user without executing as **code** in browser. Charts list critical output encoding methods to stop XSS.

Encoding Type: HTML Entity
Encoding Mechanism: Convert `&` to `&amp;`, Convert `<` to `&lt;`, Convert `>` to `&gt;`, Convert `"` to `&quot;`, Convert `'` to `&#x27`

Encoding Type: HTML Attribute Encoding
Encoding Mechanism: Use framework or library encoder for quoted HTML text attributes; surround value with `"` or `'`. Encoding every space or non-alphanumeric character unnecessary. Doesn't validate URLs or encode JavaScript, CSS, or HTML contained in attribute.

Encoding Type: URL Encoding
Encoding Mechanism: Standard percent encoding, per W3C specification, to encode parameter values. Be cautious: encode only parameter values, not entire URL or path fragments of URL.

Encoding Type: JavaScript Encoding
Encoding Mechanism: Library encoder for JavaScript string data in actual surrounding context. Must protect string delimiters and, when embedded in HTML, enclosing script or attribute. Follow library's supported contexts; hex or Unicode escapes alone ≠ substitute for that contract.

Encoding Type: CSS Hex Encoding
Encoding Mechanism: CSS encoding supports `\XX` and `\XXXXXX` formats. For proper encoding: (a) add space after CSS encode (ignored by CSS parser), or (b) use full six-character CSS encoding format by zero-padding value. E.g., `A` becomes `\41` (short format) or `\000041` (full format). Alphanumeric characters (letters A to Z, a to z, digits 0 to 9) remain unencoded.

## Common Anti-patterns: Ineffective Approaches to Avoid

Defending vs XSS hard; some seek shortcuts.

Two common anti-patterns frequently in ancient posts, still commonly cited as solutions in modern posts on programmer forums such as Stack Overflow and other developer hangouts.

### Sole Reliance on Content-Security-Policy (CSP) Headers

Strong proponent of CSP when used properly. For XSS defense, CSP works best when:

- Used as defense-in-depth technique.
- Customized per individual application, not one-size-fits-all enterprise solution.

Against blanket CSP policy for entire enterprise. Problems:

#### Problem 1 - Assumption Browser Versions Support CSP Equally

Implicit assumption: all customer browsers support all CSP constructs in blanket policy. Often done w/o explicitly testing `User-Agent` request header for supported browser type and rejecting site use if not. Why: most businesses don't want to turn away customers using outdated browsers lacking some CSP Level 2 or Level 3 construct relied on for XSS prevention.  (Statistically almost all browsers support CSP Level 1 directives; unless worried about Grandpa using old Windows 98 laptop and ancient Internet Explorer, CSP Level 1 support can probably be assumed.)

#### Problem 2 - Issues Supporting Legacy Applications

Mandatory universal enterprise-wide CSP response headers inevitably break some web apps, esp. legacy. Business pushes back against AppSec guidelines; AppSec issues waivers and/or security exceptions until code patched. Exceptions crack XSS armor; even temporary cracks can impact business, at least reputationally.

### Reliance on HTTP Interceptors

Other common anti-pattern: validation and/or output encoding in interceptor such as Spring Interceptor (generally implements `org.springframework.web.servlet.HandlerInterceptor`) or JavaEE servlet filter (implements `javax.servlet.Filter`). Can succeed for very specific applications (e.g., validate all rendered input requests only alphanumeric data), but violates major XSS defense tenet: perform output encoding as close as possible to where data rendered. Generally HTTP request examined for query and POST parameters but other things like HTTP request headers that might be rendered, such as cookie data, not examined. Common approach: call `ESAPI.validator().getValidSafeHTML()` or `ESAPI.encoder.canonicalize()`, then depending on results redirect to error page or call something like `ESAPI.encoder().encodeForHTML()`. Often misses tainted input such as request headers or "extra path information" in URI; also output encoding completely non-contextual. E.g., how does servlet filter know input query parameter will render in HTML context (between HTML tags) rather than JavaScript context such as within `<script>` tag or JavaScript event handler attribute? It doesn't. JavaScript and HTML encoding not interchangeable → still open to XSS.

Unless filter or interceptor has full application knowledge, specifically how app uses each parameter for given request, can't succeed for all edge cases. Contend never will: providing that additional context is way too complex a design, and accidentally introducing another vulnerability (possibly far worse than XSS) almost inevitable.

Naive approach usually has at least one of four problems.

#### Problem 1 - Encoding for specific context not satisfactory for all URI paths

Improper encoding can still allow exploitable XSS in some URI paths. E.g. 'lastname' form parameter from POST normally displayed between HTML tags so HTML encoding sufficient, but edge case or two where lastname rendered as part of JavaScript block where HTML encoding insufficient → XSS.

#### Problem 2 - Interceptor approach can lead to broken rendering caused by improper or double encoding

Can result in incorrect or double encoding. E.g., in previous example, developer did proper output encoding for JavaScript rendering of lastname, but already HTML output encoded too → legitimate last name like "O'Hara" might render as "O\&#39;Hara".

Not strictly a security problem, but if frequent, business pushes back against filter; may disable filter or specify exceptions for certain pages or parameters, weakening any XSS defense it provided.

#### Problem 3 - Interceptors not effective against DOM-based XSS

Not effective vs DOM-based XSS. Would need interceptor or filter to scan all JavaScript content in HTTP response, figure out tainted output, see if susceptible to DOM-based XSS. Not practical.

#### Problem 4 - Interceptors not effective where data from responses originates outside your application

Interceptors generally oblivious to data in app's responses originating from other internal sources such as internal REST-based web service or internal database. Unless app strictly validates that data _at the point that it is retrieved_ (generally only point with enough context for strict allow-list validation), data always considered tainted. Output encoding or strict data validation of all tainted data on HTTP response side of interceptor (such as Java servlet filter): interceptor has no idea whether tainted data present from those REST web services or other databases. Response-side interceptors attempting XSS defense generally only consider matching "input parameters" tainted, do output encoding or HTML sanitization on them, everything else considered safe. Sometimes not? Frequently assumed all internal web services and databases "trusted" and used as is; very bad assumption unless included in deep threat modeling for app.

E.g., app showing customer detailed monthly bill. Assume app queries foreign (not part of your specific app) internal database or REST web service for user's full name, address, etc. That data originates from another application assumed "trusted" but with unreported persistent XSS vulnerability on customer address-related fields. Also assume company's customer support staff can examine customer's detailed bill to help with questions. Nefarious customer plants XSS bomb in address field, calls customer service about bill. Interceptor attempting to prevent XSS misses it completely; result much worse than popping alert box displaying "1" or "XSS" or "pwn'd".

### Summary

If interceptors / filters as XSS defense were useful, wouldn't they be in all commercial Web Application Firewalls (WAFs) and recommended by OWASP in this cheat sheet?

## Related Articles

See [XSS Filter Evasion Cheat Sheet](XSS_Filter_Evasion.md) for examples showing why filtering alone insufficient.

## References

- OWASP Java Encoder: Output Contexts and Boundaries
- DOMPurify Documentation
