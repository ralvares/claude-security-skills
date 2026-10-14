# Subdomain Takeover Prevention Cheat Sheet

## Introduction

Subdomain takeover: DNS record (typically CNAME) points to deprovisioned/nonexistent cloud resource or third-party service. Attacker claims orphaned resource, serves arbitrary content on victim's subdomain.

Consistently among most reported bug bounty findings. Prevalent because operational: teams create DNS records when spinning up services, rarely clean up on decommissioning.

Impact beyond defacement. Attacker controlling subdomain can:

- **Steal session cookies** scoped to parent domain (e.g., cookies set on `.example.com` sent to `attacker-controlled.example.com`)
- **Bypass Content Security Policy** rules trusting wildcard subdomains (`*.example.com`)
- **Host convincing phishing pages** on domain users/customers already trust
- **Compromise OAuth and SSO flows** whitelisting subdomain as valid redirect URI
- **Obtain valid TLS certificates** for subdomain from CAs using HTTP or email-based domain validation
- **Receive email** for subdomain if MX records involved → password resets, account verification on third-party services

Sheet guides developers, DevOps, infrastructure teams: prevent takeovers, detect dangling records before attackers, respond when found.

## How Subdomain Takeover Works

### The Basic Mechanism

1. Org creates DNS record: `blog.example.com CNAME example-blog.herokuapp.com`
2. Heroku app serves content on `blog.example.com`
3. Months later team decommissions Heroku app, forgets DNS record
4. CNAME still points to `example-blog.herokuapp.com`, which no longer exists
5. Attacker creates new Heroku app named `example-blog`, claims hostname
6. Attacker controls what's served on `blog.example.com`

### Why It Keeps Happening

Root cause: disconnect between infrastructure provisioning and DNS management:

- **Cloud resources temporary, DNS records persistent.** Services spun up/torn down often; DNS records accumulate unless managed.
- **Different teams own different parts.** Resource creator may lack DNS access; DNS team may not know resource removed.
- **No automated link between resources and DNS.** No mechanism detects DNS target ceasing to exist.
- **Shadow IT and forgotten proof-of-concepts.** Temporary test/demo subdomains never cleaned up.
- **Mergers, acquisitions, reorganizations.** Inherited DNS zones poorly inventoried; original infrastructure owners gone.

### Record Types at Risk

- **CNAME records:** most common vector. Canonical name resolving to claimable service → takeover possible.
- **A records** pointing to released IPs vulnerable if IP reassigned and attacker obtains it. Common in cloud: elastic IPs released to provider pool.
- **NS records** delegating subdomain to third-party DNS provider: particularly dangerous. If DNS provider account closed, anyone creating new account can potentially claim delegated zone, control all records under subdomain.
- **MX records** pointing to deprovisioned mail services let attacker receive subdomain email. Beyond intercepting password resets, worse: most CAs accept email-based domain validation (DV) via addresses like `admin@subdomain.example.com`. Attacker controlling MX completes DV challenges, obtains legitimate TLS certificates for subdomain → transparent HTTPS phishing or man-in-the-middle.

## Cloud Provider Vulnerability Reference

Vulnerability depends on whether service lets new customer claim previously used hostname/resource name. Table = snapshot; providers update policies continuously, always verify current behavior against community-maintained can-i-take-over-xyz repository.

### High Risk: Takeover Possible When Resource Is Removed

| Provider/Service | Vulnerable Resource | Indicator (CNAME Target) | Takeover Mechanism |
|---|---|---|---|
| AWS S3 (Website Hosting) | S3 bucket | `*.s3.amazonaws.com`, `*.s3-website-*.amazonaws.com` | Bucket names globally unique across all AWS accounts. Deleted bucket → any AWS account can recreate same name, serve content on CNAME. |
| AWS Elastic Beanstalk | Environment | `*.elasticbeanstalk.com` | Environment CNAMEs globally unique, released on environment termination. Attacker creates new environment w/ same CNAME prefix. |
| Azure App Service | Web App | `*.azurewebsites.net` | App names globally unique. After deletion any Azure tenant can create app w/ same name. Azure offers domain verification mechanism to mitigate; see Prevention Strategies. |
| Azure Traffic Manager | Profile | `*.trafficmanager.net` | Profile names globally unique, reclaimable after deletion. |
| Azure CDN | Endpoint | `*.azureedge.net` | Endpoint names globally unique. Deleted endpoint name registrable by another tenant. |
| GitHub Pages (Custom Domains) | Unverified custom domain | `*.github.io` | Takeover possible when domain still points to GitHub Pages after repository deleted or Pages disabled, and domain unverified. Account/organization domain verification prevents other GitHub users publishing to verified domain and its immediate subdomains. |
| Heroku | App | `*.herokuapp.com` | App names globally unique, released on app deletion. Any Heroku account can claim name. |
| Shopify | Store | `shops.myshopify.com` | Custom domain associations claimable by any Shopify store. |
| Netlify | Site | `*.netlify.app`, `*.netlify.com` | Site names reclaimable after deletion. |
| Fastly | CDN service | `*.fastly.net`, `*.global.ssl.fastly.net` | Attacker w/ Fastly account adds victim's domain to own Fastly service config. |
| Zendesk | Support portal | `*.zendesk.com` | Support portal subdomain names reclaimable by new Zendesk accounts. |
| Cargo Collective | Portfolio | `*.cargocollective.com` | Portfolio names reclaimable. |
| Tumblr | Blog | `*.tumblr.com` | Custom domain associations released when blog deleted. |

### Conditional Risk: Takeover Possible Under Specific Circumstances

| Provider/Service | Condition | Details |
|---|---|---|
| AWS CloudFront | Dangling DNS alone doesn't establish claimability | Adding new alternate domain name requires attached trusted, valid TLS certificate covering that name. CloudFront checks certificate subject alternative name. Verify prerequisites rather than treating deleted distribution as sufficient evidence of takeover; remove stale DNS records. |
| AWS Route 53 (NS Delegation) | NS delegation to deleted hosted zone | If subdomain NS records delegate to deleted Route 53 hosted zone, attacker can create new hosted zone for same subdomain, may receive same NS server assignments → control of all DNS records for subdomain. |
| Google Cloud Storage | Bucket deleted | GCS bucket names globally unique, reclaimable after deletion. Google rate-limits bucket creation, may temporarily reserve recently deleted names, but not documented security guarantee; don't rely on it. Remove DNS records when decommissioning GCS buckets. |
| Cloudflare | Misconfigured SaaS setup | Standard Cloudflare requires domain ownership verification via nameserver delegation. Cloudflare for SaaS (custom hostnames) configs should use custom hostname verification feature to prevent hostname claim conflicts. |

### Service Fingerprints for Detection

When scanning, look for distinctive error responses indicating backend resource gone:

| Service | Error Response Pattern |
|---|---|
| AWS S3 | `NoSuchBucket`, `The specified bucket does not exist` |
| GitHub Pages | `There isn't a GitHub Pages site here.` |
| Heroku | `No such app`, `herokucdn.com/error-pages/no-such-app.html` |
| Azure App Service | `404 Web Site not found` on `*.azurewebsites.net` |
| Shopify | `Sorry, this shop is currently unavailable.` |
| Netlify | `Not Found - Request ID:` |
| Fastly | `Fastly error: unknown domain:` |
| Zendesk | `Help Center Closed` |

## Prevention Strategies

### 1. Manage DNS Record Lifecycle During Decommissioning

Correct decommissioning order:

1. **Redirect or serve maintenance page** at subdomain → avoids broken links/confusion during transition
2. **Update or remove DNS record** pointing to resource
3. **Wait for DNS propagation** (at least TTL duration, typically 300 to 3600 seconds)
4. **Then decommission cloud resource**

Common mistake: reverse order. Deleting cloud resource first opens immediate takeover window lasting until someone notices dangling record.

Immediate DNS record deletion can disrupt if subdomain linked from other pages, bookmarked, or search-indexed. Reasonable intermediate step: point record to internal server returning HTTP redirect to main domain or simple maintenance page; removes takeover risk, keeps functional UX during transition.

### 2. Maintain a DNS Inventory Linked to Resource Ownership

Keep documented mapping of DNS records to cloud resources:

- **What resource** each CNAME, A, or NS record resolves to?
- **Which team** owns resource?
- **What project or service** it belongs to?
- **When** created, when expected to be decommissioned?
- **Business justification** for subdomain?

Spreadsheet for small orgs; Configuration Management Database (CMDB) for larger. Critical: consult and update during every infrastructure change. Infrastructure-as-Code tools (Terraform, Pulumi, AWS CDK) can serve as living inventory when DNS records and cloud resources share a codebase.

### 3. Implement Automated Dangling Record Detection

Regularly scan DNS records for entries pointing to nonexistent resources:

- **Scheduled scans:** automated checks daily or weekly on all DNS records; verify targets still resolve and respond with expected content, not cloud provider error pages.
- **CI/CD integration:** add DNS validation to deployment and teardown pipelines. On service removal, pipeline verifies associated DNS records also removed before marking decommissioning complete.
- **DNS change monitoring:** alert on new CNAME creation and on target resources returning errors such as HTTP 404, NXDOMAIN, or cloud provider default error pages.

Open-source detection tools:

- dnsReaper: actively maintained subdomain takeover scanner, 40+ service fingerprints, signature-based detection
- nuclei: general-purpose vulnerability scanner w/ dedicated subdomain takeover detection templates
- can-i-take-over-xyz: community-maintained reference of which services are/aren't vulnerable, w/ proof-of-concept details

### 4. Use Domain Verification Where Available

Several cloud providers offer domain verification preventing unauthorized users associating custom domain w/ their account. Strong defense layer when available:

- **Azure App Service:** supports custom domain verification via TXT records. Verification TXT record (e.g., `asuid.subdomain TXT <verification-id>`) ties custom domain to specific Azure subscription. Keep TXT record after decommissioning App Service to prevent another tenant claiming domain.
- **Google Cloud:** many GCP services require domain verification via Google Search Console or DNS TXT record before associating custom domain. Retain verification records as long as DNS record exists.
- **Cloudflare:** standard setup requires domain ownership via nameserver delegation. Cloudflare for SaaS configs should use custom hostname verification feature.
- **GitHub Pages:** verify domain in owning account/organization's Pages settings, retain verification TXT record. Protects verified domain and immediate subdomains, not arbitrary deeper names covered by wildcard DNS; see GitHub's verification scope and instructions.
- **AWS CloudFront:** new alternate domain names require trusted certificate covering name. Name already associated with another distribution can't be added as same alternate name. Keep removing stale DNS during decommissioning; protections differ across AWS services.

Where no domain verification exists, DNS record itself is only control. Prompt removal on decommissioning is only reliable protection.

### 5. Restrict Wildcard DNS Records

Wildcard DNS records (`*.example.com`) especially dangerous: resolve for any subdomain, incl. those matching defunct services. Any service previously under wildcard potentially takeover-able; org may not know which subdomains were in use.

Avoid wildcards unless absolutely necessary. If required:

- Scope as narrowly as possible (e.g., `*.staging.example.com` rather than `*.example.com`)
- Combine w/ reverse proxy or load balancer keeping allowlist of valid hostnames, returning error for unrecognized ones
- Monitor Certificate Transparency logs for unexpected certificate issuance on subdomains matching wildcard

### 6. Establish a Decommissioning Checklist

Formal checklist for removing any externally facing service:

- [ ] Identify all DNS records (CNAME, A, MX, NS, TXT) associated with service
- [ ] Point DNS record to maintenance page or redirect (if immediate removal causes user-facing disruption)
- [ ] Remove or update DNS records
- [ ] Wait for DNS propagation (at least TTL duration)
- [ ] Decommission cloud resource
- [ ] Revoke or let expire any SSL/TLS certificates issued for subdomain
- [ ] Update DNS inventory documentation
- [ ] Remove subdomain from any OAuth redirect URI allowlists, CSP directives, CORS configurations
- [ ] Verify subdomain no longer resolves or returns expected content
- [ ] Run takeover detection scan on subdomain to confirm not claimable

### 7. Limit the Blast Radius with Proper Security Scoping

Limit damage even if takeover occurs by scoping security controls:

- **Cookies:** don't scope session cookies to parent domain (`.example.com`) unless necessary. Prefer specific fully qualified subdomain (`app.example.com`). Use `__Host-` cookie prefix where possible: restricts cookie to exact origin.
- **Content Security Policy:** avoid `*.example.com` in CSP directives; list trusted subdomains explicitly. Taken-over subdomain matching CSP wildcard lets attacker inject scripts/exfiltrate data w/o violating policy.
- **CORS:** no wildcard subdomain patterns in `Access-Control-Allow-Origin` validation. Validate against explicit allowlist of trusted origins.
- **OAuth/SSO:** don't whitelist whole subdomain patterns in redirect URI validation. Use exact-match redirect URIs. Taken-over subdomain in OAuth redirect allowlist enables token theft.
- **Email (SPF/DKIM/DMARC):** SPF mechanisms matching taken-over subdomain's IP let attacker send SPF-authenticated email appearing to originate from your domain.

## Monitoring and Detection

### Continuous DNS Monitoring

Ongoing monitoring to catch dangling records before attackers:

- **Compare DNS records against live resources.** For every CNAME in zone, verify target still exists and responds with expected content, not cloud provider error page.
- **Monitor for service fingerprints.** Error responses in Service Fingerprints table strongly indicate resource removed while DNS record remains. Automated scanning for these patterns at least weekly.
- **Track DNS zone changes.** Version-controlled DNS management (e.g., Terraform, OctoDNS, DNSControl): all additions/removals reviewed, approved, logged. Creates audit trail for investigating how dangling record arose.
- **Monitor Certificate Transparency logs.** Services like crt.sh or certspotter alert on any certificate issuance for your subdomains. Unexpected certificate for subdomain you don't control strongly indicates takeover occurred or in progress.

### Indicators of Compromise

Signs subdomain may already be taken over:

- Subdomain suddenly serves unexpected content, parking page, or different application
- SSL/TLS certificate for subdomain issued to unknown entity/organization (visible in Certificate Transparency logs)
- Users report phishing emails/pages appearing to come from subdomain
- WAF or proxy logs show subdomain resolving to IP outside known infrastructure ranges
- DMARC aggregate reports show email sent from subdomain not originated by your org

## Incident Response

If subdomain takeover discovered:

1. **Remove DNS record immediately.** Fastest mitigation; breaks link between your domain and attacker's resource. If can't remove quickly, point it to IP or CNAME you control.
2. **Revoke or request revocation of any certificates** issued for subdomain during takeover. Check Certificate Transparency logs to find all issued certificates.
3. **Assess impact.** Determine whether parent-domain-scoped cookies could be stolen, whether phishing content served and how long, whether OAuth/SSO flows referenced subdomain, whether attacker could receive subdomain email (MX-based takeover).
4. **Notify affected users** if evidence sensitive data exposed, credentials phished, or session cookies intercepted.
5. **Investigate root cause.** Find process gap allowing dangling record; update decommissioning procedures to prevent recurrence.
6. **Scan all DNS zones** owned by org for other dangling records; same gap likely affects other subdomains.
7. **Document incident**: timeline, impact assessment, corrective actions, for internal review and improving future response.

## References

- OWASP WSTG 4.1: Test for Subdomain Takeover
- Microsoft: Prevent Dangling DNS Entries and Avoid Subdomain Takeover
