# Abuse Case Cheat Sheet (Historical)

## Archive Statement

Reviewers: abuse cases rarely used in practice. Material also presented as "getting started tutorial", unsuited to cheat sheet series.

## Introduction

Security requirements often phrased:

- _The application must be secure_.
- _The application must defend against all attacks targeting this category of application_.
- _The application must defend against attacks from the OWASP TOP 10_
- ...

Too generic, useless for dev team...

Pragmatically, identify attacks app must defend against, per business and technical context. Abuse cases = frequently recommended _threat modeling_ technique; see [threat modeling](Threat_Modeling.md) sheet. In practice abuse case framework seems heavyweight; few published examples or success stories.

### Objective

Explain what **Abuse Case** is, why important for app security, and propose pragmatic approach to build list of abuse cases and track them per planned feature. Usable regardless of methodology (waterfall or agile).

**Important note about this Cheat Sheet:**

```text
The main objective is to provide a pragmatic approach in order to allow a company or a project team
to start building and handling the list of abuse cases and then customize the elements
proposed to its context/culture in order to, finally, build its own method.

This cheat sheet can be seen as a getting-started tutorial.
```

### Context & approach

#### Why clearly identify the attacks

Clear attack identification enables project/sprint steps:

- Evaluate business risk per attack → select by business risk and project/sprint budget.
- Derive security requirements; add to project spec or sprint user stories and acceptance criteria.
- Estimate overhead needed in initial project/sprint charge to implement countermeasures.
- Countermeasures: project team defines them, decides location (network, infrastructure, code...).

#### Notion of Abuse Cases

Two uses: discover attacks (answer "what can go wrong"); record attacks (informally threats, issues, risks) in form less intimidating to developers.

**Abuse Case** definition:

```text
A way to use a feature that was not expected by the implementer,
allowing an attacker to influence the feature or outcome of use of
the feature based on the attacker action (or input).
```

Synopsis defines **Abuse Case**:

```text
Misuse and abuse cases describe how users misuse or exploit the weaknesses
of controls in software features to attack an application.

This can lead to tangible business impact when a direct attack against
business functionalities, which may bring in revenue or provide
positive user experience, are attacked.

Abuse cases can also be an effective way to drive security requirements
that lead to proper protection of these critical business use cases.
```

#### How to define the list of Abuse Cases

Many ways to define abuse cases per feature (maps to user story in agile).

[Threat Modeling](Threat_Modeling.md) = techniques to anticipate what can go wrong and act on each scenario. Writing abuse case per "what are we going to do about it" item may help engineering teams process output.

OWASP Open SAMM proposes in _Stream B_ of Security Practice _Requirements Driven Testing_, Maturity level 2:

```text
Misuse and abuse cases describe unintended and malicious use scenarios of the application, describing how an attacker could do this. Create misuse and abuse cases to misuse or exploit the weaknesses of controls in software features to attack an application. Use abuse-case models for an application to serve as fuel for identification of concrete security tests that directly or indirectly exploit the abuse scenarios.

Abuse of functionality, sometimes referred to as a “business logic attack”, depends on the design and implementation of application functions and features. An example is using a password reset flow to enumerate accounts. As part of business logic testing, identify the business rules that are important for the application and turn them into experiments to verify whether the application properly enforces the business rule. For example, on a stock trading application, is the attacker allowed to start a trade at the beginning of the day and lock in a price, hold the transaction open until the end of the day, then complete the sale if the stock price has risen or cancel if the price dropped?
```

Alternative (bottom-up, collaborative): workshop w/ these profiles:

- **Business analyst**: business key people; describe each feature from business view.
- **Risk analyst**: company risk personnel; evaluate business risk of proposed attack (sometimes = **Business analyst**).
- **Penetration tester**: _attacker_; proposes attacks on business feature(s). No in-house person → hire external specialist. If possible include 2 pentesters w/ different backgrounds → more attacks identified.
- **Technical leaders of the projects**: technical exchange on attacks and countermeasures.
- **Quality assurance analyst or functional tester**: knows how app/functionality should work (positive testing), not work (negative testing), what causes failure (failure cases).

Workshop (duration per feature list size; 4 hours good start) processes all business features of project or sprint. Output: list of attacks (abuse cases) for all features, each w/ risk rating for filtering and prioritization.

Take into account **Technical** and **Business** abuse cases; mark accordingly.

_Example:_

- Technical flagged abuse case: Add Cross Site Scripting injection into a comment input field.
- Business flagged abuse case: Ability to arbitrarily modify the price of an article in an online shop prior to passing an order causing the user to pay a lower amount for the wanted article.

#### When to define the list of Abuse Cases

Agile: hold workshop after meeting that includes User Stories in Sprint.

Waterfall: hold workshop when business features to implement identified and known by business.

Either mode: selected abuse cases MUST become security requirements in each feature spec section (waterfall) or User Story acceptance criteria (agile) → enables cost/effort evaluation, countermeasure identification and implementation.

Each abuse case needs unique identifier for tracking through whole project/sprint (details in proposal section).

Example ID format: **ABUSE_CASE_001**.

Figure: chaining of steps (left to right):

![Overview Schema](../assets/Abuse_Case_Cheat_Sheet_Overview.png)

### Proposal

Focus on workshop output described above.

#### Step 1: Preparation of the workshop

First, key business people must know, understand, be able to explain business features to be processed.

Second, create new Microsoft Excel file (or Google Sheets etc.) w/ sheets (tabs):

- **FEATURES**
    - Table of business features planned for workshop.
- **ABUSE CASES**
    - Table of all abuse cases identified in workshop.
- **COUNTERMEASURES**
    - Table of possible countermeasures (light description) for identified abuse cases.
    - Optional, but useful (per abuse case, shows whether fix easy to implement, which can affect risk rating).
    - AppSec profile can identify countermeasures during workshop: AppSec person can attack and also build/identify defenses (Pentester focus generally attack only; Pentester + AppSec combo gives 360 degree view).

Each sheet w/ example content filled during workshop:

_FEATURES_ sheet:

| Feature unique ID |     Feature name      |           Feature short description           |
| :---------------: | :-------------------: | :-------------------------------------------: |
|    FEATURE_001    | DocumentUploadFeature | Allow user to upload document along a message |

_COUNTERMEASURES_ sheet:

| Countermeasure unique ID | Countermeasure short description                       | Countermeasure help/hint                                |
| ------------------------ | ------------------------------------------------------ | ------------------------------------------------------- |
| DEFENSE_001              | Validate the uploaded file by loading it into a parser | Use advice from the OWASP Cheat Sheet about file upload |

_ABUSE CASES_ sheet:

| Abuse case unique ID | Feature ID impacted | Abuse case's attack description | Attack referential ID (if applicable) | Business risk rating | CVSS severity and vector (if applicable) | Kind of abuse case | Countermeasure ID applicable | Handling decision (To Address or Risk Accepted) |
| ------------------- | ------------------- | ------------------------------ | ------------------------------------ | -------------------- | --------------------------------------- | ------------------ | ---------------------------- | ---------------------------------------------- |
| ABUSE_CASE_001 | FEATURE_001 | Upload Office file with malicious macro in charge of dropping a malware | CAPEC-17 | To be assessed | Not assigned | Technical | DEFENSE_001 | To Address |

#### Step 2: During the workshop

Use spreadsheet to review all features.

Per feature:

1. Key business people explain feature from business view.
2. Pentesters propose and explain attacks against feature.
3. Per attack:
   1. Appsec proposes countermeasure and preferred location (infrastructure, network, code, design...).
   2. Technical people give feasibility feedback.
   3. Abuse case involving specific vulnerability: pentesters may record Common Vulnerability Scoring System (CVSS) severity score and vector. FIRST: CVSS measures severity; don't use alone to assess risk.
   4. Risk leaders assess abuse case likelihood and business impact w/ organization's risk assessment method. Record business risk rating and rationale separately from CVSS score; never modify CVSS score to represent business risk.

4. Business, Risk, Technical leaders reach consensus; filter abuses for current feature to keep those that must be addressed; flag in _ABUSE CASES_ sheet (**if risk accepted add comment explaining why**).
5. Next feature...

No pentesters available → use these references to identify applicable attacks:

- OWASP Automated Threats to Web Applications
- OWASP Testing Guide
- OWASP Mobile Testing Guide
- Common Attack Pattern Enumeration and Classification (CAPEC)

Important note on attacks and countermeasure knowledge base(s):

```text
With time and experience across projects, you will obtain your own dictionary of attacks and countermeasures
that are applicable to the kind of application in your business domain.

This dictionary will speed up the future workshops in a significant way.

To promote the creation of this dictionary, you can, at the end of the project/sprint, gather the list
of attacks and countermeasures identified in a central location (wiki, database, file...) that will be
used during the next workshop in combination with input from penetration testers.
```

#### Step 3: After the workshop

Spreadsheet now holds all abuse cases to handle and, potentially (capacity permitting), countermeasures.

Two remaining tasks:

1. Key business people update spec of each feature (waterfall) or User Story (agile) to include abuse cases as Security Requirements (waterfall) or Acceptance Criteria (agile).
2. Key technical people evaluate expense/effort overhead of countermeasure.

#### Step 4: During implementation - Abuse cases handling tracking

Track handling of abuse cases. If one or several handled at:

- **Design, Infrastructure or Network level**
    - Note in documentation or schema: _This design/network/infrastructure takes into account the abuse cases ABUSE_CASE_001, ABUSE_CASE_002, ABUSE_CASE_xxx_.
- **Code level**
    - Special comment in classes/scripts/modules: _This class/module/script takes into account the abuse cases ABUSE_CASE_001, ABUSE_CASE_002, ABUSE_CASE_xxx_.
    - Dedicated annotation like `@AbuseCase(ids={"ABUSE_CASE_001","ABUSE_CASE_002"})` eases tracking and IDE identification.

With minor scripting → find where abuse cases addressed.

#### Step 5: During implementation - Abuse cases handling validation

Once defined, add automated or manual validations ensuring:

- All selected abuse cases handled.
- Abuse case correctly/completely handled.

Validation types:

- Automated (run regularly at commit, daily or weekly in project CI jobs):
    - Custom audit rules in Static Application Security Testing (SAST) or Dynamic Application Security Testing (DAST) tools.
    - Dedicated unit, integration or functional security tests.
    - ...
- Manual:
    - Security code review among project peers during design or implementation.
    - Give pentesters list of addressed abuse cases → validate protection efficiency per abuse case during intrusion test (confirm identified attacks no longer effective; also seek other attacks).
    - ...

Automated tests also let teams track countermeasure effectiveness and confirm countermeasures still in place during maintenance or bug fixing (prevents accidental removal/disabling). Also useful with Continuous Delivery: ensure all abuse case protections in place before opening access to app.

### Example of derivation of Abuse Cases as User Stories

Example deriving Abuse Cases as User Stories from OWASP TOP 10 as input.

Threat Oriented Personas:

- Malicious User
- Abusive User
- Unknowing User

#### A1:2017-Injection

_Epic:_

Almost any data source can be injection vector: environment variables, parameters, external and internal web services, all user types. Injection flaws occur when attacker sends hostile data to interpreter.

_Abuse Case:_

As an attacker, I will perform an injection attack (SQL, LDAP, XPath, or NoSQL queries, OS commands, XML parsers, SMTP headers, expression languages, and ORM queries) against input fields of the User or API interfaces

#### A2:2017-Broken Authentication

_Epic:_

Attackers have hundreds of millions of valid username/password combinations for credential stuffing, default admin account lists, automated brute force and dictionary attack tools. Session management attacks well understood, esp. unexpired session tokens.

_Abuse Case:_

As an attacker, I have access to hundreds of millions of valid username and password combinations for credential stuffing.

_Abuse Case:_

As an attacker, I have default administrative account lists, automated brute force, and dictionary attack tools I use against login areas of the application and support systems.

_Abuse Case:_

As an attacker, I manipulate session tokens using expired and fake tokens to gain access.

#### A3:2017-Sensitive Data Exposure

_Epic:_

Rather than attack crypto directly, attackers steal keys, run man-in-the-middle attacks, or steal clear text data off server, in transit, or from user's client (e.g. browser). Generally manual attack. Previously retrieved password databases can be brute forced by Graphics Processing Units (GPUs).

_Abuse Case:_

As an attacker, I steal keys that were exposed in the application to get unauthorized access to the application or system.

_Abuse Case:_

As an attacker, I execute man-in-the-middle attacks to get access to traffic and leverage it to obtain sensitive data and possibly get unauthorized access to the application.

_Abuse Case:_

As an attacker, I steal clear text data off the server, while in transit, or from the user's client, e.g. browser to get unauthorized access to the application or system.

_Abuse Case:_

As an attacker, I find and target old or weak cryptographic algorithms by capturing traffic and breaking the encryption.

#### A4:2017-XML External Entities (XXE)

_Epic:_

Attackers exploit vulnerable XML processors if they can upload XML or include hostile content in XML document, exploiting vulnerable code, dependencies or integrations.

_Abuse Case:_

As an attacker, I exploit vulnerable areas of the application where the user or system can upload XML to extract data, execute a remote request from the server, scan internal systems, perform a denial-of-service attack, as well as execute other attacks.

_Abuse Case:_

As an attacker, I include hostile content in an XML document which is uploaded to the application or system to extract data, execute a remote request from the server, scan internal systems, perform a denial-of-service attack, as well as execute other attacks.

_Abuse Case:_

As an attacker, I include malicious XML code to exploit vulnerable code, dependencies or integrations to extract data, execute a remote request from the server, scan internal systems, perform a denial-of-service attack (e.g. Billion Laughs attack), as well as execute other attacks.

#### A5:2017-Broken Access Control

_Epic:_

Exploiting access control = core attacker skill. Detectable manually, or possibly via automation for absent access controls in certain frameworks.

_Abuse Case:_

As an attacker, I bypass access control checks by modifying the URL, internal application state, or the HTML page, or simply using a custom API attack tool.

_Abuse Case:_

As an attacker, I manipulate the primary key and change it to access another's users record, allowing viewing or editing someone else's account.

_Abuse Case:_

As an attacker, I manipulate sessions, access tokens, or other access controls in the application to act as a user without being logged in, or acting as an admin/privileged user when logged in as a user.

_Abuse Case:_

As an attacker, I leverage metadata manipulation, such as replaying or tampering with a JSON Web Token (JWT) access control token or a cookie or hidden field manipulated to elevate privileges or abusing JWT invalidation.

_Abuse Case:_

As an attacker, I exploit Cross-Origin Resource Sharing CORS misconfiguration allowing unauthorized API access.

_Abuse Case:_

As an attacker, I force browsing to authenticated pages as an unauthenticated user or to privileged pages as a standard user.

_Abuse Case:_

As an attacker, I access APIs with missing access controls for POST, PUT and DELETE.

_Abuse Case:_

As an attacker, I target default crypto keys in use, weak crypto keys generated or re-used, or keys where rotation is missing.

_Abuse Case:_

As an attacker, I find areas where the user agent (e.g. app, mail client) does not verify if the received server certificate is valid and perform attacks where I get unauthorized access to data.

#### A6:2017-Security Misconfiguration

_Epic:_

Attackers often try unpatched flaws, default accounts, unused pages, unprotected files and directories, etc → unauthorized access or system knowledge.

_Abuse Case:_

As an attacker, I find and exploit missing appropriate security hardening configurations on any part of the application stack, or improperly configured permissions on cloud services.

_Abuse Case:_

As an attacker, I find unnecessary features which are enabled or installed (e.g. unnecessary ports, services, pages, accounts, or privileges) and attack or exploit the weakness.

_Abuse Case:_

As an attacker, I use default accounts and their passwords to access systems, interfaces, or perform actions on components which I should not be able to.

_Abuse Case:_

As an attacker, I find areas of the application where error handling reveals stack traces or other overly informative error messages I can use for further exploitation.

_Abuse Case:_

As an attacker, I find areas where upgraded systems, latest security features are disabled or not configured securely.

_Abuse Case:_

As an attacker, I find security settings in the application servers, application frameworks (e.g. Struts, Spring, ASP.NET), libraries, databases, etc. not set to secure values.

_Abuse Case:_

As an attacker, I find the server does not send security headers or directives or are set to insecure values.

#### A7:2017-Cross-Site Scripting (XSS)

_Epic:_

XSS = second most prevalent issue in OWASP Top 10; found in around two-thirds of apps.

_Abuse Case:_

As an attacker, I perform reflected XSS where the application or API includes unvalidated and unescaped user input as part of HTML output. My successful attack can allow the attacker to execute arbitrary HTML and JavaScript in my victim's browser. Typically the victim will need to interact with some malicious link that points to an attacker-controlled page, such as malicious watering hole websites, advertisements, or similar.

_Abuse Case:_

As an attacker, I perform stored XSS where the application or API stores unsanitized user input that is viewed at a later time by another user or an administrator.

_Abuse Case:_

As an attacker, I perform DOM XSS where JavaScript frameworks, single-page applications, and APIs that dynamically include attacker-controllable data to a page is vulnerable to DOM XSS.

#### A8:2017-Insecure Deserialization

_Epic:_

Deserialization exploitation somewhat difficult: off-the-shelf exploits rarely work w/o changes to exploit code.

_Abuse Case:_

As an attacker, I find areas of the application and APIs where deserialization of hostile or tampered objects can be supplied. As a result, I can focus on an object and data structure related attacks where the attacker modifies application logic or achieves arbitrary remote code execution if there are classes available to the application that can change behavior during or after deserialization. Or I focus on data tampering attacks such as access-control-related attacks where existing data structures are used but the content is changed.

#### A9:2017-Using Components with Known Vulnerabilities

_Epic:_

Exploits for many known vulnerabilities easy to find; others need concentrated effort for custom exploit.

_Abuse Case:_

As an attacker, I find common open source or closed source packages with weaknesses and perform attacks against vulnerabilities and exploits which are disclosed

#### A10:2017-Insufficient Logging & Monitoring

_Epic:_

Insufficient logging and monitoring = bedrock of nearly every major incident. Attackers rely on lack of monitoring and timely response to avoid detection. In 2016, identifying breach took average of 191 days → substantial chance for damage.

_Abuse Case:_

As an attacker, I attack an organization and the logs, monitoring systems, and teams do not see or respond to my attacks.

## Sources of the schemas

Figures created on draw.io, exported as PNG.

XML descriptor files for each schema (modifiable via DRAW.IO):

[Schemas descriptors archive](../assets/Abuse_Case_Cheat_Sheet_SchemaBundle.zip)

## References

- OWASP SAMM: Misuse/Abuse Testing
- OWASP SAMM: Security Requirements
