# Transaction Authorization Cheat Sheet

## Purpose and audience

How to secure transaction authorizations, prevent bypass. Audience:

- **Banks** - create functional/non-functional requirements for transaction authorization.
- **Developers** – eliminate vulnerabilities in transaction authorizations.
- **Pentesters** – determine if transaction authorizations secure.

## Introduction

Mobile/online apps often require second factor so system can check user authorized for sensitive operation (e.g., wire transfer). Such actions = *transaction authorizations*.

Common in financial systems, now spread across internet. E.g., email unlocking account via secret code or tokenized link contains transaction authorization. Implementation methods:

- Card with transaction authorization number
- Time-based one-time password (OTP) token, e.g., OATH TOTP (Time-based One-Time Password)
- OTP sent by SMS or provided by phone
- Digital signature from smart card or smartphone
- Challenge-response token, incl. unconnected card readers or solutions scanning transaction data from user's computer screen

Some forms implementable in physical device or mobile app.

## 1. Functional Guidelines

### 1.1 Transaction authorization method has to allow a user to identify and acknowledge significant transaction data

User's computer can't be assumed secure → external authorization component must check data for typical transaction.

Build components on *What You See Is What You Sign* principle. Method must let user identify and acknowledge data significant to transaction. E.g., wire transfer: user identifies target account and amount.

Decide significant data by:

- Real risk
- Technical capabilities/constraints of chosen method
- Positive user experience

E.g., SMS confirming significant data: return target account, amount, transfer type. Unconnected CAP reader: entering that data inconvenient → return minimum significant data (e.g., partial target account number + amount) for confirmation.

User must verify all significant transaction data during authorization. If process requires entering transaction data into external device, prompt user to confirm specific value (e.g., target account number). No meaningful prompt → easily abused by social engineering and malware (Section 1.4). Input overloading problems: see Drimer et al. paper.

### 1.2 Change of authorization token should be authorized using the current authorization token

If user can change authorization token via app interface, authorize with current credentials (like password change procedure). E.g., changing phone number for SMS codes: send authorization SMS code to current number.

### 1.3 Change of authorization method should be authorized using the current authorization method

If user chooses authorization method, app must confirm user's current method to stop malware switching to most vulnerable method. App should also inform user of dangers of their method.

### 1.4 Users should be able to easily distinguish the authentication process from the transaction authorization process

To prevent authorizing fraudulent operations, don't require same actions for authentication and transaction authorization. Example:

1. App uses same method for authentication and transaction authorization {i.e. with an OTP token).
2. Malware uses man-in-the-middle to show false error on credential submission, tricking user into repeating authentication. First credential used by malware to authenticate, second to authorize fraudulent transaction. Even challenge-response schemes abusable: malware presents challenge from fraudulent transaction, tricks user into responding. Widely used in malware attacks against electronic banking.

Countermeasures: make authentication differ from transaction authorization by:

- Different methods to authenticate vs authorize
- Different actions in external security component (i.e using different mode of operation in CAP reader)
- Clear message on what user "signs" (What You See Is What You Sign Principle)

Social engineering can work despite authentication/authorization methods (Tatanga attack, ChipTAN), but app shouldn't make it easier.

### 1.5 Each transaction should be authorized using unique authorization credentials

If app asks for authorization credentials once (static password, SMS code, token response), user could authorize any transaction during entire session or reuse credentials. Malware sniffs credentials, authorizes any transaction w/o user knowledge.

## 2. Non-functional guidelines

### 2.1 Authorization should be performed and enforced server-side

Like all security controls, enforce transaction authorizations server-side. **Never** allow client→server data alteration to influence authorization result by:

- Tampering with parameters containing transaction data
- Adding/removing parameters disabling authorization check
- Causing an error

Keep data managed server-side via secure programming practices:

- Default deny
- No debugging functionality in production code

Consider further anti-tampering safeguards, e.g., encrypt data for confidentiality + integrity, decrypt and verify server-side.

### 2.2 Authorization method should be enforced server-side

If multiple methods available, server must ensure transaction uses user's chosen method or one enforced by app policy. Else malware downgrades to least secure method. Make it impossible to change chosen method by manipulating client parameters.

Take care when adding new, security-enhancing method. Developers often build it atop old codebase: insecure. Attacker manipulates client to authorize transaction via old method parameters though app already switched to new method.

### 2.3 Transaction verification data should be generated server-side

When sending significant transaction data programmatically to authorization component, prevent client modification at authorization. **All significant transaction data must be verified by user, generated and stored on server, then passed to authorization component w/o possibility of client tampering.**

If significant transaction data collected client-side and passed to server, malware can manipulate it and show faked data in authorization component.

### 2.4 Application should prevent authorization credentials brute-forcing

**Prevent brute-forcing transaction at point where authorization credentials submitted for verification. After set number of failed attempts, restart entire transaction authorization process.** Other anti-brute-force/automation methods: [OWASP Authentication Cheat Sheet](Authentication.md#protect-against-automated-attacks).

### 2.5 Application should control which transaction state transitions are allowed

Authorization usually multi-step, e.g.:

1. User enters transaction data.
2. User requests authorization from app.
3. App initializes authorization mechanism.
4. User verifies/confirms transaction data.
5. User responds w/ authorization credentials.
6. App validates authorization, executes transaction.

**Ensure business logic flow occurs in sequential order so users (or attackers) can't perform steps out of order or skip any.** Protects against:

- Overwriting transaction data before user enters authorization credentials
- Skipping transaction authorization

 See OWASP ASVS requirement **15.1**).

### 2.6 Transaction data should be protected against modification

Don't allow attackers to modify transaction data when user first enters it. Poor implementations let malware:

1. Replay first step in Section 2.5 (sending transaction data) in background before user enters authorization credentials, overwrite details with fraudulent transaction.
2. Add new transaction data parameters to HTTP request authorizing transaction. Poorly implemented process may authorize initial transaction, then execute fraudulent one (specific example of Time of Check to Time of Use vulnerability).

Prevention methods:

1. On transaction data modification, invalidate any previously entered authorization data (e.g. generated OTP) and challenge.
2. Modification triggers reset of authorization process.
3. Any attempt to modify transaction data after user entry = attack: log, monitor, investigate carefully.

### 2.7 Confidentiality of transaction data should be protected during all client-server communications

Protect privacy of transaction data being authorized (i.e. at Section 2.5, steps 2 and 4).

### 2.8 System should check each transaction execution and make sure it has been properly authorized

Final result of entry + authorization process (Section 2.5) = *transaction execution*. Add final control gate before execution verifying proper user authorization. Tie control to execution; prevents:

- Time of Check to Time of Use (TOCTOU) – example in Section 2.6
- Skipping authorization check in transaction entry process (see. Section 2.5)

### 2.9 Authorization credentials should only be valid during a limited time period

In some attacks malware passes user's authorization credentials to command-and-control server, attacker uses them from own machine, often manually. Hinder: server allows authorization only in limited time window between challenge (or OTP) generation and authorization completion. Also helps stop resource exhaustion attacks. Choose period carefully to not disrupt normal user behavior.

### 2.10 Authorization credentials should be unique for every operation

Prevent multiple replay attacks: unique credentials per operation. Generation depends on mechanism, e.g., timestamp, sequence number, or random value in signed transaction data or as part of challenge.

## Remarks

Original implementation recommendations: Wojciech Dworakowski's AppSec EU 2015 presentation. Banking threat-modeling context: Morana and Ucedavelez's AppSec EU 2011 presentation.

Other issues beyond scope:

- Which transactions to authorize? All or some? App owner decides per app; consider risk analysis, risk exposition, other implemented safeguards.
- **Use cryptographic operations to protect transactions, ensure integrity, confidentiality, non-repudiation.**
- **Critically important: provision and protect device signing keys during device "pairing" and in signing protocol itself. Malware may inject/replace or steal signing keys.**
- User awareness: when typing significant transaction data into authorization component (external device or mobile app), train users to rewrite data from trusted source, not computer screen.
- **Some anti-malware solutions protect against such threats but cannot be 100% effective; use only as additional layer.**
- Protect signing keys with second factor (passwords, biometrics, etc.) or secure elements (TEE, TPM, Smart card).

## References

- Drimer, Murdoch and Anderson: Optimised to Fail — Card Readers for Online Banking
- Peotta et al.: A Formal Classification of Internet Banking Attacks and Vulnerabilities
- Blom et al.: Designed to Fail — A USB-Connected Reader for Online Banking
