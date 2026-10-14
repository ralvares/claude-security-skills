# JAAS Cheat Sheet

## Introduction - What is JAAS authentication

Authentication = verifying identity of user/other system.

JAAS = authentication framework; manages authenticated user's identity and credentials from login to logout.

JAAS authentication lifecycle:

1. App creates `LoginContext` using configured login name + callback handler.
2. `LoginContext` reads configuration, instantiates configured `LoginModule`s.
3. `LoginContext` calls each module's `initialize()` w/ shared `Subject` + other context.
4. App calls `LoginContext.login()`, invoking configured modules' `login()` methods per control flags.
5. Overall authentication succeeds → `LoginContext` invokes modules' `commit()`; else their `abort()`.

## Configuration file

JAAS config file has a `LoginModule` stanza for each `LoginModule` available for logging on to app.

Example stanza:

```text
Branches
{
    USNavy.AppLoginModule required
    debug=true
    succeeded=true;
}
```

Semicolons terminate both `LoginModule` entries and stanzas.

required = `LoginContext`'s `login()` must succeed when logging in user. `LoginModule`-specific values `debug`, `succeeded` passed to `LoginModule`; defined by it, usage managed inside it. Options = key-value pairs such as `debug="true"`, key and value separated by `=`.

## Main.java (The client)

- Execution syntax:

```text
Java –Djava.security.auth.login.config==packageName/packageName.config
        packageName.Main Stanza1

Where:
    packageName is the directory containing the config file.
    packageName.config specifies the config file in the Java package, packageName.
    packageName.Main specifies Main.java in the Java package, packageName.
    Stanza1 is the name of the stanza Main() should read from the config file.
```

- 1st command-line arg = stanza from config file; names the `LoginModule` to use. 2nd arg = `CallbackHandler`.
- Create new `LoginContext` w/ args passed to `Main.java`.
    - `loginContext = new LoginContext (args[0], new AppCallbackHandler());`
- Call LoginContext.Login Module:
    - `loginContext.login();`
- `LoginContext.login()` returns w/o value on success, throws `LoginException` on failure.
- Retrieve authenticated `Subject` via `loginContext.getSubject()` after successful login.

## LoginModule.java

`LoginModule` must have authentication methods:

- `initialize()`
- `login()`
- `commit()`
- `abort()`
- `logout()`

### initialize()

In `Main()`, after `LoginContext` reads correct stanza from config file, it instantiates `LoginModule` specified in stanza.

- `initialize()` signature:
    - `public void initialize(Subject subject, CallbackHandler callbackHandler, Map<String, ?> sharedState, Map<String, ?> options)`
- Save arguments as:
    - `this.subject = subject;`
    - `this.callbackHandler = callbackHandler;`
    - `this.sharedState = sharedState;`
    - `this.options = options;`
- `initialize()` does:
    - Stores supplied shared `Subject`; successful `commit()` associates authenticated principals + credentials with it.
    - Sets `CallbackHandler` that interacts w/ user to gather login info.
    - `LoginContext` w/ 2+ LoginModules (legal): they share info via `sharedState` map.
    - Saves state info such as debug and succeeded in options Map.

### login()

Captures user-supplied login info. Snippet declares array of two callback objects; passed to `callbackHandler.handle` in `callbackHandler.java`, loaded w/ username + password provided interactively:

```java
NameCallback nameCB = new NameCallback("Username");
PasswordCallback passwordCB = new PasswordCallback ("Password", false);
Callback[] callbacks = new Callback[] { nameCB, passwordCB };
callbackHandler.handle (callbacks);
```

- Authenticates user
- Retrieves user-supplied info from callback objects:
    - `String ID = nameCallback.getName ();`
    - `char[] tempPW = passwordCallback.getPassword ();`
- Compare `name` and `tempPW` to values in repository such as LDAP.
- Set variable succeeded, return to `Main()`.

### commit()

After credentials verified in `login()`, JAAS associates credentials, as needed, with subject.

`Subject` separates credentials by protection and sharing requirements:

- Public credentials: intended to be shared, e.g. public key certificates.
- Private credentials: need special protection, e.g. passwords, private cryptographic keys.

Principals (identities subject has besides login name), e.g. employee number, user-group membership ID, added to subject.

Implement `commit()` using auth state saved by `login()`. Associate principals + credentials w/ shared `Subject` only when this module's authentication succeeded; else clean up saved state. Return `true` on success, `false` when module ignored, throw `LoginException` on failure.

### abort()

Called when authentication doesn't succeed. Before `abort()` exits `LoginModule`, reset state incl. username and password input fields.

### logout()

Releases user's principals + credentials when `LoginContext.logout` called:

```java
public boolean logout() {
    if (!subject.isReadOnly()) {
        Set principals = subject.getPrincipals(UserGroupPrincipal.class);
        subject.getPrincipals().removeAll(principals);
        Set creds = subject.getPublicCredentials(UsernameCredential.class);
        subject.getPublicCredentials().removeAll(creds);
        return true;
    } else {
        return false;
    }
}
```

## CallbackHandler.java

`callbackHandler` lives in source (`.java`) file separate from any single `LoginModule` so it can service many LoginModules w/ differing callback objects:

- Creates instance of `CallbackHandler` class; only one method, `handle()`.
- `CallbackHandler` servicing LoginModule needing username & password:

```java
public void handle(Callback[] callbacks) {
    for (int i = 0; i < callbacks.length; i++) {
        Callback callback = callbacks[i];
        if (callback instanceof NameCallback) {
            NameCallback nameCallBack = (NameCallback) callback;
            nameCallBack.setName(username);
    }  else if (callback instanceof PasswordCallback) {
            PasswordCallback passwordCallBack = (PasswordCallback) callback;
            passwordCallBack.setPassword(password.toCharArray());
        }
    }
}
```

## Related Articles

- JAAS in Action, Michael Coté, posted September 27, 2009, URL as 5/14/2012.
- Pistoia Marco, Nagaratnam Nataraj, Koved Larry, Nadalin Anthony, book "Enterprise Java Security" - Addison-Wesley, 2004.

## Disclosure

All code in this JAAS cheat sheet copied verbatim from free source (JAAS in Action).

## References

- Oracle JAAS Reference Guide
- Oracle JAAS: LoginModule Developer's Guide
