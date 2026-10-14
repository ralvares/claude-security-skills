# Server-Side Template Injection Prevention Cheat Sheet

## Introduction

Server-Side Template Injection (SSTI): server-side template engine evaluates untrusted input as template code, not data (CWE-1336). Engines (Jinja2, Twig, FreeMarker) have own expression languages → injected syntax runs w/ engine's access to application objects. Impact, depending on engine/config: sensitive data/file reads up to remote code execution.

Untrusted input reaches template code 3 ways:

- **Input becomes template source.** Untrusted data (request parameters, stored user content, third-party files) concatenated into template string, even inside expression like `"Hello {{" + name + "}}"`, or passed to string-to-template API e.g. Jinja2 `from_string()`, Flask `render_template_string()`.
- **Template evaluates input as code.** Fixed template passes value to feature parsing strings as template code, e.g. FreeMarker `?interpret`/`?eval` built-ins, Twig `template_from_string()`.
- **Input chooses template.** User input selects template name, path, include target → engine may load files it shouldn't.

Don't filter template syntax from input. Syntax differs per engine/context; denylist misses payloads.

Prevention only here. Testing running app: OWASP Web Security Testing Guide (WSTG-INJT-18).

## Prevention

### Treat templates as code

Keep templates w/ application source, review changes like code, never build from untrusted data. Untrusted data must not choose template name, path, include target: map user choice to fixed server-side list of template names. Users must author templates → see User-Supplied Templates below.

### Pass untrusted input only as data

Render fixed template, pass user values as named variables (like parameterized query keeps data out of SQL).

### Keep the render context minimal

Template reads whole render context and, per engine, can call methods on passed objects. Pass only needed values. No secrets, configuration, service clients, objects w/ side-effect methods. Limits what injected template reaches; doesn't stop code execution in non-sandboxed engine.

### Prefer the least powerful engine

Choose engine that limits power of expressions, function calls, commands, e.g. logic-less engine like Mustache, unless more needed. Registered custom helpers/lambdas still run as application code.

### Keep output escaping on

Auto-escaping helps prevent [cross-site scripting](Cross_Site_Scripting_Prevention.md) in HTML output. Doesn't prevent SSTI: escaping applies to printed values, not template code engine already parsed. Keep enabled; never mark untrusted values safe.

### Find vulnerable template code

- Inventory every template-rendering place: email/notification bodies, PDF/report generation, LLM prompts, every feature letting users create/edit templates. Templates shipped in third-party files = templates you didn't write.
- Search string-to-template APIs/features: Jinja2 `from_string()`, Flask `render_template_string()`, Twig `createTemplate()` and `template_from_string()`, FreeMarker `Template` constructor and `?interpret`/`?eval` built-ins. Also search code building template source/names from input.
- Per call site, confirm untrusted data reaches only render variables, no template passes it to feature evaluating strings as code.

## Engine Configuration

Frameworks can change engine defaults; check effective settings. Other engines: consult docs for untrusted-template restrictions.

| Engine | Restrictions for untrusted templates |
| --- | --- |
| Jinja2 | Use `SandboxedEnvironment`, or `ImmutableSandboxedEnvironment` to also block changes to lists, sets, dictionaries. Restrict attributes further by overriding `is_safe_attribute()`; decorate dangerous methods w/ `unsafe()`. |
| Twig | Twig treats templates as trusted code → its sandbox = only boundary for untrusted authors. Give sandbox own environment + strict `SecurityPolicy` allowlisting tags, filters, functions, tests, methods, properties. `Sandbox` class requires Twig 3.29 or later. Never allow `template_from_string()` in sandboxed templates. |
| FreeMarker | Follow FAQ on uploaded templates: set `?new` class resolver to `ALLOWS_NOTHING_RESOLVER`, not `SAFER_RESOLVER`; keep `?api` disabled (default), restrict member access w/ `SimpleObjectWrapper` or `WhitelistMemberAccessPolicy`, disable DOM node wrapping, use template loader loading only approved files. |

## User-Supplied Templates

Some products let users write templates by design (email builders, CMS themes, report designers). Privileged feature running user-written code:

- Limit template editing to authorized roles; log template changes for audit.
- Render w/ engine's sandbox/restricted config from table above; keep engine up to date.
- Register only filters, functions, globals safe to call w/ any arguments template author chooses. Sandbox doesn't limit your own code once called.
- Contain what sandbox doesn't. Per Twig docs, sandbox doesn't limit CPU/memory use or make rendered output safe; Jinja2 and FreeMarker warn same about resources. Treat output as untrusted; render in isolated process/container w/ time + memory limits, no secrets, restricted network access.

## References

- CWE-1336: Improper Neutralization of Special Elements Used in a Template Engine
- Twig Documentation: Twig Sandbox
- Apache FreeMarker FAQ: Can I allow users to upload templates?
