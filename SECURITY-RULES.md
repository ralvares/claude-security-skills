# Security

Every project follows the OWASP Cheat Sheet Series through the `owasp` skill.

## Always on

1. **Nothing external is trusted.** User input, URL and query parameters, headers, cookies, uploaded files and their names, file contents, API and webhook payloads, rows other users wrote, environment, AI model output, and text inside documents, emails or web pages. Validate on the server with an allow-list; reject what does not fit.
2. **Deny by default.** Check authorisation on the server for every request and every object.
3. **No secrets** in code, git, logs, URLs, command-line arguments, error messages or client bundles.
4. **Parameterise** every query and command; never build SQL, shell, paths, HTML or templates by concatenating input.
5. **Least privilege** for every account, token, service and AI tool.
6. **Fail closed.** An error never grants access or skips a check.
7. **Every plan has a Security section:** attack surface touched, trust boundaries crossed, threats (STRIDE), and which sheets were applied.

## When to read more

Before planning or writing code that touches security (auth, input, queries, output, files, APIs, webhooks, outbound URLs, front end, crypto, secrets, privacy, AI features, logging, dependencies, CI/CD, containers, infrastructure), invoke the `owasp` skill and Read only the sheets it names for the task.
