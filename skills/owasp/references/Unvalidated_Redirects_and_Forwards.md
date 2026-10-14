# Unvalidated Redirects and Forwards Cheat Sheet

## Introduction

Unvalidated redirects/forwards: app accepts untrusted input that redirects request to URL contained in that input. Attacker swaps URL for malicious site → phishing, credential theft.

Server name in modified link identical to original → phishing looks trustworthy. Also usable to craft URL that passes access control check, then forwards attacker to privileged functions normally inaccessible.

## Safe URL Redirects

Automatic redirect (no visitor action like clicking link), typical code:

Java

```java
response.sendRedirect("http://www.mysite.com");
```

PHP

```php
<?php
/* Redirect browser */
header("Location: http://www.mysite.com");
/* Exit to prevent the rest of the code from executing */
exit;
?>
```

ASP .NET

```csharp
Response.Redirect("~/folder/Login.aspx")
```

Rails

```ruby
redirect_to login_path
```

Rust actix web

```rust
  Ok(HttpResponse::Found()
        .insert_header((header::LOCATION, "https://mysite.com/"))
        .finish())
```

Above: URL declared explicitly in code, attacker can't manipulate.

## Dangerous URL Redirects

Unsafe redirect/forward code follows.

### Dangerous URL Redirect Example 1

Java takes URL from parameter `url` (GET or POST), redirects to it:

```java
response.sendRedirect(request.getParameter("url"));
```

PHP takes URL from query string (parameter `url`), redirects. Code after this `header()` call keeps executing → user who configures browser to ignore redirect may access rest of page.

```php
$redirect_url = $_GET['url'];
header("Location: " . $redirect_url);
```

Similar C\# .NET vulnerable code:

```csharp
string url = request.QueryString["url"];
Response.Redirect(url);
```

Rails:

```ruby
redirect_to params[:url]
```

Rust actix web

```rust
  Ok(HttpResponse::Found()
        .insert_header((header::LOCATION, query_string.path.as_str()))
        .finish())
```

Code vulnerable if no validation/extra method controls verify URL. Usable in phishing by redirecting users to malicious site.

W/o validation, attacker creates hyperlink redirecting users to unvalidated malicious site, e.g.:

```text
 http://example.com/example.php?url=http://malicious.example.com
```

User sees link to original trusted site (`example.com`), unaware of redirection.

### Dangerous URL Redirect Example 2

ASP .NET MVC 1 & 2 sites esp. vulnerable to open redirection. Fix: apply MVC 3.

LogOn action in ASP.NET MVC 2 app: after successful login, controller redirects to returnUrl; no validation on returnUrl.

ASP.NET MVC 2 LogOn action in `AccountController.cs` (see Microsoft Docs for context):

```csharp
[HttpPost]
 public ActionResult LogOn(LogOnModel model, string returnUrl)
 {
   if (ModelState.IsValid)
   {
     if (MembershipService.ValidateUser(model.UserName, model.Password))
     {
       FormsService.SignIn(model.UserName, model.RememberMe);
       if (!String.IsNullOrEmpty(returnUrl))
       {
         return Redirect(returnUrl);
       }
       else
       {
         return RedirectToAction("Index", "Home");
       }
     }
     else
     {
       ModelState.AddModelError("", "The user name or password provided is incorrect.");
     }
   }

   // If we got this far, something failed, redisplay form
   return View(model);
 }
```

### Dangerous Forward Example

When user input forwards requests between site parts, app must check user is authorized for URL, for functions it provides, and that it is an appropriate URL request.

W/o checks, crafted URL may pass access control check, then forward attacker to admin function normally not permitted.

Example:

```text
http://www.example.com/function.jsp?fwd=admin.jsp
```

Java servlet receives `GET` w/ URL parameter `fwd`, forwards to that address. Retrieves parameter value from request, completes server-side forward before responding to browser.

```java
public class ForwardServlet extends HttpServlet
{
  protected void doGet(HttpServletRequest request, HttpServletResponse response)
                    throws ServletException, IOException {
    String query = request.getQueryString();
    if (query.contains("fwd"))
    {
      String fwd = request.getParameter("fwd");
      try
      {
        request.getRequestDispatcher(fwd).forward(request, response);
      }
      catch (ServletException e)
      {
        e.printStackTrace();
      }
    }
  }
}
```

## Preventing Unvalidated Redirects and Forwards

- Avoid redirects/forwards.
- If used, don't allow URL as user input for destination.
- Where possible, user supplies short name, ID or token mapped server-side to full target URL.
    - Highest protection against URL tampering.
    - Beware enumeration vulnerability: user cycling IDs to find all redirect targets.
- If user input unavoidable, ensure supplied **value** is valid, appropriate for app, **authorized** for user.
- Local return URLs: use framework helper rejecting non-local destinations, e.g., ASP.NET Core LocalRedirect or IsLocalUrl.
- External destinations required: allow-list explicitly approved destinations using parsed URL components, see below.
- Force all redirects through interstitial page notifying users they leave your site, destination clearly displayed, user clicks link to confirm.

### Validating URLs

Use maintained URL parser compatible with redirect API and browser URL interpretation. Compare parsed scheme, canonical host, effective port against explicit allowlist; constrain path when only specific endpoints permitted. Reject userinfo and ambiguous input; redirect using validated URL, don't transform afterward. No raw prefix/suffix matching: userinfo and misleading hostnames bypass such checks (GitLab demonstrates). Server-side mapping from approved destination ID remains preferable to accepting arbitrary URLs.

## References

- CWE Entry 601 on Open Redirects
- Microsoft: Prevent Open Redirect Attacks in ASP.NET Core
