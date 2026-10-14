# Serverless / FaaS Security Cheat Sheet

## Introduction

Serverless (Functions as a Service, FaaS) platforms: AWS Lambda, Azure Functions, Google Cloud Functions. Execution model (short-lived, event-driven functions in managed environments) adds unique security risks vs traditional architectures.

Best practices to secure serverless apps, minimize attack surface.

## Key Risks

- Over-permissioned functions (broad IAM roles, `*` policies).
- Unvalidated event inputs (API Gateway, S3, Pub/Sub, IoT).
- Cold start data leakage (persistent state, side-channel timing).
- Function chaining abuse (compromised function invoking others).
- Shared environment risks (multi-tenant leakage, `/tmp` reuse).
- Hardcoded secrets in code/platform config.
- Excessive network access.

## Best Practices

### 1. Principle of Least Privilege

- Minimal IAM permissions per function.
- Role-per-function (no shared high-privilege roles).
- Scope database/API keys to smallest action set needed.

**Bad IAM Policy (too broad):**

```json
{
  "Effect": "Allow",
  "Action": "*",
  "Resource": "*"
}
```

**Good IAM Policy (scoped):**

```json
{
  "Effect": "Allow",
  "Action": ["dynamodb:GetItem", "dynamodb:PutItem"],
  "Resource": "arn:aws:dynamodb:us-east-1:123456789012:table/Orders"
}
```

### 2. Environment Isolation

- Disable default network access unless required (e.g. outbound internet access).
- Functions in private subnets w/ controlled egress.
- Isolate sensitive functions (e.g. payment, auth) from general-purpose ones.
- Separate production vs. staging w/ strict boundaries.

**AWS Lambda VPC Config (restrictive):**

```yaml
VpcConfig:
  SubnetIds:
    - subnet-123456
  SecurityGroupIds:
    - sg-restrict-outbound
```

### 3. Secure Function Invocation

- Enforce authentication + authorization on all triggers (API Gateway, Pub/Sub, S3, IoT).
- Validate function-to-function calls w/ signed tokens or workload identities.
- Rate limiting + throttling vs DoS/abuse.

**API Gateway Authorizer Example (JWT validation):**

```json
{
  "Type": "JWT",
  "IdentitySource": "$request.header.Authorization",
  "Issuer": "https://secure-idp.example.com/",
  "Audience": "my-api-client"
}
```

### 4. Event Data Validation

- Treat all event payloads as untrusted.
- Strong input validation & sanitization (length, type, format).
- Protect vs injection (SQLi, XSS, JSON injection, deserialization).
- Strip unnecessary fields/metadata before processing.

Example: Python input validation for Lambda

```python
import json
import re

def lambda_handler(event, context):
    body = json.loads(event["body"])
    email = body.get("email", "")

    if not re.match(r"[^@]+@[^@]+\.[^@]+", email):
        return {"statusCode": 400, "body": "Invalid email"}

    # process safely
    return {"statusCode": 200, "body": "OK"}
```

### 5. Cold Start & Execution Context Security

- Don't assume runtime context clean between invocations.
- No secrets/temporary sensitive data in global/static variables.
- Protect vs side-channel leaks (timing differences, leftover files in /tmp).
- Sensitive workloads: enforce single-use execution environments if platform supports.

**Bad:**

```python
# Secret stays in global variable across invocations
SECRET_KEY = "hardcoded-secret"
```

**Good:**

```python
import os
from my_secrets_lib import get_secret

def lambda_handler(event, context):
    secret = get_secret("db-password")  # fetch fresh each time
    ...
```

### 6. Secrets Management

Secret lifecycle: [Secrets Management Cheat Sheet](Secrets_Management.md).

- Fetch secrets at runtime from vault/caching extension, not platform-level function config (e.g. Lambda Environment Variables).
- Ephemeral credentials (STS, workload identity federation).
- Rotate secrets automatically.

**AWS Lambda Secret Fetch (Python via Parameters and Secrets Extension):**

**Note:** AWS Lambda Parameters and Secrets Extension must be added + enabled for function (e.g., as Lambda layer). Otherwise `http://localhost:2773` unavailable, requests fail.

```python
import os
import json
import urllib.request
import urllib.parse

def get_secret(secret_name):
    """
    Retrieves a secret using the AWS Lambda Extension local endpoint.
    This method is faster and more cost-effective due to local caching.
    """
    # The extension provides a local HTTP endpoint on port 2773
    encoded_name = urllib.parse.quote_plus(secret_name)

    secrets_extension_endpoint = (
        f"http://localhost:2773/secretsmanager/get?secretId={encoded_name}"
    )

    # Authenticate using the identity token provided by the Lambda environment.
    # Fail fast if the token is missing to avoid confusing 4xx errors.
    session_token = os.environ.get("AWS_SESSION_TOKEN")
    if not session_token:
        raise RuntimeError(
            "Missing AWS_SESSION_TOKEN required for "
            "Parameters and Secrets Extension authentication."
        )

    headers = {
        "X-Aws-Parameters-Secrets-Token": session_token
    }

    request = urllib.request.Request(
        secrets_extension_endpoint,
        headers=headers,
        method="GET"
    )

    with urllib.request.urlopen(request, timeout=3) as response:
        if response.status != 200:
            raise Exception(
                f"Error retrieving secret: {response.read().decode('utf-8')}"
            )

        response_json = json.loads(response.read())
        secret_string = response_json["SecretString"]

        return json.loads(secret_string)
```

### 7. Monitoring & Logging

- Centralized logging (CloudWatch, Azure Monitor, GCP Logging).
- Mask secrets + PII.

Example: Redacting fields

```python
import logging

def log_event(event):
    safe_event = {k: ("***" if "password" in k else v) for k,v in event.items()}
    logging.info(safe_event)
```

### 8. Supply Chain Security

- Scan dependencies (`npm audit`, `pip-audit`, `safety`).
- Minimal deployment packages.
- Sign deployment packages; verify signatures vs approved publisher before deployment. Checksum alone doesn't authenticate publisher.

AWS Lambda: use code signing configurations w/ allowed signing profiles + `UntrustedArtifactOnDeployment` set to `Enforce`; default `Warn` allows deployments failing expiry, publisher, or revocation checks. Layers added to code-signing-enabled functions must also be signed by allowed profile.

## Do’s and Don’ts

**Do**:

- Least privilege per function.
- Validate all event inputs.
- Fetch secrets from vaults, not platform config.
- Restrict network egress.
- Monitor invocations + logs.

**Don’t**:

- Hardcode secrets in code/configs.
- Assume clean runtime between invocations.
- Give `*` IAM permissions.
- Leave sensitive data in `/tmp`/globals.
- Trust event sources blindly.

## References

- AWS Lambda: Best practices
- Azure Functions: Security concepts
- Google Cloud Run: Security
