# Input Validation Cheat Sheet

## Introduction

Input validation checks data meets app requirements before use. Reduces risk of malformed data, invalid business operations, excessive resource consumption. OWASP Proactive Control C3 separates validation from additional defenses needed when using data:

- Use [parameterized queries](SQL_Injection_Prevention.md) for SQL, [context-aware output encoding](Cross_Site_Scripting_Prevention.md#output-encoding) against cross-site scripting (XSS).
- Check [authorization](Authorization.md) separately: valid account identifier ≠ caller may access account.

## Input Validation Strategies

Validate **syntax** (expected type, format) and **semantics** (value makes sense for operation). E.g. booking needs valid dates, end date after start. CWE-20 describes these checks, incl. consistency between related fields.

Define rules per field:

| Input | Rules to enforce |
| --- | --- |
| Fixed choices | Exact membership in allowed set, incl. values from drop-down menus |
| Numbers and dates | Expected type, accepted format, min and max values |
| Strings | Length limits; characters/structure field requires |
| Objects | Allowed fields, required fields, rules for missing/null values |
| Arrays | Min and max item counts; validate every item, incl. nested objects |

### Allowlist vs Denylist

Define what app accepts; reject values outside rules. Do not try to recognize every malicious string. E.g. blocking apostrophes rejects legit names w/o making DB query safe. Free-form comments: allowlist can permit broad Unicode text, limit length; need not restrict to letters/digits.

## Implementing Input Validation

### Parse Safely, Then Validate

Apply request size limits before buffering/parsing; configure parser limits such as max nesting depth. JSON supports implementation limits on size, depth, numbers (RFC 8259 section 9). Schema check after parsing cannot protect parser that already exhausted resources.

Use maintained parser for expected format, handle parse failures, validate resulting values before business processing/storage. Configure parsers for untrusted input; see [XML External Entity Prevention](XML_External_Entity_Prevention.md#general-guidance), [Deserialization](Deserialization.md). Text → integer conversion establishes type only, not acceptable quantity.

Decode per protocol before field-rule checks. Validate representation actually used; avoid decoding again downstream; CWE-20: inconsistent decoding can invalidate earlier checks.

### Validate Structured Data

Use framework validators or schema validator for field rules. JSON: explicitly configure required and additional properties; listing property alone neither requires it nor rejects unknown fields. Apply schemas to nested objects; use item schemas and array length limits. Keep business checks (e.g. date ordering) alongside structural checks.

Reject invalid requests w/ clear error; never continue w/ partially validated data. Bind only intended input fields to app objects; see [Mass Assignment](Mass_Assignment.md).

### Validating Free-form Unicode Text

Agree on character encoding across components; reject malformed input. Preserve legit punctuation and scripts in names/comments. Where field needs Unicode normalization for consistent comparison, define and apply same policy before validation, storage, comparison. Unicode Standard Annex #15 defines normalization forms; warns compatibility normalization can erase meaningful distinctions. Normalization ≠ sanitization; does not replace output encoding.

### Regular Expressions (Regex)

Use regex for simple, structured fields. Require match of entire value, using API such as Python's `fullmatch` where available. Check engine's character classes and newline behavior; do not assume patterns behave identically across languages.

Bound input length before matching, avoid patterns w/ excessive backtracking, use non-backtracking engine or match timeout where supported. Test valid, invalid, near-matching values; near-matches can cause denial of service (Microsoft regex guidance). Treat timeout as validation failure.

### Validating Rich User Content

User-authored HTML: use maintained [HTML sanitization library](Cross_Site_Scripting_Prevention.md#html-sanitization). Input validation and regex cannot replace it.

### File Upload Validation

Submitted filename and content type = untrusted metadata. Validate filenames after protocol decoding; allowed extension alone ≠ safe content. Follow [File Upload Cheat Sheet](File_Upload.md) for content checks, size limits, storage, safe serving.

### Email Address Validation

Use maintained email validation library compatible w/ addresses your mail system supports. Format validation ≠ proof of mailbox access. Follow [Email Validation and Verification](Email_Validation_and_Verification.md) for comparison policies, ownership verification, email change workflows.

## Common Pitfalls

- **Client-only checks:** Validate on server even if browser checks same fields. Client-side validation bypassable; use for immediate feedback.
- **Trusting internal sources:** Validate data from internal APIs, partner feeds, queues, stored records when crossing trust boundary. Internal transport ≠ value meets receiving component's rules (CWE-20).
- **Denylisting or “cleaning” input:** Apply field-specific acceptance rules. Removing suspicious characters can change meaning; still no query parameterization or output encoding.
- **Stopping at parsing or outer fields:** Test rejected ranges, missing fields, invalid nested items, oversized arrays, not just malformed syntax.
- **Assuming regex or Unicode normalization makes data safe:** Check whole-value matching and resource limits; keep normalization consistent w/ field meaning.
- **Trusting upload metadata:** Use file upload controls above; checking filename ≠ checking file contents.
- **Logging rejected input verbatim:** Record failure + relevant metadata w/o secrets or full request bodies. Escape retained untrusted values for log format to prevent log injection; see [Logging: Event collection](Logging.md#event-collection), [Data to exclude](Logging.md#data-to-exclude).

## References

- OWASP Top 10 Proactive Controls 2024: C3 — Validate all Input & Handle Exceptions
- CWE-20: Improper Input Validation
- Unicode Standard Annex #15: Unicode Normalization Forms
