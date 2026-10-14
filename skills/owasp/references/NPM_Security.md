# NPM Security best practices

npm security best practices + productivity tips for JavaScript/Node.js devs. Originally based on Snyk blog "10 npm security best practices".

## 1) Avoid publishing secrets to the npm registry

API keys, passwords, other secrets easily leak into source control or published package on public npm registry. Secrets in working directory files (e.g., `.env`) belong in `.gitignore` to avoid committing to SCM; but publishing npm package from project directory?

npm CLI packs project into tar archive (tarball) to push to registry. Tarball contents determined by:

- `.gitignore` or `.npmignore` present: file contents used as ignore pattern when preparing package.
- Both ignore files exist: everything not in `.npmignore` is published. Common source of confusion; can leak secrets.

Devs may update `.gitignore` but forget `.npmignore` → sensitive file not pushed to source control but still in npm package.

Also use `files` property in `package.json`: allowlist specifying array of files to include in package (ignore file = denylist). Both together determine explicit includes + excludes. When both used, `files` in `package.json` takes precedence over ignore file.

On publish, npm CLI verbosely displays archive being created. To be extra careful, add `--dry-run` to publish command to review tarball creation without publishing.

Revoking access token: official docs "Revoking access tokens".

## 2) Enforce the lockfile

Lockfiles give deterministic installs across environments, enforce dependency expectations across team. But: change to `package.json` without committing lockfile?

Yarn + npm act same: on inconsistency between `package.json` and lockfile, compensate based on `package.json` manifest by installing different versions than recorded in lockfile.

Hazardous for build + production: pulls unintended package versions, voids lockfile benefit.

Tell Yarn + npm to adhere to lockfile versions; any inconsistency aborts installation:

- Yarn: run `yarn install --frozen-lockfile`.
- npm: run `npm ci`.

## 3) Minimize attack surfaces by ignoring run-scripts

npm CLI works with package run-scripts (e.g., `npm start`, `npm test`). Packages can declare scripts run at specific entry points during installation, e.g., `postinstall` scripts for housekeeping (script hook docs).

Bad actors create/alter packages to run arbitrary commands on install. Cases: eslint-scope incident (harvested npm tokens); crossenv incident, w/ 36 other packages abusing typosquatting on npm registry.

Minimize malicious module attack surface:

- Always vet third-party modules; due diligence on health + credibility.
- Hold off upgrading immediately; let new versions circulate before trying.
- Review changelog + release notes before upgrading.
- Add `--ignore-scripts` suffix when installing packages to disable third-party script execution.
- Consider adding `ignore-scripts=true` to project `.npmrc` or global npm config.

### Using an allowlist for lifecycle scripts

Disabling lifecycle scripts by default via `ignore-scripts=true` in `.npmrc` = safest. If packages legitimately need lifecycle scripts, use plugin like `@lavamoat/allow-scripts` to create _allowlist_ of packages authorized to run them.

`package.json` allowlist for project using image-processing package sharp:

```json
{
  "lavamoat": {
    "allowScripts": {
      "sharp": true
    }
  }
}
```

## 4) Assess npm project health

### npm outdated command

Rushing to latest releases without reviewing release notes, code changes, comprehensive testing = not necessarily good. Staying out of date / not upgrading for long = trouble too.

npm CLI reports dependency freshness vs semantic versioning offset. `npm outdated` shows out-of-date packages. Yellow = semantic versioning as specified in `package.json` manifest; red = update available. Output also shows latest version per dependency.

### npm doctor command

Many Node.js package managers + Node.js versions in path: how to verify healthy npm install + working environment? Matters in dev environment and CI.

npm CLI has health assessment tool. Run `npm doctor`:

- Check official npm registry reachable; display currently configured registry.
- Check Git available.
- Review installed npm + Node.js versions.
- Permission checks on folders (local + global `node_modules`, package cache folder).
- Check local npm module cache checksum correctness.

## 5) Audit for vulnerabilities in open source dependencies

npm = largest repository of application libraries across language ecosystems; core for JavaScript devs. Growing open source adoption → growing risk of introducing vulnerabilities.

Many popular npm packages found vulnerable; significant risk without dependency auditing. Examples: npm request, superagent, mongoose, security-related packages like jsonwebtoken and validator.

Security is not just scanning at install; integrate with dev workflows across software lifecycle, monitor continuously after deploy:

- Scan for vulnerabilities in third-party open source projects (OWASP Component Analysis)
- Monitor snapshots of project manifests for alerts when new CVEs impact them (OWASP Dependency-Track)

## 6) Artifact governance and supply chain protections

### Use a local npm proxy

npm registry = biggest package collection, home of most Open Source web projects. Different needs for security, deployments, performance: npm allows switching registry.

`npm install` auto-contacts main registry to resolve dependencies; switching is straightforward:

- `npm set registry` sets default registry.
- `--registry` argument for one single registry.

Verdaccio: simple, lightweight, zero-config private registry; install: `$ npm install --global verdaccio`.

Features:

- Supports npm registry format incl. private package features, scope support, package access control, authenticated users in web interface.
- Hooks remote registries; routes dependencies to different registries; caches tarballs. Proxy all dependencies to reduce duplicate downloads + save bandwidth in local dev + CI servers.
- Authentication provider: htpasswd by default; also GitLab, Bitbucket, LDAP; or your own.
- Scales via different storage provider.
- Docker-based project: use official image.
- Fast bootstrap for testing environments; handy for big mono-repo projects.

### Governance & Verification Steps

Supply-chain attacks increasingly target build artifacts, registries, CI credentials. Add lightweight governance + verification to reduce risk + improve response time:

- Track provenance and produce SBOM for builds (CycloneDX/SPDX) to trace what was built + where inputs originated.

  CycloneDX Example:

  ```bash
  # Generate SBOM
  npm install @cyclonedx/cyclonedx-npm
  npx @cyclonedx/cyclonedx-npm --validate > sbom.json # Use the flag `--omit dev` to exclude dev dependencies from SBOM if needed
  ```

- Sign artifacts + build provenance (e.g., Sigstore / cosign or similar) so consumers verify integrity before installing.

  Illustrative Sigstore 5 verification example, assuming GitHub Actions signing workflow. Replace placeholder repository + workflow with your trusted release policy. Verify both expected issuer and certificate identity; identity patterns are regular expressions → anchor them, escape literal dots. Never derive policy from untrusted bundle.

  ```javascript
  // sign-and-verify.mjs
  // npm install sigstore@5

  import * as fs from 'fs';
  import * as sigstore from 'sigstore';

  // Path to your built npm package (via `npm pack`)
  const artifact = 'my-lib-1.0.0.tgz';

  // --- Sign ---
  const payload = fs.readFileSync(artifact);
  const bundle = await sigstore.sign(payload);
  fs.writeFileSync(`${artifact}.sigstore.json`, JSON.stringify(bundle, null, 2));
  console.log('Signed:', artifact);

  // --- Verify ---
  await sigstore.verify(bundle, payload, {
    certificateIssuer: 'https://token.actions.githubusercontent.com',
    certificateIdentityURI:
      '^https://github\\.com/OWNER/REPOSITORY/\\.github/workflows/release\\.yml@refs/heads/main$',
  });
  console.log('Verified OK!');
  ```

- Prefer immutable, access-controlled registries or vetted mirrors (private registries, Verdaccio w/ upstream cache, or [approved mirrors](#use-a-local-npm-proxy)); enable retention / immutability policies where available.
- Restrict, scope, rotate CI + publisher tokens. Bind publisher tokens to workflows or IP ranges; minimize privileges.
- Verify packages in CI: check signatures/provenance, validate SBOM, [run SCA and static analysis](#5-audit-for-vulnerabilities-in-open-source-dependencies), [install from pinned lockfile resolutions](#2-enforce-the-lockfile).
- Automate monitoring + alerts for unusual publishes, token usage, dependency changes; keep documented remediation playbook (revoke tokens, deprecate/yank compromised packages, publish fixes, notify consumers).

Measures incremental, low-risk; combined make supply-chain attacks harder, speed identification + recovery.

## 7) Responsibly disclose security vulnerabilities

Vulnerabilities publicised without prior warning or remedial action are serious threat to users who cannot protect themselves.

Researchers should follow responsible disclosure program: processes/guidelines connecting researchers with vendor/maintainer to convey vulnerability, impact, applicability. After triage, vendor + researcher coordinate fix + publication date, providing upgrade-path/remediation for affected users before public disclosure.

## 8) Enable 2FA

Enabling two-factor authentication (2FA) = critical npm security practice. npm requires 2FA or granular access token configured to bypass 2FA for package publishing. Interactive publishing: require 2FA, disallow token-based publishing where practical.

npm 2FA modes:

- Authorization-only: login via website/CLI, other actions e.g. changing profile info.
- Authorization and write-mode: profile + login actions, plus write actions e.g. managing tokens + packages, minor support for team + package visibility info.

See official docs: configuring 2FA; requiring 2FA for package publishing.

Use authentication app (e.g., Google Authenticator) on mobile device. Easy via npm's UI. CLI: supported npm client version (>=5.5.1):

```sh
npm profile enable-2fa auth-and-writes
```

Follow CLI instructions to enable 2FA, save emergency authentication codes. For 2FA on login + profile changes only, replace `auth-and-writes` with `auth-only`.

## Additional Security Resources

- About secret scanning
- Best practices for securing accounts

## 9) Minimize npm Access Token Use

Classic npm tokens revoked. Prefer trusted publishing with OpenID Connect for supported CI/CD publishing workflows: avoids stored long-lived publishing credentials.

If token still required: granular access token w/ only needed packages, organizations, permissions. Read-only for dependency installation, shortest practical expiration, restrict source IP ranges where stable, enable bypassing 2FA only for non-interactive workflows that cannot use trusted publishing. Store token in CI secret store; never commit.

Review tokens regularly w/ `npm token list`; immediately revoke unnecessary/exposed tokens w/ `npm token revoke <token-id>`.

## 10) Understanding typosquatting and slopsquatting attacks

### Typosquatting attacks

Relies on user mistakes (typos). Bad actors publish malicious modules to npm registry w/ names resembling popular modules; exploit typing errors/visual similarity to trick devs into installing them.

Snyk tracked tens of malicious typosquatting packages in npm; similar on PyPi. Notable: cross-env, event-stream, eslint-scope.

Main target: user credentials, since any package can access env vars via global `process.env`. Other: event-stream case, attackers targeted devs hoping to inject malicious code into app source.

### Slopsquatting attacks

Newer vector exploiting AI coding assistants. When devs ask AI tools (ChatGPT, GitHub Copilot) to suggest packages, models may hallucinate non-existent package names. Attackers monitor hallucinations, publish malicious packages under those exact names; devs may blindly install AI-suggested packages.

Unlike typosquatting (human typing errors), exploits AI generating plausible but non-existent names → harder to detect; name looks legitimate.

E.g., AI suggests `node-fetch-promise` instead of real `node-fetch`. If attacker already published malicious package under hallucinated name, install silently compromises system.

Protect:

- Run `npm view <package-name>` before installing any AI-suggested package to confirm exists.
- Check download count: legitimate = thousands/millions; new malicious = very few.
- Verify real GitHub repository w/ genuine code, commits, contributors.
- Suspect very recently created packages w/ no release history.
- Never blindly `npm install` AI-suggested packages w/o independent verification.
- Teams: add `npm view <package-name>` as CI check for new AI-suggested dependencies before production.

## 11) Use trusted publishers for secure package publishing

Traditional npm publishing uses long-lived tokens that can be compromised/accidentally exposed. Trusted publishing w/ OpenID Connect (OIDC) = more secure: short-lived, workflow-specific credentials auto-generated during CI/CD. Check official trusted publishing docs for current supported providers + runner restrictions.

### How trusted publishing works

Trust relationship between npm + CI/CD provider via OIDC. Configure trusted publisher for package → npm accepts publishes from specific authorized workflow, in addition to traditional methods (npm tokens, manual publishes). npm CLI auto-detects OIDC environments, uses them for authentication before falling back to traditional tokens.

Eliminates risks of long-lived write tokens (compromise, exposure in logs, manual rotation). Each publish uses short-lived, cryptographically-signed tokens specific to workflow; cannot be extracted or reused.

### Automatic provenance generation

Trusted publishing auto-generates provenance attestations: cryptographic proof of package authenticity. Helps users verify packages come from legitimate sources, untampered.

See npm trusted publishing documentation.

## 12) Prevent dependency confusion attacks

Attacker publishes malicious package on public npm registry w/ same name as your internal private package, higher version number. `npm install` may resolve public malicious package over internal one due to higher version.

Attackers discover internal package names via:

- Leaked `package.json` files accidentally pushed to public GitHub repos
- Job postings mentioning internal tools/package names
- Error messages/stack traces revealing internal dependency names

Protect:

- Always use **scoped package names** for internal packages (e.g., `@yourorg/package-name` instead of `package-name`)
- Configure `.npmrc` to point scoped packages explicitly to private registry: `@yourorg:registry=https://your-private-registry.example.com`
- Reserve internal package names on public npm registry by publishing empty placeholder to prevent attacker claims.

## 13) Verify documentation examples before copying into production

Library READMEs/official examples often copied into production. Libraries may use secure defaults internally, but doc examples sometimes show insecure patterns undermining those defaults. "Documentation attack surface": risk comes from how docs teach library use, not library code.

### The pattern

Library implements strong security internally but README examples use weaker configs for brevity/backward compatibility. Devs copy verbatim → introduce vulnerabilities library was designed to prevent. Unlike supply chain attacks, passes every audit tool since library code safe; only copy-pasted usage insecure.

### Real-world examples

Documented across popular npm packages w/ combined weekly downloads exceeding 195 million:

- **Weak key derivation**: widely-used encryption library's README examples derive AES keys from passphrases using MD5 w/ single iteration (EVP_BytesToKey) → GPU tests billions of candidate passphrases per second. Library's own PBKDF2 module has stronger defaults, but prominent AES examples don't use it.
- **Credential exposure on redirect**: HTTP client library's README shows `beforeRedirect` callback re-injecting authorization headers after library already stripped them during protocol downgrades (HTTPS to HTTP) → bypasses library's own security mechanism.
- **Regex anchoring**: libraries accepting regex patterns for validation (e.g., JWT audience matching, CORS origin matching) show unanchored examples like `/example\.com/`, matching `malicious-example.com`. Fix: `^https:\/\/example\.com$`; docs don't demonstrate anchoring.
- **Insecure randomness**: file upload library's README generates filenames with `Math.random()` while library default uses `crypto.randomBytes(16)`. Devs customizing filename per README downgrade from cryptographic to predictable randomness.

### How to protect yourself

- **Never copy README examples into production without security review.** Treat doc code like Stack Overflow code: starting point, not production-ready.
- **Check library source for secure defaults.** If library internally uses `crypto.randomBytes()`, `PBKDF2`, or anchored regex but README uses `Math.random()`, `MD5`, or unanchored patterns, prefer library's internal approach.
- **Validate security-sensitive parameters.** When library accepts patterns, keys, credentials as input, verify usage matches best practices for that type (anchored regex, authenticated encryption, HTTPS-only credentials).
- **Report insecure documentation.** File issue with maintainer for README examples teaching insecure patterns; affects every dev copying them.

More context: Node.js Security Working Group discussion.

## Final Recommendations

Tips to reduce risk:

- Be extra careful copy-pasting package installation instructions into terminal. Verify in source repo + npm registry that it is the intended package. Verify package metadata with `npm info` for contributors + latest versions.
- Default to npm logged-out user in daily routines so credentials aren't the weak spot.
- When installing packages, append `--ignore-scripts` to reduce arbitrary command execution risk. E.g.: `npm install my-malicious-package --ignore-scripts`

## References

- npm: Trusted Publishing with OIDC
- npm: Configuring Two-Factor Authentication
