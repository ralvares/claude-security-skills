# Multi-Tenant Application Security Cheat Sheet

## Introduction

Multi-tenant apps serve multiple customers (tenants) from shared infrastructure, codebase, often shared databases. Foundation of SaaS: cost efficiency, simpler operations.

Critical challenges: single vulnerability can expose all tenants' data; misconfigurations leak data across tenant boundaries; resource contention hits availability.

Best practices to secure multi-tenant apps, ensure tenant isolation, prevent cross-tenant attacks.

## Key Risks

Baseline access controls: [Authorization Cheat Sheet](Authorization.md).

- **Cross-Tenant Data Leakage**: bugs/misconfigurations expose one tenant's data to another.
- **Tenant Impersonation**: attackers gain another tenant's context/resources.
- **Broken Tenant Isolation**: insufficient separation at database, cache, storage, compute layers.
- **Insecure Direct Object References (IDOR)**: access resources by manipulating tenant/resource IDs.
- **Noisy Neighbor Attacks**: one tenant exhausts shared resources, impacts others (DoS).
- **Privilege Escalation Across Tenants**: exploit admin functions to access other tenants.
- **Tenant Context Injection**: manipulate tenant identifiers in requests, tokens, headers.
- **Shared Resource Poisoning**: cache poisoning, queue injection, storage pollution affecting other tenants.
- **Insecure Tenant Onboarding/Offboarding**: incomplete provisioning, residual unauthorized access, retention beyond policy.
- **Audit & Compliance Gaps**: insufficient tenant-specific logging for regulatory requirements.

## Best Practices

### 1. Tenant Identification & Context Management

- Tenant-scoped operations: establish tenant context early in request lifecycle (middleware/interceptor).
- Choose identifiers appropriate to exposure risk. Opaque random identifiers can reduce enumeration; not authorization controls.
- Client-supplied tenant identifiers = selectors only. Verify authenticated principal authorized to act in selected tenant.
- Bind tenant context to server-verified identity + current tenant membership or service authorization.
- Propagate server-verified tenant context to components needing it for tenant-sensitive decisions/observability; downstream components must not replace it with unverified input.

<details>
<summary>Bad example: Trusting client-supplied tenant ID</summary>

```python
# Dangerous: The header selects a tenant without checking the caller's membership.
# Query parameterization prevents injection, not cross-tenant access.
def get_tenant_data(request):
    tenant_id = request.headers.get("X-Tenant-ID")  # Attacker can modify!
    return db.execute("SELECT * FROM data WHERE tenant_id = :tid", {"tid": tenant_id})
```

</details>

<details>
<summary>Good example: Verifying tenant context against authenticated identity</summary>

```python
from functools import wraps
from contextvars import ContextVar
from typing import Optional

class TenantContext:
    def __init__(self, tenant_id: str, user_id: str, roles: list):
        self.tenant_id = tenant_id
        self.user_id = user_id
        self.roles = roles
        self.is_validated = True

# Request-local tenant context
current_tenant: ContextVar[Optional[TenantContext]] = ContextVar(
    'current_tenant', default=None
)

class TenantMiddleware:
    """Verify tenant context against authenticated identity and membership."""
    
    async def __call__(self, request, call_next):
        # A verified claim may select the tenant, but authorization still
        # depends on the issuer's guarantees or a current membership check.
        token_claims = request.state.verified_claims  # Set by auth middleware
        
        if not token_claims or "tenant_id" not in token_claims:
            return JSONResponse(status_code=401, content={"error": "Missing tenant context"})
        
        tenant_id = token_claims["tenant_id"]
        
        principal_id = token_claims["sub"]
        membership = await self.tenant_service.get_active_membership(
            principal_id, tenant_id
        )
        if not membership:
            return JSONResponse(status_code=403, content={"error": "Tenant access denied"})
        
        # Set tenant context for this request
        ctx = TenantContext(
            tenant_id=tenant_id,
            user_id=principal_id,
            roles=membership.roles
        )
        token = current_tenant.set(ctx)
        
        try:
            response = await call_next(request)
            return response
        finally:
            current_tenant.reset(token)

def require_tenant(func):
    """Decorator ensuring tenant context is present."""
    @wraps(func)
    async def wrapper(*args, **kwargs):
        ctx = current_tenant.get()
        if not ctx or not ctx.is_validated:
            raise SecurityException("Tenant context required")
        return await func(*args, **kwargs)
    return wrapper
```

</details>

### 2. Database Isolation Strategies

Choose strategy by security requirements, compliance needs, operational complexity:

| Strategy | Potential Boundary | Conditions and Trade-Offs |
|----------|--------------------|---------------------------|
| Separate Databases | Database + credential boundary | Strong when credentials, network access, admin paths, backups isolated; higher operational cost |
| Separate Schemas | Namespace + database-role boundary | Needs disciplined grants, role separation, `search_path` handling, migrations |
| Shared Tables (Row-Level) | Policy + row boundary | Needs enforceable tenant ownership, policy coverage for classified tenant-owned tables, constrained request roles, negative-path tests |
| Hybrid | Varies by workload/tier | Document + test boundary used per data class |

<details>
<summary>Row-Level Security Implementation (PostgreSQL)</summary>

```sql
-- Enable RLS on tenant tables
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;

-- Create policy that restricts access to current tenant
CREATE POLICY tenant_isolation_policy ON orders
    FOR ALL
    USING (tenant_id = current_setting('app.current_tenant')::uuid);

CREATE POLICY tenant_isolation_policy ON customers
    FOR ALL
    USING (tenant_id = current_setting('app.current_tenant')::uuid);

-- Force RLS for table owners (not superusers or BYPASSRLS roles)
ALTER TABLE orders FORCE ROW LEVEL SECURITY;
ALTER TABLE customers FORCE ROW LEVEL SECURITY;
```

</details>

#### Do Not Use an RLS-Bypassing Role for Tenant-Scoped Request Paths

`FORCE ROW LEVEL SECURITY` applies policies to table owner. Does not constrain superuser or role w/ `BYPASSRLS` attribute; PostgreSQL: both always bypass row security.

- Connect normal app request path w/ least-privileged role that is neither superuser nor `BYPASSRLS`.
- Reserve privileged connections for migrations + explicitly authorized admin jobs.
- Never serve ordinary tenant-scoped requests through privileged connection. Privileged job must explicitly authorize + constrain its tenant set/cross-tenant operation; RLS won't.
- Check deployed request role, not only role declared in source-controlled config. PostgreSQL exposes `rolsuper` and `rolbypassrls` in `pg_roles`.

#### Scope Tenant Context to the Transaction

Example policy depends on `current_setting('app.current_tenant')`. Omitting optional `missing_ok => true` argument → PostgreSQL raises error if setting missing instead of returning `NULL`; deliberate fail-closed. `current_setting` docs describe both behaviors.

Normal `SET` persists until session ends after transaction commits; `SET LOCAL` lasts only current transaction. If app/connection pool reuses DB session w/o reset, session-scoped tenant state inherited by next request.

- Begin transaction, set tenant context w/ `SET LOCAL` or `set_config('app.current_tenant', tenant_id, true)`, run dependent queries in same transaction. `true` argument makes `set_config` transaction-local.
- Re-establish tenant context every transaction. Never assume newly borrowed connection has correct setting.
- Fail closed if tenant context missing/invalid; no fallback to unscoped query.
- Commit/roll back before returning connection to pool.

SQLAlchemy deprecated `QueryEvents.before_compile`: no coverage of ORM-level attribute + relationship loads. Current recommended pattern: `SessionEvents.do_orm_execute` + `with_loader_criteria`, so criteria propagate to occurrences of mapped entity, incl. eager + lazy relationship loads.

<details>
<summary>Application-Level Enforcement (Python/SQLAlchemy)</summary>

```python
from sqlalchemy import event, Column, String, text
from sqlalchemy.orm import Session, declared_attr, with_loader_criteria
from contextlib import contextmanager

class TenantMixin:
    """Mixin that adds tenant_id to models that inherit it."""
    
    @declared_attr
    def tenant_id(cls):
        return Column(String(36), nullable=False, index=True)

class TenantAwareSession(Session):
    """Session carrying tenant context for participating ORM operations."""
    
    def __init__(self, *args, tenant_id: str | None = None, **kwargs):
        super().__init__(*args, **kwargs)
        self._tenant_id = tenant_id
    
    @property
    def tenant_id(self):
        if not self._tenant_id:
            raise SecurityException("Tenant ID not set on session")
        return self._tenant_id

# Add tenant criteria to ORM SELECTs issued through TenantAwareSession.
# with_loader_criteria propagates this rule to eager and lazy relationship loads.
@event.listens_for(TenantAwareSession, "do_orm_execute")
def add_tenant_filter(execute_state):
    if (
        execute_state.is_select
        and not execute_state.is_column_load
        and not execute_state.is_relationship_load
    ):
        tenant_id = execute_state.session.tenant_id
        execute_state.statement = execute_state.statement.options(
            with_loader_criteria(
                TenantMixin,
                lambda model: model.tenant_id == tenant_id,
                include_aliases=True,
            )
        )

# Set and validate tenant_id for new mapped objects in this session.
@event.listens_for(TenantAwareSession, "before_flush")
def set_tenant_on_insert(session, flush_context, instances):
    tenant_id = session.tenant_id
    for target in session.new:
        if isinstance(target, TenantMixin):
            if target.tenant_id not in (None, tenant_id):
                raise SecurityException("Object tenant does not match session")
            target.tenant_id = tenant_id

# Secure session factory
@contextmanager
def tenant_session(tenant_id: str):
    """Create a tenant-scoped database session."""
    ctx = current_tenant.get()
    if not ctx or ctx.tenant_id != tenant_id:
        raise SecurityException("Tenant session requires verified context")

    session = TenantAwareSession(bind=engine, tenant_id=tenant_id)
    
    try:
        # The final true makes the tenant context transaction-local
        session.execute(
            text("SELECT set_config('app.current_tenant', :tenant_id, true)"),
            {"tenant_id": tenant_id}
        )
        yield session
        session.commit()
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()
```

</details>

ORM helper = defense in depth, not complete enforcement. Applies tenant criteria to ORM SELECTs issued through `TenantAwareSession`, propagated to relationship loaders. Raw SQL, Core connections, bulk operations, code using another session type need separate controls; use database policies/constrained roles as final boundary where possible.

#### Verify Tenant Isolation

Test isolation via same role, connection path, pooling mode as app. Privileged test connection can make correct policy appear broken; test not exercising deployed request role can miss bypass.

- **Test the authorization matrix.** Each RLS-protected table: prove expected cross-tenant operations denied, expected same-tenant operations succeed. Where sharing/platform admin intentional, test exact permitted path, prove no broader access.
- **Discover coverage.** Derive expected tenant-scoped table inventory from schema or explicit classification; compare w/ PostgreSQL `pg_class.relrowsecurity` and `relforcerowsecurity` and `pg_policies` view. Fail when new table has no classification, RLS disabled, or expected policy absent.
- **Assert the request role.** In deployed environment, fail config test if request-path role has `rolsuper` or `rolbypassrls` set.
- **Exercise connection reuse.** Run requests for two tenants over reused connections; prove second request cannot observe first request's tenant context.

Hand-maintained table list drifts: same omission leaving RLS off new table can leave it out of test. Prefer schema-derived discovery, or gate schema changes so each new table must be classified tenant-scoped, intentionally shared, or otherwise isolated.

### 3. Preventing Cross-Tenant Data Access (IDOR Prevention)

- Each tenant-scoped resource: verify authenticated principal can act in resource's tenant.
- Include tenant scope in lookup/authorization policy when ownership tenant-specific. Composite key (`tenant_id` + `resource_id`) = one option, not universal requirement.
- Enforce authorization at boundary traversed by every tenant-owned access path. Add data-layer checks as defense in depth where architecture supports.
- Opaque/random identifiers = defense in depth against enumeration, not substitute for authorization.

<details>
<summary>Bad example: Direct object reference without tenant validation</summary>

```python
# Dangerous: Only checks resource_id, not tenant ownership
@app.get("/api/documents/{document_id}")
async def get_document(document_id: str):
    doc = db.query(Document).filter(Document.id == document_id).first()
    if not doc:
        raise HTTPException(404)
    return doc  # Could return another tenant's document!
```

</details>

<details>
<summary>Good example: Tenant-scoped resource access</summary>

```python
from uuid import UUID
from typing import TypeVar, Generic, Type

T = TypeVar('T')

class TenantScopedRepository(Generic[T]):
    """Repository that scopes the operations provided below to one tenant."""
    
    def __init__(self, model: Type[T], session: Session):
        self.model = model
        self.session = session
    
    @property
    def tenant_id(self) -> str:
        ctx = current_tenant.get()
        if not ctx:
            raise SecurityException("Tenant context required")
        return ctx.tenant_id
    
    def get_by_id(self, resource_id: UUID) -> Optional[T]:
        """Get resource only if it belongs to current tenant."""
        return self.session.query(self.model).filter(
            self.model.id == resource_id,
            self.model.tenant_id == self.tenant_id  # Tenant-owned resource
        ).first()
    
    def list_all(self, limit: int = 100, offset: int = 0) -> list[T]:
        """List resources for current tenant only."""
        return self.session.query(self.model).filter(
            self.model.tenant_id == self.tenant_id
        ).limit(limit).offset(offset).all()
    
    def create(self, **kwargs) -> T:
        """Create resource with tenant_id automatically set."""
        if 'tenant_id' in kwargs and kwargs['tenant_id'] != self.tenant_id:
            raise SecurityException("Cannot create resource for different tenant")
        
        kwargs['tenant_id'] = self.tenant_id
        instance = self.model(**kwargs)
        self.session.add(instance)
        return instance
    
    def delete(self, resource_id: UUID) -> bool:
        """Delete resource only if it belongs to current tenant."""
        result = self.session.query(self.model).filter(
            self.model.id == resource_id,
            self.model.tenant_id == self.tenant_id
        ).delete()
        return result > 0

# Usage
@app.get("/api/documents/{document_id}")
@require_tenant
async def get_document(document_id: UUID, db: Session = Depends(get_db)):
    repo = TenantScopedRepository(Document, db)
    doc = repo.get_by_id(document_id)
    if not doc:
        raise HTTPException(404, "Document not found")  # Don't reveal if it exists for other tenant
    return doc
```

</details>

### 4. Cache & Session Isolation

- Classify each cached value: global, tenant-scoped, or user-scoped.
- Include tenant identifier in every cache key whose value/authorization varies by tenant.
- Intentionally shared entries: explicit global namespace; document why safe to share.
- Include every other attribute changing result (user, locale, feature set, permission version).
- Authorize request before reading protected cached value; cache-key separation ≠ authorization.
- Separate cache instances for tenants needing stronger physical isolation.
- Choose TTL + invalidation by freshness + authorization risk. Immutable, versioned global entries may not need expiry.

<details>
<summary>Bad example: Tenant-scoped data stored under a shared key</summary>

```python
# Dangerous: user IDs are not guaranteed to be unique across tenants,
# and the key incorrectly places tenant-scoped data in a global namespace.
def get_user_preferences(user_id: str):
    cache_key = f"global:user-preferences:{user_id}"
    cached = redis.get(cache_key)
    if cached:
        return json.loads(cached)
    # ...
```

</details>

<details>
<summary>Good example: Explicit tenant and global cache scopes</summary>

```python
import json

def tenant_cache_key(tenant_id: str, resource: str, item_id: str) -> str:
    return f"tenant:{tenant_id}:{resource}:{item_id}"

def global_cache_key(resource: str, version: str) -> str:
    return f"global:{resource}:{version}"

async def get_user_preferences(user_id: str):
    # These application-specific helpers derive tenant context from the
    # verified session and enforce access before the cache lookup.
    tenant_id = require_authenticated_tenant()
    await authorize_user_access(tenant_id, user_id)

    # Preferences vary by tenant, so tenant_id is part of the key.
    key = tenant_cache_key(tenant_id, "user-preferences", user_id)
    if cached := redis.get(key):
        return json.loads(cached)

    preferences = await db.fetch_preferences(tenant_id, user_id)
    redis.setex(key, 1800, json.dumps(preferences))
    return preferences

async def get_country_codes():
    # This versioned reference data is identical and authorized for all tenants.
    key = global_cache_key("country-codes", "v1")
    if cached := redis.get(key):
        return json.loads(cached)

    country_codes = await db.fetch_public_country_codes()
    redis.setex(key, 86400, json.dumps(country_codes))
    return country_codes
```

</details>

### 5. API, Asynchronous Work & Resource Controls

#### API Security & Rate Limiting

- Tenants share capacity/quotas: include tenant identity as one rate-limit dimension alongside any required global, endpoint, user, IP limits.
- HTTP-boundary rate limits do not constrain every shared resource. Where tenant load can affect other tenants, apply tenant-aware limits/scheduling to relevant bottlenecks (concurrent work, queued messages, database connections, fan-out, CPU, memory). Keep global safety limits; isolate worker/resource pool when risk or service commitment justifies operational cost. AWS SaaS Lens: scaling, throttling, selective resource isolation = complementary noisy-neighbor controls.
- Validate server-verified tenant context on every tenant-scoped API request. Public/global endpoints need no artificial tenant context.
- Bind API credentials to explicit tenant sets, environments, permission scopes. Intentionally cross-tenant service identity: separately authorized, least privileged.
- B2B request signing required: bind signature to security-relevant request context (tenant selection, target audience, method, path, body digest, expiration, as applicable).

Limits below illustrative. Choose production limits from capacity, abuse risk, contractual quotas; mount tenant-aware middleware only on routes needing tenant context.

<details>
<summary>Tenant-Aware Rate Limiting</summary>

```python
import time
from dataclasses import dataclass
from enum import Enum

class TenantTier(Enum):
    FREE = "free"
    STARTER = "starter"
    BUSINESS = "business"
    ENTERPRISE = "enterprise"

@dataclass
class RateLimitConfig:
    requests_per_minute: int
    requests_per_day: int
    burst_size: int

TIER_LIMITS = {
    TenantTier.FREE: RateLimitConfig(60, 1000, 10),
    TenantTier.STARTER: RateLimitConfig(300, 10000, 50),
    TenantTier.BUSINESS: RateLimitConfig(1000, 100000, 100),
    TenantTier.ENTERPRISE: RateLimitConfig(5000, 1000000, 500),
}

class TenantRateLimiter:
    """One tenant dimension in a broader rate-limiting strategy."""
    
    def __init__(self, redis_client):
        self.redis = redis_client
    
    async def check_rate_limit(self, tenant_id: str, tenant_tier: TenantTier) -> dict:
        """Check and update rate limit for tenant."""
        config = TIER_LIMITS[tenant_tier]
        now = time.time()
        minute_key = f"rl:{tenant_id}:min:{int(now // 60)}"
        day_key = f"rl:{tenant_id}:day:{int(now // 86400)}"
        
        pipe = self.redis.pipeline()
        
        # Increment counters
        pipe.incr(minute_key)
        pipe.expire(minute_key, 60)
        pipe.incr(day_key)
        pipe.expire(day_key, 86400)
        
        results = pipe.execute()
        minute_count = results[0]
        day_count = results[2]
        
        # Check limits
        if minute_count > config.requests_per_minute:
            return {
                "allowed": False,
                "reason": "minute_limit_exceeded",
                "retry_after": 60 - (now % 60),
                "limit": config.requests_per_minute
            }
        
        if day_count > config.requests_per_day:
            return {
                "allowed": False,
                "reason": "daily_limit_exceeded",
                "retry_after": 86400 - (now % 86400),
                "limit": config.requests_per_day
            }
        
        return {
            "allowed": True,
            "remaining_minute": config.requests_per_minute - minute_count,
            "remaining_day": config.requests_per_day - day_count
        }

class RateLimitMiddleware:
    """Middleware for routes that require tenant-scoped rate limits."""
    
    async def __call__(self, request, call_next):
        ctx = current_tenant.get()
        if not ctx:
            return JSONResponse(
                status_code=401,
                content={"error": "Tenant context required"}
            )
        
        tenant = await self.tenant_service.get_tenant(ctx.tenant_id)
        result = await self.rate_limiter.check_rate_limit(
            ctx.tenant_id, 
            tenant.tier
        )
        
        if not result["allowed"]:
            return JSONResponse(
                status_code=429,
                content={"error": "Rate limit exceeded", "details": result},
                headers={
                    "Retry-After": str(int(result["retry_after"])),
                    "X-RateLimit-Limit": str(result["limit"]),
                    "X-RateLimit-Remaining": "0"
                }
            )
        
        response = await call_next(request)
        
        # Add rate limit headers
        response.headers["X-RateLimit-Remaining-Minute"] = str(result["remaining_minute"])
        response.headers["X-RateLimit-Remaining-Day"] = str(result["remaining_day"])
        
        return response
```

</details>

#### Tenant-Aware Asynchronous Work

Classify async work: global, tenant-scoped, or explicitly cross-tenant. Shared queue/topic ≠ tenant-isolation boundary. Microsoft multitenant messaging guidance: trade-off shared vs dedicated messaging infrastructure; app-enforced isolation needed when shared.

- Tenant-scoped work: derive tenant context from authenticated producer, bind to message via trusted broker routing, authenticated metadata, or integrity-protected payload. Unverified message field must not replace producer's authorized scope.
- Consumer: authenticate producer/broker path, re-establish tenant context, authorize operation + target resource. Re-check time-sensitive membership/permission when delayed execution could stale original decision.
- Scope idempotency/deduplication keys, retry state, dead-letter access, per-tenant ordering when data/effects vary by tenant. Global + authorized cross-tenant jobs: explicit identities + scopes, not fabricated tenant.
- Tenant-aware queue depth, concurrency, throughput controls when shared worker fleet/broker susceptible to noisy-neighbor load; keep service-wide limits for aggregate exhaustion.

### 6. File Storage & Blob Isolation

- Classify stored objects: global, tenant-scoped, or user-scoped. Intentionally shared assets in explicit global namespace.
- Partition tenant-scoped objects w/ tenant-aware key, bucket, account, or enforceable storage policy.
- Authorize access to exact object + operation before serving or generating signed URL.
- Limit signed URLs to required object + method, lifetime appropriate to operation + revocation model. Tenant identifier need not appear in URL when authorization happened before signing.
- Tenant-specific encryption keys when risk/compliance requires cryptographic isolation. Shared managed key w/ enforced access context can also be appropriate.

<details>
<summary>Illustrative Tenant-Scoped File Storage</summary>

```python
import boto3
from botocore.config import Config
from datetime import datetime
from pathlib import PurePosixPath
from typing import Optional
import re

class TenantFileStorage:
    """Illustrative S3 helper for tenant-scoped objects."""
    
    def __init__(self, bucket_name: str, kms_key_id: str = None):
        self.bucket = bucket_name
        self.s3 = boto3.client('s3', config=Config(signature_version='s3v4'))
        self.kms_key_id = kms_key_id
    
    def _get_tenant_prefix(self, tenant_id: str) -> str:
        """Generate tenant-specific path prefix."""
        # Naming is not authorization. Accept only the application's canonical
        # tenant identifier format so it cannot alter the object-key structure.
        if not re.fullmatch(r"[A-Za-z0-9_-]{1,128}", tenant_id):
            raise ValueError("Invalid tenant identifier")
        return f"tenants/{tenant_id}"
    
    def _build_key(self, tenant_id: str, file_path: str) -> str:
        """Build full S3 key with tenant isolation."""
        path = PurePosixPath(file_path)
        if not path.parts or path.is_absolute() or ".." in path.parts or "\\" in file_path:
            raise ValueError("Invalid object path")
        return f"{self._get_tenant_prefix(tenant_id)}/{path.as_posix()}"
    
    async def upload_file(self, tenant_id: str, file_path: str, 
                         content: bytes, content_type: str) -> dict:
        """Upload file for tenant."""
        await authorize_file_access(tenant_id, file_path, "put_object")
        key = self._build_key(tenant_id, file_path)
        
        extra_args = {
            'ContentType': content_type,
            'Metadata': {
                'tenant-id': tenant_id,
                'uploaded-at': datetime.utcnow().isoformat()
            }
        }
        
        # Use tenant-specific KMS key if available
        if self.kms_key_id:
            extra_args['ServerSideEncryption'] = 'aws:kms'
            extra_args['SSEKMSKeyId'] = self.kms_key_id
        
        self.s3.put_object(
            Bucket=self.bucket,
            Key=key,
            Body=content,
            **extra_args
        )
        
        return {"key": key, "size": len(content)}
    
    async def get_file(self, tenant_id: str, file_path: str) -> Optional[bytes]:
        """Get file only if it belongs to tenant."""
        await authorize_file_access(tenant_id, file_path, "get_object")
        key = self._build_key(tenant_id, file_path)
        
        try:
            response = self.s3.get_object(Bucket=self.bucket, Key=key)
            
            # Verify tenant ownership from metadata
            metadata_tenant = response.get('Metadata', {}).get('tenant-id')
            if metadata_tenant != tenant_id:
                raise SecurityException("Tenant mismatch in file metadata")
            
            return response['Body'].read()
        except self.s3.exceptions.NoSuchKey:
            return None
    
    async def generate_presigned_url(self, tenant_id: str, file_path: str,
                                     expiration: int = 3600,
                                     operation: str = 'get_object') -> str:
        """Authorize and sign one object operation for a verified tenant."""
        await authorize_file_access(tenant_id, file_path, operation)
        key = self._build_key(tenant_id, file_path)

        url = self.s3.generate_presigned_url(
            ClientMethod=operation,
            Params={
                'Bucket': self.bucket,
                'Key': key,
            },
            ExpiresIn=expiration
        )
        
        return url
    
    async def delete_tenant_data(self, tenant_id: str):
        """Delete current objects; versions and backups follow retention policy."""
        # The delimiter prevents a tenant such as "acme" from matching
        # another tenant's "acme-west" prefix.
        prefix = f"{self._get_tenant_prefix(tenant_id)}/"
        
        paginator = self.s3.get_paginator('list_objects_v2')
        for page in paginator.paginate(Bucket=self.bucket, Prefix=prefix):
            objects = page.get('Contents', [])
            if objects:
                self.s3.delete_objects(
                    Bucket=self.bucket,
                    Delete={'Objects': [{'Key': obj['Key']} for obj in objects]}
                )
```

</details>

### 7. Tenant Onboarding & Offboarding Security

- Secure tenant provisioning w/ isolated resources.
- Unique encryption keys per tenant where required.
- Documented retention + deletion policy across active stores, caches, object versions, replicas, exports, backups. Restrict any legally required retained records.
- Maintain audit trail of provisioning/deprovisioning.
- Provide tenant data export when contract, regulation, or product policy requires.

#### Tenant Backup Restore

Shared backup can contain several tenants' data. Single-tenant recovery from shared database: restore into separate resource, selectively recover target tenant's data (Azure multitenant storage guidance).

- Authorize operator for target tenant; record source backup, target, reason, outcome.
- Check tenant ownership before copying records/objects into live tenant scope. Never give tenant operator access to shared backup.
- Reapply current access + retention rules; backup can contain old memberships or data that should no longer be accessible.
- Test backup w/ two tenants: recover one, verify other tenant's records/objects absent, reject restore request by unauthorized actor.

<details>
<summary>Illustrative Tenant Lifecycle Management</summary>

```python
from dataclasses import dataclass
from datetime import datetime, timedelta
from enum import Enum
import hashlib
import secrets

class TenantStatus(Enum):
    PROVISIONING = "provisioning"
    ACTIVE = "active"
    SUSPENDED = "suspended"
    OFFBOARDING = "offboarding"
    DELETED = "deleted"

@dataclass
class TenantProvisioningResult:
    tenant_id: str
    status: TenantStatus
    api_key: str
    database_schema: str
    storage_prefix: str

class TenantLifecycleManager:
    """Manages secure tenant onboarding and offboarding."""
    
    def __init__(self, db, cache, storage, audit_log):
        self.db = db
        self.cache = cache
        self.storage = storage
        self.audit = audit_log
    
    async def provision_tenant(self, tenant_name: str, admin_email: str,
                               tier: TenantTier) -> TenantProvisioningResult:
        """Securely provision a new tenant."""
        tenant_id = secrets.token_urlsafe(16)
        
        await self.audit.log("tenant_provisioning_started", {
            "tenant_id": tenant_id,
            "tenant_name": tenant_name,
            "tier": tier.value
        })
        
        try:
            # 1. Create tenant record
            tenant = await self.db.create_tenant(
                id=tenant_id,
                name=tenant_name,
                status=TenantStatus.PROVISIONING,
                tier=tier
            )
            
            # 2. Create isolated database schema (if using schema isolation)
            schema_name = f"tenant_{tenant_id.replace('-', '_')}"
            await self.db.execute(f"CREATE SCHEMA {schema_name}")
            await self._apply_schema_migrations(schema_name)
            
            # 3. Generate a high-entropy random API credential.
            # SHA-256 is used for this random key, not for a user password.
            api_key = secrets.token_urlsafe(32)
            api_key_hash = hashlib.sha256(api_key.encode()).hexdigest()
            await self.db.store_api_key(tenant_id, api_key_hash)
            
            # 4. Create storage prefix
            storage_prefix = self.storage._get_tenant_prefix(tenant_id)
            
            # 5. Initialize tenant-specific encryption key (if required)
            if tier in [TenantTier.BUSINESS, TenantTier.ENTERPRISE]:
                await self._provision_tenant_kms_key(tenant_id)
            
            # 6. Activate tenant
            await self.db.update_tenant_status(tenant_id, TenantStatus.ACTIVE)
            
            await self.audit.log("tenant_provisioning_completed", {
                "tenant_id": tenant_id,
                "schema": schema_name
            })
            
            return TenantProvisioningResult(
                tenant_id=tenant_id,
                status=TenantStatus.ACTIVE,
                api_key=api_key,  # Return only once, never stored in plain text
                database_schema=schema_name,
                storage_prefix=storage_prefix
            )
            
        except Exception as e:
            await self.audit.log("tenant_provisioning_failed", {
                "tenant_id": tenant_id,
                "error": str(e)
            })
            await self._cleanup_failed_provisioning(tenant_id)
            raise
    
    async def offboard_tenant(self, tenant_id: str, retain_days: int,
                              export_required: bool = False) -> dict:
        """Securely offboard a tenant with data retention."""
        await self.audit.log("tenant_offboarding_started", {"tenant_id": tenant_id})
        
        # 1. Mark tenant as offboarding (prevents new operations)
        await self.db.update_tenant_status(tenant_id, TenantStatus.OFFBOARDING)
        
        # 2. Revoke all active sessions and API keys
        await self._revoke_all_access(tenant_id)
        
        # 3. Export data only when the applicable policy requires it
        export_location = None
        if export_required:
            export_location = await self._export_tenant_data(tenant_id)
        
        # 4. Schedule data deletion after retention period
        deletion_date = datetime.utcnow() + timedelta(days=retain_days)
        await self.db.schedule_tenant_deletion(tenant_id, deletion_date)
        
        await self.audit.log("tenant_offboarding_completed", {
            "tenant_id": tenant_id,
            "export_location": export_location,
            "scheduled_deletion": deletion_date.isoformat()
        })
        
        return {
            "status": "offboarding_complete",
            "data_export": export_location,
            "scheduled_active_store_deletion": deletion_date.isoformat()
        }
    
    async def execute_tenant_deletion(self, tenant_id: str):
        """Apply the active-store deletion stage of the retention policy."""
        await self.audit.log("tenant_deletion_started", {"tenant_id": tenant_id})
        
        # 1. Delete database schema/data
        schema_name = f"tenant_{tenant_id.replace('-', '_')}"
        await self.db.execute(f"DROP SCHEMA IF EXISTS {schema_name} CASCADE")
        
        # For shared table model, delete rows
        await self.db.execute(
            "DELETE FROM shared_table WHERE tenant_id = :tid",
            {"tid": tenant_id}
        )
        
        # 2. Delete cached data
        await self.cache.invalidate_tenant(tenant_id)
        
        # 3. Delete stored files
        await self.storage.delete_tenant_data(tenant_id)
        
        # 4. Delete encryption keys
        await self._delete_tenant_kms_key(tenant_id)
        
        # 5. Mark as deleted (keep minimal audit record)
        await self.db.update_tenant_status(tenant_id, TenantStatus.DELETED)

        # Verify replicas, exports, object versions, backups, and legal holds
        # through their own retention-policy controls.
        
        await self.audit.log("tenant_deletion_completed", {"tenant_id": tenant_id})
```

</details>

SHA-256 example applies only to high-entropy random credential created by `secrets.token_urlsafe(32)`. Fast digest does not make low-entropy/user-chosen secret safe against offline guessing. Store passwords per [Password Storage Cheat Sheet](Password_Storage.md), using suitable password-hashing function, not this API-key pattern.

### 8. Logging, Monitoring & Audit

- Include server-verified tenant context in tenant-scoped security + audit events; global infrastructure events may have no tenant.
- Centralized audit store acceptable when read access enforces tenant scope + cross-tenant access needs explicit platform permission.
- Monitor denied/unexpected cross-tenant access attempts; do not treat explicitly authorized platform operations as violations.
- Alert on tenant-isolation control failures + suspicious denial patterns.
- Apply documented access + retention policy per audit-data class.

<details>
<summary>Tenant-Aware Logging & Monitoring</summary>

```python
import structlog
from typing import Any, Dict
from datetime import datetime
import secrets

class TenantAwareLogger:
    """Logger that includes verified tenant context when one is active."""
    
    def __init__(self):
        self.logger = structlog.get_logger()
    
    def _enrich_with_tenant(self, event_data: dict) -> dict:
        """Add tenant context to log entry."""
        ctx = current_tenant.get()
        if ctx:
            event_data["tenant_id"] = ctx.tenant_id
            event_data["user_id"] = ctx.user_id
        return event_data
    
    def info(self, message: str, **kwargs):
        self.logger.info(message, **self._enrich_with_tenant(kwargs))
    
    def warning(self, message: str, **kwargs):
        self.logger.warning(message, **self._enrich_with_tenant(kwargs))
    
    def error(self, message: str, **kwargs):
        self.logger.error(message, **self._enrich_with_tenant(kwargs))
    
    def security_event(self, event_type: str, severity: str, **kwargs):
        """Log security-relevant events."""
        self.logger.warning(
            "security_event",
            event_type=event_type,
            severity=severity,
            **self._enrich_with_tenant(kwargs)
        )

class TenantAuditLog:
    """Audit API with tenant-aware reads and append-only writes."""
    
    def __init__(self, db):
        self.db = db
    
    async def log(self, action: str, details: Dict[str, Any], 
                  tenant_id: str = None):
        """Record audit entry."""
        ctx = current_tenant.get()
        if (
            ctx
            and tenant_id
            and tenant_id != ctx.tenant_id
            and not has_permission(ctx, "platform:audit:write")
        ):
            raise SecurityException("Cannot write another tenant's audit log")

        effective_tenant_id = tenant_id or (ctx.tenant_id if ctx else "system")
        
        entry = {
            "id": secrets.token_urlsafe(16),
            "tenant_id": effective_tenant_id,
            "user_id": ctx.user_id if ctx else None,
            "action": action,
            "details": details,
            "timestamp": datetime.utcnow(),
            "ip_address": get_client_ip(),
            "user_agent": get_user_agent()
        }
        
        # This API only appends. Database permissions, tamper-evident storage,
        # or WORM controls must enforce the required immutability properties.
        await self.db.execute("""
            INSERT INTO audit_log 
            (id, tenant_id, user_id, action, details, timestamp, ip_address, user_agent)
            VALUES (:id, :tenant_id, :user_id, :action, :details, :timestamp, :ip_address, :user_agent)
        """, entry)
    
    async def get_tenant_audit_trail(self, tenant_id: str, 
                                     start_date: datetime,
                                     end_date: datetime) -> list:
        """Retrieve audit trail for a specific tenant."""
        ctx = current_tenant.get()
        
        # Tenant audit readers and platform auditors are distinct permissions;
        # a tenant-local admin is not implicitly a platform auditor.
        can_read_tenant = (
            ctx
            and ctx.tenant_id == tenant_id
            and has_permission(ctx, "tenant:audit:read")
        )
        can_read_platform = ctx and has_permission(ctx, "platform:audit:read")
        if not (can_read_tenant or can_read_platform):
            raise SecurityException("Audit access denied")
        
        return await self.db.fetch_all("""
            SELECT * FROM audit_log 
            WHERE tenant_id = :tenant_id 
            AND timestamp BETWEEN :start AND :end
            ORDER BY timestamp DESC
        """, {"tenant_id": tenant_id, "start": start_date, "end": end_date})

class CrossTenantAccessMonitor:
    """Monitor and alert on potential cross-tenant access attempts."""
    
    def __init__(self, alert_service):
        self.alerts = alert_service
        self.violation_counts = {}
    
    async def check_access(self, requested_tenant: str, 
                          resource_type: str, resource_id: str):
        """Check for cross-tenant access attempts."""
        ctx = current_tenant.get()
        
        if not ctx or not await authorize_tenant_access(
            ctx, requested_tenant, resource_type, resource_id
        ):
            # Log a denied attempt, not an explicitly authorized platform action
            logger.security_event(
                "cross_tenant_access_attempt",
                severity="HIGH",
                requested_tenant=requested_tenant,
                resource_type=resource_type,
                resource_id=resource_id
            )
            
            # Track violations per user
            principal_id = ctx.user_id if ctx else "anonymous"
            source_tenant = ctx.tenant_id if ctx else "none"
            key = f"{principal_id}:{source_tenant}"
            self.violation_counts[key] = self.violation_counts.get(key, 0) + 1
            
            # Alert on repeated attempts
            if self.violation_counts[key] >= 3:
                await self.alerts.send(
                    severity="CRITICAL",
                    message="Repeated cross-tenant access attempts detected",
                    details={
                        "user_id": principal_id,
                        "tenant_id": source_tenant,
                        "attempts": self.violation_counts[key]
                    }
                )
            
            raise SecurityException("Access denied")
```

</details>

## Do's and Don'ts

**Do:**

- Derive tenant context from server-verified identity + current membership/service authorization.
- Use enforceable isolation boundary appropriate to data + threat model; database controls (RLS, schema + credential separation) can add defense in depth.
- Include tenant scope in queries, cache keys, storage boundaries when resource/result varies by tenant.
- Include tenant identity in rate limits + quotas when tenants share capacity or have tenant-level entitlements; keep needed global, endpoint, user, IP limits.
- Bound tenant consumption of other shared bottlenecks (queued work, concurrency, database connections, compute) when they can create cross-tenant availability impact.
- Carry verified tenant context through tenant-scoped async work; re-establish authorization at consumer.
- Log verified tenant context for tenant-scoped security + audit events.
- Enforce tenant ownership at boundary traversed by every tenant-owned access path.
- Separate encryption keys when risk/compliance requires cryptographic isolation.
- Apply + verify documented retention + deletion policy during offboarding.
- Authorize + test tenant-scoped restores, esp. when source backup contains other tenants.
- Monitor + alert on denied/unexpected cross-tenant access attempts.
- Shared-table PostgreSQL RLS using tenant setting: prefer transaction-local context, re-establish each transaction.
- Shared-table PostgreSQL RLS: inventory classified tenant-owned tables, test cross-tenant denial for each.
- Verify ordinary tenant-request database role cannot bypass row security when RLS = isolation boundary.

**Don't:**

- Treat tenant IDs from client headers/request params as authorization proof; selectors needing server-side verification.
- Use shared cache key for data/authorization varying by tenant.
- Rely on identifier complexity to prevent cross-tenant access.
- Allow ordinary tenant-owned request path to perform unscoped query; make any cross-tenant admin path explicit, separately authorized, auditable.
- Store tenant-owned data without enforceable tenant association/isolation boundary; literal `tenant_id` column not required by every architecture.
- Give tenant-scoped credential access to other tenants. Explicitly cross-tenant service credentials need own least-privileged scope + controls.
- Skip authorization merely because service internal.
- Treat tenant identifier in queued message as authorization proof without authenticating producer path + authorizing consumer operation.
- Allow one tenant unbounded consumption of shared queue, worker pool, connection pool, or other resource that can degrade other tenants.
- Retain tenant data beyond documented retention policy without contractual/legal basis + appropriate access restrictions.
- Restore shared snapshot over live data to recover only one tenant.
- Log sensitive tenant data in plain text.
- Serve ordinary tenant-scoped PostgreSQL RLS request paths w/ superuser or `BYPASSRLS` role.
- Use session-scoped database tenant setting across pooled requests without reliable reset-on-checkout or equivalent isolation + connection-reuse tests; prefer transaction-local settings.

## References

- AWS SaaS Lens: Tenant Isolation
- PostgreSQL: Row Security Policies
- Microsoft: Messaging in Multitenant Solutions
