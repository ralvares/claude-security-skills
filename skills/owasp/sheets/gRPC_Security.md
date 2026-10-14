# gRPC Security Cheat Sheet

## Introduction

gRPC (gRPC Remote Procedure Call) = high-performance language-neutral RPC framework; HTTP/2 transport, Protocol Buffers serialization. Large performance advantages for microservices/distributed systems, but unique security challenges vs REST APIs.

Sections cover essential controls protecting gRPC services from common attack vectors.

## Transport Security

### Always Use TLS in Production

Production needs TLS encryption against eavesdropping and man-in-the-middle.

```go
// Go - Secure server with TLS
creds, err := credentials.NewServerTLSFromFile(certFile, keyFile)
if err != nil {
    log.Fatalf("Failed to load TLS credentials: %v", err)
}
s := grpc.NewServer(grpc.Creds(creds))
```

Configure TLS 1.2 or higher w/ strong cipher suites; disable weak protocols/ciphers.

### Implement Mutual TLS (mTLS) for Service-to-Service Communication

mTLS = mutual authentication; client and server verify each other's certificates → zero-trust communication.

```go
// Go - mTLS client configuration
cert, err := tls.LoadX509KeyPair(clientCertFile, clientKeyFile)
caCert, err := ioutil.ReadFile(caCertFile)
caCertPool := x509.NewCertPool()
caCertPool.AppendCertsFromPEM(caCert)

creds := credentials.NewTLS(&tls.Config{
    Certificates: []tls.Certificate{cert},
    RootCAs:      caCertPool,
})
conn, err := grpc.Dial(address, grpc.WithTransportCredentials(creds))
```

Short-lived certificates (90 days or less) w/ automated rotation limit compromised-key impact.

## Authentication and Authorization

### Implement Strong Authentication

Authentication checks for each protected service method.

#### Token-Based Authentication

Following unary server interceptor illustrates authentication for unary RPCs only. Register with server; protected streaming RPCs need equivalent checks in stream server interceptor before invoking stream handler. Registering unary interceptor doesn't protect streaming methods.

```go
// Go - JWT token validation interceptor
func authInterceptor(ctx context.Context, req interface{}, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (interface{}, error) {
    md, ok := metadata.FromIncomingContext(ctx)
    if !ok {
        return nil, status.Errorf(codes.Unauthenticated, "missing metadata")
    }
    
    tokens := md["authorization"]
    if len(tokens) == 0 {
        return nil, status.Errorf(codes.Unauthenticated, "missing authorization token")
    }
    
    token := strings.TrimPrefix(tokens[0], "Bearer ")
    if !validateJWT(token) {
        return nil, status.Errorf(codes.Unauthenticated, "invalid token")
    }
    
    return handler(ctx, req)
}
```

#### API Key Authentication

```go
// Go - API key validation
func validateAPIKey(ctx context.Context) error {
    md, ok := metadata.FromIncomingContext(ctx)
    if !ok {
        return status.Error(codes.Unauthenticated, "missing metadata")
    }
    
    keys := md["x-api-key"]
    if len(keys) == 0 || !isValidAPIKey(keys[0]) {
        return status.Error(codes.Unauthenticated, "invalid API key")
    }
    return nil
}
```

Implement token expiration + refresh w/ short-lived tokens (15-60 minutes). Avoid credentials in gRPC method parameters; use metadata headers.

### Enforce Granular Authorization

Method-level authorization checks, least privilege.

```go
// Go - Role-based authorization
func authorizeMethod(ctx context.Context, methodName string, userRoles []string) error {
    requiredRole, exists := methodPermissions[methodName]
    if !exists {
        return status.Errorf(codes.PermissionDenied, "method not found")
    }
    
    for _, role := range userRoles {
        if role == requiredRole {
            return nil
        }
    }
    
    return status.Errorf(codes.PermissionDenied, "insufficient permissions")
}
```

Log all authorization failures to detect attacks and compliance violations.

## Input Validation and Data Security

### Validate All Protocol Buffer Messages

Protocol Buffers give type safety, not business logic validation. Always validate thoroughly server-side.

```protobuf
// Use protoc-gen-validate for automatic validation
syntax = "proto3";
import "validate/validate.proto";

message CreateUserRequest {
  string email = 1 [(validate.rules).string.email = true];
  string name = 2 [(validate.rules).string = {min_len: 1, max_len: 100}];
  int32 age = 3 [(validate.rules).int32 = {gte: 0, lte: 150}];
}
```

Allowlist validation for string inputs prevents unexpected characters and injection attempts.

### Prevent Injection Attacks

Validate user input carefully when used in database queries or system operations.

```go
// Go - Safe database query with parameterization
func getUserByEmail(email string) (*User, error) {
    if !isValidEmail(email) {
        return nil, errors.New("invalid email format")
    }
    
    query := "SELECT id, name, email FROM users WHERE email = ?"
    row := db.QueryRow(query, email)
    
    var user User
    err := row.Scan(&user.ID, &user.Name, &user.Email)
    return &user, err
}
```

Always use prepared statements for database operations against [SQL injection](SQL_Injection_Prevention.md).

### Implement Message Size Limits

Set app-appropriate limits on individual messages both directions. grpc-go server's `MaxRecvMsgSize` already defaults to 4 MiB. Stream can still carry many individually valid messages → per-message limit doesn't bound total data or processing work for stream.

```go
// Go - Set message size limits
s := grpc.NewServer(
    grpc.MaxRecvMsgSize(4*1024*1024), // 4 MiB max receive
    grpc.MaxSendMsgSize(4*1024*1024), // 4 MiB max send
)
```

Limit streaming sessions and message counts against resource exhaustion. Monitor and enforce max messages per stream and max session duration.

## Rate Limiting and Resource Protection

### Implement Request Rate Limiting

Protect against request flooding and resource exhaustion. Example limits unary RPCs only. Apply stream admission limits via stream interceptor, enforce per-message limits within stream; limiting stream creation alone doesn't limit messages over existing stream.

```go
// Go - Illustrative unary rate limiting with bounded entry count
import (
    "golang.org/x/time/rate"
    "sync"
    "time"
)

type RateLimiterStore struct {
    limiters map[string]*rateLimiterEntry
    mu       sync.RWMutex
}

type rateLimiterEntry struct {
    limiter  *rate.Limiter
    lastSeen time.Time
}

var store = &RateLimiterStore{
    limiters: make(map[string]*rateLimiterEntry),
}

func rateLimitInterceptor(ctx context.Context, req interface{}, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (interface{}, error) {
    clientIP := getClientIP(ctx)
    
    store.mu.Lock()
    entry, exists := store.limiters[clientIP]
    if !exists {
        if len(store.limiters) >= maxLimiterEntries {
            store.mu.Unlock()
            return nil, status.Error(codes.ResourceExhausted, "limiter capacity reached")
        }
        entry = &rateLimiterEntry{
            limiter:  rate.NewLimiter(rate.Limit(10), 20), // 10 req/sec, burst 20
            lastSeen: time.Now(),
        }
        store.limiters[clientIP] = entry
    }
    entry.lastSeen = time.Now()
    store.mu.Unlock()
    
    if !entry.limiter.Allow() {
        return nil, status.Errorf(codes.ResourceExhausted, "rate limit exceeded")
    }
    
    return handler(ctx, req)
}

// Cleanup old limiters periodically
func cleanupOldLimiters() {
    store.mu.Lock()
    defer store.mu.Unlock()
    
    cutoff := time.Now().Add(-time.Hour)
    for ip, entry := range store.limiters {
        if entry.lastSeen.Before(cutoff) {
            delete(store.limiters, ip)
        }
    }
}
```

Configure `maxLimiterEntries` as positive cap from process memory budget. Schedule `cleanupOldLimiters` in service lifecycle; defining it doesn't run it. At capacity, illustration rejects new client keys while retaining existing limits → monitor saturation and effect on legitimate clients. Derive client keys from trusted connection or authenticated identity, not arbitrary forwarded headers.

Each `rate.Limiter` limits events for one key; doesn't bound number of keys in map. Store local to one process. Use maintained shared rate-limiting service when limits must apply across replicas.

### Set Appropriate Timeouts

Timeouts prevent resource exhaustion from long-running requests.

```go
// Go - Server-side timeout for resource protection
func (s *server) GetUser(ctx context.Context, req *pb.GetUserRequest) (*pb.User, error) {
    // Check if client already set a deadline
    if deadline, ok := ctx.Deadline(); ok && time.Until(deadline) < 5*time.Second {
        return processGetUser(ctx, req)
    }
    
    // Set defensive timeout to prevent resource exhaustion
    ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
    defer cancel()
    
    return processGetUser(ctx, req)
}
```

Configure client-side and server-side timeouts for use case.

## Error Handling and Information Disclosure

### Secure Error Responses

Detailed errors reveal system internals. Return generic messages, log details server-side.

```go
// Go - Secure error handling
func (s *server) ProcessPayment(ctx context.Context, req *pb.PaymentRequest) (*pb.PaymentResponse, error) {
    if err := validatePayment(req); err != nil {
        // Log detailed error server-side
        log.Printf("Payment validation failed for user %s: %v", getUserID(ctx), err)
        // Return generic error to client
        return nil, status.Error(codes.InvalidArgument, "invalid payment request")
    }
    
    // Continue processing...
}
```

Use proper gRPC status codes: `UNAUTHENTICATED` auth failures, `PERMISSION_DENIED` authorization failures, `INVALID_ARGUMENT` validation errors.

### Implement Structured Logging

Log security events to detect attacks, investigate incidents: authentication attempts, authorization failures, suspicious activities.

```go
// Go - Security event logging
func logSecurityEvent(event string, userID string, clientIP string, success bool) {
    log.Printf("SECURITY_EVENT: %s | User: %s | IP: %s | Success: %t | Time: %s",
        event, userID, clientIP, success, time.Now().UTC().Format(time.RFC3339))
}
```

Include correlation IDs to track requests across distributed services; ensure logs contain no sensitive data like passwords or tokens.

## Service Discovery and Reflection

### Disable gRPC Reflection in Production

Reflection lets clients discover service methods/message schemas at runtime; valuable for development/debugging, but gives attackers detailed API surface info → easier targeted attacks.

```go
// Go - Conditional reflection (development only)
if os.Getenv("ENVIRONMENT") != "production" {
    reflection.Register(s)
}
```

### Secure Service Discovery

Protect service discovery against attackers injecting malicious service endpoints or intercepting service info.

**Consul with mTLS:**

```go
consulConfig := &api.Config{
    Address:    "consul.example.com:8500",
    Scheme:     "https",
    TLSConfig: &api.TLSConfig{
        CertFile: "/path/to/client.crt",
        KeyFile:  "/path/to/client.key",
        CAFile:   "/path/to/ca.crt",
    },
}
```

**Kubernetes RBAC:**

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: grpc-service-discovery
rules:
- apiGroups: [""]
  resources: ["services", "endpoints"]
  verbs: ["get", "list", "watch"]
```

Service mesh (Istio, Linkerd) gives automatic mTLS + centralized security policies.

## Monitoring and Incident Response

### Implement Security Monitoring

Monitor gRPC services for security events and attacks.

Key metrics:

- Request rates per method and client
- Authentication and authorization failure rates
- Error rates and types
- Unusual traffic patterns

Alerts for:

- High authentication failure rates
- Attempts to access non-existent methods
- Resource exhaustion patterns

### Enable Distributed Tracing

Track requests across microservices for security analysis.

```go
// Go - OpenTelemetry tracing with security context
tracer := otel.Tracer("grpc-service")
ctx, span := tracer.Start(ctx, "grpc.method.call")
defer span.End()

span.SetAttributes(
    attribute.String("grpc.method", info.FullMethod),
    attribute.String("client.ip", getClientIP(ctx)),
)
```

## Testing and Validation

### Perform gRPC Security Testing

Include gRPC-specific security tests in dev pipeline.

Test categories:

- Authentication bypass attempts
- Authorization boundary testing
- Input validation and injection testing
- Rate limiting effectiveness
- Message size limit enforcement

Use `grpcurl` and custom test clients to verify controls.

```bash
# Test authentication requirement
grpcurl -plaintext localhost:50051 list
grpcurl -plaintext localhost:50051 myservice.MyService/GetUser

# Test with invalid tokens
grpcurl -plaintext -H "authorization: Bearer invalid_token" \
  localhost:50051 myservice.MyService/GetUser
```

### Security Assessment Guidelines

- Test all gRPC methods for proper authentication and authorization
- Verify input validation on all message fields
- Test rate limiting and resource exhaustion protections
- Validate TLS configuration and certificate handling
- Check for information disclosure in error messages

## Language-Specific Considerations

### Go

- Interceptors for cross-cutting security concerns
- `context` package for request-scoped security info
- Configure TLS explicitly; Go's gRPC requires manual TLS setup

### Java

- Use Java's security ecosystem (Spring Security, etc.)
- Configure Netty properly for TLS settings
- Ensure ALPN support for HTTP/2

### Python

- Validate all inputs; dynamic typing can hide type issues
- Secure credential management for certificate storage
- Mind GIL limits in high-concurrency scenarios

### C# (.NET)

- Use ASP.NET Core's built-in security features
- `[Authorize]` attribute on service methods
- Configure HTTPS properly in production

## References

- gRPC Authentication Documentation
- gRPC: Deadlines
- gRPC: Reflection
