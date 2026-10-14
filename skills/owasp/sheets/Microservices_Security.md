# Microservices Security Cheat Sheet

## Introduction

Microservice architecture increasingly used for cloud + on-premise, high-scale systems. Many security challenges in design + implementation. Fundamental design-phase requirements: authentication + authorization. Security architects must understand + properly use existing architecture patterns for authN/authZ in microservices systems. Goal: identify such patterns, recommend ways to use them.

## Edge-level authorization

Use gateway checks to reject unauthorized ingress requests; prevent direct access bypassing those checks. Keep fine-grained authorization at service when it needs resource/business context. See [Authorization Patterns](Authorization_Patterns.md#gateway-and-proxy-enforcement) for gateway/proxy enforcement, limitations, propagated authorization context.

## Service-level authorization

Each service must enforce access to its protected operations, incl. internal calls. Prefer shared, reviewed policies as system grows; service-level enforcement of object, tenant, business-specific rules. See [Authorization Patterns](Authorization_Patterns.md#service-level-authorization) for policy placement, [Policy and Data Distribution](Authorization_Policy_And_Data_Distribution.md) for update/outage handling. Gateway checks complement these; do not establish downstream operation is authorized.

## External Entity Identity Propagation

Propagate authenticated user context in form each receiving service can validate; authenticate calling service separately. Signature protects assertion integrity; does not itself grant access to requested resource. See [Identity Propagation Patterns](Identity_Propagation_Patterns.md) for forwarding, token exchange, trusted internal assertions, limitations.

## Service-to-service authentication

### Existing patterns

#### Mutual transport layer security

mTLS: each microservice can legitimately identify peer, plus confidentiality + integrity of data. Each microservice carries public/private key pair, authenticates to recipients via mTLS. Usually implemented w/ self-hosted Public Key Infrastructure. Main challenges: key provisioning + trust bootstrap, certificate revocation, key rotation.

#### Token-based

Works at application layer. Token = container that may hold caller ID (microservice ID) + permissions (scopes). Caller obtains signed token from security token service using own service ID + password, attaches to every outgoing request (e.g., HTTP headers). Called microservice extracts token, validates online or offline.
![Signed ID propagation](../assets/Token_validation.png)

Choose token validation by required revocation response time, token lifetime, availability requirements:

1. Online validation:
    - Microservice queries token service. OAuth token introspection reports whether token active; can reflect revocation known to authorization server.
    - Network calls add latency + dependency on token service availability. Caching introspection responses delays revocation detection; bound cache duration to required freshness, never beyond token expiry.
2. Local validation:
    - Microservice validates signed token using trusted issuer keys + applicable token profile. E.g., RFC 9068 defines validation for JSON Web Token (JWT) access tokens; signature verification alone insufficient. See [validation at each boundary](Identity_Propagation_Patterns.md#validation-at-each-boundary).
    - Avoids per-request introspection call, but alone does not detect server-side revocation before token expiry. Use token lifetimes or additional revocation mechanism meeting required response time.

Neither approach replaces service-level authorization. Reject requests when required token validation cannot be completed.

Token-based authN usually runs over TLS (confidentiality + integrity in transit).

## Logging

Logging in microservice systems serves accountability + traceability, helps detect security anomalies via log analysis. Architects must understand + use existing patterns for audit logging. High-level architecture (picture below) based on:

- Each microservice writes log message to local file via standard output (stdout, stderr).
- Logging agent periodically pulls log messages, publishes to message broker (e.g., NATS, Apache Kafka).
- Central logging service subscribes to broker, receives + processes messages.
![Logging pattern](../assets/ms_logging_pattern.png)

Recommendations for logging subsystem architecture, w/ rationale:

1. Buffer logs locally so temporary downstream outage does not immediately interrupt collection. Local files do not guarantee lossless delivery: storage limits, rotation, node loss can remove records before shipping. E.g., Kubernetes documents container log rotation + eviction behavior.
2. Run dedicated logging agent on same host to collect + forward local logs. After agent failure, can resume shipping only records still retained locally.
3. Use message broker to decouple collection from central processing. Define buffer limits + behavior when storage fills, monitor delivery failures, test recovery from outages; see [logging verification](Logging.md#verification). Broker alone does not prevent log loss or denial of service.
4. Logging agent + message broker shall use mutual authentication (e.g., TLS-based) to encrypt all transmitted data (log messages) + authenticate themselves:
    - mitigates: microservice spoofing, logging/transport system spoofing, network traffic injection, sniffing
5. Message broker shall enforce access control policy to mitigate unauthorized access, implement least privilege:
    - mitigates microservice elevation of privileges
6. Exclude secrets + unnecessary sensitive data before microservice emits log entry, incl. to local files or stdout. Agent-side filtering = additional safeguard; cannot remove sensitive data already in local logs. Follow [OWASP Logging Cheat Sheet guidance on data to exclude](Logging.md#data-to-exclude).
7. Microservices shall generate correlation ID uniquely identifying every call chain, to group log messages for investigation. Logging agent shall include correlation ID in every log message.
8. Logging agent shall periodically provide health + status data indicating availability/non-availability.
9. Logging agent shall publish log messages in structured format (e.g., JSON, CSV).
10. Logging agent shall append context data to log messages, e.g., platform context (hostname, container name), runtime context (class name, filename).

Events to log + data format: [OWASP Logging Cheat Sheet](Logging.md#which-events-to-log), [Application Logging Vocabulary Cheat Sheet](Logging_Vocabulary.md)

## References

- NIST SP 800-204: Security Strategies for Microservices-Based Application Systems
- NIST SP 800-204A: Building Secure Microservices-Based Applications Using Service-Mesh Architecture
