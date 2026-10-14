# Ruby on Rails Cheat Sheet

## Introduction

Quick basic Ruby on Rails security tips for developers. Complements/emphasizes Rails core security guide.

Rails abstracts tedious work; developers unfamiliar with Rails internals need basic guidelines to secure fundamental application aspects. This doc = that guide.

## Items

### Command Injection

Ruby "eval" dynamically builds Ruby code from Strings. Many ways to call system commands too.

``` ruby
eval("ruby code here")
system("os command here")
`ls -al /` # (backticks contain os command)
exec("os command here")
spawn("os command here")
open("| os command here")
Process.exec("os command here")
Process.spawn("os command here")
IO.binread("| os command here")
IO.binwrite("| os command here", "foo")
IO.foreach("| os command here") {}
IO.popen("os command here")
IO.read("| os command here")
IO.readlines("| os command here")
IO.write("| os command here", "foo")
```

Powerful but use extreme care in Rails apps; usually a bad idea. If needed: allow-list of possible values, validate input as thoroughly as possible.

Further: Rails and OWASP command injection guides.

### SQL Injection

Rails often uses ORM ActiveRecord (other data sources possible). Simple apps query via model methods; many use cases protect against SQL Injection out of the box, but code can still allow it.

``` ruby
name = params[:name]
@projects = Project.where("name like '" + name + "'");
```

Injectable: name parameter not escaped.

Idiom:

``` ruby
@projects = Project.where("name like ?", "%#{ActiveRecord::Base.sanitize_sql_like(params[:name])}%")
```

Never build SQL statements from user-controlled input. More realistic examples: rails-sqli.org. OWASP SQL Injection info.

### Cross-site Scripting (XSS)

XSS protection default: string data shown in views is escaped before sending to browser. Developers commonly bypass it, e.g. rich text editing. Tempting in .erb file (ruby markup) to pass variables with tags intact:

``` ruby
# Wrong! Do not do this!
<%= raw @product.name %>

# Wrong! Do not do this!
<%== @product.name %>

# Wrong! Do not do this!
<%= @product.name.html_safe %>
```

Any field using `raw`, `html_safe` or similar = potential XSS target. Widespread misunderstandings about `html_safe()`.

SafeBuffer mechanism: StackOverflow "raw vs html_safe vs h". Other tags changing output string preparation can introduce similar issues.

String `html_safe` confusingly named: means content known safe to include in HTML without escaping. **Method itself is un-safe!**

Must accept user HTML → use markup language for rich text (e.g. Markdown, textile), disallow HTML tags; input then excludes malicious HTML.

Cannot restrict HTML input → implement content security policy disallowing JavaScript execution. Also consider `#sanitize` (lists allowed tags); flawed numerous times, never complete solution.

User-controlled link destinations need URL validation in addition to HTML escaping:

``` ruby
<%= link_to "Personal Website", @user.website %>
```

`@user.website` containing `javascript:` URL → clicking link can execute script:

``` html
<a href="javascript:alert('Haxored')">Personal Website</a>
```

`link_to` enforces no URL-scheme allowlist. Validate personal website URLs allow only `https` or `http` before rendering; keep HTML attribute escaping. See [XSS prevention rules](Cross_Site_Scripting_Prevention.md#xss-prevention-rules-summary) for URL validation + encoding. Never use `html_safe` to bypass escaping.

Restrictive Content Security Policy can additionally block `javascript:` navigation; does not replace URL validation.

Brakeman scanner helps find XSS in Rails apps.

General XSS info: OWASP Cross-site Scripting (XSS).

### Sessions

Rails default: Cookie based session store → session does not expire on server unless changed; default apps may be vulnerable to replay attacks. Never put sensitive information in session.

Best practice: database based session, easy in Rails:

``` ruby
Project::Application.config.session_store :active_record_store
```

See [Session Management Cheat Sheet](Session_Management.md).

### Authentication

Start securing authentication by enabling TLS in configuration:

``` ruby
# config/environments/production.rb
# Force all access to the app over SSL, use Strict-Transport-Security,
# and use secure cookies
config.force_ssl = true
```

Uncomment line 3 as above in configuration.

Rails 8.0 introduced built-in authentication generator for basic authentication + password reset. Starting point; must adapt to app, incl. implementing sign-up flow. Libraries such as Devise remain an option.

Examples below use Devise gem.

Install:

```bash
gem 'devise'
```

Install to user model:

```bash
rails generate devise:install
```

Specify resources (routes) requiring authenticated access:

``` ruby
Rails.application.routes.draw do
  authenticate :user do
    resources :something do  # these resource require authentication
      ...
    end
  end

  devise_for :users # sign-up/-in/out routes

  root to: 'static#home' # no authentication required
end
```

Enforce password complexity with zxcvbn gem (devise_zxcvbn). Configure user model:

``` ruby
class User < ApplicationRecord
  devise :database_authenticatable,
    # other devise features, then
    :zxcvbnable
end
```

Configure required password complexity:

``` ruby
# in config/initializers/devise.rb
Devise.setup do |config|
  # zxcvbn score for devise
  config.min_password_score = 4 # complexity score here.
  ...
```

PoC: qutorial/revise.

omniauth gem: multiple authentication strategies; secure authentication with Facebook, LDAP, many other providers.

#### Token Authentication

Devise usually uses Cookies. Token authentication: gem devise_token_auth.

Supports multiple front end technologies, e.g. angular2-token.

Configured like devise itself. Requires omniauth dependency.

```bash
# token-based authentication
gem 'devise_token_auth'
gem 'omniauth'
```

Define route:

```ruby
mount_devise_token_auth_for 'User', at: 'auth'
```

Modify User model accordingly.

One command does these:

```bash
rails g devise_token_auth:install [USER_CLASS] [MOUNT_PATH]
```

May need to edit generated migration to avoid unnecessary/duplicate fields.

Note: token authentication only → no CSRF protection needed in controllers. Cookies and tokens both → paths using cookies for authentication still must be protected from forgery!

See [Authentication Cheat Sheet](Authentication.md).

### Insecure Direct Object Reference or Forceful Browsing

Rails apps use RESTful URI structure → paths intuitive, guessable. Control actions specifically to stop users accessing/modifying other users' data. Vanilla Rails has no such built-in protection. Do by hand at controller level.

Or, probably recommended: resource-based access control libraries such as cancancan (cancan replacement) or pundit → all operations on database object authorized by app business logic.

More: OWASP Top 10:2025 A01 Broken Access Control; [Insecure Direct Object Reference Prevention Cheat Sheet](Insecure_Direct_Object_Reference_Prevention.md).

### CSRF (Cross Site Request Forgery)

Rails has built-in CSRF token support. Enable/verify: find base `ApplicationController`, look for directive:

``` ruby
class ApplicationController < ActionController::Base
  protect_from_forgery
```

Syntax allows exceptions. Useful for APIs or other reasons, but review and include consciously. Below, Rails ProjectController provides no CSRF protection for show method.

``` ruby
class ProjectController < ApplicationController
  protect_from_forgery except: :show
```

By default Rails provides no CSRF protection for any HTTP `GET` request.

**Note:** token authentication only → no CSRF protection needed in controllers like this. Cookie-based authentication on some paths → protection still required there.

General: OWASP Cross-Site Request Forgery (CSRF) page.

### Redirects and Forwards

Web apps often dynamically redirect users based on client-supplied data: client includes URL in request parameter; app redirects user to it.

Example:

`http://www.example.com/redirect?url=http://www.example_commerce_site.com/checkout`

Redirects user to `http://www.example.com/checkout`. Risk: org's trusted brand leveraged to phish users into visiting malicious site, here `badhacker.com`.

Example:

`http://www.example.com/redirect?url=http://badhacker.com`

Redirects that must stay within app: Rails' `url_from` validates destination against request host; provide fixed fallback:

```ruby
redirect_to url_from(params[:url]) || "/"
```

Never treat `URI.parse(value).path` as redirect validation: path of `https://trusted.example//evil.example/path` is `//evil.example/path`, protocol-relative external destination. Keep Rails' open-redirect protection enabled; specific destinations required → app-defined allowlist.

Matching user input against approved sites/TLDs via regular expression unavoidable: use library such as `URI.parse()` to get host, match host against regex patterns. Regexes must at minimum have anchors, else attacker more likely bypasses validation.

Example:

``` ruby
require 'uri'
host = URI.parse("#{params[:url]}").host
# this can be vulnerable to javascript://trusted.com/%0Aalert(0)
# so check .scheme and .port too
validation_routine(host) if host
def validation_routine(host)
  # Validation routine where we use  \A and \z as anchors *not* ^ and $
  # you could also check the host value against an allowlist
end
```

Blind redirecting to user input parameter can also lead to XSS.

Example code:

``` ruby
redirect_to params[:to]
```

Gives URL:

`http://example.com/redirect?to[status]=200&to[protocol]=javascript:alert(0)//`

Fix: restrict to specific Top-Level Domains (TLDs), statically define specific sites, or map key to value.

Example code:

``` ruby
ACCEPTABLE_URLS = {
  'our_app_1' => "https://www.example_commerce_site.com/checkout",
  'our_app_2' => "https://www.example_user_site.com/change_settings"
}
```

Gives URL:

`http://www.example.com/redirect?url=our_app_1`

Redirection handling code:

``` ruby
def redirect
  url = ACCEPTABLE_URLS["#{params[:url]}"]
  redirect_to url if url
end
```

See [unvalidated redirects and forwards](Unvalidated_Redirects_and_Forwards.md).

### Dynamic Render Paths

Controller actions/views dynamically pick view or partial via `render`. User input in template name → attacker can make app render arbitrary view, e.g. administrative page.

Take care using user input to determine view. If possible, no user input in view name or path.

### Cross Origin Resource Sharing

Sometimes resources shared with another domain, e.g. file-upload sending data via AJAX to another domain. Same-origin rules must be relaxed; modern HTML5-compliant browsers allow it with precautions.

Nonstandard HTTP construct (e.g. atypical Content-Type header):

Receiving site should list only allowed domains and set `Access-Control-Allow-Origin` header in both `OPTIONS` response and `POST` response. OPTIONS request sent first to determine whether receiving site allows requesting domain; then second request, `POST`. Header must be set again for transaction to succeed.

Standard HTTP constructs:

*Request sent; browser, on receiving response, inspects response headers to determine whether response can and should be processed.*

Allowlist in Rails:

**Gemfile:**

```bash
gem 'rack-cors', :require => 'rack/cors'
```

**config/application.rb:**

```ruby
module Sample
  class Application < Rails::Application
    config.middleware.use Rack::Cors do
      allow do
        origins 'someserver.example.com'
        resource %r{/users/\d+.json},
        :headers => ['Origin', 'Accept', 'Content-Type'],
        :methods => [:post, :get]
      end
    end
  end
end
```

### Security-related headers

Set header: access response.headers object as hash inside controller (often before/after_filter).

```ruby
response.headers['X-header-name'] = 'value'
```

Rails `default_headers` auto-applies supplied values; works for most headers almost always.

```ruby
ActionDispatch::Response.default_headers = {
  'X-Frame-Options' => 'SAMEORIGIN',
  'X-Content-Type-Options' => 'nosniff',
  'X-XSS-Protection' => '0'
}
```

Strict transport security = special case; set in environment file (e.g. `production.rb`)

```ruby
config.force_ssl = true
```

Not on edge Rails: library secure_headers gives same behavior plus content security policy abstraction; auto-applies logic per user agent → concise header set.

### Business Logic Bugs

Any app in any technology can have business logic errors causing security bugs; hard/impossible to detect with automated tools. Best prevention: code review, pair programming, unit tests.

### Attack Surface

Rails generally avoids open redirect and path traversal via /config/routes.rb, which dictates accessible URLs and handling controllers. Routes file = good place to scope attack surface.

Example:

```ruby
# this is an example of what NOT to do
match ':controller(/:action(/:id(.:format)))'
```

This route allows any public method on any controller to be called as action. Ensure users reach only intended controller methods, in intended way.

### Sensitive Files

Many Rails apps open source on public repositories. Public or corporate source control: some files must be excluded or carefully managed.

```text
/config/database.yml                 -  May contain production credentials.
/config/initializers/secret_token.rb -  Contains a secret used to hash session cookie.
/db/seeds.rb                         -  May contain seed data including bootstrap admin user.
/db/development.sqlite3              -  May contain real data.
```

### Encryption

Rails uses OS encryption. Never write own encryption.

Devise default bcrypt for password hashing: appropriate.

Typically config causes 10 stretches for production: `/config/initializers/devise.rb`

```ruby
config.stretches = Rails.env.test? ? 1 : 10
```

## Updating Rails and Having a Process for Updating Dependencies

Early 2013: critical Rails Framework vulnerabilities identified. Orgs behind current versions had harder updates and decisions, incl. patching framework source.

Ruby concern: most libraries (gems) not signed by authors → impossible to build Rails project from libraries of trusted sources. Good practice: audit gems used.

Have dependency update process. Example, three triggers:

- Every month/quarter: dependencies generally updated.
- Every week: important security vulnerabilities considered, may trigger update.
- EXCEPTIONAL conditions: emergency updates.

## Tools

brakeman: open source code analysis tool for Rails apps; finds many potential issues. Not comprehensive, but finds easily exposed issues. Review brakeman documentation of warning types to see potential Rails issues.

bearer: newer alternative; open source code security + privacy analysis for Ruby and JavaScript/TypeScript; finds broad range of OWASP Top 10 issues. Many configuration options; integrates into CI/CD.

Dependency-set security tracking: automated scanning from GitHub and GitLab.

Gauntlt: security testing tool built on cucumber, gherkin syntax defines attack files.

Launched May 2013, similar to brakeman: dawnscanner rubygem, static analyzer for Rails, Sinatra, Padrino web apps. Version 1.6.6 has more than 235 ruby specific CVE security checks.

## References

- Securing Rails Applications
- Rails security policy
