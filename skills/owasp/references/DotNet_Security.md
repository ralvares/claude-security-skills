# DotNet Security Cheat Sheet

## Introduction

Quick basic .NET security tips for developers.

### The .NET Framework

.NET Framework = Microsoft's principal enterprise development platform. Supporting API for ASP.NET, Windows Desktop applications, Windows Communication Foundation services, SharePoint, Visual Studio Tools for Office, other technologies.

Collection of APIs for advanced type system, data management, graphics, networking, file operations, etc. - covers vast majority of enterprise application requirements in Microsoft ecosystem. Nearly ubiquitous library; strongly named and versioned at assembly level.

### Updating the Framework

Microsoft updates .NET Framework via Windows Update service; developers normally need no separate Framework updates. Access Windows Update or Windows Update program on Windows computer.

Individual frameworks updatable via NuGet. Visual Studio prompts for updates; build into lifecycle.

Third-party libraries need separate updates; not all use NuGet. ELMAH, for instance, needs separate update effort.

### Security Announcements

Get security notifications via "Watch" button at repositories:

- .NET Core Security Announcements
- ASP.NET Core & Entity Framework Core Security Announcements

## .NET General Guidance

General guidance for all .NET applications, incl. ASP.NET, WPF, WinForms, others.

OWASP Top 10 = most prevalent, dangerous web security threats; reviewed every few years, updated with latest threat data. This section based on it. Secure web app starting at top threat A1 below, working down: spends security time most effectively, covers top threats first. After Top 10, generally assess other threats or get professional Penetration Test.

### A01 Broken Access Control

#### Weak Account management

Send cookies with HttpOnly flag set, preventing client side scripts accessing cookie:

```csharp
CookieHttpOnly = true,
```

Reduce window for session theft: reduce session timeout, remove sliding expiration:

Sliding expiration use depends on app threat model. `SlidingExpiration` `false` enforces absolute session lifetime, limiting stolen session reuse, at cost of reduced usability for long-lived interactive sessions. Some apps may prefer sliding expiration (`true`) for user experience: keeps session alive while user active. Convenience raises risk if session compromised.

```csharp
ExpireTimeSpan = TimeSpan.FromMinutes(60),
SlidingExpiration = false
```

Full startup code snippet example available (SecurityEssentials Startup.Auth.cs).

Send cookies over HTTPS in production. Enforce in config transforms:

```xml
<httpCookies requireSSL="true" />
<authentication>
    <forms requireSSL="true" />
</authentication>
```

Protect LogOn, Registration, password reset methods vs brute force by throttling requests (see code below). Consider ReCaptcha too.

```csharp
[HttpPost]
[AllowAnonymous]
[ValidateAntiForgeryToken]
[AllowXRequestsEveryXSecondsAttribute(Name = "LogOn",
Message = "You have performed this action more than {x} times in the last {n} seconds.",
Requests = 3, Seconds = 60)]
public async Task<ActionResult> LogOn(LogOnViewModel model, string returnUrl)
```

DO NOT: Roll your own authentication or session management. Use .NET's.

DO NOT: Reveal whether account exists on LogOn, Registration or Password reset. Say e.g. 'Either the username or password was incorrect', or 'If this account exists then a reset token will be sent to the registered email address'. Protects vs account enumeration.

User feedback must be identical whether or not account exists, in content and behavior. E.g., response taking 50% longer when account real → membership information guessable/testable.

#### Missing function-level access control

DO: Authorize users on all externally facing endpoints. .NET framework has many authorization ways; use at method level:

```csharp
[Authorize(Roles = "Admin")]
[HttpGet]
public ActionResult Index(int page = 1)
```

or better, at controller level:

```csharp
[Authorize]
public class UserController
```

Can also check roles in code using .net identity features: `System.Web.Security.Roles.IsUserInRole(userName, roleName)`

More: [Authorization Cheat Sheet](Authorization.md) and
[Authorization Testing Automation Cheat Sheet](Authorization_Testing_Automation.md).

#### Insecure Direct object references

Resource (object) accessed by reference (below: `id`): ensure user is intended to access that resource.

```csharp
// Insecure
public ActionResult Edit(int id)
{
  var user = _context.Users.FirstOrDefault(e => e.Id == id);
  return View("Details", new UserViewModel(user);
}

// Secure
public ActionResult Edit(int id)
{
  var user = _context.Users.FirstOrDefault(e => e.Id == id);
  // Establish user has right to edit the details
  if (user.Id != _userIdentity.GetUserId())
  {
        HandleErrorInfo error = new HandleErrorInfo(
            new Exception("INFO: You do not have permission to edit these details"));
        return View("Error", error);
  }
  return View("Edit", new UserViewModel(user);
}
```

More: [Insecure Direct Object Reference Prevention Cheat Sheet](Insecure_Direct_Object_Reference_Prevention.md).

### A02 Cryptographic Failures

#### General cryptography guidance

- **Never, ever write your own cryptographic functions.**
- Wherever possible avoid writing any cryptographic code. Use pre-existing secrets management solutions or cloud provider's. See [OWASP Secrets Management Cheat Sheet](Secrets_Management.md).
- If no pre-existing secrets management solution usable, use trusted well known implementation library rather than libraries built into .NET; too easy to make cryptographic errors with them.
- Ensure app/protocol easily supports future cryptographic algorithm change.

#### Hashing

DO: Use strong hashing algorithm.

- .NET (Framework and Core): strongest hashing algorithm for general hashing requirements: System.Security.Cryptography.SHA512.
- New ASP.NET Core apps: use ASP.NET Core Identity and its `PasswordHasher<TUser>` for password storage. Microsoft advises against calling `KeyDerivation.Pbkdf2` directly for this; low-level primitive for integration with existing cryptographic systems.
- Don't use general-purpose hashes such as SHA-512 directly for password storage.
- See [Password Storage Cheat Sheet](Password_Storage.md).

#### Passwords

DO: Follow [Authentication Cheat Sheet](Authentication.md#implement-proper-password-strength-controls) for password length + breached-password screening. Allow long passphrases without mandatory character-composition rules.

#### Encryption

DO: Use strong encryption algorithm such as AES-256 where personally identifiable data must be restored to original format.

DO: Protect encryption keys more than any other asset. Storing keys at rest: [Key Management Cheat Sheet](Key_Management.md#storage).

DO: Use TLS 1.2+ for entire site. Get free certificate (LetsEncrypt.org); automate renewals.

DO NOT: Allow SSL; now obsolete.

DO: Strong TLS policy (see SSL Best Practices), TLS 1.2+ wherever possible. Check configuration with SSL Test or TestSSL.

More: [Transport Layer Security Cheat Sheet](Transport_Layer_Security.md).

DO: Ensure headers don't disclose app information. See HttpHeaders.cs, Dionach StripHeaders; disable via `web.config` or Startup.cs.

e.g Web.config

```xml
<system.web>
    <httpRuntime enableVersionHeader="false"/>
</system.web>
<system.webServer>
    <security>
        <requestFiltering removeServerHeader="true" />
    </security>
    <httpProtocol>
        <customHeaders>
            <add name="X-Content-Type-Options" value="nosniff" />
            <add name="X-Frame-Options" value="DENY" />
            <add name="X-Permitted-Cross-Domain-Policies" value="master-only"/>
            <add name="X-XSS-Protection" value="0"/>
            <remove name="X-Powered-By"/>
        </customHeaders>
    </httpProtocol>
</system.webServer>
```

e.g Startup.cs

``` csharp
app.UseHsts(hsts => hsts.MaxAge(365).IncludeSubdomains());
app.UseXContentTypeOptions();
app.UseReferrerPolicy(opts => opts.NoReferrer());
app.UseXXssProtection(options => options.FilterDisabled());
app.UseXfo(options => options.Deny());

app.UseCsp(opts => opts
 .BlockAllMixedContent()
 .StyleSources(s => s.Self())
 .StyleSources(s => s.UnsafeInline())
 .FontSources(s => s.Self())
 .FormActions(s => s.Self())
 .FrameAncestors(s => s.Self())
 .ImageSources(s => s.Self())
 .ScriptSources(s => s.Self())
 );
```

More: OWASP Secure Headers Project.

#### Encryption for storage

- Use Windows Data Protection API (DPAPI) for secure local storage of sensitive data.
- Where DPAPI unusable, follow algorithm guidance in [OWASP Cryptographic Storage Cheat Sheet](Cryptographic_Storage.md#algorithms).

Snippet: AES-GCM encryption/decryption of data. Strongly recommended: cryptography expert reviews final design + code; even trivial error severely weakens encryption.

Code based on example at scottbrady91.com (c-sharp/aes-gcm-dotnet).

Constraints/pitfalls:

- Ignores key rotation/management (whole topic itself).
- Use different nonce for every encryption operation, even with same key.
- Key must be stored securely.

<details>
  <summary>Click here to view the "AES-GCM symmetric encryption" code snippet.</summary>

```csharp
// Code based on example from here:
// https://www.scottbrady91.com/c-sharp/aes-gcm-dotnet

public class AesGcmSimpleTest
{
    public static void Main()
    {

        // Key of 32 bytes / 256 bits for AES
        var key = new byte[32];
        RandomNumberGenerator.Fill(key);

        // MaxSize = 12 bytes / 96 bits and this size should always be used.
        var nonce = new byte[AesGcm.NonceByteSizes.MaxSize];
        RandomNumberGenerator.Fill(nonce);

        // Tag for authenticated encryption
        var tag = new byte[AesGcm.TagByteSizes.MaxSize];

        var message = "This message to be encrypted";
        Console.WriteLine(message);

        // Encrypt the message
        var cipherText = AesGcmSimple.Encrypt(message, nonce, out tag, key);
        Console.WriteLine(Convert.ToBase64String(cipherText));

        // Decrypt the message
        var message2 = AesGcmSimple.Decrypt(cipherText, nonce, tag, key);
        Console.WriteLine(message2);


    }
}


public static class AesGcmSimple
{

    public static byte[] Encrypt(string plaintext, byte[] nonce, out byte[] tag, byte[] key)
    {
        using(var aes = new AesGcm(key))
        {
            // Tag for authenticated encryption
            tag = new byte[AesGcm.TagByteSizes.MaxSize];

            // Create a byte array from the message to encrypt
            var plaintextBytes = Encoding.UTF8.GetBytes(plaintext);

            // Ciphertext will be same length in bytes as plaintext
            var ciphertext = new byte[plaintextBytes.Length];

            // perform the actual encryption
            aes.Encrypt(nonce, plaintextBytes, ciphertext, tag);
            return ciphertext;
        }
    }

    public static string Decrypt(byte[] ciphertext, byte[] nonce, byte[] tag, byte[] key)
    {
        using(var aes = new AesGcm(key))
        {
            // Plaintext will be same length in bytes as Ciphertext
            var plaintextBytes = new byte[ciphertext.Length];

            // perform the actual decryption
            aes.Decrypt(nonce, ciphertext, tag, plaintextBytes);

            return Encoding.UTF8.GetString(plaintextBytes);
        }
    }
}

```

</details>

#### Encryption for transmission

- Again follow algorithm guidance in [OWASP Cryptographic Storage Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Cryptographic_Storage_Cheat_Sheet.html#algorithms).

Snippet: Elliptic Curve/Diffie-Hellman (ECDH) with AES-GCM to encrypt/decrypt data between two sides without transferring symmetric key. Sides exchange public keys; ECDH generates shared secret for symmetric encryption.

Again strongly recommended: cryptography expert reviews final design + code; even trivial error severely weakens encryption.

Sample relies on `AesGcmSimple` class from [previous section](#encryption-for-storage).

Constraints/pitfalls:

- Ignores key rotation/management (whole topic itself).
- Code deliberately enforces new nonce per encryption operation; must be managed as separate data item alongside ciphertext.
- Private keys must be stored securely.
- No validation of public keys before use.
- No verification of authenticity between two sides.

<details>
  <summary>Click here to view the "ECDH asymmetric encryption" code snippet.</summary>

```csharp
public class ECDHSimpleTest
{
    public static void Main()
    {
        // Generate ECC key pair for Alice
        var alice = new ECDHSimple();
        byte[] alicePublicKey = alice.PublicKey;

        // Generate ECC key pair for Bob
        var bob = new ECDHSimple();
        byte[] bobPublicKey = bob.PublicKey;

        string plaintext = "Hello, Bob! How are you?";
        Console.WriteLine("Secret being sent from Alice to Bob: " + plaintext);

        // Note that a new nonce is generated with every encryption operation in line with
        // in line with the AES GCM security
        byte[] tag;
        byte[] nonce;
        var cipherText = alice.Encrypt(bobPublicKey, plaintext, out nonce, out tag);
        Console.WriteLine("Ciphertext, nonce, and tag being sent from Alice to Bob: " + Convert.ToBase64String(cipherText) + " " + Convert.ToBase64String(nonce) + " " + Convert.ToBase64String(tag));

        var decrypted = bob.Decrypt(alicePublicKey, cipherText, nonce, tag);
        Console.WriteLine("Secret received by Bob from Alice: " + decrypted);

        Console.WriteLine();

        string plaintext2 = "Hello, Alice! I'm good, how are you?";
        Console.WriteLine("Secret being sent from Bob to Alice: " + plaintext2);

        byte[] tag2;
        byte[] nonce2;
        var cipherText2 = bob.Encrypt(alicePublicKey, plaintext2, out nonce2, out tag2);
        Console.WriteLine("Ciphertext, nonce, and tag being sent from Bob to Alice: " + Convert.ToBase64String(cipherText2) + " " + Convert.ToBase64String(nonce2) + " " + Convert.ToBase64String(tag2));

        var decrypted2 = alice.Decrypt(bobPublicKey, cipherText2, nonce2, tag2);
        Console.WriteLine("Secret received by Alice from Bob: " + decrypted2);
    }
}


public class ECDHSimple
{

    private ECDiffieHellmanCng ecdh = new ECDiffieHellmanCng();

    public byte[] PublicKey
    {
        get
        {
            return ecdh.PublicKey.ToByteArray();
        }
    }

    public byte[] Encrypt(byte[] partnerPublicKey, string message, out byte[] nonce, out byte[] tag)
    {
        // Generate the AES Key and Nonce
        var aesKey = GenerateAESKey(partnerPublicKey);

        // Tag for authenticated encryption
        tag = new byte[AesGcm.TagByteSizes.MaxSize];

        // MaxSize = 12 bytes / 96 bits and this size should always be used.
        // A new nonce is generated with every encryption operation in line with
        // the AES GCM security model
        nonce = new byte[AesGcm.NonceByteSizes.MaxSize];
        RandomNumberGenerator.Fill(nonce);

        // return the encrypted value
        return AesGcmSimple.Encrypt(message, nonce, out tag, aesKey);
    }


    public string Decrypt(byte[] partnerPublicKey, byte[] ciphertext, byte[] nonce, byte[] tag)
    {
        // Generate the AES Key and Nonce
        var aesKey = GenerateAESKey(partnerPublicKey);

        // return the decrypted value
        return AesGcmSimple.Decrypt(ciphertext, nonce, tag, aesKey);
    }

    private byte[] GenerateAESKey(byte[] partnerPublicKey)
    {
        // Derive the secret based on this side's private key and the other side's public key
        byte[] secret = ecdh.DeriveKeyMaterial(CngKey.Import(partnerPublicKey, CngKeyBlobFormat.EccPublicBlob));

        byte[] aesKey = new byte[32]; // 256-bit AES key
        Array.Copy(secret, 0, aesKey, 0, 32); // Copy first 32 bytes as the key

        return aesKey;
    }
}
```

</details>

### A03 Injection

#### SQL Injection

DO: Object relational mapper (ORM) or stored procedures = most effective counter to SQL Injection.

DO: Parameterized queries where direct SQL query unavoidable. See
[Query Parameterization Cheat Sheet](Query_Parameterization.md).

E.g., Entity Framework:

```csharp
var sql = @"Update [User] SET FirstName = @FirstName WHERE Id = @Id";
context.Database.ExecuteSqlCommand(
    sql,
    new SqlParameter("@FirstName", firstname),
    new SqlParameter("@Id", id));
```

DO NOT: Concatenate strings anywhere in code and execute against database (*dynamic SQL*).

Note: Still possible accidentally with ORMs or Stored procedures; check everywhere. E.g.:

```csharp
string sql = "SELECT * FROM Users WHERE UserName='" + txtUser.Text + "' AND Password='"
                + txtPassword.Text + "'";
context.Database.ExecuteSqlCommand(sql); // SQL Injection vulnerability!
```

DO: Least Privilege - connect to database with account having minimum permissions needed, not database administrator account.

#### OS Injection

General OS Injection guidance: [OS Command Injection Defense Cheat Sheet](OS_Command_Injection_Defense.md).

DO: Use System.Diagnostics.Process.Start to call underlying OS functions.

e.g

``` csharp
var process = new System.Diagnostics.Process();
var startInfo = new System.Diagnostics.ProcessStartInfo();
startInfo.FileName = "validatedCommand";
startInfo.Arguments = "validatedArg1 validatedArg2 validatedArg3";
process.StartInfo = startInfo;
process.Start();
```

DO NOT: Assume this mechanism protects vs malicious input breaking out of one argument and tampering with another argument to the process. Still possible.

DO: Allowlist validation on all user supplied input wherever possible. Input validation prevents improperly formed data entering information system. See [Input Validation Cheat Sheet](Input_Validation.md).

e.g Validating user input using IPAddress.TryParse Method

``` csharp
//User input
string ipAddress = "127.0.0.1";

//check to make sure an ip address was provided
if (!string.IsNullOrEmpty(ipAddress))
{
 // Create an instance of IPAddress for the specified address string (in
 // dotted-quad, or colon-hexadecimal notation).
 if (IPAddress.TryParse(ipAddress, out var address))
 {
  // Display the address in standard notation.
  return address.ToString();
 }
 else
 {
  //ipAddress is not of type IPAddress
  ...
 }
    ...
}
```

DO: Accept only simple alphanumeric characters where possible.

DO NOT: Assume special characters sanitizable without removing them. Combinations of ```\```, ```'``` and ```@``` may unexpectedly impact sanitization attempts.

DO NOT: Rely on methods without security guarantee.

e.g. .NET Core 2.2 and greater and .NET 5 and greater support ProcessStartInfo.ArgumentList which performs some character escaping but object includes disclaimer it's not safe with untrusted input.

DO: Look at alternatives to passing raw untrusted arguments via command-line parameters, e.g. Base64 encoding (safely encodes special characters) then decode parameters in receiving application.

#### LDAP injection

Almost any characters usable in Distinguished Names; some must be escaped with backslash `\` escape character.
Table of characters to escape for Active Directory: [LDAP Injection Prevention Cheat Sheet](LDAP_Injection_Prevention.md).

Note: space character must be escaped only if leading or trailing character in component name, such as Common Name.
Embedded spaces not escaped.

More: [LDAP Injection Prevention Cheat Sheet](LDAP_Injection_Prevention.md).

### A04 Insecure Design

Insecure design = security failures in application/system design; other OWASP Top 10 items refer to implementation failures. Secure design not tied to specific technology/language → out of scope here. See [Secure Product Design Cheat Sheet](Secure_Product_Design.md).

### A05 Security Misconfiguration

#### Debug and Stack Trace

Ensure debug and trace off in production. Enforce via web.config transforms:

```xml
<compilation xdt:Transform="RemoveAttributes(debug)" />
<trace enabled="false" xdt:Transform="Replace"/>
```

DO NOT: Use default passwords

DO: Redirect HTTP requests to HTTPS:

E.g, Global.asax.cs:

```csharp
protected void Application_BeginRequest()
{
    #if !DEBUG
    // SECURE: Ensure any request is returned over SSL/TLS in production
    if (!Request.IsLocal && !Context.Request.IsSecureConnection) {
        var redirect = Context.Request.Url.ToString()
                        .ToLower(CultureInfo.CurrentCulture)
                        .Replace("http:", "https:");
        Response.Redirect(redirect);
    }
    #endif
}
```

E.g., Startup.cs in `Configure()`:

``` csharp
  app.UseHttpsRedirection();
```

#### Cross-site request forgery

DO NOT: Send sensitive data without validating Anti-Forgery-Tokens (.NET / .NET Core).

DO: Send anti-forgery token with every POST/PUT request:

##### Using .NET Framework

```csharp
using (Html.BeginForm("LogOff", "Account", FormMethod.Post, new { id = "logoutForm",
                        @class = "pull-right" }))
{
    @Html.AntiForgeryToken()
    <ul class="nav nav-pills">
        <li role="presentation">
        Logged on as @User.Identity.Name
        </li>
        <li role="presentation">
        <a href="javascript:document.getElementById('logoutForm').submit()">Log off</a>
        </li>
    </ul>
}
```

Then validate at method or preferably controller level:

```csharp
[HttpPost]
[ValidateAntiForgeryToken]
public ActionResult LogOff()
```

Ensure tokens removed completely for invalidation on logout.

```csharp
/// <summary>
/// SECURE: Remove any remaining cookies including Anti-CSRF cookie
/// </summary>
public void RemoveAntiForgeryCookie(Controller controller)
{
    string[] allCookies = controller.Request.Cookies.AllKeys;
    foreach (string cookie in allCookies)
    {
        if (controller.Response.Cookies[cookie] != null &&
            cookie == "__RequestVerificationToken")
        {
            controller.Response.Cookies[cookie].Expires = DateTime.Now.AddDays(-1);
        }
    }
}
```

##### Using .NET Core 2.0 or later

Since .NET Core 2.0 antiforgery token can be automatically generated and verified.

With FormTagHelper enabled, form with `method="post"` and absent/empty `action` automatically gets antiforgery token unless token generation disabled. Doesn't apply to every form. Check tag helpers enabled in main `_ViewImports.cshtml`:

```csharp
@addTagHelper *, Microsoft.AspNetCore.Mvc.TagHelpers
```

`IHtmlHelper.BeginForm` generates antiforgery token by default for methods other than GET. Token generation must be paired with server-side validation, below.

Forms needing antiforgery protection without automatic token generation: add token explicitly:

```html
<form action="RelevantAction" >
@Html.AntiForgeryToken()
</form>
```

To automatically validate all requests other than GET, HEAD, OPTIONS and TRACE, add global action filter with AutoValidateAntiforgeryToken attribute in `Startup.cs`:

```csharp
services.AddMvc(options =>
{
    options.Filters.Add(new AutoValidateAntiforgeryTokenAttribute());
});
```

To disable validation for specific controller method, add IgnoreAntiforgeryToken attribute to controller method (MVC controllers) or parent class (Razor pages):

```csharp
[IgnoreAntiforgeryToken]
[HttpDelete]
public IActionResult Delete()
```

```csharp
[IgnoreAntiforgeryToken]
public class UnsafeModel : PageModel
```

To also validate token on GET, HEAD, OPTIONS and TRACE requests, add ValidateAntiforgeryToken attribute to controller method (MVC controllers) or parent class (Razor pages):

```csharp
[HttpGet]
[ValidateAntiforgeryToken]
public IActionResult DoSomethingDangerous()
```

```csharp
[HttpGet]
[ValidateAntiforgeryToken]
public class SafeModel : PageModel
```

Without global action filter, add AutoValidateAntiforgeryToken attribute to controller classes or razor page models:

```csharp
[AutoValidateAntiforgeryToken]
public class UserController
```

```csharp
[AutoValidateAntiforgeryToken]
public class SafeModel : PageModel
```

##### Using .Net Core or .NET Framework with AJAX

Attach anti-forgery token to AJAX requests.

jQuery in ASP.NET Core MVC view:

```javascript
@inject  Microsoft.AspNetCore.Antiforgery.IAntiforgery antiforgeryProvider
$.ajax(
{
    type: "POST",
    url: '@Url.Action("Action", "Controller")',
    contentType: "application/x-www-form-urlencoded; charset=utf-8",
    data: {
        id: id,
        '__RequestVerificationToken': '@antiforgeryProvider.GetAndStoreTokens(this.Context).RequestToken'
    }
})
```

.NET Framework: code snippets in Microsoft docs (anti-CSRF and AJAX).

More: [Cross-Site Request Forgery Prevention Cheat Sheet](Cross-Site_Request_Forgery_Prevention.md).

### A06 Vulnerable and Outdated Components

DO: Keep .NET framework updated with latest patches

DO: Keep NuGet packages up to date

DO: Run [OWASP Dependency Checker](Vulnerable_Dependency_Management.md#tools) against app as part of build; act on high or critical level vulnerabilities.

DO: Include SCA (software composition analysis) tools in CI/CD pipeline so new dependency vulnerabilities detected and acted upon.

### A07 Identification and Authentication Failures

DO: Use ASP.NET Core Identity.
Well configured by default: secure password hashes and individual salt. Uses PBKDF2 hashing function for passwords; random salt per user.

DO: Configure password length/composition per NIST password guidance: at least 15 characters when passwords usable without multifactor authentication (MFA), at least eight when used only with MFA, no mandatory character-composition rules.

Example assumes passwords usable without MFA. Identity's default password validator measures length in UTF-16 code units; add Unicode code-point length validation to enforce NIST minimum. Settings also don't implement breached-password screening; follow [Authentication Cheat Sheet](Authentication.md#implement-proper-password-strength-controls) for complete policy.

``` csharp
//Startup.cs
services.Configure<IdentityOptions>(options =>
{
 // Password settings
 options.Password.RequireDigit = false;
 options.Password.RequiredLength = 15;
 options.Password.RequireNonAlphanumeric = false;
 options.Password.RequireUppercase = false;
 options.Password.RequireLowercase = false;
 options.Password.RequiredUniqueChars = 1;

 options.Lockout.DefaultLockoutTimeSpan = TimeSpan.FromMinutes(30);
 options.Lockout.MaxFailedAccessAttempts = 3;

 options.SignIn.RequireConfirmedEmail = true;

 options.User.RequireUniqueEmail = true;
});
```

DO: Set cookie policy

e.g

``` csharp
//Startup.cs
services.ConfigureApplicationCookie(options =>
{
 options.Cookie.HttpOnly = true;
 options.ExpireTimeSpan = TimeSpan.FromMinutes(60);
 // See the discussion in A01 for trade-offs on using sliding expiration.
 options.SlidingExpiration = false;
});
```

### A08 Software and Data Integrity Failures

DO: Digitally sign assemblies and executable files

DO: Use Nuget package signing

DO: Review code/configuration changes to avoid introducing malicious code or dependencies

DO NOT: Send unsigned or unencrypted serialized objects over network

DO: Integrity checks or digital signature validation on serialized objects received from network

DO NOT: Use BinaryFormatter type; dangerous and not recommended for data processing.
.NET in-box serializers handling untrusted data safely:

- XmlSerializer and DataContractSerializer: object graphs to/from XML. Don't confuse DataContractSerializer with NetDataContractSerializer.
- BinaryReader and BinaryWriter: primitive data types (such as Int32, Double, Boolean, and String) in binary format.
- System.Text.Json APIs: object graphs to JSON.

### A09 Security Logging and Monitoring Failures

DO: Log all login, access control, server-side input validation failures with sufficient user context to identify suspicious/malicious accounts.

DO: Establish effective monitoring + alerting for timely detection/response to suspicious activities.

DO NOT: Log generic error messages such as: ```csharp Log.Error("Error was thrown");```. Log stack trace, error message, user ID causing error.

DO NOT: Log sensitive data such as user's passwords.

#### Logging

What to log + more: [Logging Cheat Sheet](Logging.md).

.NET Core has LoggerFactory, in Microsoft.Extensions.Logging. ILogger docs in Microsoft docs.

Log all errors from `Startup.cs` so any thrown error is logged:

``` csharp
public void Configure(IApplicationBuilder app, IHostingEnvironment env)
{
    if (env.IsDevelopment())
    {
        _isDevelopment = true;
        app.UseDeveloperExceptionPage();
    }

    //Log all errors in the application
    app.UseExceptionHandler(errorApp =>
    {
        errorApp.Run(async context =>
        {
            var errorFeature = context.Features.Get<IExceptionHandlerFeature>();
            var exception = errorFeature.Error;

            Log.Error(String.Format("Stacktrace of error: {0}",exception.StackTrace.ToString()));
        });
    });

    app.UseAuthentication();
    app.UseMvc();
 }
}
```

Inject into class constructor: simpler unit tests. Recommended if instances created via dependency injection (e.g. MVC controllers). Example logs unsuccessful login attempts and sets [`lockoutOnFailure: true`](https://learn.microsoft.com/en-us/aspnet/core/security/authentication/identity-configuration?view=aspnetcore-10.0#lockout) so failed password attempts count toward configured lockout threshold for accounts with lockout enabled.

``` csharp
public class AccountsController : Controller
{
        private ILogger _Logger;

        public AccountsController(ILogger logger)
        {
            _Logger = logger;
        }

        [HttpPost]
        [AllowAnonymous]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Login(LoginViewModel model)
        {
            if (ModelState.IsValid)
            {
                var result = await _signInManager.PasswordSignInAsync(model.Email, model.Password, model.RememberMe, lockoutOnFailure: true);
                if (result.Succeeded)
                {
                    //Log all successful log in attempts
                    Log.Information(String.Format("User: {0}, Successfully Logged in", model.Email));
                    //Code for successful login
                    //...
                }
                else
                {
                    //Log all incorrect log in attempts
                    Log.Information(String.Format("User: {0}, Incorrect Password", model.Email));
                }
             }
            ...
        }
```

#### Monitoring

Monitoring validates performance + health of running system via key performance indicators.

.NET monitoring option: Application Insights.

More on Logging and Monitoring: Microsoft code-with-engineering-playbook observability.

### A10 Server-Side Request Forgery (SSRF)

DO: Validate + sanitize all user input before using it to make request

DO: Use allowlist of allowed protocols and domains

DO: Use `IPAddress.TryParse()` and `Uri.CheckHostName()` to ensure IP addresses and domain names valid

DO NOT: Follow HTTP redirects

DO NOT: Forward raw HTTP responses to user

More: [Server-Side Request Forgery Prevention Cheat Sheet](Server_Side_Request_Forgery_Prevention.md).

### OWASP 2013 & 2017

Vulnerabilities in 2013 or 2017 OWASP Top 10 but not 2021 list. Still relevant; dropped from 2021 because less prevalent.

#### A04:2017 XML External Entities (XXE)

XXE: XML parser improperly processes user input containing external entity declarations in doctype of XML payload.

Microsoft article discusses most common XML Processing Options for .NET.

Preventing XXE and other XML Denial of Service attacks: [XXE cheat sheet](XML_External_Entity_Prevention.md#net).

#### A07:2017 Cross-Site Scripting (XSS)

DO NOT: Trust any user-sent data. Prefer allowlists (always safe) over denylists.

MVC3 encodes all HTML content. To properly encode all content whether HTML,
JavaScript, CSS, LDAP, etc., use Microsoft AntiXSS library:

`Install-Package AntiXSS`

Then set in config:

```xml
<system.web>
<httpRuntime targetFramework="4.5"
enableVersionHeader="false"
encoderType="Microsoft.Security.Application.AntiXssEncoder, AntiXssLibrary"
maxRequestLength="4096" />
```

DO NOT: Use `[AllowHTML]` attribute or helper class `@Html.Raw` unless absolutely sure content written to browser is safe and properly escaped.

DO: Enable [Content Security Policy](Content_Security_Policy.md#context). Prevents pages accessing assets they shouldn't (e.g. malicious scripts):

```xml
<system.webServer>
    <httpProtocol>
        <customHeaders>
            <add name="Content-Security-Policy"
                value="default-src 'none'; style-src 'self'; img-src 'self';
                font-src 'self'; script-src 'self'" />
```

More: [Cross Site Scripting Prevention Cheat Sheet](Cross_Site_Scripting_Prevention.md).

#### A08:2017 Insecure Deserialization

DO NOT: Accept Serialized Objects from Untrusted Sources

DO: Validate User Input

Malicious users can use objects like cookies to insert malicious information changing user roles. Sometimes hackers elevate to administrator rights using pre-existing or cached password hash from previous session.

DO: Prevent Deserialization of Domain Objects

DO: Run Deserialization Code with Limited Access Permissions
If deserialized hostile object tries to initiate system process or access resource within server or host OS, access denied and permission flag raised so system administrator learns of anomalous activity on server.

More: [Deserialization Cheat Sheet](Deserialization.md#net-csharp).

#### A10:2013 Unvalidated redirects and forwards

Protection introduced in MVC 3 template. Code:

```csharp
public async Task<ActionResult> LogOn(LogOnViewModel model, string returnUrl)
{
    if (ModelState.IsValid)
    {
        var logonResult = await _userManager.TryLogOnAsync(model.UserName, model.Password);
        if (logonResult.Success)
        {
            await _userManager.LogOnAsync(logonResult.UserName, model.RememberMe);  
            return RedirectToLocal(returnUrl);
...
```

```csharp
private ActionResult RedirectToLocal(string returnUrl)
{
    if (Url.IsLocalUrl(returnUrl))
    {
        return Redirect(returnUrl);
    }
    else
    {
        return RedirectToAction("Landing", "Account");
    }
}
```

### Other advice

- Protect vs Clickjacking and Man-in-the-Middle capturing initial Non-TLS request: set `X-Frame-Options` and `Strict-Transport-Security` (HSTS) headers. Details: SecurityEssentials HttpHeaders.cs
- Protect vs man-in-the-middle for user who never visited site before: register for HSTS preload
- Maintain security testing/analysis on Web API services. Hidden inside MVC sites; public parts of site attackers will find. All MVC guidance and much WCF guidance applies to Web API too.
- Also see [Unvalidated Redirects and Forwards Cheat Sheet](Unvalidated_Redirects_and_Forwards.md).

#### Sample project

All above + code samples in sample MVC5 application with enhanced security baseline: Security Essentials Baseline project.

## Guidance for specific topics

Guidance for specific .NET topics.

### Configuration and Deployment

- Lock down config files.
    - Remove all unused configuration.
    - **Do not store secrets in source-controlled config files (`web.config`, `appsettings.json`).** Keep secrets out of configuration file entirely.
        - Modern .NET (Core / 6+ / 8+): use User Secrets for development; managed secret store (Azure Key Vault, AWS Secrets Manager, HashiCorp Vault) via Managed Identity / Workload Identity for production.
        - Legacy .NET Framework (4.7.1+): use Configuration Builders (e.g. `Microsoft.Configuration.ConfigurationBuilders.Azure`, `...Environment`) to inject secrets at runtime from secret store or environment variables, so they never appear in `web.config`.
        - Last resort only — legacy applications that cannot be modified — encrypt sensitive `web.config` sections using `aspnet_regiis -pe` (command line help). Only protects file at rest on server; application still loads plaintext into memory.
- ClickOnce applications: upgrade .NET Framework to latest version to ensure TLS 1.2 or later support.

### Data Access

- Use Parameterized SQL commands for all data access, without exception.
- Don't use SqlCommand with string parameter made of concatenated SQL String.
- List allowable values from user. Use enums, TryParse or lookup values to assure data from user as expected.
    - Enums still vulnerable to unexpected values: .NET validates only successful cast to underlying data type, integer by default. Enum.IsDefined validates input value within list of defined constants.
- Least privilege for Database User in database of choice. Database user accesses only items sensible for use case.
- Entity Framework = very effective [SQL injection](SQL_Injection_Prevention.md) prevention mechanism. **Building own ad hoc queries in Entity Framework just as susceptible to SQLi as plain SQL query**.
- SQL Server: prefer integrated authentication over SQL authentication.
- Use Always Encrypted where possible for sensitive data (SQL Server 2016+ and Azure SQL)

## ASP NET Web Forms Guidance

ASP.NET Web Forms = original browser-based application development API for .NET Framework; still most common enterprise platform for web application development.

- Always use HTTPS.
- Enable requireSSL on cookies and form elements and HttpOnly on cookies in web.config.
- Implement customErrors.
- Ensure tracing turned off.
- ViewState not always appropriate for web development, but can mitigate CSRF. For ViewState CSRF protection set ViewStateUserKey:

```csharp
protected override OnInit(EventArgs e) {
    base.OnInit(e);
    ViewStateUserKey = Session.SessionID;
}
```

Without Viewstate, see default main page of ASP.NET Web Forms default template for manual anti-CSRF token using double-submit cookie.

```csharp
private const string AntiXsrfTokenKey = "__AntiXsrfToken";
private const string AntiXsrfUserNameKey = "__AntiXsrfUserName";
private string _antiXsrfTokenValue;
protected void Page_Init(object sender, EventArgs e)
{
    // The code below helps to protect against XSRF attacks
    var requestCookie = Request.Cookies[AntiXsrfTokenKey];
    Guid requestCookieGuidValue;
    if (requestCookie != null && Guid.TryParse(requestCookie.Value, out requestCookieGuidValue))
    {
       // Use the Anti-XSRF token from the cookie
       _antiXsrfTokenValue = requestCookie.Value;
       Page.ViewStateUserKey = _antiXsrfTokenValue;
    }
    else
    {
       // Generate a new Anti-XSRF token and save to the cookie
       _antiXsrfTokenValue = Guid.NewGuid().ToString("N");
       Page.ViewStateUserKey = _antiXsrfTokenValue;
       var responseCookie = new HttpCookie(AntiXsrfTokenKey)
       {
          HttpOnly = true,
          Value = _antiXsrfTokenValue
       };
       if (FormsAuthentication.RequireSSL && Request.IsSecureConnection)
       {
          responseCookie.Secure = true;
       }
       Response.Cookies.Set(responseCookie);
    }
    Page.PreLoad += master_Page_PreLoad;
}
protected void master_Page_PreLoad(object sender, EventArgs e)
{
    if (!IsPostBack)
    {
       // Set Anti-XSRF token
       ViewState[AntiXsrfTokenKey] = Page.ViewStateUserKey;
       ViewState[AntiXsrfUserNameKey] = Context.User.Identity.Name ?? String.Empty;
    }
    else
    {
       // Validate the Anti-XSRF token
       if ((string)ViewState[AntiXsrfTokenKey] != _antiXsrfTokenValue ||
          (string)ViewState[AntiXsrfUserNameKey] != (Context.User.Identity.Name ?? String.Empty))
       {
          throw new InvalidOperationException("Validation of Anti-XSRF token failed.");
       }
    }
}
```

- Consider HSTS in IIS. Procedure in Microsoft docs.
- Recommended `web.config` setup handling HSTS among other things.

```xml
<?xml version="1.0" encoding="UTF-8"?>
 <configuration>
   <system.web>
     <httpRuntime enableVersionHeader="false"/>
   </system.web>
   <system.webServer>
     <security>
       <requestFiltering removeServerHeader="true" />
     </security>
     <staticContent>
       <clientCache cacheControlCustom="public"
            cacheControlMode="UseMaxAge"
            cacheControlMaxAge="1.00:00:00"
            setEtag="true" />
     </staticContent>
     <httpProtocol>
       <customHeaders>
         <add name="Content-Security-Policy"
            value="default-src 'none'; style-src 'self'; img-src 'self'; font-src 'self'" />
         <add name="X-Content-Type-Options" value="NOSNIFF" />
         <add name="X-Frame-Options" value="DENY" />
         <add name="X-Permitted-Cross-Domain-Policies" value="master-only"/>
         <add name="X-XSS-Protection" value="0"/>
         <remove name="X-Powered-By"/>
       </customHeaders>
     </httpProtocol>
     <rewrite>
       <rules>
         <rule name="Redirect to https">
           <match url="(.*)"/>
           <conditions>
             <add input="{HTTPS}" pattern="Off"/>
             <add input="{REQUEST_METHOD}" pattern="^get$|^head$" />
           </conditions>
           <action type="Redirect" url="https://{HTTP_HOST}/{R:1}" redirectType="Permanent"/>
         </rule>
       </rules>
       <outboundRules>
         <rule name="Add HSTS Header" enabled="true">
           <match serverVariable="RESPONSE_Strict_Transport_Security" pattern=".*" />
           <conditions>
             <add input="{HTTPS}" pattern="on" ignoreCase="true" />
           </conditions>
           <action type="Rewrite" value="max-age=15768000" />
         </rule>
       </outboundRules>
     </rewrite>
   </system.webServer>
 </configuration>
```

- Remove version header by adding line to `Machine.config` file:

```xml
<httpRuntime enableVersionHeader="false" />
```

- Also remove Server header using HttpContext Class in code.

```csharp
HttpContext.Current.Response.Headers.Remove("Server");
```

### HTTP validation and encoding

- Don't disable validateRequest in `web.config` or page setup. Enables limited XSS protection in ASP.NET; leave intact, partial XSS prevention. Complete request validation recommended in addition to built-in protections.
- .NET Framework 4.5 includes AntiXssEncoder library, comprehensive input encoding library for XSS prevention. Use it.
- List allowable values whenever user input accepted.
- Validate URI format with Uri.IsWellFormedUriString.

### Forms authentication

- Use cookies for persistence when possible. `Cookieless` auth defaults to UseDeviceProfile.
- Don't trust request URI for session persistence or authorization; easily faked.
- Reduce Forms Authentication timeout from default *20 minutes* to shortest period appropriate for app. If slidingExpiration used, timeout resets after each request, active users unaffected.
- No HTTPS: disable slidingExpiration. Consider disabling slidingExpiration even with HTTPS.
- Always implement proper access controls.
    - Compare user provided username with `User.Identity.Name`.
    - Check roles against `User.Identity.IsInRole`.
- Use ASP.NET Membership provider and role provider, but review password storage. Default storage hashes password with single iteration of SHA-1; rather weak. ASP.NET MVC4 template uses ASP.NET Identity instead of ASP.NET Membership; ASP.NET Identity uses PBKDF2 by default, better. See OWASP [Password Storage Cheat Sheet](Password_Storage.md).
- Explicitly authorize resource requests.
- Use role based authorization via `User.Identity.IsInRole`.

## XAML Guidance

- Work within Internet Zone security constraints.
- Use ClickOnce deployment. Enhanced permissions: permission elevation at runtime or trusted application deployment at install time.

## Windows Forms Guidance

- Use partial trust when possible; reduces attack surface. Manage list of permissions app must use and may use; request them declaratively at runtime.
- Use ClickOnce deployment. Enhanced permissions: permission elevation at runtime or trusted application deployment at install time.

## WCF Guidance

- HTTPS for RESTful requests regardless of HTTP method; choose methods per semantics. Keep sensitive values out of URLs (exposed in logs, browser history even with HTTPS). POST can carry sensitive form data in request body rather than URL, but POST alone provides no confidentiality or authorization.
- Avoid BasicHttpBinding; no default security configuration. Use WSHttpBinding.
- Use at least two security modes for binding. Message security: security provisions in headers. Transport security: SSL. TransportWithMessageCredential combines both.
- Test WCF implementation with fuzzer like ZAP.

## References

- Microsoft: Secure coding guidelines for .NET
- Microsoft: Introduction to Identity on ASP.NET Core
