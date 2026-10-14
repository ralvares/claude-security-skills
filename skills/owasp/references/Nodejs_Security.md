# NodeJS Security Cheat Sheet

## Introduction

Actions devs can take to develop secure Node.js apps. Each item: brief explanation + Node.js-specific solution.

## Context

Node.js apps increasing in number; like other frameworks/languages, prone to all kinds of web app vulnerabilities.

## Objective

Best practices to follow during Node.js app development.

## Recommendations

Recommendations to enhance Node.js app security, categorized:

- **Application Security**
- **Error & Exception Handling**
- **Server Security**
- **Platform Security**

### Application Security

#### Use flat Promise chains

Asynchronous callbacks = one of Node.js's strongest features, but nesting layers become a problem. Any multistage process can nest 10 or more levels deep: "Pyramid of Doom" / "Callback Hell". Errors + results get lost within callback. Promises write async code without nested pyramids: top-down execution while async, delivering errors + results to next `.then` function.

Promises also handle errors better: error in Promise class skips `.then` functions, invokes first `.catch` found → higher assurance of capturing/handling errors. Principle: make all async code (apart from emitters) return promises. Promise calls can also become pyramid. To fully avoid "Callback Hell", use flat Promise chains. If module doesn't support Promises, convert base object to Promise with `Promise.promisifyAll()`.

"Callback Hell" example:

```JavaScript
function func1(name, callback) {
  // operations that takes a bit of time and then calls the callback
}
function func2(name, callback) {
  // operations that takes a bit of time and then calls the callback
}
function func3(name, callback) {
  // operations that takes a bit of time and then calls the callback
}
function func4(name, callback) {
  // operations that takes a bit of time and then calls the callback
}

func1("input1", function(err, result1){
   if(err){
      // error operations
   }
   else {
      //some operations
      func2("input2", function(err, result2){
         if(err){
            //error operations
         }
         else{
            //some operations
            func3("input3", function(err, result3){
               if(err){
                  //error operations
               }
               else{
                  // some operations
                  func4("input 4", function(err, result4){
                     if(err){
                        // error operations
                     }
                     else {
                        // some operations
                     }
                  });
               }
            });
         }
      });
   }
});
```

Securely written with flat Promise chain:

```JavaScript
function func1(name) {
  // operations that takes a bit of time and then resolves the promise
}
function func2(name) {
  // operations that takes a bit of time and then resolves the promise
}
function func3(name) {
  // operations that takes a bit of time and then resolves the promise
}
function func4(name) {
  // operations that takes a bit of time and then resolves the promise
}

func1("input1")
   .then(function (result){
      return func2("input2");
   })
   .then(function (result){
      return func3("input3");
   })
   .then(function (result){
      return func4("input4");
   })
   .catch(function (error) {
      // error operations
   });
```

Using async/await:

```JavaScript
async function func1(name) {
  // operations that takes a bit of time and then resolves the promise
}
async function func2(name) {
  // operations that takes a bit of time and then resolves the promise
}
async function func3(name) {
  // operations that takes a bit of time and then resolves the promise
}
async function func4(name) {
  // operations that takes a bit of time and then resolves the promise
}

(async() => {
  try {
    let res1 = await func1("input1");
    let res2 = await func2("input2");
    let res3 = await func3("input2");
    let res4 = await func4("input2");
  } catch(err) {
    // error operations
  }
})();
```

#### Set request size limits

Buffering + parsing request bodies is resource intensive. Without request size limit, attackers send large bodies → exhaust server memory and/or fill disk. Limit request body size for all requests using raw-body.

```JavaScript
const contentType = require('content-type')
const express = require('express')
const getRawBody = require('raw-body')

const app = express()

app.use(function (req, res, next) {
  if (!['POST', 'PUT', 'DELETE'].includes(req.method)) {
    next()
    return
  }

  getRawBody(req, {
    length: req.headers['content-length'],
    limit: '1kb',
    encoding: contentType.parse(req).parameters.charset
  }, function (err, string) {
    if (err) return next(err)
    req.text = string
    next()
  })
})
```

But fixed limit for all requests may be wrong: some requests have large payloads (e.g., file upload). Also JSON input more dangerous than multipart: parsing JSON is blocking. So set limits per content type. Easy with express middleware:

```JavaScript
app.use(express.urlencoded({ extended: true, limit: "1kb" }));
app.use(express.json({ limit: "1kb" }));
```

Attackers can change `Content-Type` header to bypass size limits. Before processing, validate request data against content type stated in headers. If per-request content type validation hurts performance severely, validate only specific content types or requests larger than predetermined size.

#### Do not block the event loop

Node.js: single-thread event-driven architecture (unlike thread-based platforms) → high throughput, simpler programming model. Built around non-blocking I/O event loop: no waiting on I/O or context switching. Event loop looks for events, dispatches to handler functions. So CPU intensive JavaScript operations make event loop wait ("blocking"). Node.js allows assigning callbacks to IO-blocked events: main app not blocked, callbacks run asynchronously. General principle: do all blocking operations asynchronously so event loop not blocked.

Even async blocking operations may misbehave if code outside callback relies on callback code running first. E.g.:

```JavaScript
const fs = require('fs');
fs.readFile('/file.txt', (err, data) => {
  // perform actions on file content
});
fs.unlinkSync('/file.txt');
```

Here `unlinkSync` may run before callback → file deleted before desired actions on content done. Such race conditions can affect security, e.g., authentication performed in callback while authenticated actions run synchronously. Eliminate: write all interdependent operations in single non-blocking function → guaranteed correct order. Above example, non-blocking:

```JavaScript
const fs = require('fs');
fs.readFile('/file.txt', (err, data) => {
  // perform actions on file content
  fs.unlink('/file.txt', (err) => {
    if (err) throw err;
  });
});
```

File unlink + other file operations within same callback → correct order.

#### Perform input validation

Input validation failures enable many attacks: SQL Injection, Cross-Site Scripting, Command Injection, Local/Remote File Inclusion, Denial of Service, Directory Traversal, LDAP Injection, many other injection attacks. Sanitize input first. Best technique: list of accepted inputs. If impossible, check input against expected scheme, escape dangerous inputs. Modules easing validation: validator, express-mongo-sanitize.
Details: [Input Validation Cheat Sheet](Input_Validation.md).

JavaScript dynamic; depending on how framework parses URL, data seen by app code takes many forms. Examples after parsing query string in express.js:

| URL | Content of request.query.foo in code |
| --- | --- |
| `?foo=bar` | `'bar'` (string) |
| `?foo=bar&foo=baz` | `['bar', 'baz']` (array of string) |
| `?foo[]=bar` | `['bar']` (array of string) |
| `?foo[]=bar&foo[]=baz` | `['bar', 'baz']` (array of string) |
| `?foo[bar]=baz` | `{ bar : 'baz' }` (object with a key) |
| `?foo[]baz=bar` | `['bar']` (array of string - postfix is lost) |
| `?foo[][baz]=bar` | `[ { baz: 'bar' } ]` (array of object) |
| `?foo[bar][baz]=bar` | `{ foo: { bar: { baz: 'bar' } } }` (object tree) |
| `?foo[10]=bar&foo[9]=baz` | `[ 'baz', 'bar' ]` (array of string - notice order) |
| `?foo[toString]=bar` | `{}` (object where calling `toString()` will fail) |

#### Perform output escaping

Use output encoding matching destination context to prevent cross-site scripting (XSS). escape-html supports ordinary HTML text + quoted ordinary-text attribute values; does not safely encode JavaScript, CSS, URL contexts. Follow [XSS Prevention Cheat Sheet](Cross_Site_Scripting_Prevention.md#output-encoding) for context-specific controls. To render user-supplied HTML (rather than escape), use maintained sanitizer such as DOMPurify (with `jsdom` for server-side) or `sanitize-html`. Avoid `node-esapi`: no longer actively maintained.

#### Perform application activity logging

Logging app activity = good practice: easier debugging of runtime errors; useful for incident response; feeds Intrusion Detection/Prevention Systems (IDS/IPS). Node.js modules: Winston, Bunyan, Pino. Enable streaming + querying logs, handle uncaught exceptions.

Log app activities to console + desired log file:

```JavaScript
const logger = new (Winston.Logger) ({
    transports: [
        new (winston.transports.Console)(),
        new (winston.transports.File)({ filename: 'application.log' })
    ],
    level: 'verbose'
});
```

Provide different transports to save errors to separate log file vs general app logs. More: Logging Cheat Sheet.

#### Monitor the event loop

App server under heavy network traffic may be unable to serve users: essentially Denial of Service (DoS) attack. toobusy-js module monitors event loop: tracks response time; beyond threshold indicates server too busy. Then stop processing incoming requests, send `503 Server Too Busy` so app stays responsive. Example:

```JavaScript
const toobusy = require('toobusy-js');
const express = require('express');
const app = express();
app.use(function(req, res, next) {
    if (toobusy()) {
        // log if you see necessary
        res.status(503).send("Server Too Busy");
    } else {
    next();
    }
});
```

#### Take precautions against brute-forcing

Brute-forcing = common threat to all web apps; password guessing to obtain account passwords. Take precautions esp. on login pages. Node.js modules: Express-bouncer, express-brute, rate-limiter; choose one or more per needs. Express-bouncer + express-brute work similarly: increase delay for each failed request; configurable per route. Usage:

```JavaScript
const bouncer = require('express-bouncer');
bouncer.whitelist.push('127.0.0.1'); // allow an IP address
// give a custom error message
bouncer.blocked = function (req, res, next, remaining) {
    res.status(429).send("Too many requests have been made. Please wait " + remaining/1000 + " seconds.");
};
// route to protect
app.post("/login", bouncer.block, function(req, res) {
    if (LoginFailed){  }
    else {
        bouncer.reset( req );
    }
});
```

```JavaScript
const ExpressBrute = require('express-brute');

const store = new ExpressBrute.MemoryStore(); // stores state locally, don't use this in production
const bruteforce = new ExpressBrute(store);

app.post('/auth',
    bruteforce.prevent, // error 429 if we hit this route too often
    function (req, res, next) {
        res.send('Success!');
    }
);
```

Apart from express-bouncer + express-brute, rate-limiter module helps prevent brute-forcing: specify how many requests specific IP can make in specified time period.

```JavaScript
const limiter = new RateLimiter();
limiter.addLimit('/login', 'GET', 5, 500); // login page can be requested 5 times at max within 500 seconds
```

CAPTCHA usage also common against brute-forcing. Node.js CAPTCHA modules; common: svg-captcha. Usage:

```JavaScript
const svgCaptcha = require('svg-captcha');
app.get('/captcha', function (req, res) {
    const captcha = svgCaptcha.create();
    req.session.captcha = captcha.text;
    res.type('svg');
    res.status(200).send(captcha.data);
});
```

Account lockout recommended to keep attackers away from valid users. Possible with many modules like mongoose; see blog post on implementing max login attempts with mongoose.

#### Use Anti-CSRF tokens

Cross-Site Request Forgery (CSRF) performs authorized actions on behalf of authenticated user without their knowledge; generally state-changing requests (changing password, adding users, placing orders). Csurf = express middleware used to mitigate CSRF, but security hole recently discovered; package team has not fixed it, marked package deprecated, recommends any other CSRF protection package.

Details: Cross-Site Request Forgery Prevention.

#### Remove unnecessary routes

Web app should contain no unused pages (increase attack surface). Disable all unused API routes in Node.js apps. Esp. in frameworks like Sails and Feathers, which auto-generate REST API endpoints. E.g., in Sails, URL not matching custom route may match automatic route and still generate response → results from information leakage to arbitrary command execution. Before using such frameworks/modules, know routes they auto-generate; remove/disable them.

#### Prevent HTTP Parameter Pollution

HTTP Parameter Pollution (HPP): attackers send multiple HTTP parameters with same name → app interprets unpredictably. Express populates multiple values in array. Fix: hpp module; ignores all values submitted for parameter in `req.query` and/or `req.body`, selects last value submitted. Usage:

```JavaScript
const hpp = require('hpp');
app.use(hpp());
```

#### Only return what is necessary

User info among most critical app info. User tables generally hold ID, username, full name, email address, birth date, password, sometimes social security numbers. When querying/using user objects, return only needed fields (personal information disclosure risk). Same for other stored objects: return only specific fields required. E.g., function below returns only needed fields: if listing user names, not returning email addresses or credit card numbers too.

```JavaScript
exports.sanitizeUser = function(user) {
  return {
    id: user.id,
    username: user.username,
    fullName: user.fullName
  };
};
```

#### Use object property descriptors

Object properties have three hidden attributes: `writable` (if false, value cannot be changed), `enumerable` (if false, property cannot be used in for loops), `configurable` (if false, property cannot be deleted). Defining property through assignment sets all three true by default. Set as follows:

```JavaScript
const o = {};
Object.defineProperty(o, "a", {
    writable: true,
    enumerable: true,
    configurable: true,
    value: "A"
});
```

Special functions for object attributes too. `Object.preventExtensions()` prevents new properties being added.

#### Use access control lists

Authorization prevents users acting outside intended permissions. Determine users + roles per least privilege; each role accesses only resources it must use. Node.js: acl module provides ACL (access control list) implementation; create roles, assign users.

### Permissions

Node.js v20+: Permission Model restricts app privileges. As of Node.js v23.5.0 stable, enabled via `--permission` flag (earlier versions need `--experimental-permission`).

#### Usage

```bash
node --permission [--allow-<type>=...] app.js
```

#### Examples

Only `--permission` restricts all permissions by default:

```bash
node --permission index.js
```

`--allow‑fs‑read` specifies files/directories Node.js may read. Esp. useful to prevent Local File Inclusion (LFI):

```bash
node --permission --allow-fs-read=/uploads/ index.js
```

`--allow-fs-write` specifies where Node.js may write files:

```bash
node --permission --allow-fs-write=/uploads/ index.js
```

Unauthorized access triggers runtime error:

```text
Error: Access to this API has been restricted
code: 'ERR_ACCESS_DENIED'
permission: 'FileSystemRead'
resource: '/path/to/file'
```

Other flags:

- `--allow-child-process` — allows using `child_process` APIs
- `--allow-worker` — allows usage of `worker_threads` APIs
- `--allow-addons` — enables loading native addons
- `--allow-wasi` — enables usage of WASI modules

**Important note:** Symbolic links followed even if pointing outside allowed paths → relative symlinks can bypass restrictions, grant unintended access. Ensure no allowed paths include relative symbolic links when using permission model.

Details: official documentation (Node.js permissions).

### Error & Exception Handling

#### Handle uncaughtException

Default for uncaught exceptions: print current stack trace, terminate thread. Customizable. Global object process (EventEmitter) emits uncaughtException event to main event loop; bind to it for custom behavior. Resuming app after uncaught exception can cause further problems. To not miss any, bind to uncaughtException event + clean up allocated resources (file descriptors, handles etc.) before shutting down process. Resuming strongly discouraged: app in unknown state. When showing error messages to user for uncaught exception, never reveal detail like stack traces; show custom error messages to avoid information leakage.

```JavaScript
process.on("uncaughtException", function(err) {
    // clean up allocated resources
    // log necessary error details to log files
    process.exit(); // exit the process to avoid unknown state
});
```

#### Listen to errors when using EventEmitter

Errors can occur anywhere in EventEmitter event chain. Normally error in EventEmitter calls `error` event with Error object argument. With no attached listeners to that event, Error object is thrown → uncaught exception. Unhandled errors in EventEmitter may crash app. Always listen to error events on EventEmitter objects.

```JavaScript
const events = require('events');
const myEventEmitter = function(){
    events.EventEmitter.call(this);
}
require('util').inherits(myEventEmitter, events.EventEmitter);
myEventEmitter.prototype.someFunction = function(param1, param2) {
    //in case of an error
    this.emit('error', err);
}
const emitter = new myEventEmitter();
emitter.on('error', function(err){
    //Perform necessary error handling here
});
```

#### Handle errors in asynchronous calls

Errors in async callbacks easy to miss. Principle: first argument to async calls = Error object. Express routes handle errors themselves, but errors in async calls made within express routes are not handled unless Error object sent as first argument.

Errors in these callbacks can propagate many times. Each callback receiving error can ignore, handle, or propagate it.

### Server Security

#### Set cookie flags appropriately

Session info generally sent via cookies; improper HTTP cookie use → session management vulnerabilities. Flags per cookie prevent these. `httpOnly`, `Secure`, `SameSite` very important for session cookies. `httpOnly`: prevents client-side JavaScript access; effective counter-measure for XSS. `Secure`: cookie sent only over HTTPS. `SameSite`: prevents cookies in cross-site requests; helps protect against Cross-Site Request Forgery (CSRF). Other flags (domain, path, expires): encouraged to set appropriately, but mostly cookie scope, not cookie security. Sample:

```JavaScript
const session = require('express-session');
app.use(session({
    secret: 'your-secret-key',
    name: 'cookieName',
    cookie: { secure: true, httpOnly: true, path: '/user', sameSite: true}
}));
```

#### Use appropriate security headers

HTTP security headers help prevent common attack vectors.
helmet package sets those headers:

```Javascript
const express = require("express");
const helmet = require("helmet");

const app = express();

app.use(helmet()); // Add various HTTP headers
```

Top-level `helmet` function wraps 14 smaller middlewares.
HTTP security headers covered by `helmet` middlewares:

- **Strict-Transport-Security**: HTTP Strict Transport Security (HSTS) tells browsers app accessible only via HTTPS. Add:

```JavaScript
app.use(helmet.hsts()); // default configuration
app.use(
  helmet.hsts({
    maxAge: 123456,
    includeSubDomains: false,
  })
); // custom configuration
```

- **X-Frame-Options:** determines if page can be loaded via `<frame>` or `<iframe>`. Allowing framing may enable Clickjacking attacks.

```JavaScript
app.use(helmet.frameguard()); // default behavior (SAMEORIGIN)
```

- **X-XSS-Protection:** stops pages loading when reflected cross-site scripting (XSS) attacks detected. Deprecated by modern browsers; its use can introduce additional client-side security issues. Recommended: set header **X-XSS-Protection: 0** to disable XSS Auditor, not allow browser default behavior.

```JavaScript
app.use(helmet.xssFilter()); // sets "X-XSS-Protection: 0"
```

Modern browsers: implement strong **Content-Security-Policy**, detailed in next section.

- **Content-Security-Policy:** reduces risk of attacks like Cross-Site Scripting (XSS) and Clickjacking. Allows content from list you decide. Several directives, each prohibits loading specific content type. See [Content Security Policy Cheat Sheet](Content_Security_Policy.md) for directive details. Implement:

```JavaScript
app.use(
  helmet.contentSecurityPolicy({
    // the following directives will be merged into the default helmet CSP policy
    directives: {
      defaultSrc: ["'self'"],  // default value for all directives that are absent
      scriptSrc: ["'self'"],   // helps prevent XSS attacks
      frameAncestors: ["'none'"],  // helps prevent Clickjacking attacks
      imgSrc: ["'self'", "'http://imgexample.com'"],
      styleSrc: ["'none'"]
    }
  })
);
```

This middleware does little validation; rely on CSP checkers like CSP Evaluator instead.

- **X-Content-Type-Options:** even with valid `Content-Type` header, browsers may sniff MIME type. Header stops this: browser must not change MIME types specified in `Content-Type`. Configure:

```JavaScript
app.use(helmet.noSniff());
```

- **Cache-Control and Pragma:** Cache-Control prevents browser caching of given responses. Do for pages with sensitive user/app info. Disabling caching for non-sensitive pages may seriously hurt performance → disable caching only for pages returning sensitive info. Set appropriate caching controls/headers with nocache package:

```JavaScript
const nocache = require("nocache");

app.use(nocache());
```

Above sets Cache-Control, Surrogate-Control, Pragma, Expires headers.

- **X-Download-Options:** prevents Internet Explorer executing downloaded files in site's context, via noopen directive:

```JavaScript
app.use(helmet.ieNoOpen());
```

- **X-Powered-By:** reveals server-side technology; unnecessary, causes information leakage → remove. Use `hidePoweredBy`:

```JavaScript
app.use(helmet.hidePoweredBy());
```

Can also lie about technologies used: e.g., set X-Powered-By to seem PHP though app doesn't use it.

```JavaScript
app.use(helmet.hidePoweredBy({ setTo: 'PHP 4.2.0' }));
```

### Platform Security

#### Keep your packages up-to-date

App security depends directly on security of third-party packages used. Keep packages up-to-date. Using Components with Known Vulnerabilities still in OWASP Top 10. OWASP Dependency-Check shows whether project packages have known vulnerabilities. Retire.js checks JavaScript libraries with known vulnerabilities.

`npm` version 6+ introduced `audit`, warns about vulnerable packages:

```bash
npm audit
```

`npm` also upgrades affected packages simply:

```bash
npm audit fix
```

Other dependency-check tools: see Vulnerable Dependency Management CS (tools).

#### Do not use dangerous functions

Some JavaScript functions dangerous; use only where necessary/unavoidable. First: `eval()`: takes string argument, executes as JavaScript source; with user input inherently leads to remote code execution. Similarly `child_process.exec` very dangerous: acts as bash interpreter, sends arguments to /bin/sh; injected input lets attackers execute arbitrary commands on server.

Some modules need special care. E.g., `fs` handles filesystem operations; improperly sanitized user input → file inclusion + directory traversal vulnerabilities. `node:vm` module compiles + runs code in V8 contexts, but is not a security mechanism. Never use it to execute untrusted code.

These functions/modules not forbidden outright, but use carefully, esp. with user input. Other direct-execution sinks (domxsswiki) can also make app vulnerable.

#### Stay away from evil regexes

Regular expression Denial of Service (ReDoS): DoS attack exploiting that most Regular Expression implementations may reach extreme situations making them work very slowly (exponential in input size). Attacker makes program using regex enter these situations and hang for very long.

Regexes are "evil" if app can get stuck on crafted input. Generally exploited by grouping with repetition and alternation with overlapping. E.g., `^(([a-z])+.)+[A-Z]([a-z])+$` can specify Java class names, but very long string (aaaa...aaaaAaaaaa...aaaa) also matches it. Tools check regex DoS potential, e.g., vuln-regex-detector.

#### Run security linters

Hard to keep all security tips in mind or have whole team obey rules. JavaScript dynamic + loosely-typed → linting tools essential in software development life cycle. ESLint and JSHint commonly used; no security checks by default; may catch general problems that are actually security issues. Enforce strict linting rules for security.

More importantly, third-party rulesets flag dangerous patterns such as `eval()`, `child_process`:

- eslint-plugin-security;
- eslint-plugin-node-security

Review linting rules periodically; audit findings. Custom rules possible for patterns you see as dangerous.

Even with dedicated rulesets, linters do not replace dedicated Static Analysis Security Testing (SAST) tools, which typically track code flow + detect complex vulnerabilities.

#### Use strict mode

JavaScript has unsafe, dangerous legacy features. ES5 strict mode removes them: previously silent errors thrown; helps engines optimize; previously accepted bad syntax causes real errors. Always use strict mode: write `"use strict";` at top of code.

Following generates `ReferenceError: Can't find variable: y` on console, not displayed unless strict mode used:

```JavaScript
"use strict";

func();
function func() {
  y = 3.14;   // This will cause an error (y is not defined)
}
```

#### Adhere to general application security principles

List focuses on issues common in Node.js apps. General security by design principles also apply to web apps regardless of app server technology; keep in mind while developing. OWASP Cheat Sheet Series: more on web app vulnerabilities + mitigations.

## References

- Node.js Security Best Practices
- Node.js Permissions
- Express: Production Security Best Practices
