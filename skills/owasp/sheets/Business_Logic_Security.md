# Business Logic Security Cheat Sheet

## Introduction

Business logic vulnerabilities = flaws in how app implements intended workflow. Not missing input sanitization or unescaped output. Code does what developer told it, but that ≠ what business needs. User skips required step, submits requests out of order, pays negative price, stacks unplanned coupons, wins race vs server bookkeeping.

Generic scanners often miss these: lack business rules. Automated analysis can detect some patterns, incl. workflow enforcement weaknesses (CWE-841). Combine tools w/ review and testing that checks intended business process.

Covers practical patterns preventing business logic abuse, aimed at developers building features, not pen testers. Testing guidance: OWASP Web Security Testing Guide, Business Logic Testing section.

Key takeaways:

- Always re-derive security-relevant values (prices, permissions, ownership) server-side. Client state = input, not truth.
- Enforce workflows as explicit state machines. Don't rely on UI to gate step order.
- Concurrency = real threat. If two requests can race, assume they will.
- Rate-limit and monitor per feature, not just authentication. Abuse-friendly features (referrals, coupons, password reset) need own controls.
- Threat model from business process, not just technical architecture. Ask what happens if user acts dishonestly, not just if attacker sends malicious payload.

## Why Business Logic Flaws Are Different

Well-known web vulns (SQL injection, XSS, CSRF, path traversal) have clear technical signature; scanner can fuzz parameters, look for reflected payloads, produce reasonable report. Business logic flaws often need extra knowledge of intended workflow.

Example e-commerce checkout: server accepts product ID, quantity, coupon code. Every input validated: product ID exists, quantity positive integer, coupon matches known pattern. No technical rule broken. But app recalculates total from client-submitted price instead of server-side lookup → user pays one cent for television. Business logic bug; input validation can't help, input syntactically perfect.

Patterns repeat across industries:

- App assumes client respects multi-step order, exposes each step's endpoint w/o checking previous steps completed.
- System trusts user-controlled data (price, account balance, user role) from request body because UI never shows how to change it.
- Endpoint does two operations (check balance, then debit) w/o lock → two concurrent requests both pass check, both debit.
- Feature rewarding legitimate use (referrals, points, promo credits) has no controls vs one user creating many accounts.

Review these patterns against app's business rules; clean scanner report doesn't show rules enforced.

## Always Re-derive Security-relevant Values Server-side

If request value influences price, access, ownership, or state: assume client made it up, recompute from trusted data.

### Prices and Totals

Never accept price, subtotal, tax, or total from client. Accept product identifiers and quantities only; compute rest server-side from own database. Same for discounts: accept coupon code, validate and apply discount server-side. No "discount amount" field from request.

| Client sends | Server should | Server should not |
|---|---|---|
| Product ID and quantity | Look up the price, compute line total | Accept a price field and trust it |
| Coupon code | Validate and apply the discount itself | Accept a "discounted total" field |
| Shipping selection | Compute cost from its own rate table | Accept a shipping cost field |
| Tax-exempt flag | Determine from account state | Accept a client-supplied exemption |

Extends beyond commerce. Social app shouldn't accept client "post visibility" if derived from user's privacy settings. Banking app shouldn't accept client-calculated "source account balance".

### Permissions and Ownership

Re-check ownership on every request acting on a resource. Don't rely on URL, referrer, or request-body flag. Backend asks: "Is authenticated user allowed to perform this action on this object, right now?"

Common mistake: check ownership once at resource load, trust later requests referencing it. Each request independent; authorize each on its own.

### Identity and Role

Never accept user ID, tenant ID, or role from request body, unless request is explicitly administrative action by privileged caller, and even then validate value against what caller may manage. Acting user's identity always from server-side session or token, never user-editable field.

## Enforce Workflows as Explicit State Machines

Multi-step processes (signup, checkout, approvals, KYC, password reset) = prime targets: often implemented as page sequence UI walks user through. If only UI enforces sequence, attacker sending requests directly can skip steps, repeat steps, or reach terminal steps w/o prerequisites.

### Model State on the Server

Every multi-step workflow needs explicit server-stored state, keyed to user or session. Validate each transition vs current state.

Minimal pattern:

1. Workflow start: create record w/ initial state (e.g., `awaiting_email_verification`).
2. Each step endpoint checks current state, performs action, updates state to next valid value.
3. Request for step not matching current state → reject.
4. Terminal actions (submit order, approve, transfer funds) run only if state exactly what action requires.

### Don't Use Hidden Form Fields as State

Common: "current step" stored as hidden form field, or client-readable cookie. Not enforcement; client sets any value. State lives server-side, in storage client can't write.

### Reject Replays of Completed Steps

Completed step re-run attempts should fail. Esp. one-time operations: signup bonus, coupon redemption, voucher claim, referral reward. Cleanest: mark operation complete in persistent storage, treat re-run attempts as errors.

### Expire Partial States

Workflows pausing for user input (email verification, bank transfer confirmation, multi-step KYC) need deadline. No progress within bounded time → invalidate partial state, require restart. Long-lived half-completed workflows accumulate, frequent source of exploitable inconsistencies.

## Prevent Race Conditions on Sensitive Operations

Any read-decide-write operation = potential race. Concurrent requests both read old value, both decide same, both write. Drains loyalty points, makes balances negative, single-use coupons redeemed many times, one-per-account bonuses become many-per-account.

### Identify the Critical Sections

Find operations shaped "check condition, then act". Typical:

- Check balance, then debit.
- Check coupon unused, then record use.
- Check user has fewer than N items, then add one.
- Check slot available, then book.
- Check referral code not applied to account, then apply.
- Check registration request unique, then insert new user record.

Each = race unless check and act in single atomic operation.

### Use Database Transactions and Locks

Most broadly available fix: database transaction w/ right isolation level. Default isolation in most databases: check and update run separately, another transaction can slip between. For atomic operations use one of:

- `SERIALIZABLE` transaction isolation level. DB detects conflicts, rolls back one competing transaction.
- Explicit row lock (`SELECT ... FOR UPDATE` in PostgreSQL, MySQL InnoDB, similar). Second caller blocks until first commits.
- Conditional update (`UPDATE ... WHERE balance >= amount`) succeeding only if predicate still holds at write time. Check affected row count. Zero → check failed, caller sees error.

### Use Idempotency Keys for External Actions

External actions e.g. charging card: use provider's idempotency mechanism, reuse same key when retrying same operation. Follow its key-generation, parameter-matching, retention rules; e.g., Stripe rejects changed parameters and can treat key as new after stored record expires.

Own API: scope stored keys to authenticated caller and operation, bind to original request parameters, reject reuse w/ different parameters. Authorize request before returning cached result; possessing key ≠ authorization. Coordinate concurrent requests atomically so only one starts action; record state and result durably. AWS describes caller-scoped identifiers, atomic processing, parameter-mismatch checks.

Define retry and retention window, incl. recovery when external result unknown. Local database transaction alone can't make external side effect atomic w/ saving its result. After retry window expires, reconcile external outcome before resubmitting.

### Don't Assume "Fast Enough"

Rationalization "check-to-update window is microseconds, no attacker can exploit" is wrong. Concurrent request tools trivially send dozens of requests arriving within a millisecond. Modern bug bounty tooling sends them as single multiplexed HTTP/2 request → land effectively simultaneously. Window exists at all → assume exploitable.

### Pattern Reference

| Operation shape | Safe pattern |
|---|---|
| Read-modify-write on a single row | `SELECT ... FOR UPDATE` then `UPDATE`, inside a transaction |
| Conditional decrement on a counter | `UPDATE ... SET value = value - 1 WHERE value > 0`, check affected rows |
| One-per-user bonus | Unique constraint on (user_id, bonus_type) and let the database reject duplicates |
| External non-idempotent call | Provider-supported idempotency, with durable state for retries and recovery |
| Cross-row consistency | Serializable transaction with explicit retry logic |

## Protect Abuse-friendly Features

Features dispensing value in response to user actions = abuse magnets: referral bonuses, promo codes, signup credits, free trials, email reminders, password reset flows, account recovery paths, anything sending messages or making outbound requests. Need own controls beyond app-wide authentication controls.

### Abuse Patterns to Design Against

- **Multi-accounting.** One human, many accounts, claims one-per-account rewards repeatedly. Ask whether signup makes this trivially cheap; consider detection signals.
- **Self-referral.** User refers self via second account. Referral flows check referrer and referee are distinguishable humans, not just distinguishable accounts.
- **Coupon stacking.** Promos meant standalone combined to push price below cost. Coupon engine allowing stacking by default is probably a bug.
- **Free trial resets.** User cancels, re-signs up repeatedly to stay on free tier. Track trial eligibility by something more stable than email address.
- **Resource exhaustion.** Features sending email, making outbound HTTP calls, triggering webhooks, or running expensive on-demand computations = DoS and spam vectors unless rate-limited.
- **Enumeration through behavior.** Password reset endpoint returning different messages for valid/invalid emails leaks account existence.

### Controls to Apply

- **Per-feature rate limits.** Global edge limit not enough. Signup-bonus, referral, promo-redemption endpoints each need own limits.
- **Identity signals beyond email.** Device fingerprints, payment-method fingerprints, phone number verification, KYC verification carry more signal than email addresses (cheap to create in bulk).
- **Audit trails on value-dispensing operations.** Log every issued credit, applied promo, granted bonus w/ triggering user, target user, IP, timestamp. Log is how to untangle suspected abuse.
- **Maximums at every layer.** Per-action cap (e.g., one bonus per account) + per-account cap (e.g., total lifetime promo value) + per-source cap (e.g., per payment method or device) = defense in depth.
- **Asymmetric consequences.** Value-giving actions harder than non-value actions. Making someone wait 30 seconds, or complete CAPTCHA, to claim reward is fine: legitimate user clicks once, automated abuser pays per-request cost.

## Threat Model from the Business Process

See [Abuse Case Cheat Sheet](Abuse_Case.md) for identifying misuse scenarios.

Most threat modeling is technical: data flow diagrams, trust boundaries, STRIDE. Useful but misses bugs where code is technically correct and process is the problem. Business logic threat modeling asks different questions.

### Questions to Ask Early

- What does legitimate user do in this feature, step by step?
- What does system do at each step; what assumption about user's intent?
- Which assumptions would benefit user if false? (Bugs live there.)
- Can user act out of order? Skip a step? Repeat a step?
- Can two users act on same object at same time?
- Can one user act from two directions at once (e.g., two tabs, two devices)?
- What does feature produce that has value? (Credits, access, trust, messages, outbound requests.)
- If adversary tried exploiting feature for gain, how?
- What invariant must always hold (e.g., "a coupon can only be used once", "an account balance can never be negative")? What enforces it; is enforcement atomic?

### The "Dishonest User" Exercise

Take feature spec; imagine user whose only goal is max value while staying within letter of system rules. What would they do? Which combination of legitimate actions yields illegitimate outcome? Differs from technical attacker: dishonest user sends no malicious payloads, uses app exactly as designed, in order or volume designer didn't anticipate.

### Write Down the Invariants

For any feature handling value, ownership, or state, write invariants in plain English:

- A user cannot approve their own request.
- A coupon code is valid for one redemption per user, and never more than N total.
- A transfer cannot complete if it would leave the source account below zero.
- A workflow reaches the "approved" state only after both reviewer A and reviewer B have approved.

For each invariant, identify exactly what code enforces it. Answer "the UI" or "the user won't try that" → invariant not enforced.

## Authorization at the Business-logic Layer

Technical authorization (authenticated? has role?) necessary, not sufficient. Many business logic bugs = authorization bugs in disguise: user has general permission for feature, but specific action violates rule system didn't check.

### Contextual Authorization

Check not just "can this user do X" but "can this user do X on this object, in this state, right now".

Examples:

- Manager can approve expense reports, but not own.
- Reviewer can approve pull request, but not if authored it.
- User can cancel order, but not after shipped.
- User can change email, but not to address already in use, and not w/o verifying new address.

Checks are business logic, not authentication layer. Typically need knowledge auth middleware lacks. Keep close to operation guarded.

### Avoid "Implicit" Permissions

If two features logically grant same permission, guard both. Carefully checked internal admin endpoint useless if same operation reachable via less-guarded public endpoint.

Map every sensitive operation to every entry point that can trigger it; verify each enforces rules. New entry point (new API version, internal tool, webhook handler) → explicitly audit which business rules it needs.

### Reference Related Guidance

General access control: [Access Control Cheat Sheet](Authorization.md) and [Authorization Cheat Sheet](Authorization.md). Higher-sensitivity financial or state-changing transactions: [Transaction Authorization Cheat Sheet](Transaction_Authorization.md).

## Validate Inputs for Business Meaning, Not Just Format

See [Input Validation Cheat Sheet](Input_Validation.md) for validation controls.

Input validation typically checks format: well-formed integer, length limits, character whitelist. Catches injection, not business logic abuse. Input can be perfectly formatted yet semantically invalid.

### Validate Ranges

Positive-integer quantity can still be wrong. Numeric discount can still be absurd. Validate vs meaningful business range:

- Quantity ≥ 1 and ≤ stock available.
- Date in future, not more than a year out, not on blocked day.
- Amount positive, not more than account allows, not above regulatory limit.
- Text length matches what downstream system accepts, maybe shorter than generic limit.

### Validate Combinations

Individually valid fields can be collectively invalid. Booking w/ valid room, valid check-in, valid check-out still invalid if check-out precedes check-in. Transfer between two valid accounts still invalid if accounts belong to different customers and user lacks permission on both.

Write validation rules describing legal combinations; enforce server-side. Unit-test cases where each field valid but combination not.

### Don't Trust Derived or Hidden Fields

Fields "not editable in UI" fully editable at HTTP layer. Every request field = input, incl. hidden form controls, disabled form controls, JavaScript-set fields, fields set in previous response and expected back unchanged. If field matters, validate as if from attacker, because it did.

## Observability and Anomaly Detection

Well-designed feature will eventually face creative abuse. Logging and monitoring let you notice and respond.

### What to Log

Any operation dispensing value, changing permissions, or moving money:

- Authenticated user
- Target resource
- Action taken
- Outcome
- Enough request context to reconstruct what happened (IP, user agent, correlation ID)
- Enough business context to audit (price computed, coupon applied, new state)

Logs tamper-evident and separate from general application logs.

### What to Alert On

Rates of these often precede or accompany abuse:

- Signups from same IP, device fingerprint, or payment instrument
- Repeated failed password-reset requests from same source
- Unusually high promo redemptions, referral completions, credit issuances
- Request bursts to single endpoint from single user
- Workflows completing substantially faster than human could

No sophisticated ML needed. Simple thresholds on per-user, per-IP, per-device rates catch most automated abuse.

### Close the Loop

On potential abuse: investigate and resolve specific incident, and add or tighten control that should have prevented it. Detection w/o prevention = detection repeated next month.

## Testing Business Logic

Automated tests keep business rules enforced as code evolves. Focus on rules, not happy path.

### Test the Rules, Not the Implementation

For each invariant from threat modeling, write test failing if invariant violated. Test "a user cannot approve their own request" attempts exactly that, asserts rejection. Tests document rules as much as verify them.

### Test Concurrency

If two requests can race, write test racing them. Most test frameworks fire concurrent requests and assert consistent end state (e.g., balance never negative, coupon redeemed exactly once, bonus granted exactly once across all winners).

### Test Ordering

Multi-step workflows: test skip, repeat, reorder attempts. Expected outcome each: rejection, not progress.

### Test with an Adversarial Mindset

Developer-written unit tests cover cases developer already thought of. Complement w/ adversarial tests: take feature spec, write tests for ways motivated user would misuse it. Bug often reproduces first attempt; feature wasn't designed for that misuse.

## Common Examples of Business Logic Flaws

Concrete examples help recognize pattern. Not exhaustive.

### Price and Quantity

- Negative quantity in cart to get refund against another item's cost.
- Client-supplied price server trusts.
- Zero-price items actually valuable because "free" flag intended for different product.
- Currency switching mid-transaction: amount kept, currency changes (e.g., USD to much weaker unit).
- Coupon codes applied multiple times, or to unintended products.

### Workflow

- Skipping identity verification by calling post-verification endpoint directly.
- Advancing job application, approval, or KYC workflow past stage supposed gated on reviewer.
- Triggering "checkout complete" w/o paying.
- Claiming reward for never-completed task.

### Concurrency

- Withdrawing same balance from two concurrent sessions.
- Redeeming single-use voucher from two parallel requests.
- Transferring same item to two recipients at once.
- Concurrently updating counter so one update lost.

### Authorization-in-disguise

- Approving own request because "not the author" check forgotten.
- Canceling order after supposed lock-in.
- Modifying shared resource because "only owner can modify" never enforced on specific endpoint.

### Value-dispensing Abuse

- Claiming signup bonus repeatedly by re-signing up.
- Earning referral rewards by referring self.
- Stacking promos meant mutually exclusive.
- Abusing "refer a friend" mechanics to send spam appearing from your platform.

## Summary Checklist

Before shipping any feature handling money, permissions, or state, walk through:

- All security-relevant values (prices, permissions, identity, ownership) derived server-side, not accepted from client?
- Every multi-step workflow an explicit state machine in server-side storage, each transition validated?
- Every check-then-act operation atomic (transaction, row lock, or conditional update)?
- External-action retries reuse same idempotency key within provider's documented retry window?
- Every value-dispensing feature has per-action cap, per-account cap, rate limit?
- All invariants written down and tested?
- Every entry point for sensitive operation subject to same business rules?
- Logging captures enough context to reconstruct abuse after the fact; alerts fire on anomalous rates?
- Considered dishonest-user perspective, not just attacker-with-exploit?

## References

- CWE-840: Business Logic Errors
- CWE-841: Improper Enforcement of Behavioral Workflow
- CWE-367: Time-of-check Time-of-use Race Condition
