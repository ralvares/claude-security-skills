# Error Handling Cheat Sheet

## Introduction

Error handling = part of overall app security. Attack always begins w/ **Reconnaissance**: attacker gathers technical info (often *name* and *version* properties) on target: app server, frameworks, libraries etc.

Unhandled errors assist attacker in this phase.

OWASP Web Security Testing Guide explains how error messages can expose app details.

## Context

Error handling issues reveal much about target, can identify injection points in target's features.

Example: technology stack disclosure (Struts2 and Tomcat versions) via exception rendered to user:

```text
HTTP Status 500 - For input string: "null"

type Exception report

message For input string: "null"

description The server encountered an internal error that prevented it from fulfilling this request.

exception

java.lang.NumberFormatException: For input string: "null"
    java.lang.NumberFormatException.forInputString(NumberFormatException.java:65)
    java.lang.Integer.parseInt(Integer.java:492)
    java.lang.Integer.parseInt(Integer.java:527)
    sun.reflect.NativeMethodAccessorImpl.invoke0(Native Method)
    sun.reflect.NativeMethodAccessorImpl.invoke(NativeMethodAccessorImpl.java:57)
    sun.reflect.DelegatingMethodAccessorImpl.invoke(DelegatingMethodAccessorImpl.java:43)
    java.lang.reflect.Method.invoke(Method.java:606)
    com.opensymphony.xwork2.DefaultActionInvocation.invokeAction(DefaultActionInvocation.java:450)
    com.opensymphony.xwork2.DefaultActionInvocation.invokeActionOnly(DefaultActionInvocation.java:289)
    com.opensymphony.xwork2.DefaultActionInvocation.invoke(DefaultActionInvocation.java:252)
    org.apache.struts2.interceptor.debugging.DebuggingInterceptor.intercept(DebuggingInterceptor.java:256)
    com.opensymphony.xwork2.DefaultActionInvocation.invoke(DefaultActionInvocation.java:246)
    ...

note: The full stack trace of the root cause is available in the Apache Tomcat/7.0.56 logs.
```

Example: SQL query error disclosure plus site installation path; can identify injection point:

```text
Warning: odbc_fetch_array() expects parameter /1 to be resource, boolean given
in D:\app\index_new.php on line 188
```

OWASP Testing Guide gives techniques to obtain technical info from an app.

## Objective

Configure global error handler in app runtime configuration; sometimes more efficient in code. Outcome: unexpected error → app returns generic response; error details logged server side for investigation, not returned to user.

Target approach:

![Overview](../assets/Error_Handling_Cheat_Sheet_Overview.png)

Recent topologies *API based*; assume backend exposes only REST API, no UI content. App should exhaustively cover all failure modes; use 5xx only for responses to requests it cannot fulfill, w/ no content revealing implementation details. RFC 7807 - Problem Details for HTTP APIs defines document format.  
Error logging itself: use [logging cheat sheet](Logging.md). This sheet covers error handling only.

## Proposition

Configuration options per technology stack:

### Standard Java Web Application

Global error handler configurable in **web.xml** deployment descriptor. Configuration below works from Servlet specification *version 2.5* up.

Any unexpected error → redirect to page **error.jsp**, which traces error and returns generic response.

Redirection config in **web.xml**:

``` xml
<?xml version="1.0" encoding="UTF-8"?>
<web-app xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" ns="http://java.sun.com/xml/ns/javaee"
xsi:schemaLocation="http://java.sun.com/xml/ns/javaee http://java.sun.com/xml/ns/javaee/web-app_3_0.xsd"
version="3.0">
...
    <error-page>
        <exception-type>java.lang.Exception</exception-type>
        <location>/error.jsp</location>
    </error-page>
...
</web-app>
```

Content of **error.jsp**:

``` java
<%@ page language="java" isErrorPage="true" contentType="application/json; charset=UTF-8"
    pageEncoding="UTF-8"%>
<%
String errorMessage = exception.getMessage();
//Log the exception via the content of the implicit variable named "exception"
//...
//We build a generic response with a JSON format because we are in a REST API app context
//We also add an HTTP response header to indicate to the client app that the response is an error
response.setHeader("X-ERROR", "true");
//Note that we're using an internal server error response
//In some cases it may be prudent to return 4xx error codes, when we have misbehaving clients
response.setStatus(500);
%>
{"message":"An error occur, please retry"}
```

### Java SpringMVC/SpringBoot web application

SpringMVC or SpringBoot: define global error handler by implementing class below. Spring Framework 6 introduced problem details based on RFC 7807.

Annotation @ExceptionHandler tells handler to act when any exception extending *java.lang.Exception* thrown by app. ProblemDetail class creates response object.

``` java
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.context.request.WebRequest;
import org.springframework.web.servlet.mvc.method.annotation.ResponseEntityExceptionHandler;

/**
 * Global error handler in charge of returning a generic response in case of unexpected error situation.
 */
@RestControllerAdvice
public class RestResponseEntityExceptionHandler extends ResponseEntityExceptionHandler {

    @ExceptionHandler(value = {Exception.class})
    public ProblemDetail handleGlobalError(Exception exception, WebRequest request) {
        //Log the exception via the content of the parameter named "exception"
        //...
        //Note that we're using an internal server error response
        //In some cases it may be prudent to return 4xx error codes, if we have misbehaving clients
        //By specification, the content-type can be "application/problem+json" or "application/problem+xml"
        return ProblemDetail.forStatusAndDetail(HttpStatus.INTERNAL_SERVER_ERROR, "An error occur, please retry");
    }
}
```

References:

- Exception handling with Spring
- Exception handling with SpringBoot

### ASP NET Core web application

ASP.NET Core: define global error handler by making exception handler a dedicated API Controller.

Content of error-handling API Controller:

``` csharp
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using System;
using System.Collections.Generic;
using System.Net;

namespace MyProject.Controllers
{
    /// <summary>
    /// API Controller used to intercept and handle all unexpected exception
    /// </summary>
    [Route("api/[controller]")]
    [ApiController]
    [AllowAnonymous]
    public class ErrorController : ControllerBase
    {
        /// <summary>
        /// Action that will be invoked for any call to this Controller in order to handle the current error
        /// </summary>
        /// <returns>A generic error formatted as JSON because we are in a REST API app context</returns>
        [HttpGet]
        [HttpPost]
        [HttpHead]
        [HttpDelete]
        [HttpPut]
        [HttpOptions]
        [HttpPatch]
        public JsonResult Handle()
        {
            //Get the exception that has implied the call to this controller
            Exception exception = HttpContext.Features.Get<IExceptionHandlerFeature>()?.Error;
            //Log the exception via the content of the variable named "exception" if it is not NULL
            //...
            //We build a generic response with a JSON format because we are in a REST API app context
            //We also add an HTTP response header to indicate to the client app that the response
            //is an error
            var responseBody = new Dictionary<String, String>{ {
                "message", "An error occur, please retry"
            } };
            JsonResult response = new JsonResult(responseBody);
            //Note that we're using an internal server error response
            //In some cases it may be prudent to return 4xx error codes, if we have misbehaving clients
            response.StatusCode = (int)HttpStatusCode.InternalServerError;
            Request.HttpContext.Response.Headers.Remove("X-ERROR");
            Request.HttpContext.Response.Headers.Add("X-ERROR", "true");
            return response;
        }
    }
}
```

Mapping exception handler to dedicated error API controller, in app **Startup.cs**:

``` csharp
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace MyProject
{
    public class Startup
    {
...
        public void Configure(IApplicationBuilder app, IHostingEnvironment env)
        {
            //First we configure the error handler middleware!
            //We enable the global error handler in others environments than DEV
            //because debug page are useful during implementation
            if (env.IsDevelopment())
            {
                app.UseDeveloperExceptionPage();
            }
            else
            {
                //Our global handler is defined on "/api/error" URL so we indicate to the
                //exception handler to call this API controller
                //on any unexpected exception raised by the application
                app.UseExceptionHandler("/api/error");

                //To customize the response content type and text, use the overload of
                //UseStatusCodePages that takes a content type and format string.
                app.UseStatusCodePages("text/plain", "Status code page, status code: {0}");
            }

            //We configure others middlewares, remember that the declaration order is important...
            app.UseMvc();
            //...
        }
    }
}
```

References:

- Exception handling with ASP.Net Core

### ASP NET Web API web application

ASP.NET Web API (standard .NET framework, not .NET Core): define and register handlers to trace and handle any app error.

Handler tracing error details:

``` csharp
using System;
using System.Web.Http.ExceptionHandling;

namespace MyProject.Security
{
    /// <summary>
    /// Global logger used to trace any error that occurs at application wide level
    /// </summary>
    public class GlobalErrorLogger : ExceptionLogger
    {
        /// <summary>
        /// Method in charge of the management of the error from a tracing point of view
        /// </summary>
        /// <param name="context">Context containing the error details</param>
        public override void Log(ExceptionLoggerContext context)
        {
            //Get the exception
            Exception exception = context.Exception;
            //Log the exception via the content of the variable named "exception" if it is not NULL
            //...
        }
    }
}
```

Handler managing error to return generic response:

``` csharp
using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.Net;
using System.Net.Http;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Web.Http;
using System.Web.Http.ExceptionHandling;

namespace MyProject.Security
{
    /// <summary>
    /// Global handler used to handle any error that occurs at application wide level
    /// </summary>
    public class GlobalErrorHandler : ExceptionHandler
    {
        /// <summary>
        /// Method in charge of handle the generic response send in case of error
        /// </summary>
        /// <param name="context">Error context</param>
        public override void Handle(ExceptionHandlerContext context)
        {
            context.Result = new GenericResult();
        }

        /// <summary>
        /// Class used to represent the generic response send
        /// </summary>
        private class GenericResult : IHttpActionResult
        {
            /// <summary>
            /// Method in charge of creating the generic response
            /// </summary>
            /// <param name="cancellationToken">Object to cancel the task</param>
            /// <returns>A task in charge of sending the generic response</returns>
            public Task<HttpResponseMessage> ExecuteAsync(CancellationToken cancellationToken)
            {
                //We build a generic response with a JSON format because we are in a REST API app context
                //We also add an HTTP response header to indicate to the client app that the response
                //is an error
                var responseBody = new Dictionary<String, String>{ {
                    "message", "An error occur, please retry"
                } };
                // Note that we're using an internal server error response
                // In some cases it may be prudent to return 4xx error codes, if we have misbehaving clients 
                HttpResponseMessage response = new HttpResponseMessage(HttpStatusCode.InternalServerError);
                response.Headers.Add("X-ERROR", "true");
                response.Content = new StringContent(JsonConvert.SerializeObject(responseBody),
                                                     Encoding.UTF8, "application/json");
                return Task.FromResult(response);
            }
        }
    }
}
```

Registration of both handlers in app **WebApiConfig.cs**:

``` csharp
using MyProject.Security;
using System.Web.Http;
using System.Web.Http.ExceptionHandling;

namespace MyProject
{
    public static class WebApiConfig
    {
        public static void Register(HttpConfiguration config)
        {
            //Register global error logging and handling handlers in first
            config.Services.Replace(typeof(IExceptionLogger), new GlobalErrorLogger());
            config.Services.Replace(typeof(IExceptionHandler), new GlobalErrorHandler());
            //Rest of the configuration
            //...
        }
    }
}
```

Set customErrors section in **Web.config** within ```csharp <system.web>``` node:

```csharp
<configuration>
    ...
    <system.web>
        <customErrors mode="RemoteOnly"
                      defaultRedirect="~/ErrorPages/Oops.aspx" />
        ...
    </system.web>
</configuration>
```

References:

- Exception handling with ASP.Net Web API

- ASP.NET Error Handling

## Sources of the prototype

Source of all sandbox projects built to find right setup: GitHub repository poc-error-handling (righettod).

## Appendix HTTP Errors

HTTP errors reference: RFC 2616. Error messages w/o implementation details avoid info leakage. Generally 4xx for requests failing due to HTTP client error (e.g. unauthorized access, request body too large); 5xx for server-side errors from unforeseen bug. Monitor apps for 5xx errors: good indicator app fails for some inputs.

## References

- OWASP WSTG: Testing for Improper Error Handling
- RFC 9457: Problem Details for HTTP APIs
