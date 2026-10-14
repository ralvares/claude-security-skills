# Secure Integration of Third-Party Payment Gateways Cheat Sheet

## Introduction

Third-party gateways outsource payment processing, handle cardholder data, reduce PCI DSS scope if integrated correctly.

Insecure integration → payment spoofing, order manipulation, fraud, business logic flaws. Sheet covers general flow, failure points per step, mitigations.

## Understanding the Payment Flow

Typical flow, five steps:

1. **Cart Preparation**  
   User selects items, starts checkout.

2. **Order Initialization (Merchant Backend → Payment Gateway)**  
   Backend creates transaction/order via API, receives `order_id` or `payment_url`.

3. **User Redirection to Payment Gateway**  
   User redirected to gateway-hosted payment page.

4. **Payment Execution (User → Gateway)**  
   User completes or fails payment.

5. **Return and Verification (Payment Gateway → Merchant)**  
   User redirected to merchant (callback/return URL); gateway optionally sends server-to-server notification. Merchant verifies result, then fulfills order.

![Payment integration sequence flow](../assets/third_party_integration_workflow.png)

---

## What Can Go Wrong at Each Step and How to Prevent It

### 1. Sending Order data

**Risks:**

- Price tampering/product substitution via client-side manipulation.
- Missing server-side cart validation.

**Mitigations:**

- Validate all cart details (product IDs, prices, discounts) on backend.
- Recalculate totals server-side from trusted data before order creation.

---

### 2. Redirect to webhook

**Risks:**

- Trusting unauthenticated/spoofed callbacks.
- Processing orders before verifying payment status.
- Race conditions from multiple callbacks.
- Callback replay → repeated fulfillment (e.g., multiple shipments, account credits).
- Trusting user redirection parameters (untrusted, manipulable).

**Mitigations:**

- Validate all cart details (product IDs, prices, discounts) on backend.
- Always verify payment status server-side via gateway API before fulfilling.
- Match expected amount, currency, order ID.
- Validate callback authenticity (e.g., HMAC signatures, secret tokens).
- Idempotency: process order once regardless of callback count.
- Treat checkout expiry separately from webhook signature freshness. Gateways can retry delivery or send events out of order; verify late notifications, reconcile current payment state, don't discard solely because checkout expired. Use persistent duplicate-event records + idempotent fulfillment per [Webhook Security Cheat Sheet](Webhook_Security.md#idempotency-and-duplicate-events).
- Trust only server-to-server callbacks for payment verification and fulfillment.
- Log all callback attempts for forensics.

## Logging and Monitoring

**Why it matters:**
Monitoring detects abuse, fraud attempts, misbehavior even when validation/logic are correct.

**Recommendations:**

- Log all payment attempts (initiation, redirects, callbacks) w/ timestamps, IPs.
- Alert on:
    - Unexpected order statuses (e.g., "Paid" w/o gateway confirmation).
    - Excessive callback attempts for same order.
    - Payment failures followed by repeated attempts w/ identical data.
- Log callback identifiers, validation outcomes, order correlation data, not raw headers/bodies. Exclude credentials, unnecessary personal/payment data; apply [Logging Cheat Sheet's data-exclusion guidance](Logging.md#data-to-exclude).
- Don't retain sensitive authentication data (card verification codes, PIN data) after authorization, even if encrypted (PCI). Restrict access to permitted investigation records; define retention period.
- Add fraud/risk scoring to detect carding attacks, other suspicious activity during payment execution.

---

## References

- OWASP WSTG: Payment Functionality
- Adyen: API idempotency
- Adyen: Verify HMAC signatures
