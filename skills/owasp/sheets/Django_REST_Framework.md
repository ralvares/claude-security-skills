# Django REST Framework (DRF) Cheat Sheet

## Introduction

Basic DRF security guidelines for developers securing fundamental application aspects.

Original analysis of unsafe deserialization + serializer field selection: sections 4.4.1.12 and 4.4.1.18 of Django REST Framework (DRF) Secure Code Guidelines.

## What is a view in Django?

Django view = Python class or function returning web response after receiving web request. Response: plain HTTP, HTML template, or HTTP redirect to another page.

## Settings

Configure DRF in namespace REST_FRAMEWORK, normally in settings.py. Security-relevant items:

### DEFAULT_AUTHENTICATION_CLASSES

Authentication classes used by default to identify authenticated user via request.user or request.auth. Classes: 'rest_framework.authentication.SessionAuthentication' (session) and 'rest_framework.authentication.BasicAuthentication' (basic).

### DEFAULT_PERMISSION_CLASSES

Permission classes defining default permissions Django checks before view access. Default is 'rest_framework.permissions.AllowAny' → **unless changed, everybody can access every view by default.**

### DEFAULT_THROTTLE_CLASSES

Throttle classes checked by default at start of view. **Default class empty → no throttling by default.**

### DEFAULT_PAGINATION_CLASS

Default class for queryset pagination. **Django disables pagination by default.** Without pagination, lots of data → Denial of Service (DoS) problems/attacks.

## OWASP API Security Top 10 (2019)

OWASP API Security Top 10 = most critical API security risks, by Open Worldwide Application Security Project (OWASP). Helps organizations identify/prioritize significant API risks and implement controls.

Uses 2019 version. Secure web API starting from top threat (A1) downward; covers top threats first, spends security time most effectively. After Top 10, generally assess other threats or get professional penetration test.

### API1:2019 Broken Object Level Authorization

With object-level permissions, ensure user may access object via `.check_object_permissions(request, obj)`.

Example:

```python
def get_object(self):
    obj = get_object_or_404(self.get_queryset(), pk=self.kwargs["pk"])
    self.check_object_permissions(self.request, obj)
    return obj
```

DO NOT override `get_object()` without checking whether request should access that object.

### API2:2019 Broken User Authentication

Use DEFAULT_AUTHENTICATION_CLASSES w/ correct classes for project; authenticate every non-public API endpoint. Don't overwrite authentication class on class-based (variable `authentication_classes`) or function-based (decorator `authentication_classes`) view unless confident + understand impact.

### API3:2019 Excessive Data Exposure

Display only minimum required information. Review serializer + displayed information. Serializer inheriting ModelSerializer: DO NOT use exclude Meta property.

### API4:2019 Lack of Resources & Rate Limiting

Configure `DEFAULT_THROTTLE_CLASSES` and `DEFAULT_THROTTLE_RATES` for application usage policies; review per-view overrides. DRF explicitly warns [built-in throttling is not a security defense against brute force or denial-of-service attacks](https://www.django-rest-framework.org/api-guide/throttling/). Cache operations non-atomic → concurrent requests can exceed configured limit.

Enforce abuse controls at reverse proxy or API gateway as well as in app. Apply request-size + resource limits; layered defenses: [Denial of Service Cheat Sheet](Denial_of_Service.md).

### API5:2019 Broken Function Level Authorization

Change default (`'rest_framework.permissions.AllowAny'`) of DEFAULT_PERMISSION_CLASSES. Set DEFAULT_PERMISSION_CLASSES w/ correct classes for project.

DO NOT use `rest_framework.permissions.AllowAny` except for public API endpoints; DO NOT overwrite authorization class on class-based (variable `permission_classes`) or function-based (decorator `permission_classes`) view unless confident + understand impact.

### API6:2019 Mass Assignment

DRF APIs: explicitly allowlist fields in `ModelSerializer.Meta.fields`; avoid `Meta.exclude` and `fields = "__all__"` (expose newly added model fields). Follow serializer field selection guidance. Fields clients may read but must not change: read-only; `Meta.read_only_fields` for generated fields, `read_only=True` on explicitly declared fields. Serializer controls don't replace authorization checks for requested operation.

### API7:2019 Security Misconfiguration

Need repeatable hardening process → fast, easy deployment of properly locked down environment. Automated process continuously assessing configuration/settings effectiveness in all environments.

**DO NOT use default passwords. Set Django settings `DEBUG` and `DEBUG_PROPAGATE_EXCEPTIONS` to False. API accessible only by specified HTTP verbs; disable all others. Set `SECRET_KEY` to random value; NEVER hardcode secrets.**

**DO validate, filter, sanitize all client-provided data and data from integrated systems.**

### API8:2019 Injection

#### SQLi

**Use parametrized queries.** Careful w/ dangerous methods `raw()`, `extra()`, custom SQL (via `cursor.execute()`). DO NOT add user input to them (`raw()`, `extra()`, `cursor.execute()`).

#### RCE

Use `Loader=yaml.SafeLoader` for YAML files. DO NOT load user-controlled YAML files w/ `load()`.

DO NOT add user input to dangerous methods (`eval()`, `exec()` and `execfile()`); DO NOT load user-controlled pickle files, incl. pandas `pandas.read_pickle()`.

### API9:2019 Improper Assets Management

Inventory all API hosts; document important aspects of each: API version, API environment (e.g., production, staging, test, development), who should have network access (e.g., public, internal, partners). Document all API aspects: authentication, errors, redirects, rate limiting, cross-origin resource sharing (CORS) policy, endpoints incl. parameters, requests, responses.

### API10:2019 Insufficient Logging & Monitoring

Logging + monitoring:

- Log all failed authentication attempts, denied access, input validation errors w/ sufficient user context to identify suspicious/malicious accounts.
- Log in format suited to log management solution; include enough detail to identify malicious actor.
- Handle logs as sensitive data; guarantee integrity at rest + transit.
- Monitor infrastructure, network, API functioning continuously.
- Use Security Information and Event Management (SIEM) to aggregate/manage logs from all API stack components + hosts.
- Configure custom dashboards + alerts → earlier detection/response to suspicious activity.
- Establish effective monitoring + alerting → timely detection/response.

DO NOT:

- Log generic error messages like Log.Error("Error was thrown"); log stack trace, error message, user ID causing error.
- Log sensitive data e.g. user passwords, API Tokens, PII.

## Other Security Risks

API risks not in OWASP API Security Top 10.

### Business Logic Bugs

Business logic errors cause security bugs; hard to impossible to detect w/ automated tools. Best prevention: threat models, security design reviews, code reviews, pair programming, unit tests.

### Secret Management

**Never hardcode secrets. Best practice: Secret Manager.** See OWASP [Secrets Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)

## Updating Django and DRF and Having a Process for Updating Dependencies

All apps have dependencies; dependencies can have vulnerabilities. Audit project dependencies. Have dependency update process. Sample process, three update triggers:

- Every month/quarter: general dependency updates.
- Every week: consider important security vulnerabilities; may trigger update.
- EXCEPTIONAL conditions: emergency updates.

Django Security team: How Django discloses security issues.

Evaluating library: check "Security Health" (update frequency, known vulnerabilities, active community, etc.). Tools help (E.g. Snyk Advisor)

## SAST Tools

Open-source Python static analysis security tools:

Bandit: finds common Python security issues. Builds Abstract Syntax Tree (AST) per file, runs plugins against AST nodes, generates report after scanning all files. Originally developed within OpenStack Security Project, later rehomed to PyCQA.

Semgrep: fast open-source static analysis engine; finds bugs, detects vulnerabilities in third-party dependencies, enforces code standards. Developed by "Return To Corporation" (r2c) and open-source contributors. Rule-based (security, language best practices, etc.); creating rules easy; very powerful. Django: 29 rules.

PyCharm Security (Pycharm-security): plugin for PyCharm or JetBrains IDEs w/ Python plugin. Checks Python code for common security vulnerabilities, suggests fixes. Runnable from Docker container. About 40 checks, some Django specific.

## References

- Security in Django
- Django REST framework permissions
- Django REST framework settings
