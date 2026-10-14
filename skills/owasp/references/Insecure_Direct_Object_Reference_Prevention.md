# Insecure Direct Object Reference Prevention Cheat Sheet

## Introduction

IDOR: attacker accesses/modifies objects by manipulating identifiers in URLs or parameters. Cause: missing access control checks; app doesn't verify user may access specific data.

Three ingredients:

1. **Object**: account, document, support ticket, transaction, partner profile.
2. **Reference** to object: ID, UUID, account number, token, slug.
3. **Missing object-level authorization check**: user accesses/manipulates object they shouldn't.

## Examples

Profile URL:

```text
https://example.org/users/123
```

123 = direct reference to user's DB record (often primary key). Attacker changes to 124, gets other user's info → vulnerable. App didn't check permission for user 124.

Identifier may be in POST body:

```html
<form action="/update_profile" method="post">
  <!-- Other fields for updating name, email, etc. -->
  <input type="hidden" name="user_id" value="12345">
  <button type="submit">Update Profile</button>
</form>
```

Hidden-field user ID; w/o server-side access control, attacker manipulates "user_id" → modifies other users' profiles.

IDORs not limited to user profiles/sequential IDs:

```http
GET /documents/annual-report.pdf
```

Filename = object reference. Attacker modifies to another valid document:

```http
GET /documents/financial-statement.pdf
```

and gets other user's document → IDOR. References may be filenames, account numbers, tokens, other values.

## Identifier complexity

Complex identifiers (GUIDs) make guessing practically impossible. Access control checks still essential: if attacker obtains URLs for unauthorized objects, app must still block access.

## Verifying access controls

Test w/ multiple user accounts of different authorization scopes to verify consistent object-level authorization.

1. Create User A, User B.
2. Create objects owned by each (documents, support tickets, invoices, etc.).
3. Authenticate as User A, access User B's objects by modifying references.
4. Verify denial regardless of predictable/unguessable identifier.

Perform for all operations involving object references: read, create, update, delete, export, administrative actions.

## Mitigation

- Implement access control checks for each object users try to access. Web frameworks often help.
- Complex identifiers = defense-in-depth only; access control still crucial.
- Avoid exposing identifiers in URLs/POST bodies if possible; determine current user from session. Multi-step flows: pass identifiers in session to prevent tampering.
- Look up objects by primary key within datasets user has access to. Ruby on Rails:

```ruby
# vulnerable, searches all projects
@project = Project.find(params[:id])

# secure, searches projects related to the current user
@project = @current_user.projects.find(params[:id])
```

- Verify permission on every access attempt. Implement structurally using framework's recommended approach.
- Defense-in-depth: replace enumerable numeric identifiers w/ random ones. Add DB column w/ random strings, use in URLs instead of numeric primary keys; or use UUIDs/other long random values as primary keys. Avoid encrypting identifiers: hard to do securely.

## Java and Spring Boot example

Illustrative; assume authenticated requests, policy: only owners read documents. `currentUser()` = app helper getting user from trusted authentication context. Spring Boot endpoint returning document by identifier:

```java
@GetMapping("/documents/{id}")
public Document getDocument(@PathVariable Long id) {
    return documentRepository.findById(id).orElseThrow();
}
```

`{id}` path variable is requester-controlled, flows directly into `findById()`. No check document belongs to authenticated user → anyone guessing/obtaining valid identifier reads other user's document.

### Fixing the code

Prefer lookup limited to current user's documents (scoped-query approach as in Rails above):

```java
@GetMapping("/documents/{id}")
public Document getDocument(@PathVariable Long id) {
    return documentRepository.findByIdAndOwnerId(id, currentUser().getId())
        .orElseThrow();
}
```

Alternative: verify ownership explicitly after fetch:

```java
@GetMapping("/documents/{id}")
public Document getDocument(@PathVariable Long id) {
    Document document = documentRepository.findById(id).orElseThrow();
    if (!document.getOwnerId().equals(currentUser().getId())) {
        throw new AccessDeniedException("Not allowed");
    }
    return document;
}
```

Post-fetch check can distinguish missing object from forbidden one. If existence sensitive, use scoped lookup, map both cases to same public response, e.g. 404 (Not Found) response (RFC 9110). E.g. `GET /user/john@example.com` must not reveal account existence to unauthorized caller.

Spring Security `@PreAuthorize` alternative: first enable method security via `@EnableMethodSecurity` on Spring `@Configuration` class; Spring Boot security starter doesn't enable by default. Example applies to Spring-managed component, assumes app-provided `documentAuthorizationService` checking ownership:

```java
@PreAuthorize("@documentAuthorizationService.isOwner(#id, authentication.name)")
@GetMapping("/documents/{id}")
public Document getDocument(@PathVariable Long id) {
    return documentRepository.findById(id).orElseThrow();
}
```

## References

- CWE-639: Authorization Bypass Through User-Controlled Key
- OWASP WSTG: Testing for Insecure Direct Object References
