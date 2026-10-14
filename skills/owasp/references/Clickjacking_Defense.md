# Clickjacking Defense Cheat Sheet

## Introduction

Guidance for defending vs Clickjacking (aka UI redress attacks).

Three main defense mechanisms:

- Prevent browser loading page in frame via X-Frame-Options or Content Security Policy (frame-ancestors) HTTP headers.
- Prevent session cookies in cross-site iframe requests via SameSite cookie attribute.
- JavaScript in page attempting to prevent loading in frame ("frame-buster").

These address frame-based clickjacking. [DoubleClickjacking](#defending-against-doubleclickjacking) uses separate windows; needs additional safeguards for sensitive actions.

Mechanisms independent; implement more than one where possible for defense in depth.

## Defending with Content Security Policy (CSP) frame-ancestors directive

`frame-ancestors` directive in Content-Security-Policy HTTP response header indicates whether browser may render page in `<frame>` or `<iframe>`. Avoids Clickjacking by ensuring content not embedded in other sites.

`frame-ancestors` lets site authorize multiple domains using normal CSP semantics.

### Content-Security-Policy: frame-ancestors Examples

Common uses:

- `Content-Security-Policy: frame-ancestors 'none';`
    - Prevents any domain framing content. Recommended unless specific framing need identified.
- `Content-Security-Policy: frame-ancestors 'self';`
    - Only current site may frame content.
- `Content-Security-Policy: frame-ancestors 'self' https://*.somesite.com https://myfriend.site.com;`
    - HTTPS page: allows own origin, HTTPS subdomains of `somesite.com`, and `https://myfriend.site.com` to frame it. Two HTTPS host expressions use default port (443). Wildcard matches subdomains, not bare `somesite.com` host; add that host explicitly if required.

Single quotes required around `self` and `none`, may not occur around other source expressions.

Further details/complex examples: W3C CSP spec frame-ancestors directive; MDN frame-ancestors.

### Limitations

**X-Frame-Options takes priority:** CSP Spec section "Relation to X-Frame-Options": "*If a resource is delivered with a policy that includes a directive named frame-ancestors and whose disposition is "enforce", then the X-Frame-Options header MUST be ignored*", but older browser versions (e.g., Chrome 40 & Firefox 35) ignored this and followed X-Frame-Options.

### Browser Support

See caniuse for browsers supporting CSP frame-ancestors.

References:

- Mozilla Developer Network

## Defending with X-Frame-Options Response Headers

`X-Frame-Options` HTTP response header indicates whether browser may render page in `<frame>` or `<iframe>`. Avoids Clickjacking by ensuring content not embedded in other sites. Set on all responses containing HTML content. Values: "DENY", "SAMEORIGIN", or "ALLOW-FROM uri"

### X-Frame-Options Header Types

Three values:

- **DENY**: prevents any domain framing content. Recommended unless specific framing need identified.
- **SAMEORIGIN**: only current site may frame content.
- **ALLOW-FROM uri**: permits specified 'uri' to frame page (e.g., `ALLOW-FROM http://www.example.com`).
    - Obsolete directive; no longer works in modern browsers.
    - See limitations below: fails open if browser doesn't support it.
    - Other browsers support new CSP frame-ancestors directive instead. A few support both.

### Browser Support

See caniuse for browsers supporting X-Frame-Options headers.

References:

- Mozilla Developer Network
- IETF Draft
- X-Frame-Options Compatibility Test - check for LATEST browser support info for X-Frame-Options header

### Implementation

Add `X-Frame-Options` HTTP Response header to any page to protect from clickjacking via framebusting. Options: add header manually to every page; possibly simpler: filter that automatically adds header to every page, or add at Web Application Firewall or Web/Application Server level.

### Common Defense Mistakes

Meta-tags applying X-Frame-Options directive DO NOT WORK. E.g. `<meta http-equiv="X-Frame-Options" content="deny">` won't work. Apply X-FRAME-OPTIONS directive as HTTP Response Header as above. Same for CSP directive `frame-ancestors`: HTTP Response Header, not `<meta>` tag.

### Limitations

- **Per-page policy specification**: policy specified for every page; complicates deployment. Enforcing for entire site, e.g. at login time, could simplify adoption.
- **Problems with multi-domain sites**: current implementation doesn't let administrator list domains allowed to frame page. Listing allowed domains can be dangerous, but sometimes administrator has no choice but multiple hostnames.
- **ALLOW-FROM browser support**: ALLOW-FROM obsolete, no longer works in modern browsers. BE CAREFUL ABOUT DEPENDING ON ALLOW-FROM. Applied but unsupported by browser → NO clickjacking defense in place.
- **Multiple options not supported**: no way to allow current site and third-party site to frame same response. Browsers honor only one X-Frame-Options header and one value on it.
- **Nested Frames don't work with SAMEORIGIN and ALLOW-FROM**: in the following situation, `http://framed.invalid/child` frame doesn't load: ALLOW-FROM applies to top-level browsing context, not immediate parent. Solution: ALLOW-FROM in both parent and child frames (but this prevents child frame loading if `//framed.invalid/parent` page loaded as top level document).

![NestedFrames](../assets/Clickjacking_Defense_Cheat_Sheet_NestedFrames.png)

- **X-Frame-Options Deprecated**: supported by major browsers, but obsoleted in favor of frame-ancestors directive from CSP Level 2 specification.
- **Proxies**: web proxies notorious for adding and stripping headers. Proxy strips X-Frame-Options → site loses framing protection.

## Defending with SameSite Cookies

Cookies marked `SameSite=Strict` or `SameSite=Lax` withheld from cross-site iframe requests. Can prevent clickjacking depending on those cookies for authentication. Other security uses: [CSRF guidance on SameSite](Cross-Site_Request_Forgery_Prevention.md#samesite-cookie-attribute).

SameSite doesn't block framing or withhold cookies from same-site requests. Attacker-controlled sibling subdomain w/ same scheme can be same-site yet different origin. Use [CSP `frame-ancestors`](#defending-with-content-security-policy-csp-frame-ancestors-directive) to restrict which origins may frame page, even w/ SameSite cookies configured.

### Limitations

Clickjacking not requiring authenticated user → attribute gives no protection.

`SameSite` supported by most modern browsers, but some users (approximately 6% as of November 2020) have browsers without support.

Part of defense-in-depth; not sole protective measure vs Clickjacking.

## Defending against DoubleClickjacking

DoubleClickjacking tricks user into activating sensitive control in another window during double-click. Target page is top-level window → framing restrictions such as `X-Frame-Options` and CSP `frame-ancestors` don't prevent it.

`SameSite` controls whether cookies accompany cross-site requests. `Lax` permits cookies on top-level navigations w/ safe HTTP methods; `Strict` withholds on initial cross-site request. Neither verifies user intended resulting action.

Pages your application controls, such as consent screens, payment confirmations, account security settings:

- High-risk actions: require user review of action's details and complete [transaction authorization](Transaction_Authorization.md). Enforce authorization server-side; extra confirmation button alone not complete defense vs UI redress.
- Disabling sensitive controls until prior interaction = proposed supplementary mitigation (Paulos Yibelo's disclosure). Mouse movement or key press alone doesn't establish user understands or approves action.
- If used, render controls disabled from start; test users can enable and activate them w/ mouse, keyboard, touch, assistive technology. Click events support all these input methods; don't require every user to move mouse or press key.
- Keep framing defenses above for frame-based attacks. Client-side interaction checks supplement, don't replace transaction authorization.

## Best-for-now Legacy Browser Frame Breaking Script

Defense: "frame-breaker" script in each page not to be framed. Following prevents framing even in legacy browsers not supporting X-Frame-Options-Header.

In document HEAD element, add:

First apply ID to style element itself:

```html
<style id="antiClickjack">
    body{display:none !important;}
</style>
```

Then delete that style by ID immediately after in script:

```html
<script type="text/javascript">
    if (self === top) {
        var antiClickjack = document.getElementById("antiClickjack");
        antiClickjack.parentNode.removeChild(antiClickjack);
    } else {
        top.location = self.location;
    }
</script>
```

Everything in document HEAD; only one method/taglib needed in API.

## window.confirm() Protection

X-Frame-Options or frame-breaking script = more fail-safe. Where content must be frameable, `window.confirm()` can help mitigate Clickjacking by informing user of action about to be performed.

Treat `window.confirm()` as supplementary confirmation, not guarantee users see dialog or origin label. Browsers can suppress simple dialogs, e.g. in sandboxed frame w/o `allow-modals`; `confirm()` then returns `false`. Perform action only after `true` result, as below:

```html
<script type="text/javascript">
    var action_confirm = window.confirm("Are you sure you want to delete your youtube account?")
    if (action_confirm) {
        //... Perform action
    } else {
        //... The user does not want to perform the requested action.`
    }
</script>
```

## Insecure Non-Working Scripts DO NOT USE

Following snippet **NOT recommended** vs clickjacking:

```html
<script>if (top!=self) top.location.href=self.location.href</script>
```

Simple frame breaking script tries to prevent incorporation into frame or iframe by forcing parent window to load current frame's URL. Multiple ways of defeating it public; some outlined here.

### Double Framing

Some frame busting techniques navigate to correct page by assigning to `parent.location`. Works if victim page framed by single page. If attacker encloses victim in one frame inside another (double frame), accessing `parent.location` becomes security violation in all popular browsers, due to **descendant frame navigation policy**. Violation disables counter-action navigation.

**Victim frame busting code:**

```javascript
if(top.location != self.location) {
    parent.location = self.location;
}
```

**Attacker top frame:**

```html
<iframe src="attacker2.html">
```

**Attacker sub-frame:**

```html
<iframe src="http://www.victim.com">
```

### The onBeforeUnload Event

User can manually cancel any navigation request submitted by framed page. Framing page registers `onBeforeUnload` handler, called whenever framing page about to unload due to navigation. Handler returns string that becomes part of prompt shown to user.

Say attacker wants to frame PayPal. Registers unload handler returning "Do you want to exit PayPal?". User likely cancels navigation on seeing string, defeating PayPal's frame busting.

Attacker registers unload event on top page:

```html
<script>
    window.onbeforeunload = function(){
        return "Asking the user nicely";
    }
</script>

<iframe src="http://www.paypal.com">
```

PayPal's frame busting code generates `BeforeUnload` event, activating function and prompting user to cancel navigation.

### No-Content Flushing

Previous attack needs user interaction; same attack possible w/o prompting. Modern browsers let attacker automatically cancel incoming navigation request in `onBeforeUnload` handler by repeatedly submitting navigation request to site responding "*204 - No Content*".

Navigating to No Content site = effectively NOP, but flushes request pipeline, canceling original navigation request. Sample code:

```javascript
var preventbust = 0
window.onbeforeunload = function() { killbust++ }
setInterval( function() {
    if(killbust > 0){
    killbust = 2;
    window.top.location = 'http://nocontent204.com'
    }
}, 1);
```

```html
<iframe src="http://www.victim.com">
```

### Restricted zones

Most frame busting relies on JavaScript in framed page to detect framing and bust out. JavaScript disabled in subframe context → frame busting code doesn't run. Several ways to restrict JavaScript in subframe:

**In Chrome:**

```html
<iframe src="http://www.victim.com" sandbox></iframe>
```

**Firefox:**

Activate designMode in parent page. designMode still supported in modern browsers, but effectiveness as clickjacking vector may vary in current browser versions.

```javascript
document.designMode = "on";
```

## References

- MDN: Content-Security-Policy frame-ancestors Directive
- MDN: X-Frame-Options
