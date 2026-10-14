# FastAPI Security Cheat Sheet

## Introduction

FastAPI = Python web framework on Asynchronous Server Gateway Interface (ASGI). Covers authentication dependencies, input/output models, deployment controls; builds on FastAPI security documentation.

General API controls: [REST Security Cheat Sheet](REST_Security.md).

Snippets illustrate single controls, not complete apps. Assume existing FastAPI app and app-specific user/persistence functions; adapt and test.

## Dependency Injection and Access Control

Use FastAPI dependency injection (`Depends()`) to enforce authentication and authorization consistently. Missing/insufficient dependencies can leave sensitive operations open to unauthorized users.

### OAuth2PasswordBearer Does Not Validate Tokens

Helper class `OAuth2PasswordBearer` checks authorization scheme, extracts bearer token from `Authorization` header. It does **not validate token or verify signature**. Authentication dependency must verify token, reject invalid credentials before returning user.

### Scoping Authorization Dependencies

Authentication alone ≠ authorization. Endpoints needing elevated privileges (e.g. admin tasks) must also check user permissions. Example: `get_current_user` = authentication dependency rejecting invalid credentials.

```python
from fastapi import Depends, HTTPException, status

async def get_admin_user(current_user: User = Depends(get_current_user)):
    if not current_user.is_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Operation not permitted"
        )
    return current_user

@app.post("/admin/settings")
def update_settings(admin: User = Depends(get_admin_user)):
    return {"status": "success"}
```

### Router-Level Deny-by-Default

Apply authentication dependencies to entire `APIRouter` so new endpoints inherit check. Covers only that router's routes; sensitive operations still need permission checks.

```python
from fastapi import APIRouter, Depends

# Enforce authentication for all routes registered under this router by default
router = APIRouter(
    prefix="/items",
    dependencies=[Depends(get_current_user)]
)
```

## Secure Authentication and JWT Implementation

JSON Web Tokens (JWTs): developers responsible for token verification and key management. FastAPI OAuth2 with JWT tutorial demonstrates verification w/ PyJWT.

### Cryptographic Library Choice

- **Use PyJWT:** Delegate token verification to library; no custom parsing/crypto logic. Configure verification via PyJWT decoding API.

### Key Claims Verification

- **Validate Required Claims:** Verify signature; require `exp` (expiration), `iss` (issuer), `aud` (audience) for authentication tokens. PyJWT: `options={"require": ["exp", "iss", "aud"]}` + supply expected `issuer` and `audience`. Requiring claim checks presence only; keep corresponding verification enabled. Validate `nbf` (not before) when present; require it if token profile calls for it.
- **Explicit Algorithms:** Configure expected algorithm during decoding, e.g. `algorithms=["HS256"]` for tokens issued w/ it. Never derive accepted algorithms from token header.
- **Revocation and Replay:** Expiration bounds token lifetime. Revocation blocklist rejects revoked tokens, but stolen still-active bearer token stays reusable. See [JWT replay-protection guidance](../cheatsheets/JSON_Web_Token.md#replay-protection) for controls beyond expiration and revocation.

### Cookie-Stored Refresh Tokens

- **Cookie Attributes:** Refresh tokens in cookies: set `HttpOnly`, `Secure`, `SameSite=Lax` or `Strict` where compatible w/ auth flow. `HttpOnly` stops JavaScript reading cookie; does not stop injected scripts making authenticated requests.
- **CSRF Mitigations:** Browsers attach cookies automatically → Cross-Site Request Forgery (CSRF) risk. Protect refresh and other state-changing endpoints w/ defenses in [CSRF Prevention Cheat Sheet](../cheatsheets/Cross-Site_Request_Forgery_Prevention.md), e.g. validated CSRF tokens. `SameSite` = defense in depth.

### Signing Key Management

Never hardcode signing secrets or ship default development key in production. Supply keys from deployment-managed secret storage; prefer mounted secret file or secret manager retrieval; env vars only when safer injection unavailable. Pydantic Settings can read deployment-supplied config. Keep local `.env` files w/ secrets out of source control. Follow [Secrets Management Cheat Sheet](../cheatsheets/Secrets_Management.md) for provisioning and rotation.

## Pydantic Validation and Input Hardening

Pydantic schemas validate data; do not replace authorization checks or prevent injection.

### Reject Unrecognized Fields

Pydantic ignores undeclared input fields by default. Use `extra="forbid"` for API to reject such requests:

```python
from pydantic import BaseModel, ConfigDict

class UserCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    username: str
    password: str
```

### Prevent Mass Assignment

Use separate restricted input schemas (`UserCreate`, `UserUpdate`) excluding server-controlled fields like `is_admin` or `id`. Persist only validated allowed fields, not raw request dict. `extra="forbid"` does not stop clients setting sensitive field you declared in input schema. See [Mass Assignment Cheat Sheet](../cheatsheets/Mass_Assignment.md).

### Prevent Sensitive Data Exposure

Specify `response_model` explicitly in path decorators to filter DB objects, exclude sensitive fields (e.g., `password_hash`) from responses.

```python
class UserResponse(BaseModel):
    username: str

@app.post("/users", response_model=UserResponse)
def create_user(user: UserCreate):
    # Application function must hash the password before storing it.
    return save_user_to_db(user)
```

### Strict Typing

Pydantic can convert input to declared types, e.g. `"123"` to `123` for `int` field. Where security decisions need exact input type, use strict types e.g. `StrictInt`, `StrictBool` to reject unintended conversions.

### Injection Countermeasure

Input validation ≠ SQL injection prevention. Use parameterized queries, incl. via Object-Relational Mapper (ORM) APIs that bind parameters. Never build raw SQL w/ string formatting of user input. See [SQL Injection Prevention Cheat Sheet](../cheatsheets/SQL_Injection_Prevention.md).

## Cross-Origin Resource Sharing (CORS) Configuration

Incorrect CORS can expose private API responses to untrusted websites in user's browser. CORS does not replace endpoint authorization or restrict non-browser clients.

### Restrictive CORS Settings

- **Explicit Origins:** With `allow_credentials=True`, list trusted origins explicitly in `allow_origins`. Never combine credentialed requests w/ `allow_origins=["*"]`.
- **Restrict Headers and Methods:** Limit `allow_methods` and `allow_headers` to verbs/headers client app uses.
- Full CORS design patterns: [OWASP HTML5 Security Cheat Sheet](../cheatsheets/HTML5_Security.md).

## OpenAPI and Swagger UI Exposure

FastAPI exposes interactive docs at `/docs` and `/redoc`, schema at `/openapi.json`. Decide whether public. Hiding docs does not secure API operations themselves (conditional OpenAPI guidance).

### Hardening Documentation in Production

Private docs: restrict access to doc pages and schema, or disable w/ `FastAPI(openapi_url=None)`. Prevents disclosure via those routes; authorization must still protect every API operation.

## Async Event Loop and Background Tasks

Blocking worker's event loop stops it handling other requests → Denial of Service (DoS) risk.

### Event Loop Blocking

- Use async DB and network clients inside `async def` routes. Synchronous libraries: use `def` routes/dependencies, which FastAPI runs in thread pool. Ordinary helper functions called directly inside `async def` not auto-moved to pool.
- Move CPU-heavy/long-running work to separate worker system, e.g. Celery. `BackgroundTasks` still runs in app process (background-task caveat).

## Exception Handling and Information Leakage

Control which error details reach clients and logs. FastAPI supports custom exception handlers to sanitize validation responses.

### Validation Error Leakage

Request validation errors can include submitted values and custom error details. Avoid reflecting passwords/tokens in responses or logs. In `RequestValidationError` handler, return only safe field locations and error descriptions, or generic message where necessary. Never return `str(exc)` or entire request body; can include sensitive input or internal context.

## File Upload Security

FastAPI parses multipart uploads into `UploadFile` objects, spooling larger files to temporary disk.

### Upload Protections

- **Limit Payloads Before Parsing:** Set request-body limit at reverse proxy/gateway, e.g. Nginx `client_max_body_size`. Ensure clients cannot bypass that layer. FastAPI parses form before running dependencies; checking `UploadFile.size` in dependency/endpoint does not protect against resources already consumed during parsing.
- **Treat Metadata as Untrusted:** Never use `UploadFile.filename` directly as storage path or trust `content_type` as proof of file type. Apply filename, content-validation, storage controls in [File Upload Cheat Sheet](../cheatsheets/File_Upload.md).

## Rate Limiting

Apply request limits to reduce abuse of sensitive/expensive endpoints.

### Mitigation Options

- Dedicated library e.g. slowapi for route-specific rate limiting in code.
- Multiple workers/replicas: shared counter store (e.g. Redis) so limits apply across instances, not per process.
- Rate limit at reverse proxy (Nginx, HAProxy) or API gateway.

## ASGI Server Hardening

Configure ASGI server proxy trust explicitly so clients cannot spoof client address or request scheme via forwarding headers (Uvicorn HTTP settings).

### Deployment Configuration

- **Limit Proxy Forwarding:** Set `--forwarded-allow-ips` to trusted reverse proxy addresses; configure proxies to overwrite untrusted forwarding headers. Avoid `--forwarded-allow-ips="*"` (trusts every connecting client). Disable proxy-header handling w/ `--no-proxy-headers` if not needed.
- **Disable Server Header:** `--no-server-header` suppresses Uvicorn default `Server` header. Removes one identifying header; does not prevent other server fingerprinting.

## References

- FastAPI: Dependencies
- FastAPI: OAuth2 with JWT tokens
