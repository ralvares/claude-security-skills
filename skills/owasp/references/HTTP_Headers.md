# HTTP Security Response Headers Cheat Sheet

## Introduction

HTTP headers boost web security, easy to implement. Proper response headers help prevent vulnerabilities like Cross-Site Scripting, Clickjacking, Information disclosure, more.

Sheet reviews all security-related HTTP headers, recommended configurations, references to other sources for complicated headers.

## Security Headers

### X-Frame-Options

`X-Frame-Options` response header indicates whether browser may render page in `<frame>`, `<iframe>`, `<embed>` or `<object>`. Sites use it to avoid [clickjacking](https://owasp.org/www-community/attacks/Clickjacking) by preventing embedding in other sites.

Content Security Policy (CSP) frame-ancestors directive obsoletes X-Frame-Options for supporting browsers (MDN).

Useful only when response has something to interact with (e.g. links, buttons). Redirect or JSON API response: X-Frame-Options gives no security.

#### Recommendation

Use CSP frame-ancestors directive if possible.

Disallow displaying page in frame.
> `X-Frame-Options: DENY`

### X-XSS-Protection

`X-XSS-Protection` response header = Internet Explorer, Chrome, Safari feature stopping page loads on detecting reflected cross-site scripting (XSS).

WARNING: Protects users of older browsers lacking CSP, but in some cases creates XSS vulnerabilities in otherwise safe websites (MDN).

#### Recommendation

Use CSP disabling inline JavaScript.

Don't set header or explicitly turn off.
> `X-XSS-Protection: 0`

Details: Mozilla X-XSS-Protection.

### X-Content-Type-Options

`X-Content-Type-Options` response header: server tells browsers to follow MIME types advertised in Content-Type headers, not guess.

Blocks browsers' MIME type sniffing, which can turn non-executable MIME types into executable ones (MIME Confusion Attacks).

#### Recommendation

Set Content-Type header correctly throughout site.

> `X-Content-Type-Options: nosniff`

### Referrer-Policy

`Referrer-Policy` header controls how much referrer info (via Referer header) goes with requests.

#### Recommendation

Modern browsers default to `strict-origin-when-cross-origin`: same-origin requests include origin, path, query string in `Referer` header; cross-origin requests include only origin, except HTTPS-to-HTTP requests, which omit header. Set header explicitly; don't rely on browser defaults.

> `Referrer-Policy: strict-origin-when-cross-origin`

- *NOTE:* Configuration details: Mozilla Referrer-Policy.

### Content-Type

`Content-Type` representation header indicates original media type of resource (before content encoding for sending). If wrong, resource (e.g. image) may be interpreted as HTML → XSS possible.

Always set `Content-Type` correctly; vulnerability only if content intended for client rendering and resource untrusted (user provided/modified).

#### Recommendation

> `Content-Type: text/html; charset=UTF-8`

- *NOTE:* `charset` attribute necessary to prevent XSS in **HTML** pages
- *NOTE*: `Content-Type` can be any possible MIME type

### Cache-Control

`Cache-Control` header defines how browsers and intermediate caches cache responses.

#### Recommendation

- Use `no-store` for sensitive responses: prohibits storage in compliant HTTP caches.
- Use `private` to allow caching only in non-shared (user-specific) caches, prevent storage in shared caches (private caches may still persist response).
- Avoid relying on default caching behavior for sensitive/protected content.
- `no-cache` does not prevent caching; caches may store responses. Requires revalidation w/ origin server before reuse.

`no-store` does not control every storage mechanism: Cache API does not honor HTTP caching headers. Explicitly exclude sensitive responses from application-managed caches and remove existing sensitive entries; see [Offline Applications](HTML5_Security.md#offline-applications).

#### References

- MDN - Cache-Control

### Set-Cookie

`Set-Cookie` response header sends cookie from server to user agent, which sends it back later. Multiple cookies: send multiple Set-Cookie headers in same response.

Not a security header per se, but its security attributes crucial.

#### Recommendation

- Read [Session Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html#cookies) for cookie configuration options.

### Strict-Transport-Security (HSTS)

`Strict-Transport-Security` response header (HSTS) instructs browsers to access website only via HTTPS, even if user tries HTTP.

#### Recommendation

> `Strict-Transport-Security: max-age=63072000; includeSubDomains; preload`

- *NOTE*: Read how header works before using. Misconfigured HSTS or SSL/TLS certificate problem → legit users may lose access. E.g. very long HSTS duration plus expired/revoked SSL/TLS certificate → users locked out until HSTS duration expires.

See HSTS preload requirements before requesting preload inclusion.

More: [HTTP Strict Transport Security Cheat Sheet](HTTP_Strict_Transport_Security.md).

### Expect-CT ❌

`Expect-CT` header lets sites opt-in to reporting of Certificate Transparency (CT) requirements. Mainstream clients now require CT qualification; remaining value only reporting to header's report-uri. Now detection/reporting, not enforcement.

#### Recommendation

Do not use. Mozilla recommends avoiding it, removing from existing code if possible.

### Content-Security-Policy (CSP)

CSP specifies origins of content allowed to load on website/web app. Extra security layer detecting/mitigating attacks incl. Cross-Site Scripting (XSS) and data injection (used for data theft, site defacement, malware distribution).

- *NOTE*: Apply to pages that load/interpret scripts and code; may be meaningless in REST API responses not rendered.

#### Recommendation

CSP complex to configure/maintain. Customization options: [Content Security Policy Cheat Sheet](Content_Security_Policy.md)

### Access-Control-Allow-Origin

Without this header, site protected by default by Same Origin Policy (SOP). Header relaxes SOP in specified circumstances.

`Access-Control-Allow-Origin` = CORS (cross-origin resource sharing) header. Indicates whether response can be shared with requesting code from given origin. I.e. siteA requests resource from siteB: siteB must indicate in `Access-Control-Allow-Origin` that siteA may fetch it, else access blocked by SOP.

#### Recommendation

If used, set specific origins instead of `*`. See MDN Access-Control-Allow-Origin.
> `Access-Control-Allow-Origin: https://yoursite.com`

- *NOTE*: '\*' may be necessary depending on needs. E.g. public API accessible from any origin may need '\*'.

### Cross-Origin-Opener-Policy (COOP)

`Cross-Origin-Opener-Policy` (COOP) response header ensures top-level document doesn't share browsing context group with cross-origin documents.

Works with Cross-Origin-Embedder-Policy (COEP) and Cross-Origin-Resource-Policy (CORP) below.

Protects against attacks like Spectre, which can cross SOP security boundary for resources in same browsing context group.

Very browser-related; may not make sense for REST APIs or non-browser clients.

#### Recommendation

Isolates browsing context exclusively to same-origin documents.
> `Cross-Origin-Opener-Policy: same-origin`

### Cross-Origin-Embedder-Policy (COEP)

`Cross-Origin-Embedder-Policy` (COEP) response header prevents document loading cross-origin resources that don't explicitly grant permission (via [CORP](#cross-origin-resource-policy-corp) or CORS).

- *NOTE*: Enabling blocks cross-origin resources not configured correctly.

#### Recommendation

Document can load only same-origin resources, or resources explicitly marked loadable from another origin.
> `Cross-Origin-Embedder-Policy: require-corp`

- *NOTE*: `crossorigin` attribute requests resource in CORS mode. Resource server must permit request through CORS; attribute alone does not grant permission:
- `<img src="https://thirdparty.com/img.png" crossorigin>`

### Cross-Origin-Resource-Policy (CORP)

`Cross-Origin-Resource-Policy` (CORP) header controls set of origins empowered to include resource. Robust defense against attacks like Spectre: browsers block response before it enters attacker's process.

#### Recommendation

Limit resource loading to site and sub-domains only.
> `Cross-Origin-Resource-Policy: same-site`

### Permissions-Policy (formerly Feature-Policy)

Permissions-Policy controls which origins can use which browser features, in top-level page and embedded frames. Feature enabled in current document/frame only if its origin matches allowed list. Can configure site to never allow camera or microphone activation; prevents injection (e.g. XSS) enabling camera, microphone, other browser features.

More: MDN Permissions-Policy

#### Recommendation

Set it; disable all features site doesn't need or allow only to authorized domains:
> `Permissions-Policy: geolocation=(), camera=(), microphone=()`

- *NOTE*: Example disables geolocation, camera, microphone for all domains.

### Server

`Server` header describes software used by origin server that handled request (generated response).

Not a security header, but its use is security-relevant.

#### Recommendation

Remove header or set non-informative values.
> `Server: webserver`

- *NOTE*: Attackers have other means of fingerprinting server technology.

### X-Powered-By

`X-Powered-By` header describes webserver technologies. Exposes server; attackers find vulnerabilities easier.

#### Recommendation

Remove all `X-Powered-By` headers.

- *NOTE*: Attackers have other means of fingerprinting your tech stack.

### X-AspNet-Version

Provides .NET version info.

#### Recommendation

Disable sending. Add following line in `web.config` `<system.web>` section to remove it.

```xml
<httpRuntime enableVersionHeader="false" />
```

- *NOTE*: Attackers have other means of fingerprinting your tech stack.

### X-AspNetMvc-Version

Provides .NET version info.

#### Recommendation

Disable sending. To remove `X-AspNetMvc-Version` header, add line below in `Global.asax` file.

```lang-none
MvcHandler.DisableMvcResponseHeader = true;
```

- *NOTE*: Attackers have other means of fingerprinting your tech stack.

### X-Robots-Tag

`X-Robots-Tag` response header controls how search engines/automated crawlers index and display resources such as PDFs, images, other non-HTML content.
Like `<meta name="robots">` tag but via HTTP response header: more flexible (e.g., non-HTML files, server-wide rules).

```none
X-Robots-Tag: noindex, nofollow
```

- **Note:** Only compliant crawlers respect directives; they must still make HTTP request to read headers before deciding how to handle content.

#### Recommendation

Use `X-Robots-Tag` to control crawler behavior:

- **Private or sensitive content** not to be indexed:

  > `X-Robots-Tag: noindex, nofollow`
  > Prevents compliant search engines indexing resource or following its links.

- **Public content** to be indexed/discoverable (e.g., documentation, datasets):

  > `X-Robots-Tag: index, follow`
  > Allows search engines to index resource and follow its links.

Other directives: `noarchive`, `nosnippet`, `noimageindex`, per needs.
Server config can apply header selectively — e.g., only specific file types (PDFs, images).

### X-DNS-Prefetch-Control

`X-DNS-Prefetch-Control` response header controls DNS prefetching: browsers proactively resolve domain names of links user may follow and URLs of referenced items (images, CSS, JavaScript, etc.).

#### Recommendation

Browsers default to DNS caching; good for most websites.
If you don't control links on your website, consider `off` to disable DNS prefetch, avoiding info leaks to those domains.

> `X-DNS-Prefetch-Control: off`

- *NOTE*: Don't rely on it for anything production sensitive: nonstandard, not fully supported, implementation varies among browsers.

### Public-Key-Pins (HPKP) ❌

`Public-Key-Pins` response header associated specific cryptographic public key with web server to mitigate MITM with forged certificates. Removed from Chromium in 2018; unsupported by all modern browsers.

#### Recommendation

Do not use. Remove any `Public-Key-Pins` or `Public-Key-Pins-Report-Only` headers from production. Rely on Certificate Transparency (CT) and CAA DNS records: superior compromise detection w/o operational brittleness of pinning.

### Secure File Download Headers

Serving user-provided files: use proper headers to prevent unintended browser execution.

- Use `Content-Disposition: attachment` to force download instead of inline rendering.
- Use `Content-Type: application/octet-stream` for unknown/binary files.
- Ensure `X-Content-Type-Options: nosniff` set to prevent MIME type sniffing.

Reduce risks such as Cross-Site Scripting (XSS) and unintended file execution.

## Adding HTTP Headers in Different Technologies

### PHP

Sample code sets `X-Frame-Options` header in PHP.

```php
header("X-Frame-Options: DENY");
```

### Apache

`.htaccess` sample config setting `X-Frame-Options` header in Apache.

Per Apache documentation, `Header set` (default `onsuccess`) and `Header always set` operate on separate internal header tables.

Sometimes both tables used → duplicate headers if same header configured in both contexts.

To remove header entirely, unset in both contexts (`onsuccess` and `always`).

To avoid duplication and ensure header sent on all responses, unset first, then `always set`:

```lang-bsh
<IfModule mod_headers.c>
  Header unset X-Frame-Options
  Header always set X-Frame-Options "DENY"
</IfModule>
```

### IIS

Add configs below to `Web.config` in IIS to send `X-Frame-Options` header.

```xml
<system.webServer>
...
 <httpProtocol>
   <customHeaders>
     <add name="X-Frame-Options" value="DENY" />
   </customHeaders>
 </httpProtocol>
...
</system.webServer>
```

### HAProxy

Add line below to front-end, listen, or backend configs to send `X-Frame-Options` header.

```lang-none
http-response set-header X-Frame-Options DENY
```

### Nginx

Sample config sets `X-Frame-Options` header in Nginx. W/o `always` option, header sent only for certain status codes (see nginx documentation).

```lang-none
add_header "X-Frame-Options" "DENY" always;
```

### Express

Use helmet to set HTTP headers in Express. Sample code adds `X-Frame-Options` header.

```javascript
const helmet = require('helmet');
const app = express();
// Sets "X-Frame-Options: SAMEORIGIN"
app.use(
 helmet.frameguard({
   action: "sameorigin",
 })
);
```

## Testing Proper Implementation of Security Headers

### Mozilla Observatory

Mozilla Observatory = online tool checking website's header status.

### SmartScanner

SmartScanner has dedicated test profile for HTTP header security tests.
Online tools usually test homepage of given address; SmartScanner scans whole website → ensures all pages have right HTTP Headers.

## References

- MDN Web Docs: X-Content-Type-Options
- MDN Web Docs: Cross-Origin-Opener-Policy
- OWASP Secure Headers Project: Response Headers
