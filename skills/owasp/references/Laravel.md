# Laravel Cheat Sheet

## Introduction

*Cheatsheet* gives security tips for developers building Laravel applications. Covers common vulnerabilities + how to keep apps secure.

Laravel has in-built security features, meant secure by default, but flexibility for complex use cases lets developers unfamiliar with internals use complex features insecurely. Guide helps avoid common pitfalls.

## The Basics

- Production app MUST NOT be in debug mode. Set `APP_DEBUG` environment variable to `false`:

```ini
APP_DEBUG=false
```

- Ensure application key generated. Laravel uses app key for symmetric encryption + SHA256 hashes such as cookie encryption, signed URLs, password reset tokens, session data encryption. Generate with `key:generate` Artisan command:

```bash
php artisan key:generate
```

- Ensure PHP configuration secure; see [PHP Configuration Cheat Sheet](PHP_Configuration.md).

- Set safe file/directory permissions. In general all Laravel directories max permission level `775`, non-executable files max `664`. Executable files such as Artisan or deployment scripts max `775`.

- Ensure application has no vulnerable dependencies.

## Cookie Security and Session Management

Laravel secure by default. If changing cookie/session configurations, ensure:

- Enable cookie encryption middleware if using `cookie` session store or storing any data clients must not read/tamper with. Generally enabled unless very specific use case requires disabling. Add `EncryptCookies` middleware to `web` middleware group in `App\Http\Kernel` class:

```php
/**
 * The application's route middleware groups.
 *
 * @var array
 */
protected $middlewareGroups = [
    'web' => [
        \App\Http\Middleware\EncryptCookies::class,
        ...
    ],
    ...
];
```

- Enable `HttpOnly` attribute on session cookies via `config/session.php` so cookies inaccessible from JavaScript:

```php
'http_only' => true,
```

- Unless cookies must be shared with subdomains, set `domain` to `null` in `config/session.php` to omit Domain attribute. Restricts where browser sends cookie to setting host; doesn't prevent sibling subdomains setting same-name parent-domain cookies. Stronger protection against these cookie collisions: use [`__Host-` session cookie](Session_Management.md#cookie-name-prefixes) with `Secure`, `Path=/`, no Domain attribute on supporting browsers:

```php
'domain' => null,
```

- Set `SameSite` cookie attribute to `lax` or `strict` in `config/session.php` to restrict cookies to first-party/same-site context:

```php
'same_site' => 'lax',
```

- HTTPS-only app: recommended set `secure` option in `config/session.php` to `true` against man-in-the-middle attacks. Mixed HTTP and HTTPS: set to `null` so secure attribute set automatically on HTTPS requests:

```php
'secure' => null,
```

- Keep session idle timeout low. [OWASP recommends](Session_Management.md) 2-5 minutes idle timeout for high value applications, 15-30 minutes for low risk. Configure in `config/session.php`:

```php
'lifetime' => 15,
```

More on cookie security + attributes above: Cookie Security Guide.

## Authentication

### Guards and Providers

Laravel authentication = "guards" + "providers". Guards define how users authenticated per request. Providers define how users retrieved from persistent storage.

Ships with `session` guard (state via session storage + cookies) and `token` guard for API tokens.

Providers: `eloquent` provider (Eloquent ORM) and `database` provider (database query builder).

Configure guards/providers in `config/auth.php`. Custom guards/providers supported.

### Starter Kits

First party starter kits with in-built authentication:

1. Laravel Breeze: simple, minimal implementation of all Laravel authentication features: login, registration, password reset, email verification, password confirmation.
2. Laravel Fortify: headless authentication backend with above features plus two-factor authentication.
3. Laravel Jetstream: starter kit providing UI on top of Laravel Fortify's authentication features.

Recommended: use one of these starter kits for robust, secure authentication.

### API Authentication Packages

1. Passport: OAuth2 authentication provider.
2. Sanctum: API token authentication provider.

Starter kits such as Fortify and Jetstream have in-built Sanctum support.

## Mass Assignment

[Mass assignment](Mass_Assignment.md): common vulnerability in modern web apps using ORM like Laravel's Eloquent ORM.

ORM pattern abused to modify data items user shouldn't normally modify.

Code:

```php
Route::any('/profile', function (Request $request) {
    $request->user()->forceFill($request->all())->save();

    $user = $request->user()->fresh();

    return response()->json(compact('user'));
})->middleware('auth');
```

Profile route lets logged in user change profile info.

But if users table has `is_admin` column, user shouldn't change it; code lets users change any column values for their row → mass assignment vulnerability.

Laravel has in-built protection by default. Ensure:

- Qualify allowed update parameters using `$request->only` or `$request->validated`, not `$request->all`.
- Don't unguard models or set `$guarded` to empty array: disables Laravel's in-built mass assignment protection.
- Avoid methods like `forceFill` or `forceCreate` that bypass protection. May use if passing validated array of values.

## SQL Injection

SQL Injection common in modern web apps: attackers provide malicious request input data to interfere with SQL queries. Covers prevention for Laravel specifically. Non-Laravel-specific info: [SQL Injection Prevention Cheatsheet](SQL_Injection_Prevention.md).

### Eloquent ORM SQL Injection Protection

By default Eloquent ORM protects against SQL injection by parameterizing queries, using SQL bindings. E.g.:

```php
use App\Models\User;

User::where('email', $email)->get();
```

Fires query:

```sql
select * from `users` where `email` = ?
```

Even if `$email` is untrusted user input, protected from SQL injection.

### Raw Query SQL Injection

Laravel offers raw query expressions + raw queries for complex or database specific queries not supported out of box.

Flexible, but always use SQL data bindings for such queries. Query:

```php
use Illuminate\Support\Facades\DB;
use App\Models\User;

User::whereRaw('email = "'.$request->input('email').'"')->get();
DB::table('users')->whereRaw('email = "'.$request->input('email').'"')->get();
```

Both lines execute same query, vulnerable to SQL injection: no SQL bindings for untrusted user input data.

Fires query:

```sql
select * from `users` where `email` = "value of email query parameter"
```

Always use SQL bindings for request data. Fix:

```php
use App\Models\User;

User::whereRaw('email = ?', [$request->input('email')])->get();
```

Named SQL bindings also work:

```php
use App\Models\User;

User::whereRaw('email = :email', ['email' => $request->input('email')])->get();
```

### Column Name SQL Injection

Never allow user input data to dictate column names referenced by queries.

Possibly vulnerable to SQL injection:

```php
use App\Models\User;

User::where($request->input('colname'), 'somedata')->get();
User::query()->orderBy($request->input('sortBy'))->get();
```

Though Laravel has in-built features such as wrapping column names against the above, some database engines (depending on versions/configurations) may still be vulnerable: databases don't support binding column names.

At least may result in mass assignment vulnerability instead of SQL injection: expected set of column values not validated, user free to use other columns.

Always validate user input here:

```php
use App\Models\User;

$request->validate(['sortBy' => 'in:price,updated_at']);
User::query()->orderBy($request->validated()['sortBy'])->get();
```

### Validation Rule SQL Injection

Certain validation rules accept database column names. Vulnerable to SQL injection same as column name SQL injection: construct queries similarly.

Possibly vulnerable:

```php
use Illuminate\Validation\Rule;

$request->validate([
    'id' => Rule::unique('users')->ignore($id, $request->input('colname'))
]);
```

Behind the scenes triggers query:

```php
use App\Models\User;

$colname = $request->input('colname');
User::where($colname, $request->input('id'))->where($colname, '<>', $id)->count();
```

Column name dictated by user input → similar to column name SQL injection.

## Cross Site Scripting (XSS)

XSS attacks = injection attacks: malicious scripts (e.g. JavaScript snippets) injected into trusted websites.

Laravel's Blade echo statements `{{ }}` HTML-escape ordinary string values using `htmlspecialchars`. Appropriate for HTML text + quoted ordinary text attributes; doesn't validate URL schemes or encode JavaScript/CSS contexts.

Unescaped syntax `{!! !!}` displays unescaped data. MUST NOT be used on untrusted data, else XSS.

Vulnerable Blade template example:

```blade
{!! request()->input('somedata') !!}
```

Render untrusted text inside ordinary HTML element:

```blade
<span>{{ request()->input('somedata') }}</span>
```

Data embedded in JavaScript: follow Laravel's `Js::from` guidance. URLs, CSS, other output contexts: follow [Cross Site Scripting Prevention Cheat Sheet](Cross_Site_Scripting_Prevention.md).

## Unrestricted File Uploads

Attackers upload malicious files to compromise web apps. Protection while building Laravel apps; more: [File Upload Cheatsheet](File_Upload.md).

### Always Validate File Type and Size

Validate allowed file types + impose max file size as one protection layer. Illustrative rule uses `max` to cap file size, not require exact size:

```php
$request->validate([
    'photo' => 'file|max:100|mimes:jpg,bmp,png'
]);
```

Storage DOS attacks: missing file size validations let attackers upload massive files, exhaust disk space → denial of service (DOS).

Remote code execution: attacker uploads malicious executable files (e.g. PHP files), then triggers code by visiting file URL (if public).

These validations alone don't prevent either attack. Laravel's `mimes` rule infers type from content; doesn't validate user-supplied extension or make file safe to execute. Generate stored filenames, keep uploads outside webroot or on separate host, ensure server can't execute uploaded files. Bound aggregate storage + upload frequency as well as individual file size. Remaining controls: [File Upload Cheat Sheet](File_Upload.md#file-upload-protection).

### Do Not Rely On User Input To Dictate Filenames or Path

User controlled data constructing file upload path may overwrite critical file or store file in bad location.

Code:

```php
Route::post('/upload', function (Request $request) {
    $request->file('file')->storeAs(auth()->id(), $request->input('filename'));

    return back();
});
```

Saves file to directory specific to user ID. Relying on `filename` user input is vulnerable: filename could be `../2/filename.pdf` → uploads to user ID 2's directory instead of current logged in user's.

Fix: use `basename` PHP function to strip directory info from `filename` input data:

```php
Route::post('/upload', function (Request $request) {
    $request->file('file')->storeAs(auth()->id(), basename($request->input('filename')));

    return back();
});
```

### Avoid Processing ZIP or XML Files If Possible

XML files expose app to wide variety of attacks: XXE, billion laughs, others. Processing ZIP files may expose to zip bomb DOS attacks.

See [XML Security Cheatsheet](XML_Security.md) and [File Upload Cheatsheet](File_Upload.md).

## Path Traversal

Path traversal: access files by manipulating request input data with `../` sequences and variations or absolute file paths.

Allowing users to download files by filename exposes this vulnerability if input data not stripped of directory info.

Code:

```php
Route::get('/download', function(Request $request) {
    return response()->download(storage_path('content/').$request->input('filename'));
});
```

Filename not stripped of directory info → malformed filename such as `../../.env` could expose app credentials.

As with unrestricted file uploads, use `basename` PHP function to strip directory info:

```php
Route::get('/download', function(Request $request) {
    return response()->download(storage_path('content/').basename($request->input('filename')));
});
```

## Open Redirection

Open Redirection not that dangerous itself but enables phishing attacks.

Code:

```php
Route::get('/redirect', function (Request $request) {
   return redirect($request->input('url'));
});
```

Redirects user to any external URL from user input. Attackers create seemingly safe URLs like `https://example.com/redirect?url=http://evil.com`, e.g. to spoof password reset emails and lead victims to expose credentials on attacker's website.

## Cross Site Request Forgery (CSRF)

CSRF: malicious web site, email, blog, instant message, or program causes user's web browser to perform unwanted action on trusted site while user authenticated.

Laravel provides CSRF protection out-of-the-box via `VerifyCSRFToken` middleware. Generally, with this middleware in `web` middleware group of `App\Http\Kernel` class, well protected:

```php
/**
 * The application's route middleware groups.
 *
 * @var array
 */
protected $middlewareGroups = [
    'web' => [
        ...
         \App\Http\Middleware\VerifyCsrfToken::class,
         ...
    ],
];
```

For all `POST` request forms use `@csrf` blade directive to generate hidden CSRF input token fields:

```html
<form method="POST" action="/profile">
    @csrf

    <!-- Equivalent to... -->
    <input type="hidden" name="_token" value="{{ csrf_token() }}" />
</form>
```

AJAX requests: set up X-CSRF-Token header.

Routes can be excluded from CSRF protection using `$except` variable in CSRF middleware class. Typically exclude only stateless routes (e.g. APIs, webhooks). Excluding other routes may cause CSRF vulnerabilities.

## Command Injection

Command Injection: executing shell commands constructed with unescaped user input data.

E.g. `whois` on user provided domain name:

```php
public function verifyDomain(Request $request)
{
    exec('whois '.$request->input('domain'));
}
```

Avoid invoking OS commands when PHP library can do the operation. Process required: keep executable fixed, pass arguments separately using Symfony Process with argument array. Validate domain against expected format before passing to `whois`; argument separation doesn't stop value being interpreted as command option. Remaining risk: [Argument Injection](OS_Command_Injection_Defense.md#argument-injection).

Don't use `escapeshellcmd()` as substitute for separating arguments: still permits extra arguments. Shell invocation unavoidable: `escapeshellarg()` escapes single argument, but still validate its meaning to called program.

## Other Injections

Object injection, eval code injection, extract variable hijacking: unserializing, evaluating, or using `extract` function on untrusted user input data.

Examples:

```php
unserialize($request->input('data'));
eval($request->input('data'));
extract($request->all());
```

Avoid passing untrusted input data to these dangerous functions.

## Rate Limiting

Built-in mechanisms protect routes from excessive requests/abuse.

Two main ways:

1. **`throttle` middleware** – built-in; apply directly to routes or route groups.
2. **`RateLimiter::for()`** – define custom rate limiting rules, more flexibility.

Main ways to apply:

### 1. Per Route

Limit single route with `throttle` middleware:

```php
Route::get('/profile', function () {
    return 'User profile';
})->middleware('throttle:10,1'); // 10 requests per minute
```

### 2. Per Route Group

Limit group of routes:

```php
Route::middleware('throttle:20,1')->group(function () {
    Route::get('/posts', fn () => 'Posts');
    Route::get('/comments', fn () => 'Comments');
});
```

### 3. Custom Rate Limiter

Define custom rate limiter in `RouteServiceProvider` using `RateLimiter::for()`:

```php
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Support\Facades\RateLimiter;

RateLimiter::for('custom-limit', function ($request) {
    return Limit::perMinute(5)->by($request->user()?->id ?: $request->ip());
});
```

Apply custom limiter to routes:

```php
Route::middleware('throttle:custom-limit')->get('/dashboard', fn () => 'Dashboard');
```

### 4. Global API / Web Rate Limiting

Apply global rate limiting to entire route groups like `api` or `web` by including `throttle` middleware in `Kernel.php` (`api` group rate-limited by default).

```php
protected $middlewareGroups = [
    'api' => [
        'throttle:60,1', // 60 requests per minute globally for API
        // ...
    ],

    'web' => [
        'throttle:30,1', // 30 requests per minute globally for web
        // ...
    ],
];
```

More: official Laravel documentation on rate limiting.

## Security Headers

Consider adding these security headers to web server or Laravel application middleware:

- X-Frame-Options
- X-Content-Type-Options
- Strict-Transport-Security (for HTTPS only applications)
- Content-Security-Policy

More: OWASP secure headers project.

## References

- Laravel Documentation on Authentication
- Laravel Documentation on Authorization
- Laravel Documentation on CSRF
- Laravel Documentation on Validation
