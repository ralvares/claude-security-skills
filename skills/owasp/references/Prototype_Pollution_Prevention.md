# Prototype Pollution Prevention Cheat Sheet

## Explanation

Prototype Pollution: attacker manipulates app JavaScript objects/properties → unauthorized data access, privilege escalation, RCE.

Examples of danger: see [Other resources](#other-resources).

## Suggested protection mechanisms

### Use "new Set()" or "new Map()"

Use `new Set()` or `new Map()` instead of object literals:

```javascript
let allowedTags = new Set();
allowedTags.add('b');
if(allowedTags.has('b')){
  //...
}

let options = new Map();
options.set('spaces', 1);
let spaces = options.get('spaces')
```

### If objects or object literals are required

If objects needed, create w/ `Object.create(null)` → no inheritance from Object prototype:

```javascript
let obj = Object.create(null);
```

If object literals needed, last resort: `__proto__` property:

```javascript
let obj = {__proto__:null};
```

### Use object "freeze" and "seal" mechanisms

`Object.freeze()` on built-in prototypes: blocks adding/removing properties, makes existing data properties non-writable. Shallow: referenced objects stay mutable unless frozen separately. Test compatibility first; libraries modifying built-in prototypes can break.

`Object.seal()`: only blocks adding/removing properties and changing their configuration; existing writable values still changeable. Do not rely on sealing to prevent those modifications.

### Node.js configuration flag

Node.js: remove `__proto__` entirely w/ `--disable-proto=delete`. Defense in depth only.

Pollution still possible via `constructor.prototype`, but removing `__proto__` reduces attack surface, blocks some attacks.

### Other resources

- Portswigger Web Security Academy: What is prototype pollution?
- Snyk Learn: Prototype pollution

### Credits

Gareth Hayes: original protection guidance (OWASP ASVS issue 1563 comment).

## References

- MDN: JavaScript prototype pollution
- Node.js: Command-line API
