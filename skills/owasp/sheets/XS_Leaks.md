# Cross-site leaks Cheat Sheet

## Introduction

Examples of attacks/defenses against cross-site leaks (XS Leaks). Based on core mechanism of modern browsers → also called browser side-channel attack. XS-Leaks exploit seemingly insignificant info exchanged in cross-site communications, inferring answers to questions about victim's user account:

- Is user currently logged in?
- Is user ID 1337?
- Is user an administrator?
- Does user have person with particular email address in contact list?

Attacker deduces answers depending on app context. Mostly binary (yes/no). Impact depends strongly on app risk profile. Still, XS Leaks may be real threat to user privacy and anonymity.

## Attack vector

![XS Leaks Attack Vector](../assets/XS_Attack_Vector.png)

- Entire attack on victim's browser side, like XSS
- Sometimes victim must stay on attacker's site longer for attack to succeed.

## Same Origin Policy (SOP)

Understand critical browser mechanism first: Same-origin Policy. Key aspects:

- URLs **same-origin** if **protocol**, **port**, **host** same
- Any origin can send request to another source, but SOP blocks reading response directly
- SOP may be relaxed by Cross Origin Resource Sharing (CORS).

| Origin A              | Origin B                  | Same origin?                   |
| -------------         | -------------             | -------------                  |
| `https://example.com` | `http://sub.example.com`  | No, different hosts             |
| `https://example.com` | `https://example.com:443` | Yes! Implicit port in Origin A |

SOP protects info access in cross-origin communication, but XS-Leaks based on residual data can infer some info.

## SameSite Cookies

SameSite cookie attribute tells browser whether to include cookie in request from other site. Values:

- `None` - cookie attached to cross-site request, must be sent over secure HTTPS channel
- `Lax` - cookie appended to cross-site request only if method GET and top-level navigation (navigation changes address in browser top bar)
- `Strict` - cookie never sent from another site

Chromium based browsers treat cookies w/o SameSite attribute as Lax by default.

SameSite cookies = strong **defense-in-depth** against **some** XS Leak classes and CSRF attacks; significantly reduce attack surface but may not cut them completely (e.g., window-based XS Leak attacks like frame counting and navigation).

### How do we know that two sites are SameSite?

![XS Leaks eTLD explanation](../assets/XS_Leaks_eTLD.png)

For SameSite cookies, site = scheme + registrable domain (eTLD+1). Port not part of site. E.g.:

| Full URL                                      | Site (scheme + eTLD+1)             |
| --------------------------------------------  | ------------------------  |
| `https://example.com:443/data?query=test`     | `https://example.com`     |

Why eTLD+1, not TLD+1? Domains like `.github.io` or `.eu.org`: parts not atomic enough to compare. Hence list of "effective" TLDs (eTLDs) (public suffix list).

Same scheme + eTLD+1 = same-site. E.g.:

| Origin A                  | Origin B                   | SameSite?                    |
| ------------------------- | -------------------------- | ---------------------        |
| `https://example.com`     | `http://example.com`       | No, different schemes    |
| `https://evil.net`        | `https://example.com`      | No, different eTLD+1          |
| `https://sub.example.com` | `https://data.example.com` | Yes, subdomains don't matter |

More: article "Understanding same-site".

## Attacks using the element ID attribute

DOM elements can have ID attribute unique in document. E.g.:

```html
<button id="pro">Pro account</button>
```

Browser automatically focuses element w/ given ID if hash appended to URL, e.g. `https://example.com#pro`; JavaScript focus event fires. Attacker may embed app in iframe w/ specific source on own page:

![XS-Leaks-ID](../assets/XS_Leaks_ID.png)

then add listener in main document for blur event (opposite of focus). When victim visits attacker's site, blur event fires → attacker concludes victim has pro account.

### Defense

#### Framing protection

If other origins needn't embed app in frame, use one of two mechanisms:

- **Content Security Policy `frame-ancestors`** directive.
- **X-Frame-Options** - mainly to support old browsers.

Framing protection efficiently blocks embedding app in frame on attacker-controlled origin, protects from other attacks like Clickjacking.

#### Fetch metadata (Sec-Fetch-Dest)

Sec-Fetch-Dest header gives end goal of request. Browser includes automatically; one of Fetch Metadata standard headers.

Sec-Fetch-Dest enables effective own resource isolation policies, e.g.:

```javascript
app.get('/', (req, res) => {
    if (req.get('Sec-Fetch-Dest') === 'iframe') {
        return res.sendStatus(403);
    }
    res.send({
        message: 'Hello!'
    });
});
```

![XS Leaks Sec-Fetch-Dest](../assets/XS_Leaks_Sec_Fetch_Dest.png)

Using Fetch Metadata headers: ensure users' browsers support standard (check caniuse). Also use appropriate fallback in code if Sec-Fetch-* header missing from request.

## Attacks based on error events

Embedding resources from other origins generally allowed (e.g., image from another origin, even script). Reading cross-origin resource not permitted due to SOP.

Browser requests resource; server decides response e.g. (200 OK or 404 NOT FOUND). Browser receives HTTP response and fires appropriate JavaScript event (onload or onerror).

So attacker loads resources and, from response status, infers whether they exist in logged-in victim's context. Situation:

- `GET /api/user/1234` - 200 OK - currently logged-in user is 1234 because resource loaded (onload event fired)
- `GET /api/user/1235` - 401 Unauthorized  - 1235 not ID of currently logged in user (onerror event triggered)

Attacker's JavaScript on controlled origin guesses victim's ID by enumerating all values in simple loop.

```javascript
function checkId(id) {
    const script = document.createElement('script');
    script.src = `https://example.com/api/users/${id}`;
    script.onload = () => {
        console.log(`Logged user id: ${id}`);
    };
    document.body.appendChild(script);
}

// Generate array [0, 1, ..., 40]
const ids = Array(41)
    .fill()
    .map((_, i) => i + 0);

for (const id of ids) {
    checkId(id);
}
```

Attacker doesn't care about reading response body (can't, due to browser isolation mechanisms such as Cross-Origin Resource Blocking). Needs only success info when `onload` event fires.

### Defense

#### SubResource protection

Special unique tokens may protect sensitive endpoints.

```
/api/users/1234?token=be930b8cfb5011eb9a030242ac130003
```

- Token should be long and unique
- Back-end MUST correctly validate token passed in request

Pretty effective, but proper implementation has significant overhead.

#### Fetch metadata (Sec-Fetch-Site)

Header specifies where request was sent from. Values:

- `cross-site`
- `same-origin`
- `same-site`
- `none` - user directly reached page

Like Sec-Fetch-Dest, browser appends automatically to each request; part of Fetch Metadata standard. Example:

```javascript
app.get('/api/users/:id', authorization, (req, res) => {
    if (req.get('Sec-Fetch-Site') === 'cross-site') {
        return res.sendStatus(403);
    }

    // ... more code

    return res.send({ id: 1234, name: 'John', role: 'admin' });
});
```

#### Cross-Origin-Resource-Policy (CORP)

Server returns this header w/ appropriate value → browser won't load resources from site/origin (even static images) in another application. Values:

- `same-site`
- `same-origin`
- `cross-origin`

More: resourcepolicy.fyi.

## Attacks on postMessage communication

Despite SOP, controlled situations sometimes need info exchange between origins: postMessage mechanism. Example:

```javascript
// Origin: http://example.com
const site = new URLSearchParams(window.location.search).get('site'); // https://evil.com
const popup = window.open(site);
popup.postMessage('secret message!', '*');

// Origin: https://evil.com
window.addEventListener('message', e => {
    alert(e.data) // secret message! - leak
});
```

### Defense

#### Specify strict targetOrigin

When attacker obtains window reference to receive message (as above), always specify exact `targetOrigin` in postMessage. Wildcard `*` as `targetOrigin` lets any origin receive message.

```javascript
// Origin: http://example.com
const site = new URLSearchParams(window.location.search).get('site'); // https://evil.com
const popup = window.open(site);
popup.postMessage('secret message!', 'https://sub.example.com');

// Origin: https://evil.com
window.addEventListener('message', e => {
    alert(e.data) // no data!
});
```

## Frame counting attacks

Number of loaded frames in window can leak info. E.g., app loads search results into frame; empty results → no frame.

![XS-Leaks-Frame-Counting](../assets/XS_Leaks_Frame_Counting.png)

Attacker gets loaded frame count by counting frames in `window.frames` object.

Attacker can obtain email list and, in simple loop, open subsequent windows and count frames. Frame count in opened window equals 1 → email is in client database of app used by victim.

### Defense

#### Cross-Origin-Opener-Policy (COOP)

Header prevents cross-origin documents opening in same browsing context group. Document A opening another document gets no access to its `window` object. Values:

- `unsafe-none`
- `same-origin-allow-popups`
- `same-origin`

Server returns e.g. `same-origin` COOP header → attack fails:

```javascript
const win = window.open('https://example.com/admin/customers?search=john%40example.com');
console.log(win.frames.length) // Cannot read property 'length' of null
```

## Attacks using browser cache

Browser cache reduces page load time on revisit but risks info leakage. Attacker detecting whether resource loaded from cache (after load time) can draw conclusions.

Principle: resource from cache loads incomparably faster than from server.

![XS Leaks Cache Attack](../assets/XS_Leaks_Cache_Attack.png)

Attacker embeds on own site a resource accessible only to admin-role user, then uses JavaScript to read load time of particular resource, deducing whether in cache.

Example selects first matching resource timing entry already recorded in timeline. Set `THRESHOLD` for measurement context; short duration alone doesn't prove cache hit.

```javascript
    // Illustrative timing threshold for this measurement context
    // const THRESHOLD = ...

    const adminImagePerfEntry = window.performance
        .getEntriesByType('resource')
        .find((entry) => entry.name.endsWith('admin.svg'));

    if (adminImagePerfEntry && adminImagePerfEntry.duration < THRESHOLD) {
        console.log('Possible cache hit (timing heuristic)');
    }
```

### Defense

#### Unpredictable tokens for images

Accurate when resources should stay cached while attacker can't find out about it.

```
/avatars/admin.svg?token=be930b8cfb5011eb9a030242ac130003
```

- Tokens unique per user context
- Attacker can't guess token → can't detect whether resource loaded from cache

#### Using the Cache-Control header

Disable cache if accepting degraded performance from reloading resources from server every visit. To disable caching for protected resources, set response header `Cache-Control: no-store`.

## Quick recommendations

- App uses cookies → set appropriate [SameSite attribute](#samesite-cookies).
- Decide whether app really should be embeddable in frames. If not, use mechanisms in [framing protection](#framing-protection) section.
- Strengthen isolation between origins w/ [Cross Origin Resource Policy](#cross-origin-resource-policy-corp) and [Cross Origin Opener Policy](#cross-origin-opener-policy-coop) headers w/ appropriate values.
- Use Fetch Metadata headers to build own resource isolation policy.

## References

- MDN: Cross-Site Leaks
- W3C: Fetch Metadata Request Headers
