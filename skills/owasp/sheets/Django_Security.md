# Django Security Cheat Sheet

## Introduction

Django has built-in security features usable out-of-the-box vs common web vulnerabilities. This cheat sheet lists developer actions + tips for secure Django apps, w/ brief explanations and Django-specific code samples.

Built-ins are secure-by-default but flexible for component re-use in complex use-cases. Developers unfamiliar w/ component internals can configure them insecurely. This sheet enumerates some such cases.

## General Recommendations

- Keep Django + app dependencies up-to-date vs security vulnerabilities.
- Never run `DEBUG = True` in production; ensure app never in `DEBUG` mode there.
- Use packages like `django_ratelimit` or `django-axes` vs brute-force attacks.

## Authentication

- Use `django.contrib.auth` app for views/forms for authentication operations (login, logout, password change, etc.). Include module + dependencies `django.contrib.contenttypes` and `django.contrib.sessions` in `INSTALLED_APPS` in `settings.py`.

  ```python
  INSTALLED_APPS = [
      # ...
      'django.contrib.auth',
      'django.contrib.contenttypes',
      'django.contrib.sessions',
      # ...
  ]
  ```

- Use `@login_required` decorator so only authenticated users access a view. Sample:

  ```python
  from django.contrib.auth.decorators import login_required

  # User is redirected to default login page if not authenticated.
  @login_required
  def my_view(request):
    # Your view logic

  # User is redirected to custom '/login-page/' if not authenticated.
  @login_required(login_url='/login-page/')
  def my_view(request):
    # Your view logic
  ```

- Use password validators to enforce password policies. Add/update `AUTH_PASSWORD_VALIDATORS` in `settings.py` w/ validators your app requires.

  ```python
  AUTH_PASSWORD_VALIDATORS = [
    {
      # Checks the similarity between the password and a set of attributes of the user.
      'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator',
      'OPTIONS': {
        'user_attributes': ('username', 'email', 'first_name', 'last_name'),
        'max_similarity': 0.7,
      }
    },
    {
      # Checks whether the password meets a minimum length.
      'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator',
      'OPTIONS': {
        'min_length': 8,
      }
    },
    {
      # Checks whether the password occurs in a list of common passwords
      'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator',
    },
    {
      # Checks whether the password isn’t entirely numeric
      'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator',
    }
  ]
  ```

- Hash plain-text passwords for storage w/ `make-password` utility function.

  ```python
  from django.contrib.auth.hashers import make_password
  #...
  hashed_pwd = make_password('plaintext_password')
  ```

- Check plaintext password vs hash w/ `check-password` utility function.

  ```python
  from django.contrib.auth.hashers import check_password
  #...
  plain_pwd = 'plaintext_password'
  hashed_pwd = 'hashed_password_from_database'

  if check_password(plain_pwd, hashed_pwd):
    print("The password is correct.")
  else:
    print("The password is incorrect.")
  ```

## Key Management

`SECRET_KEY` in settings.py used for cryptographic signing; keep confidential. Recommendations:

- Generate key of at least 50 characters, mix of letters, digits, symbols.
- Generate `SECRET_KEY` w/ strong random generator e.g. Django `get_random_secret_key()`.
- Don't hard code `SECRET_KEY` in settings.py or elsewhere. Store in environment variables or secrets managers.

  ```python
  import os
  SECRET_KEY = os.environ.get('DJANGO_SECRET_KEY')
  ```

- Rotate key regularly; can invalidate sessions, password reset tokens, etc. Rotate immediately if ever exposed.

## Headers

Include `django.middleware.security.SecurityMiddleware` in `MIDDLEWARE` in project `settings.py` to add security headers. Sets:

- `SECURE_CONTENT_TYPE_NOSNIFF`: set to `True`. Protects vs MIME type sniffing via header `X-Content-Type-Options: nosniff`.
- `SECURE_HSTS_SECONDS`: positive value adds HTTP Strict Transport Security (HSTS) to HTTPS responses; supporting browsers use HTTPS for specified period. Doesn't reject HTTP requests on server or protect browser's first connection before policy known; preloading addresses that initial-connection gap.

Include `django.middleware.clickjacking.XFrameOptionsMiddleware` in `MIDDLEWARE` in project `settings.py` (list after `django.middleware.security.SecurityMiddleware`; ordering important). Sets:

- `X_FRAME_OPTIONS`: set to 'DENY' or 'SAMEORIGIN'. Adds `X-Frame-Options` header to all HTTP responses; protects vs clickjacking.

## Content Security Policy

Django 6.0+ has built-in Content Security Policy (CSP) support. Enable `django.middleware.csp.ContentSecurityPolicyMiddleware`; configure `SECURE_CSP` to enforce policy, or `SECURE_CSP_REPORT_ONLY` to monitor violations w/o blocking content. Follow Django's CSP configuration guide. Earlier versions: third-party library such as `django-csp`, or configure HTTP response headers.

More:

- [OWASP Content Security Policy Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Content_Security_Policy_Cheat_Sheet.html)
- Django Security Documentation

## Cookies

- `SESSION_COOKIE_SECURE`: set to `True` in `settings.py`. Sends session cookie over secure (HTTPS) connections only.
- `CSRF_COOKIE_SECURE`: set to `True` in `settings.py`. Sends CSRF cookie over secure connections only.
- Custom cookie via `HttpResponse.set_cookie()` in view: set secure parameter to `True`.

  ```python
  response = HttpResponse("Some response")
  response.set_cookie('my_cookie', 'cookie_value', secure=True)
  ```

## Cross Site Request Forgery (CSRF)

- Include `django.middleware.csrf.CsrfViewMiddleware` in `MIDDLEWARE` in project `settings.py` to add CSRF related headers.
- Forms: use `{% csrf_token %}` template tag to include CSRF token. Sample:

  ```html
  <form method="post">
      {% csrf_token %}
      <!-- Your form fields here -->
  </form>
  ```

- AJAX calls: extract request's CSRF token before use in call.  
- More: Django's Cross Site Request Forgery protection documentation.

## Cross Site Scripting (XSS)

Additional to XSS recommendations above.

- Render templates w/ built-in Django template system. See Django's Automatic HTML escaping documentation.
- Avoid `safe` filter (or `mark_safe` function) disabling automatic template escaping. If needed, ensure input from trusted source. Extra caution w/ user-controlled inputs.
- Use `json_script` template filter to pass data to JavaScript in Django templates.
- See Django's Cross Site Scripting (XSS) protection documentation.

## HTTPS

- Include `django.middleware.security.SecurityMiddleware` in `MIDDLEWARE` in project `settings.py` if not already.
- Set `SECURE_SSL_REDIRECT = True` in `settings.py` so all communication is HTTPS; auto-redirects HTTP to HTTPS. 301 (permanent) redirect, so browser remembers it for subsequent requests.
- Configure `SECURE_PROXY_SSL_HEADER` only behind trusted proxy that strips client-supplied copies of chosen header and sets its HTTPS-indicating value only for requests originally received over HTTPS. Prevent clients bypassing proxy to supply trusted header directly. If conditions can't be guaranteed, leave setting at `None`; see Django's proxy-header security warning.

## Admin panel URL

Advisable to change default admin panel URL (example.com/admin/) to slightly raise difficulty for automated attacks. How:

In default app folder of project, locate `urls.py` managing top-level URLs. Modify `urlpatterns` variable (list) so URL to `admin.site.urls` differs from "admin/". Obscures common admin endpoint; extra security layer.

## Django's built-in command `check --deploy`

Built-in command `check --deploy` for security checks. Example:

```
$ ./manage.py check --deploy
System check identified some issues:

WARNINGS:
?: (security.W004) You have not set a value for the SECURE_HSTS_SECONDS setting. If your entire site is served only over SSL, you may want to consider setting a value and enabling HTTP Strict Transport Security. Be sure to read the documentation first; enabling HSTS carelessly can cause serious, irreversible problems.
?: (security.W008) Your SECURE_SSL_REDIRECT setting is not set to True. Unless your site should be available over both SSL and non-SSL connections, you may want to either set this setting True or configure a load balancer or reverse-proxy server to redirect all connections to HTTPS.
?: (security.W009) Your SECRET_KEY has less than 50 characters, less than 5 unique characters, or it's prefixed with 'django-insecure-' indicating that it was generated automatically by Django. Please generate a long and random value, otherwise many of Django's security-critical features will be vulnerable to attack.
?: (security.W012) SESSION_COOKIE_SECURE is not set to True. Using a secure-only session cookie makes it more difficult for network traffic sniffers to hijack user sessions.
?: (security.W016) You have 'django.middleware.csrf.CsrfViewMiddleware' in your MIDDLEWARE, but you have not set CSRF_COOKIE_SECURE to True. Using a secure-only CSRF cookie makes it more difficult for network traffic sniffers to steal the CSRF token.
?: (security.W018) You should not have DEBUG set to True in deployment.
?: (security.W020) ALLOWED_HOSTS must not be empty in deployment.

System check identified 7 issues (0 silenced).

```

Harden project by addressing warnings.

## References

- Django 5.2: Clickjacking Protection
- Django 5.2: Security Middleware
