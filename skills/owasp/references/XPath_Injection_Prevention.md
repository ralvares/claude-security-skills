# XPath Injection Prevention Cheat Sheet

## Introduction

XPath selects data from XML documents. XPath injection (CWE-643): external input becomes part of expression syntax, changing query meaning. Prevent: keep expressions under app control, pass external values via variable binding.

## Bind Values to Fixed Expressions

Use XPath API supporting variables. Write expression in app code, supply external values separately. Don't concatenate/interpolate input into expression, even if compiled afterward: compilation alone doesn't separate data from query syntax.

E.g., Python lxml `xpath()` accepts variables as keyword arguments. Illustrative lookup assumes `xml_document` = already parsed lxml document, `requested_id` = external string:

```python
books = xml_document.xpath(
    "/catalog/book[@id=$book_id]",
    book_id=requested_id,
)
```

Expression stays fixed; `requested_id` supplies only value of `$book_id`. App must separately authorize access to selected books.

Java: use resolver pattern in [Java Security Cheat Sheet](Java_Security.md#xml-xpath-injection). Check your API's docs: accepting XPath string or compiling expression ≠ variable binding support.

API can't bind values → prefer one that can. Where practical, use fixed expression to retrieve authorized record set, compare values in app code. Don't substitute ad hoc quote replacement for variable binding.

## Keep Query Structure Under Application Control

XPath variables represent values, not expression fragments. User chooses query mode → map choice to complete fixed expression defined by app. Reject unknown choices, bind external data values separately.

E.g., catalog app maps choices `books` and `magazines` to fixed paths `/catalog/book` and `/catalog/magazine`. Don't insert selected choice directly into path or accept user-supplied predicates, operators, function calls.

Validate values against expected types, lengths, business rules per [Input Validation Cheat Sheet](Input_Validation.md). Validation complements binding; doesn't make dynamically constructed XPath safe alone.

## Limit Exposure and Review Usage

Keep these controls separate from binding:

- **Authorization:** check caller's permission for each requested resource. Fixed query, narrow path, bound identifier ≠ permission. Follow [Authorization Cheat Sheet](Authorization.md#validate-the-permissions-on-every-request) and principle of least privilege to limit data an operation can access/return.
- **Error handling:** keep XPath expressions, XML contents, stack traces out of client-facing errors. Follow [Error Handling Cheat Sheet](Error_Handling.md). Generic errors reduce disclosure; don't prevent injection.
- **XML parsing:** configure parser per [XML External Entity Prevention Cheat Sheet](XML_External_Entity_Prevention.md). Parser hardening addresses parser risks, not unsafe XPath construction; value binding doesn't harden parser.

Code review: locate calls evaluating/compiling XPath. Trace each expression to app-controlled text; verify external values reach it only via variable binding. Fixed query mappings: verify unknown choices rejected. Include correctness checks for ordinary valid values, absent records, access to resources outside caller's permissions.

Security assessment: Web Security Testing Guide's XPath injection chapter.

## References

- CWE-643: XPath Injection
- lxml: XPath Variables
- W3C XPath 3.1: Variable References
