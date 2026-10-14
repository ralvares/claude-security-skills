# Third Party JavaScript Management Cheat Sheet

## Introduction

Tags (aka marketing tags, analytics tags etc.): small bits of JavaScript on web page; can also be HTML image elements when JavaScript disabled. Purpose: collect web user actions and browsing context for page owner's marketing.

Third party vendor JavaScript tags (**tags**) two types:

- User interface tags.
- Analytic tags.

User interface tags must execute on client: change DOM (display dialog/image, change text etc.).

Analytics tags send info back to marketing information database: user action just taken, browser metadata, location, page metadata etc. Rationale: give vendor data from user's browser DOM for marketing analysis. Data can be anything available in DOM. Used for navigation and clickstream analysis, user identification to decide further content, various marketing analysis functions.

**host** = original site user visits (shopping, news site etc.) that contains or retrieves and executes third party JavaScript tag for marketing analysis of user actions.

## Major risks

Single greatest risk: compromise of third party JavaScript server, injection of malicious JavaScript into original tag JavaScript. See RiskIQ's report of 2018 Ticketmaster incident.

Invoking third-party JS requires considering 3 risks:

1. Loss of control over changes to client application,
2. Execution of arbitrary code on client systems,
3. Disclosure/leakage of sensitive info to 3rd parties.

### Risk 1: Loss of control over changes to the client application

No guarantee third-party-hosted code stays same as developers/testers saw: new features may be pushed anytime → may break interface or data-flows, expose availability of your app to users/customers.

Typical defenses (not exhaustive): in-house script mirroring (prevent alterations by 3rd parties), sub-resource integrity (browser-level interception), secure transmission of third-party code (prevent in-transit modification). Details below.

### Risk 2: Execution of arbitrary code on client systems

Original research on vulnerable third-party integrations: Randy Westergren's ad-network findings.

Third-party JavaScript rarely reviewed by invoking party before integration. When client reaches hosting site, third-party code executes w/ exact same privileges as user (similar to XSS attacks).

Pre-production testing loses some validity, incl. `AST testing` (IAST, RAST, SAST, DAST, etc.).

Probability of intentionally injected rogue code by third-party widely accepted as low, but malicious injections after compromise of third party's servers have occurred (ex: Yahoo, January 2014).

Still evaluate this risk, esp. when third-party shows no documentation of enforcing security measures better than or at least equivalent to invoking organization's. Another case: domain hosting third-party JavaScript expires (company bankrupt or developers abandoned project); malicious actor re-registers domain, publishes malicious code.

Typical defenses (not exhaustive):

- In-house script mirroring (prevent alterations by 3rd parties),
- Sub-resource integrity (browser-level interception),
- Secure transmission of third-party code (prevent in-transit modification) and various types of sandboxing. Details below.
- ...

### Risk 3: Disclosure of sensitive information to 3rd parties

ClearSky's original Magecart investigation documents payment-data theft through injected JavaScript.

Invoking third-party script: browser contacts third-party servers directly. By default request includes all regular HTTP headers. Third-party obtains browser's originating IP address, referrer (non-https requests), any cookies previously set by third-party, e.g., when visiting another organization's site invoking same script.

Often gives third-party primary access to info on organization's users/customers/clients. If third-party shares script with other entities, it also collects secondary data from all of them → knows who visitors are and what other organizations they interact with.

Typical case: major news/press sites invoking third-party code (ad engines, statistics, JavaScript APIs): any visitor informs 3rd parties of visit. Often third-party also learns which news articles each user clicks (leak via HTTP referrer field) → deeper personality profiles.

Typical defenses (not exhaustive): in-house script mirroring (prevent HTTP request leakage to 3rd parties). Users can reduce profiling by random clicking links on leaking sites (press/news). Details below.

## Third-party JavaScript Deployment Architectures

Three basic deployment mechanisms for **tags**; combinable.

### Vendor JavaScript on page

Vendor provides host JavaScript; host puts it on host page. For security, host must review code for vulnerabilities like XSS attacks or malicious actions such as sending sensitive DOM data to malicious site. Often difficult: JavaScript commonly obfuscated.

```html
<!-- Some host, e.g. foobar.com, HTML code here -->
<html>
<head></head>
    <body>
        ...
        <script type="text/javascript">/* 3rd party vendor javascript here */</script>
    </body>
</html>
```

### JavaScript Request to Vendor

One or few lines on host page each request JavaScript file/URL directly from vendor site. Developer includes vendor-provided lines when creating host page. Each page access requests vendor JavaScript, which executes in user browser.

```html
<!-- Some host, e.g. foobar.com, HTML code here -->`
<html>
    <head></head>
    <body>
        ...
        <!-- 3rd party vendor javascript -->
        <script src="https://analytics.vendor.com/v1.1/script.js"></script>
        <!-- /3rd party vendor javascript -->
    </body>
</html>
```

### Indirect request to Vendor through Tag Manager

One or few lines on host page each request JavaScript file/URL from tag aggregator or **tag manager** site, not vendor site. Aggregator/manager returns whatever third party JavaScript files host configured. Each request can return many JavaScript files from multiple vendors.

Returned content (specific files and what they do) can be changed dynamically by host employees via GUI hosted on tag manager site, usable by non-technical users such as marketing.

Changes either:

1. Get different JavaScript file from third-party vendor for same request.
2. Change what DOM object data is read, and when, to send to vendor.

Tag manager developer UI generates code implementing marketing functionality, basically determining what data to get from browser DOM and when. Tag manager always returns **container** JavaScript file to browser: set of JavaScript functions used by UI-generated code.

Like java frameworks providing functions and global data, container JavaScript executes in browser; business user specifies high level functionality via tag manager UI w/o knowing JavaScript.

```html
<!-- Some host, e.g. foobar.com, HTML code here -->
 <html>
   <head></head>
     <body>
       ...
       <!-- Tag Manager -->
       <script>(function(w, d, s, l, i){
         w[l] = w[l] || [];
         w[l].push({'tm.start':new Date().getTime(), event:'tm.js'});
         var f = d.getElementsByTagName(s)[0],
         j = d.createElement(s),
         dl = l != 'dataLayer' ? '&l=' + l : '';
         j.async=true;
         j.src='https://tagmanager.com/tm.js?id=' + i + dl;
         f.parentNode.insertBefore(j, f);
       })(window, document, 'script', 'dataLayer', 'TM-FOOBARID');</script>
       <!-- /Tag Manager -->
   </body>
</html>`
```

#### Security Problems with requesting Tags

Mechanisms hard to secure: code visible only by proxying requests or accessing GUI to see configuration. JavaScript generally obfuscated, so seeing it usually useless. Instantly deployable: each new page request executes requests to aggregator, which gets JavaScript from vendor. Once any JavaScript files change at vendor or aggregator, next call from any browser gets changed JavaScript. One management way: *Subresource Integrity* standard, below.

### Server Direct Data Layer

Tag manager developer UI can create JavaScript getting data from anywhere in browser DOM and storing it anywhere on page. Vulnerability: interface can generate code reading unvalidated DOM data (e.g. URL parameters) into page location that executes JavaScript.

Use host-defined data layer to limit data intended for collection. This agreement doesn't restrict privileges of JavaScript executing in page.

Data layer is either:

1. DIV object w/ attribute values holding marketing/user behavior data third-party wants
2. Set of JSON objects w/ same data. Each variable/attribute holds value of some DOM element or description of user action. Data layer = complete set of values all vendors need for page. Created by host developers.

On business-defined events, JavaScript handler sends data layer values directly to tag manager server, which forwards to intended third party/parties. Event handler code created by host developers via tag manager developer UI; loaded from tag manager servers on every page load.

Data layer is not a sandbox. Web tag-manager containers can execute custom JavaScript and HTML tags in browser, so remotely managed event handlers remain part of page's code trust boundary. Restrict tag-manager publishing access; review changes as application code.

Requires cooperation among host, aggregator/tag manager, vendors.

Host developers work with vendor to learn what data vendor needs for analysis; host programmer determines which DOM element holds it.

Host developers work with tag manager/aggregator to agree protocol for sending data to aggregator: URL, parameters, format etc.

Tag manager/aggregator works with vendor to agree protocol for sending data to vendor: URL, parameters, format etc. Does vendor have API?

## Security Defense Considerations

### Server Direct Data Layer

Server-side collector can filter data sent to vendors, move eligible tags out of browser. Doesn't isolate scripts still running in page.

Data layer can validate values, esp. from user-exposed DOM objects like URL parameters and input fields, if needed for marketing analysis.

Example corporate standard statement: 'The tag JavaScript can only access values in the host data layer. The tag JavaScript can never access a URL parameter.

Host page developer must agree with third-party vendors or tag manager which data layer attribute holds what value so they can write JavaScript reading it.

User interface tags can't be secured using data layer architecture: their function (or one of them) is to change client UI, not send data about user actions.

For analytics not needing browser execution, send fixed event schema through collector you control, run vendor integrations server-side. Server-side tagging complements, doesn't replace, client-side collection. Audit scripts actually loaded before claiming only first-party code executes.

Also very scalable. Large ecommerce sites can have hundreds of thousands of URL/parameter combinations, different sets in different marketing campaigns. Marketing logic could have 30 or 40 different vendor tags on single page.

Example: user actions in pages about specified cities, from specified locations on specified days send data layer elements 1, 2 and 3. Pages about other cities send elements 2 and 3 only. Event handler code sending data layer data per page is controlled by host developers/marketing technologists via tag manager developer interface → logic about when/what data layer elements go to tag manager server changeable and deployable in minutes. No third-party interaction needed; they keep getting expected data, now from different contexts chosen by host marketing technologists.

Changing third party vendors = changing data dissemination rules at tag manager server; no host code changes. Data goes directly only to tag manager → fast execution. Event handler JavaScript needn't connect to multiple third party sites.

### Indirect Requests

Tag manager/aggregator sites offering GUI to configure JavaScript may also implement:

- Technical controls, e.g., JavaScript can access only data layer values, no other DOM element
- Restricting tag types deployed on host site, e.g. disabling custom HTML tags and JavaScript code

Host company should verify tag manager site's security practices, e.g., access controls to host's tag configuration; can include two-factor authentication.

Letting marketing decide data sources can cause XSS: they may take data from URL parameter into variable in scriptable page location.

### Sandboxing Content

Both tools sandbox/clean DOM data:

- DOMPurify: fast, tolerant XSS sanitizer for HTML, MathML, SVG. Secure default, highly configurable, hooks.
- MentalJS: JavaScript parser and sandbox. Allow-lists JavaScript code by adding "$" suffix to variables and accessors.

### Subresource Integrity

Subresource Integrity ensures only reviewed code executes. Developer generates integrity metadata for vendor JavaScript, adds to script element:

```javascript
<script src="https://analytics.vendor.com/v1.1/script.js"
   integrity="sha384-MBO5IDfYaE6c6Aao94oZrIOiC7CGiSNE64QUbHNPhzk8Xhm0djE6QqTpL0HzTUxk"
   crossorigin="anonymous">
</script>
```

SRI needs vendor host w/ CORS enabled. Also monitor vendor JavaScript for changes regularly: may get **secure** but **not working** third-party code when vendor updates it.

### Keeping JavaScript libraries updated

OWASP Top 10:2025 A03 Software Supply Chain Failures covers using components w/ known vulnerabilities, incl. JavaScript libraries. Keep libraries up to date: previous versions can have known vulnerabilities, typically leaving site vulnerable to Cross Site Scripting. Tools identify such libraries, e.g., free open source RetireJS.

### Sandboxing with iframe

Put vendor JavaScript into iframe from different domain (e.g. static data host): works as "jail"; vendor JavaScript has no direct access to host page DOM and cookies.

Host main page and sandbox iframe communicate via postMessage mechanism.

Secure iframes also with iframe sandbox attribute.

High risk applications: consider Content Security Policy (CSP) in addition to iframe sandboxing; stronger XSS hardening.

```html
<!-- Some host, e.g. somehost.com, HTML code here -->
 <html>
   <head></head>
     <body>
       ...
       <!-- Include iframe with 3rd party vendor javascript -->
       <iframe
       src="https://somehost-static.net/analytics.html"
       sandbox="allow-same-origin allow-scripts">
       </iframe>
   </body>
 </html>

<!-- somehost-static.net/analytics.html -->
 <html>
   <head></head>
     <body>
       ...
       <script>
       window.addEventListener("message", receiveMessage, false);
       function receiveMessage(event) {
         if (event.origin !== "https://somehost.com:443") {
           return;
         } else {
         // Make some DOM here and initialize other
        //data required for 3rd party code
         }
       }
       </script>
       <!-- 3rd party vendor javascript -->
       <script src="https://analytics.vendor.com/v1.1/script.js"></script>
       <!-- /3rd party vendor javascript -->
   </body>
 </html>
```

### Virtual iframe Containment

Creates iFrames running asynchronously relative to main page. Provides own containment JavaScript automating dynamic implementation of protected iFrames per marketing tag requirements.

### Vendor Agreements

Agreement/RFP with 3rd parties should require evidence of secure coding and general corporate server access security. Esp. determine monitoring and control of their source code to prevent/detect malicious JavaScript changes.

## MarTechSec

Marketing Technology Security

All aspects of reducing risk from marketing JavaScript. Controls:

1. Contractual controls for risk reduction; contracts w/ any MarTech company should require evidence of code security and code integrity monitoring.
2. Contractual controls for risk transference: contracts w/ any MarTech company could include penalty for serving malicious JavaScript
3. Technical controls for malicious JavaScript execution prevention; Virtual Iframes,
4. Technical controls for malicious JavaScript identification; Subresource Integrity.
5. Technical controls including client side JavaScript malicious behavior in penetration testing requirements.

## MarSecOps

Marketing Security Operations

Operational requirements maintaining some technical controls. Involves cooperation/information exchange among marketing team, martech provider, run/operations team to update page controls info (SRI hash change, changes in pages with SRI), Virtual iFrames policies, tag manager configuration, data layer changes etc.

Most complete preventive controls for any site w/ non-trivial marketing tags -

1. Controlled collector + server-side vendor integrations to reduce third-party browser code; data layer alone doesn't enforce code isolation.

2. Subresource Integrity.

3. Virtual frame Containment.

MarSecOps requirements to implement technical controls at marketing's speed of change, or w/o significant dedicated resources, can make data layer and Subresource Integrity controls impractical.

## References

- W3C: Subresource Integrity
- W3C: Content Security Policy Level 3
- MDN: Window.postMessage()
