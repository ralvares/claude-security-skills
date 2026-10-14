# Choosing and Using Security Questions Cheat Sheet

## Introduction

**WARNING: Security questions no longer recognized as acceptable authentication factor per NIST SP 800-63. Account recovery = alternate way to authenticate → no weaker than regular authentication. See SP 800-63B sec 5.1.1.2 paragraph 4: *Verifiers SHALL NOT prompt subscribers to use specific types of information (e.g., “What was the name of your first pet?”) when choosing memorized secrets*.**

Studies: Microsoft Research 2009, Google 2015. Accompanying Security blog update has infographic on security question issues.

**Note:** No acceptable uses of security questions in secure software; this sheet guides choosing strong security questions for legacy purposes.

## Choosing Security Questions

### Desired Characteristics

Security questions presented to users to reset forgotten passwords must meet:

| Characteristic | Explanation |
|----------------|-------------|
| Memorable | User can recall answer, potentially years after creating account. |
| Consistent | Answer must not change over time. |
| Applicable | User must be able to answer. |
| Confidential | Answer hard for attacker to obtain. |
| Specific | Answer clear to user. |

### Types of Security Questions

Two main types. *User defined*: user chooses question from list, provides answer. Common examples: "What is your favourite colour?" or "What was your first car?"

Easy for applications to implement: info provided by user at account creation. But users often choose weak or easily discovered answers.

*System defined*: based on information already known about user. Avoids asking user for specific questions and answers, prevents choosing weak details. But relies on sufficient info already stored about user, and on that info being hard for attacker to obtain.

### User Defined Security Questions

#### Bad Questions

Avoid questions lacking any of the characteristics above. Examples:

| Question | Problem |
|----------|---------|
| When is your date of birth? | Easy for an attacker to discover. |
| What is your memorable date? | Most users will just enter their birthday. |
| What is your favourite movie? | Likely to change over time. |
| What is your favourite cricket team? | Not applicable to most users. |
| What is the make and model of your first car? | Fairly small range of likely answers. |
| What is your nickname? | This could be guessed by glancing through social media posts. |

Consider application context when judging questions. E.g., "What was your maths teacher's surname in your 8th year of school?" very easy to guess in virtual learning environment for your school (other students probably know), much stronger for online gaming website.

#### Good Questions

Many good questions not applicable to all users → give user list of questions to choose from. Allows more specific questions (more secure answers) while every user still gets answerable questions.

Good question examples:

- What is the name of a college you applied to but didn’t attend?
- What was the name of the first school you remember attending?
- Where was the destination of your most memorable school field trip?
- What was your maths teacher's surname in your 8th year of school?
- What was the name of your first stuffed toy?
- What was your driving instructor's first name?

Like passwords, users may re-use recovery questions across sites → exposure if other site compromised. Benefit from unique questions unlikely shared between sites. Easy way: more targeted questions by application type. E.g., share dealing platform: "What is the first company you owned shares in?"

#### Allowing Users to Write Their Own Questions

User-written questions can be very strong and unique, hard to guess. But significant risk of weak questions. Users might even set recovery question as password reminder → anyone guessing their email address compromises account.

Generally best not to allow users to write own questions.

#### Restricting Answers

Minimum answer length prevents strings such as "a" or "123". But depending on questions, may block correct answers: first name or surname could be two letters such as "Li"; color question could be four letters such as "blue".

Check answers vs denylist, incl.:

- Username or email address.
- User's current password.
- Common strings such as "123" or "password".

#### Renewing Security Questions

If questions not part of main authentication process, consider periodically (e.g. when changing passwords after expiration) prompting user to review questions and verify they still know answers. Chance to update changed answers (ideally shouldn't happen with good questions); raises likelihood they remember if they need to recover account.

### System Defined Security Questions

Based on info already known about user. Personal details often used: full name, address, date of birth. Easily obtained by attacker from social media → very weak authentication.

Usable questions vary hugely by application and info held about user. When deciding which info usable, consider:

- Will user remember the answer?
- Could attacker easily obtain info from social media or other sources?
- Is answer likely same for many users, or easily guessable?

## Using Security Questions

### When to Use Security Questions

Applications should generally use password plus second authentication factor (such as OTP code). Password + security questions **does not constitute MFA**: both factors same type (something you know).

**Security questions should never be relied upon as sole mechanism to authenticate user**. Can provide useful additional layer when stronger factors unavailable. Common cases:

- Logging in.
- Resetting forgotten password.
- Resetting lost MFA token.

#### Authentication Flow

May supplement passwords in main authentication flow where MFA unavailable. Typical flow:

- User enters username and password.
- If correct, user presented security question(s).
- If answers correct, user logged in.

Incorrect answers count as failed login attempt; increment account lockout counter for user.

#### Forgotten Password or Lost MFA Token Flow

Forgotten password functionality often lets attackers enumerate accounts if implemented incorrectly. Following flow avoids this by showing security questions only after user proves email ownership:

- User enters email address (and solves CAPTCHA).
- Application displays generic message such as "If the email address was correct, an email will be sent to it".
- Email with randomly generated, single-use link sent to user.
- User clicks link.
- User presented security question(s).
- If answer correct, user can enter new password.

### How to Use Security Questions

#### Storing Answers

Answers may contain personal info, and may be re-used across applications. Treat like passwords: store using secure hashing algorithm such as Bcrypt. See [password storage cheat sheet](Password_Storage.md).

#### Comparing Answers

Case-insensitive comparison to stored answer easier for user. Simplest: lowercase answer before hashing to store, lowercase user-provided answer before comparing.

Also give user hint of answer format. Via input validation, or by recommending specific format. E.g., date: indicate format "DD/MM/YYYY" so user needn't guess format used at registration.

#### Updating Answers

Updating answers = sensitive operation. Require re-authentication by password (ideally MFA), to prevent attacker updating questions after temporary account access.

#### Multiple Security Questions

User can be asked single question, or multiple at same time. Multiple gives greater assurance, esp. if diverse: attacker needs more info about target. Mixing user-defined and system-defined questions can be very effective.

If asking single question from bank of questions, this question **should not** change until user answers correctly. Letting attacker try all different questions greatly raises chance of guessing or obtaining one answer.

## References

- Google Research: Secrets, Lies, and Account Recovery
- NIST SP 800-63B-4: Authentication and Authenticator Management
