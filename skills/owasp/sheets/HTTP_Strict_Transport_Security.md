# HTTP Strict Transport Security Cheat Sheet

## Introduction

HTTP Strict Transport Security (**HSTS**): opt-in response header. Supporting browser then blocks all HTTP comms to domain, sends everything over HTTPS. Also removes HTTPS click-through prompts.

Specified end 2012 as RFC 6797 (IETF).

## Threats

HSTS addresses:

- User bookmarks/types `http://example.com` → MITM exposure
    - HSTS auto-redirects HTTP → HTTPS for target domain
- HTTPS-only app inadvertently has HTTP links or serves HTTP content
    - HSTS auto-redirects HTTP → HTTPS for target domain
- MITM intercepts traffic w/ invalid certificate, hopes user accepts it
    - HSTS disallows user override of invalid-certificate message

## Examples

Long max-age (2 years = 63072000 seconds) for issuing host only. Without `includeSubDomains`, policy does not extend to subdomains (RFC 6797 section 6.1.2); see subdomain cookie risks in [Problems](#problems):

`Strict-Transport-Security: max-age=63072000`

Use if all present and future subdomains are HTTPS. More secure, but blocks pages only servable over HTTP:

`Strict-Transport-Security: max-age=63072000; includeSubDomains`

Same use, very short max-age for mistakes during initial rollout:

`Strict-Transport-Security: max-age=86400; includeSubDomains`

**Recommended:**

- To include domain in HSTS preload list (maintained by Chrome, used by Firefox, Safari), use header below.
- Sending `preload` can have **PERMANENT CONSEQUENCES**: users may lose access to site and all subdomains if you must switch back to HTTP. Read preload removal details before sending `preload`.

`Strict-Transport-Security: max-age=63072000; includeSubDomains; preload`

`preload` = owner consent to preloading. Owner must still submit domain to list.

## Problems

Site owners can use HSTS to identify users w/o cookies → significant privacy leak.

Cookies can be manipulated from subdomains, so omitting `includeSubDomains` permits broad cookie attacks HSTS would otherwise prevent (valid certificate required for subdomain). `secure` flag on all cookies prevents some, not all, of same attacks.

## Browser Support

As of September 2019 all modern browsers support HSTS; notable exception Opera Mini.

TLS configuration: [Transport Layer Security Cheat Sheet](Transport_Layer_Security.md).

## References

- Chromium Projects/HSTS
- RFC 6797: HTTP Strict Transport Security
