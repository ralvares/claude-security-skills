# Kubernetes Security Cheat Sheet

## Overview

Starting point for securing Kubernetes cluster. Categories:

- Receive Alerts for Kubernetes Updates
- INTRODUCTION: What is Kubernetes?
- Securing Kubernetes hosts
- Securing Kubernetes components
- Using the Kubernetes dashboard
- Kubernetes Security Best Practices: Build Phase
- Kubernetes Security Best Practices: Deploy Phase
- Kubernetes Security Best Practices: Runtime Phase

More on Kubernetes: Appendix.

## Receive Alerts for Security Updates and Reporting Vulnerabilities

Join kubernetes-announce group for security announcement emails. Kubernetes security reporting page: how to report vulnerabilities.

## INTRODUCTION: What Is Kubernetes?

Open source container orchestration engine automating deployment, scaling, management of containerized applications. Hosted by Cloud Native Computing Foundation (CNCF).

Deploying Kubernetes gives a cluster: set of worker machines (nodes) running containerized applications. Control plane manages worker nodes + Pods.

### Control Plane Components

Components make global cluster decisions, detect/respond to cluster events: kube-apiserver, etcd, kube-scheduler, kube-controller-manager, cloud-controller-manager.

**Component:** kube-apiserver  
**Description:** Exposes Kubernetes API. Front end for control plane.

**Component:** etcd  
**Description:** Consistent, highly-available key-value store; backing store for all cluster data.

**Component:** kube-scheduler  
**Description:** Watches for newly created Pods with no assigned node, selects node to run on.

**Component:** kube-controller-manager  
**Description:** Runs controller processes. Logically each controller is separate process; to reduce complexity all compiled into single binary, run in single process.

**Component:** cloud-controller-manager  
**Description:** Links cluster into cloud provider's API; separates components interacting with cloud platform from those only interacting with cluster.

### Node Components

Run on every node, maintain running pods, provide Kubernetes runtime environment: kubelet, kube-proxy, container runtime.

**Component:** kubelet  
**Description:** Agent on each node. Ensures containers run in a Pod.

**Component:** kube-proxy  
**Description:** Network proxy on each node, implements part of Kubernetes Service concept.

**Container:** runtime  
**Description:** Software responsible for running containers |

## SECTION 1: Securing Kubernetes Hosts

Kubernetes deploys on bare metal, on-premise, public cloud (custom build on virtual machines OR managed service). Designed highly portable → customers can easily migrate workloads and switch between installations.

Flexibility to fit large variety of scenarios = weakness for securing clusters. Engineers deploying platform must know all potential attack vectors + vulnerabilities.

Harden underlying hosts: install latest OS versions, harden OS, implement patch management + configuration management systems, implement essential firewall rules, undertake specific datacenter-based security measures.

### Updating Kubernetes

No one can track all potential attack vectors → first and best defense: always run latest stable Kubernetes version.

Vulnerabilities found in running containers: always update source image and redeploy containers. **Avoid direct updates to running containers: can break image-container relationship.**

```
Example: apt-update
```

**Upgrading containers extremely easy with Kubernetes rolling updates: gradually update running application by upgrading its images to latest version.**

#### Release schedule for Kubernetes

Project maintains release branches for most recent three minor releases; backports applicable fixes, incl. security fixes, to those three branches, depending on severity + feasibility. Patch releases cut from those branches at regular cadence, plus additional urgent releases when required. Hence always upgrade cluster to latest available stable version. See version skew policy for details.

Techniques such as rolling updates, node pool migrations complete update with minimal disruption/downtime.

## SECTION 2: Securing Kubernetes Components

Topics:

- Securing the Kubernetes Dashboard
- Restricting access to etcd (Important)
- Controlling network access to sensitive ports
- Controlling access to the Kubernetes API
- Implementing role-based access control in Kubernetes
- Limiting access to Kubelets

### Securing the Kubernetes Dashboard

Dashboard = webapp for managing cluster. Not part of cluster itself; owners install it. Many tutorials exist; most create service account with very high privileges. This caused Tesla and others to be hacked via poorly configured K8s dashboard (Reference: Tesla cloud resources hacked to run cryptocurrency-mining malware).

Tips:

- Don't expose dashboard to public without additional authentication. No need to access such powerful tool from outside LAN
- Turn on Role-Based Access Control (see below) to limit dashboard's service account
- Don't grant dashboard service account high privileges
- Grant permissions per user; each user sees only what they should
- Using network policies: can block requests to dashboard even from internal pods (doesn't affect proxy tunnel via kubectl proxy)
- Before version 1.8, dashboard had service account with full privileges → check no role binding for cluster-admin left.
- Deploy dashboard with authenticating reverse proxy, multi-factor authentication enabled. Via embedded OIDC `id_tokens` or Kubernetes Impersonation. Lets dashboard use user's credentials instead of privileged `ServiceAccount`. Works on both on-prem and managed cloud clusters.

### Restricting Access To etcd (IMPORTANT)

etcd = critical component storing state + secrets; protect differently from rest of cluster. Write access to API server's etcd = root on entire cluster; even read access escalates privileges fairly easily.

Scheduler searches etcd for pod definitions without node, sends found pods to available kubelet for scheduling. API server validates submitted pods before writing to etcd → malicious users writing directly to etcd bypass many security mechanisms - e.g. PodSecurityPolicies.

Administrators: always use strong credentials from API servers to etcd server, e.g. mutual auth via TLS client certificates; often recommended to isolate etcd servers behind firewall only API servers may access.

#### Limiting access to the primary etcd instance

Letting other cluster components access primary etcd with read or write access to full keyspace = granting cluster-admin access. Strongly recommended: separate etcd instances for other components, or etcd ACLs restricting read/write to keyspace subset.

### Controlling Network Access to Sensitive Ports

Highly recommended: configure authentication + authorization on cluster and nodes. Clusters usually listen on well-defined, distinctive ports → easier for attackers to identify and attack.

Default ports below. Ensure network blocks access to ports; seriously consider limiting Kubernetes API server access to trusted networks.

**Control plane node(s):**

| Protocol | Port Range | Purpose                 |
| -------- | ---------- | ----------------------- |
| TCP      | 6443       | Kubernetes API Server   |
| TCP      | 2379-2380  | etcd server client API  |
| TCP      | 10250      | Kubelet API             |
| TCP      | 10259      | kube-scheduler          |
| TCP      | 10257      | kube-controller-manager |
| TCP      | 10255      | Read-Only Kubelet API   |

**Worker nodes:**

| Protocol | Port Range  | Purpose                |
| -------- | ----------- | ---------------------- |
| TCP      | 10248       | Kubelet Healthz API    |
| TCP      | 10249       | Kube-proxy Metrics API |
| TCP      | 10250       | Kubelet API            |
| TCP      | 10255       | Read-Only Kubelet API  |
| TCP      | 10256       | Kube-proxy Healthz API |
| TCP      | 30000-32767 | NodePort Services      |

### Controlling Access To The Kubernetes API

First line of defense: limit + secure API requests, since they control the platform. Docs: Kubernetes controlling-access.

Topics:

- How Kubernetes handles API authorization
- External API Authentication for Kubernetes (recommended)
- Kubernetes Built-In API Authentication (not recommended)
- Implementing role-based access in Kubernetes
- Limiting access to Kubelets

#### How Kubernetes handles API authorization

Request must be authenticated (logged in) before authorized (granted permission). Kubernetes expects attributes common to REST API requests → existing organization-wide or cloud-provider-wide access control systems handling other APIs work with Kubernetes authorization.

API server authorization: permissions denied by default. Evaluates all request attributes against all policies, allows or denies. All parts of API request must be allowed by some policy to proceed.

#### External API Authentication for Kubernetes (RECOMMENDED)

Kubernetes' internal API authentication mechanisms weak → strongly recommended larger/production clusters use external API authentication.

- OpenID Connect (OIDC): externalize authentication, short lived tokens, centralized groups for authorization.
- Managed Kubernetes (GKE, EKS, AKS) support authentication using credentials from their IAM providers.
- Kubernetes Impersonation: externalize authentication on managed cloud and on-prem clusters w/o access to API server configuration parameters.

Besides choosing appropriate authentication system: treat API access as privileged; Multi-Factor Authentication (MFA) for all user access.

More: Kubernetes authentication reference documentation.

#### Options for Kubernetes Built-In API Authentication (NOT RECOMMENDED)

Internal mechanisms usually suitable only for non-production or small clusters. Why not to use:

- Static Token File: clear text tokens in CSV file on API server node(s). WARNING: can't modify credentials in file until API server restarted.

- X509 Client Certs: unsuitable for production; Kubernetes does not support certificate revocation. User credentials can't be modified/revoked without rotating root certificate authority key and re-issuing all cluster certificates.

- Service Accounts Tokens: primary intended use = workloads in cluster authenticating to API server; can also be used for user authentication.

### Implementing Role-Based Access Control in Kubernetes

RBAC = regulating access to computer/network resources based on roles of individual users in organization. Kubernetes has integrated RBAC component with default roles to define user responsibilities per actions client may want. Use Node and RBAC authorizers together with NodeRestriction admission plugin.

RBAC matches incoming user/group to permissions linked to roles. Permissions combine verbs (get, create, delete) with resources (pods, services, nodes); namespace or cluster scoped. Uses rbac.authorization.k8s.io API group for authorization decisions; policies configurable dynamically through Kubernetes API.

Enable RBAC: start API server with --authorization-mode flag set to comma-separated list including RBAC; e.g.:

```bash
kube-apiserver --authorization-mode=Example,RBAC --other-options --more-options
```

RBAC examples: Kubernetes RBAC documentation.

### Limiting access to the Kubelets

Kubelets expose HTTPS endpoints granting powerful control over node and containers. By default Kubelets allow unauthenticated access to this API. Production clusters should enable Kubelet authentication + authorization.

More: Kubelet authentication/authorization documentation.

## SECTION 3: Kubernetes Security Best Practices: Build Phase

Build phase: secure container images by building secure images + scanning for known vulnerabilities.

### What is a container image?

Container image (CI) = immutable, lightweight, standalone package with everything needed to run application: code, runtime, system libraries, configuration, system tools. Built as layered, read-only artifacts; portable between hosts but share host OS kernel. See Docker: What is a container?

Build CIs on approved, secure base image. Scan + monitor base image at regular intervals so all CIs based on secure, authentic image. Implement strong governance policies on how images built + stored in trusted image registries.

#### Ensure that CIs are up to date

Keep images (and third-party tools included) up-to-date, latest component versions.

### Only use authorized images in Your environment

Downloading/running CIs from unknown sources very dangerous. Only allow images adhering to organization policy; else risk of running vulnerable or malicious containers.

### Use A CI Pipeline To Control and Identify Vulnerabilities

Kubernetes container registry = central repository of all container images. Public or private repository per needs. Store approved images in private registry, push only approved images there; automatically reduces images entering pipeline to fraction of hundreds of thousands of public images.

Strongly recommended: CI pipeline integrating security assessment (e.g. vulnerability scanning) into build. Pipeline vets all code approved for production and used to build images. Scan image for vulnerabilities after build. Push to private registry then deploy to production only if no issues found. Security assessment failing any code → pipeline failure; helps find images with security problems, prevents them entering registry.

Many source code repositories provide scanning (e.g. Github, GitLab); many CI tools integrate open source vulnerability scanners such as Trivy or Grype.

Projects developing image authorization plugins for Kubernetes preventing unauthorized images shipping (Kubernetes PR 27129).

### Minimize Features in All CIs

Best practice: Google and other tech giants strictly limit code in runtime containers for years. Improves signal-to-noise of scanners (e.g. CVE), reduces provenance burden to just what's needed.

Consider minimal CIs such as distroless images (see below). If impossible, don't include OS package managers or shells in CIs: may have unknown vulnerabilities. If OS packages absolutely needed, remove package manager at later step in generation process.

#### Use distroless or empty images when possible

Distroless images sharply reduce attack surface: no shells, fewer packages. More: GoogleContainerTools distroless.

Empty image: ideal for statically compiled languages like Go; image empty → attack surface truly minimal - only your code! More: Docker Hub scratch.

## SECTION 4: Kubernetes Security Best Practices: Deploy Phase

Configure Kubernetes infrastructure securely before any workloads deployed. While configuring, ensure visibility into what CIs deployed and how, else can't identify/respond to security policy violations. Before deployment system should know + tell:

- **What is being deployed** - image info (components, vulnerabilities), pods to be deployed.
- **Where it is going to be deployed** - clusters, namespaces, nodes.
- **How it is deployed** - runs privileged, other deployments it can communicate with, pod security context applied, if any.
- **What it can access** - secrets, volumes, other infrastructure components such as host or orchestrator API.
- **Is it compliant?** - complies with policies + security requirements.

### Code that uses namespaces to isolate Kubernetes resources

Namespaces: logical partitions, enforce resource separation, limit scope of user permissions.

#### Setting the namespace for a request

Set namespace for current request with --namespace flag:

```bash
kubectl run nginx --image=nginx --namespace=<insert-namespace-name-here>
kubectl get pods --namespace=<insert-namespace-name-here>
```

#### Setting the namespace preference

Permanently save namespace for all subsequent kubectl commands in context:

```bash
kubectl config set-context --current --namespace=<insert-namespace-name-here>
```

Validate:

```bash
kubectl config view --minify | grep namespace:
```

More on namespaces: Kubernetes namespaces docs.

### Use the ImagePolicyWebhook to govern image provenance

Strongly recommended: admission controller ImagePolicyWebhook to prevent unapproved images, reject pods using unapproved images, refuse CIs meeting these criteria:

- Images not scanned recently
- Images using base image not explicitly allowed
- Images from insecure registries

More: ImagePolicyWebhook docs.

### Implement continuous security vulnerability scanning

New vulnerabilities constantly discovered → containers may have recently-disclosed vulnerabilities (CVEs) or outdated packages unknown to you. For strong posture, regularly scan production first-party containers (apps you built and previously scanned) and third-party containers (from trusted repository/vendors).

Open Source projects Trivy, Grype, Clair help identify + prioritize vulnerabilities.

### Apply security context to your pods and containers

Use Pod and container security contexts to restrict process privileges + filesystem access. Set `readOnlyRootFilesystem: true` in each container's `securityContext` to prevent writes to root filesystem. Doesn't make mounted volumes read-only or prevent attacks not needing filesystem writes.

Configuring pod security context: grant only privileges needed for resources to function in containers and volumes. Important security context parameters:

Security Context Settings:

1. SecurityContext->**runAsNonRoot**  
   Description: containers run as non-root user.

2. SecurityContext->**Capabilities**  
   Description: controls Linux capabilities assigned to container.

3. SecurityContext->**readOnlyRootFilesystem**  
   Description: controls whether container can write into root filesystem.

4. PodSecurityContext->**runAsNonRoot**  
   Description: prevents running container with 'root' user as part of pod |

#### Security context example: A pod definition that includes security context parameters

Illustrative manifest assumes application image configured to run as numeric non-root user, no writes to root filesystem. Replace example image with your application image.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: hello-world
spec:
  securityContext:
    runAsNonRoot: true
  containers:
    - name: app
      image: registry.example.com/app:tag
      securityContext:
        readOnlyRootFilesystem: true
```

More: Pod security context docs.

### Continuously assess the privileges used by containers

Strongly recommended: all containers follow least privilege; security risk heavily influenced by capabilities, role bindings, privileges given to containers. Each container only minimum privileges/capabilities for intended function.

#### Utilize Pod Security Standards and the Built-in Pod Security Admission Controller to enforce container privilege levels

Pod Security Standards + Pod Security Admission Controller let cluster administrators enforce requirements on pod `securityContext` fields. Three Pod Security Standard profiles:

- **Privileged**: Unrestricted, allows known privilege escalations. For system/infrastructure-level workloads requiring privilege. All securityContext settings permitted
- **Baseline**: Minimally restrictive; for common containerized workloads, prevents known privilege escalations. Targets developers/operators of non-critical applications. Most dangerous securityContext settings not permitted, e.g. securityContext.privileged, hostPID, hostPath, hostIPC.
- **Restricted**: Most restrictive; enforces current Pod hardening practices at expense of some compatibility. For security critical workloads or untrusted users. Includes all baseline enforcements plus much more restrictive requirements, e.g. dropping all capabilities, enforcing runAsNotRoot, more.

Profile settings baselines: Pod Security Standards profile details.

Pod Security Admission Controller can enforce, audit, or warn on violation of defined policy. `audit` and `warn` modes determine whether a Pod Security Standard would normally prevent pod deployment when set to `enforce` mode.

Namespace allowing only Pods conforming to restricted Pod Security Standard:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: policy-test
  labels:    
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

Cluster administrators: properly organize + enforce policy on cluster namespaces; permit privileged policy only on namespaces where absolutely required, e.g. critical cluster services needing host access. Set namespaces to lowest Pod Security Policy enforceable that supports their risk level.

More granular enforcement beyond three profiles (Privileged, Baseline, Restricted): third party admission controllers like OPA Gatekeeper or Kyverno, or built-in Validating Admission Policy.

#### Use Pod security policies to control the security-related attributes of pods, which includes container privilege levels

> **Warning**  
> Kubernetes deprecated Pod Security Policies in favor of Pod Security Standards and Pod Security Admission Controller; removed from Kubernetes in v1.25. Use Pod Security Standards and Pod Security Admission Controller instead.

All security policies should include:

- Application processes don't run as root.
- Privilege escalation not allowed.
- Root filesystem read-only.
- Default (masked) /proc filesystem mount used.
- Avoid sharing host network or process namespace. NetworkPolicy behavior for `hostNetwork` Pods depends on network plugin; verify enforcement rather than assuming these Pods get same isolation as other Pods.
- Unused/unnecessary Linux capabilities eliminated.
- Use SELinux options for more fine-grained process controls.
- Each application gets own Kubernetes Service Account.
- Container not needing Kubernetes API access: don't let it mount service account credentials.

More: Pod security policy docs.

### Providing extra security with a service mesh

Service mesh = infrastructure layer handling service-to-service communication quickly, securely, reliably; reduces complexity of managing microservices + deployments. Uniform way to secure, connect, monitor microservices; resolves operational challenges running containers and microservices.

#### Advantages of a service mesh

1. Observability

Generates tracing + telemetry metrics; easy to understand system, quickly root cause problems.

2. Specialized security features

Quickly identifies compromising traffic entering cluster; secures services inside network if properly implemented. Helps manage security via mTLS, ingress and egress control, more.

3. Ability to secure microservices with mTLS

Securing microservices hard; many tools exist, but service mesh most elegant for encrypting on-the-wire traffic within network.

Defense via mutual TLS (mTLS) encryption of traffic between services; mesh automatically encrypts/decrypts requests and responses, removing burden from application developers. Can improve performance by prioritizing reuse of existing persistent connections, reducing computationally expensive new ones. Secures traffic over wire and gives strong identity-based authentication + authorization per microservice.

Valuable for enterprises: mesh shows whether mTLS enabled and working between each service; immediate alerts if security status changes.

4. Ingress & egress control

Monitor/address compromising traffic passing through mesh. E.g. Istio integrated with Kubernetes as ingress controller handles load balancing for ingress. Defenders add perimeter security with ingress rules; egress control lets you see/manage external services and control how services interact with traffic.

5. Operational Control

Helps security + platform teams set right macro controls enforcing access controls, while developers customize as needed within guardrails.

6. Ability to manage RBAC

Helps defenders implement strong Role Based Access Control (RBAC) system, arguably among most critical requirements in large engineering organizations. Even secure system easily circumvented by over-privileged users/employees; RBAC system can:

- Restrict privileged users to least privileges necessary for job responsibilities
- Ensure access to systems set to "deny all" by default
- Help developers ensure proper documentation of roles + responsibilities, one of most critical enterprise security concerns.

#### Disadvantages of the security mesh

Unique challenges:

- Adds A New Layer of Complexity

Introducing proxies, sidecars, other components into already sophisticated environment dramatically increases development + operations complexity.

- Additional Expertise Is Required

Mesh like Istio on top of orchestrator such as Kubernetes → operators must become experts in both.

- Infrastructure Can Be Slowed

Invasive, intricate technology; can significantly slow architecture.

- Requires Adoption of Yet Another Platform

Invasive → developers/operators must adapt to highly opinionated platform and its rules.

### Implementing centralized policy management

Projects providing centralized policy management for Kubernetes cluster: Open Policy Agent (OPA), Kyverno, Validating Admission Policy (built-in feature, general availability in 1.30). This sheet focuses on OPA for depth.

OPA started in 2016 to unify policy enforcement across technologies/systems; can enforce policies on platform like Kubernetes. Currently CNCF incubating project. Creates unified method of enforcing security policy in stack. RBAC and Pod security policies give fine-grained cluster control but apply only to cluster, not outside it.

OPA = general-purpose, domain-agnostic policy enforcement tool not based on any other project; policy queries/decisions follow no specific format. Integrates with APIs, Linux SSH daemon, object store like Ceph; any valid JSON data usable as request attributes if it provides required data. OPA lets you choose input and output--e.g. return True or False JSON object, number, string, or complex data object.

#### Most common use cases of OPA

##### OPA for application authorization

Gives developers already-developed authorization technology, no need to build from scratch. Declarative policy language purpose built for rules such as, "Alice can write to this repository," or "Bob can update this account." Rich tools let developers integrate policies into applications and let end users create policy for their tenants.

Existing homegrown application authorization: may not want to swap in OPA. But to improve developer efficiency with solution scaling with microservices and decomposing monolithic apps, need distributed authorization system; OPA (or related competitors) could be the answer.

##### OPA for Kubernetes admission control

Kubernetes gives developers tremendous control over traditional silos of "compute, networking and storage": set up network and storage exactly as wanted. Administrators/security teams must ensure developers don't shoot themselves (or neighbors) in the foot.

OPA addresses this: security builds policies requiring all container images from trusted sources, preventing running software as root, ensuring storage always marked with encrypt bit and not deleted just because pod restarts, limiting internet access, etc.

Also lets administrators ensure policy changes don't inadvertently do more damage than good. OPA integrates directly into Kubernetes API server, has complete authority to reject any resource admission policy says doesn't belong in cluster—-compute-, network-, storage-related, etc. Policy can also run out-of-band to monitor results; OPA's policies can be exposed early in development lifecycle (e.g. CICD pipeline, developer laptops) if developers need early feedback.

##### OPA for service mesh authorization

OPA can regulate service mesh architectures. Administrators often ensure compliance by building policies into service mesh even when source code modification involved. Even if not embedding OPA for application authorization logic (top use case above), can control microservice APIs by putting authorization policies in service mesh. Security-motivated: implement policies in service mesh to limit lateral movement within microservice architecture.

### Limiting resource usage on a cluster

Use Kubernetes ResourceQuota to limit aggregate resource requests, limits, object counts within namespace, reducing resource-exhaustion risks between tenants. Built-in admission control; doesn't require OPA.

Use LimitRange for per-Pod or per-container minimum/maximum allocations and default requests/limits. ResourceQuota doesn't supply these defaults or enforce minimum allocation per Pod.

Example permits at most four non-terminal Pods in namespace. Across those Pods, total CPU requests ≤ 1 CPU, total memory requests ≤ 1 GiB; total CPU limits ≤ 2 CPUs, total memory limits ≤ 2 GiB. Namespace totals, not per-Pod range.

`compute-resources.yaml`:

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-resources
spec:
  hard:
    pods: "4"
    requests.cpu: "1"
    requests.memory: 1Gi
    limits.cpu: "2"
    limits.memory: 2Gi
```

Assign resource quota to namespace:

```bash
kubectl create -f ./compute-resources.yaml --namespace=myspace
```

More: Kubernetes resource quotas docs.

### Use Kubernetes network policies to control traffic between pods and clusters

Compromised application can attack neighboring applications. By default Pods non-isolated for ingress and egress. Configure policies for each direction to restrict; allowing inbound traffic doesn't configure outbound policy.

Strongly recommended: network segmentation, key security control ensuring containers only communicate with approved containers and preventing attacker lateral movement across containers. Applying segmentation in cloud challenging due to "dynamic" nature of container network identities (IPs).

Use current `networking.k8s.io/v1` NetworkPolicy API. Cluster must use network plugin enforcing NetworkPolicy; creating resource alone has no effect without one.

Illustrative ingress policy selects `segment=backend` Pods in `tenant-a`, allows TCP port 80 from `segment=frontend` Pods in same namespace. Policies additive: another policy can allow additional traffic. Policy doesn't restrict egress; traffic from Pod's own node remains allowed.

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: pol1
  namespace: tenant-a
spec:
  podSelector:
    matchLabels:
      segment: backend
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              segment: frontend
      ports:
        - port: 80
          protocol: TCP
```

More: Kubernetes network policies docs.

### Securing data

#### Keep secrets as secrets

Learn how sensitive data (credentials, keys) stored/accessed in infrastructure. Kubernetes keeps them in "secret": small object containing sensitive data like password or token.

Best: mount secrets into read-only volumes in containers, rather than exposing as environment variables. Keep secrets separate from image or pod, else anyone with image access has secret too, even though a pod can't access another pod's secrets. Complex applications handling multiple processes with public access especially vulnerable.

#### Encrypt secrets at rest

Always encrypt backups using well reviewed backup + encryption solution; consider full disk encryption where possible: etcd database contains any information accessible via Kubernetes API. Access to it gives attacker significant visibility into cluster state.

Kubernetes supports encryption at rest for Secret resources in etcd, but API server stores resources without at-rest encryption by default. Configure non-`identity` encryption provider as first provider for Secrets and rewrite existing Secrets to encrypt previously stored data. Helps protect secrets against read access to etcd or backups; doesn't protect if attacker also obtains decryption keys.

#### Alternatives to Kubernetes Secret resources

External secrets manager can store/manage secrets instead of Kubernetes Secrets; consider as security alternative. Benefits over Kubernetes Secrets: handle secrets across multiple clusters (or clouds), control and rotate secrets centrally.

More on Secrets and alternatives: Kubernetes Secret docs.

See also [Secrets Management](Secrets_Management.md) cheat sheet for details + best practices.

#### Finding exposed secrets

Strongly recommended: review secret material present on container against 'least privilege' principle; assess risk of compromise.

Open-source tools such as Trivy and Gitleaks scan container filesystems for sensitive resources: API tokens, passwords, keys. Such resources accessible to any user with access to unencrypted container filesystem, whether during build, at rest in registry or backup, or running.

## SECTION 5: Kubernetes Security Best Practices: Runtime Phase

Runtime phase exposes containerized applications to new security challenges. Gain visibility into running environment to detect + respond to threats as they arise.

Proactively securing containers/deployments at build + deploy phases greatly reduces likelihood of runtime incidents and response effort.

First monitor most security-relevant container activities:

- Process activity
- Network communications among containerized services
- Network communications between containerized services and external clients/servers

Anomaly detection via container behavior generally easier in containers than VMs due to declarative nature of containers + Kubernetes: easier introspection into what's deployed and expected activity.

### Use Pod Security Admission to prevent risky containers/Pods from being deployed

Previously recommended Pod Security Policy deprecated, replaced by Pod Security Admission: enforce security policies on pods in cluster.

Use `baseline` level as minimum for all pods for standard security level across cluster. Clusters should strive to apply `restricted` level (pod hardening best practices).

More: Pod Security Admission configuration docs.

### Container Runtime Security

Hardened containers at runtime let security teams detect/respond to threats and anomalies while containers/workloads run. Typically done by intercepting low-level system calls, looking for events indicating compromise. Events that should trigger alert, e.g.:

- Shell run inside container
- Container mounts sensitive host path such as /proc
- Sensitive file unexpectedly read in running container such as /etc/shadow
- Outbound network connection established

Open source tools such as Falco from Sysdig give defenders many out-of-the-box detections plus custom rules.

### Container Sandboxing

Container runtimes making direct calls to host kernel: kernel often interacts with hardware/devices to respond. Cgroups + namespaces give some isolation, but kernel still large attack surface. Multi-tenant, highly untrusted clusters: defenders often add sandboxing layer against container breakout + kernel exploits. OSS technologies further isolating containers from host kernel:

- Kata Containers: OSS project using stripped-down VMs to keep resource footprint minimal, maximize performance, isolate containers further.
- gVisor : lighter than VM (even stripped down). Own independent kernel written in Go between container and host kernel. Strong sandbox--supports ~70% of linux system calls from container but ONLY uses about 20 system calls to host kernel.
- Firecracker: super lightweight VM running in user space. Locked down by seccomp, cgroup, namespace policies → very limited system calls. Built with security in mind, but may not support all Kubernetes or container runtime deployments.

### Preventing containers from loading unwanted kernel modules

Linux kernel automatically loads kernel modules from disk if needed in certain circumstances (hardware attached, filesystem mounted) → significant attack surface. Relevant to Kubernetes: even unprivileged processes can cause certain network-protocol-related kernel modules to load, just by creating socket of appropriate type. Attackers may exploit security hole in modules administrator assumed unused.

Prevent specific modules auto-loading: uninstall from node, or add blocking rules. Most Linux distributions: create file such as `/etc/modprobe.d/kubernetes-blacklist.conf` with contents like:

```conf
# DCCP is unlikely to be needed, has had multiple serious
# vulnerabilities, and is not well-maintained.
blacklist dccp

# SCTP is not used in most Kubernetes clusters, and has also had
# vulnerabilities in the past.
blacklist sctp
```

Block module loading more generically: use Linux Security Module (e.g. SELinux) to completely deny module_request permission to containers; kernel can't load modules for containers under any circumstances. (Pods still able to use manually loaded modules, or modules loaded by kernel on behalf of more-privileged process).

### Compare and analyze different runtime activity in pods of the same deployments

Replicas (for high availability, fault tolerance, scale) should behave nearly identically. Significant deviation → investigate further. Kubernetes security tool should integrate with external systems (email, PagerDuty, Slack, Google Cloud Security Command Center, SIEMs [security information and event management], etc.) and use deployment labels/annotations to alert team responsible for application when potential threat detected. Commercial Kubernetes security vendor should support wide array of integrations with external tools.

### Monitor network traffic to limit unnecessary or insecure communication

Containerized applications use cluster networking extensively → observing active traffic shows how applications interact and identifies unexpected communication. Observe active traffic, compare to what Kubernetes network policies allow.

Comparing active traffic with allowed also shows what isn't happening but is allowed → tighten network policies, remove superfluous connections, decrease overall attack surface.

Open source projects like inspektor-gadget (kinvolk), PacketStreamer (deepfence) may help; commercial security solutions give varying container network traffic analysis.

### If breached, scale suspicious pods to zero

Contain successful breach with Kubernetes native controls: scale suspicious pods to zero or kill then restart instances of breached applications.

### Rotate infrastructure credentials frequently

Shorter secret/credential lifetime → harder for attacker to use. Set short certificate lifetimes, automate rotation. Use authentication provider controlling issued token lifetime; short lifetimes where possible. Service account tokens in external integrations: rotate frequently. E.g. once bootstrap phase complete, bootstrap token used for setting up nodes should be revoked or its authorization removed.

### Logging

Kubernetes cluster-based logging logs container activity into central log hub. At cluster creation, each container's standard output + standard error can be ingested by Fluentd agent on each node (into Google Stackdriver Logging or Elasticsearch) and viewed with Kibana.

#### Enable audit logging

Kubernetes audit logging records API activity per configured audit policy for later analysis. Enable audit logging; archive audit file on secure server.

Monitor logs for anomalous/unwanted API calls, esp. authorization failures (status message "Forbidden"). Authorization failures could mean attacker abusing stolen credentials.

Managed Kubernetes providers, incl. GKE, give access to this data in cloud console; may allow alerts on authorization failures.

##### Audit logs

Useful for compliance: answer what happened, who did what, when. Flexible auditing of kube-apiserver requests based on policies; track all activities chronologically.

Illustrative `audit.k8s.io/v1` audit event:

```json
{
  "kind":"Event",
  "apiVersion":"audit.k8s.io/v1",
  "level":"Metadata",
  "auditID":"23bc44ds-2452-242g-fsf2-4242fe3ggfes",
  "stage":"RequestReceived",
  "requestURI":"/api/v1/namespaces/default/persistentvolumeclaims",
  "verb":"list",
  "user": {
    "username":"user@example.org",
    "groups":[ "system:authenticated" ]
  },
  "sourceIPs":[ "172.12.56.1" ],
  "objectRef": {
    "resource":"persistentvolumeclaims",
    "namespace":"default",
    "apiVersion":"v1"
  },
  "requestReceivedTimestamp":"2019-08-22T12:00:00Z",
  "stageTimestamp":"2019-08-22T12:00:00Z"
}
```

#### Define Audit Policies

Audit policy sets rules defining which events recorded and what data stored. Object structure defined in audit.k8s.io API group. Event processed → compared against rules in order; first matching rule sets event's "audit level".

Audit levels:

- None - don't log events matching rule
- Metadata - log request metadata (requesting user, timestamp, resource, verb, etc.) but not request/response body
- Request - log event metadata + request body, not response body. Doesn't apply to non-resource requests
- RequestResponse - log event metadata, request and response bodies. Doesn't apply to non-resource requests

Pass policy file to kube-apiserver with --audit-policy-file flag. Flag omitted → no events logged. rules field must be provided in audit policy file. Policy with no (0) rules treated as illegal.

#### Understanding Logging

Main challenge: understanding what logs generated and how to use them. Start with Kubernetes logging architecture overview.

##### Container logging

First log layer: generated by containerized applications. Easiest: write to standard output (stdout) and standard error (stderr) streams.

Manifest:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: example
spec:
  containers:
    - name: example
      image: busybox
      args: [/bin/sh, -c, 'while true; do echo $(date); sleep 1; done']
```

Apply manifest:

```bash
kubectl apply -f example.yaml
```

View container logs:

```bash
kubectl log <container-name> command.
```

Persisting container logs: common approach = write logs to log file, use sidecar container. Sidecar runs in same pod as application container, mounts same volume, processes logs separately.

Example Pod Manifest:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: example
spec:
  containers:
  - name: example
    image: busybox
    args:
    - /bin/sh
    - -c
    - >
      while true;
      do
        echo "$(date)\n" >> /var/log/example.log;
        sleep 1;
      done
    volumeMounts:
    - name: varlog
      mountPath: /var/log
  - name: sidecar
    image: busybox
    args: [/bin/sh, -c, 'tail -f /var/log/example.log']
    volumeMounts:
    - name: varlog
      mountPath: /var/log
  volumes:
  - name: varlog
    emptyDir: {}
```

##### Node logging

Container writing logs to stdout/stderr: container engine streams them to logging driver set by Kubernetes configuration.

Usually logs end up in /var/log/containers directory on host. Docker supports multiple logging drivers but driver configuration not supported via Kubernetes API.

Container terminated/restarted → kubelet stores logs on node. To stop files consuming all host storage, node implements log rotation. Container evicted from node → all containers with corresponding log files evicted.

Depending on host OS + additional services, may need additional logs. E.g. systemd logs:

```bash
journalctl -u
```

##### Cluster logging

Cluster itself has long list of loggable components plus additional data types (events, audit logs). Together give visibility into how Kubernetes performs as system.

Some components run in container, some at OS level (usually systemd service). systemd services write to journald; containerized components write logs to /var/log directory, unless container engine configured to stream logs differently.

#### Events

Kubernetes events indicate Kubernetes resource state changes + errors (exceeded resource quota, pending pods) and informational messages.

All events in specific namespace:

```bash
kubectl get events -n <namespace>

NAMESPACE LAST SEEN TYPE   REASON OBJECT MESSAGE
kube-system  8m22s  Normal   Scheduled            pod/metrics-server-66dbbb67db-lh865                                       Successfully assigned kube-system/metrics-server-66dbbb67db-lh865 to aks-agentpool-42213468-1
kube-system     8m14s               Normal    Pulling                   pod/metrics-server-66dbbb67db-lh865                                       Pulling image "aksrepos.azurecr.io/mirror/metrics-server-amd64:v0.2.1"
kube-system     7m58s               Normal    Pulled                    pod/metrics-server-66dbbb67db-lh865                                       Successfully pulled image "aksrepos.azurecr.io/mirror/metrics-server-amd64:v0.2.1"
kube-system     7m57s               Normal     Created                   pod/metrics-server-66dbbb67db-lh865                                       Created container metrics-server
kube-system     7m57s               Normal    Started                   pod/metrics-server-66dbbb67db-lh865                                       Started container metrics-server
kube-system     8m23s               Normal    SuccessfulCreate          replicaset/metrics-server-66dbbb67db             Created pod: metrics-server-66dbbb67db-lh865
```

Latest events for specific Kubernetes resource:

```bash
kubectl describe pod <pod-name>

Events:
  Type    Reason     Age   From                               Message
  ----    ------     ----  ----                               -------
  Normal  Scheduled  14m   default-scheduler                  Successfully assigned kube-system/coredns-7b54b5b97c-dpll7 to aks-agentpool-42213468-1
  Normal  Pulled     13m   kubelet, aks-agentpool-42213468-1  Container image "aksrepos.azurecr.io/mirror/coredns:1.3.1" already present on machine
  Normal  Created    13m   kubelet, aks-agentpool-42213468-1  Created container coredns
  Normal  Started    13m   kubelet, aks-agentpool-42213468-1  Started container coredns
```

## SECTION 5: Securing a managed-service Kubernetes on Cloud Service Provider

### AWS

Open source tools for securing managed-service Kubernetes on AWS (EKS):

- hardeneks
- MKAD (Managed Kubernetes Auditing Toolkit) from DataDog

## SECTION 6: Supply Chain Security

Container supply chain security critical to prevent attacks exploiting software delivery process vulnerabilities. Compromised supply chain can deploy malicious code into production, potentially affecting thousands of containers/applications.

Supply chain attacks in Kubernetes environments typically target:

- Base images and dependencies
- Build processes and CI/CD pipelines
- Container registries
- Deployment manifests and Helm charts
- Third-party libraries and packages

Recent high-profile attacks (SolarWinds, Codecov, ua-parser-js) show severe impact.

### Best practices for securing the container supply chain

1. Use trusted base images: start with minimal, verified base images from reputable sources to reduce vulnerabilities.
2. Implement image scanning: regularly scan container images for vulnerabilities using tools like Clair, Trivy, or Aqua Security.
3. Secure CI/CD pipelines: secure build processes, proper access controls + monitoring.
4. Sign and verify images: image signing tools like Notary or Cosign ensure container image integrity.
5. Use private registries: store container images in private registries with access controls to prevent unauthorized access.
6. Monitor for vulnerabilities: continuously monitor new vulnerabilities in dependencies and base images.
7. Implement runtime security: tools monitor container behavior at runtime, detect anomalies.

## SECTION 7: Final Thoughts

### Embed security into the container lifecycle as early as possible

Integrate security earlier into container lifecycle; ensure alignment + shared goals between security and DevOps teams. Security can (and should) enable developers/DevOps to confidently build and deploy applications production-ready for scale, stability, security.

### Use Kubernetes-native security controls to reduce operational risk

Use native Kubernetes controls whenever available to enforce security policies so security controls don't collide with orchestrator. E.g. use Kubernetes network policies for secure network communication instead of third-party proxy/shim enforcing network segmentation.

### Leverage the context that Kubernetes provides to prioritize remediation efforts

Manually triaging security incidents + policy violations time consuming in sprawling Kubernetes environments.

E.g. deployment with vulnerability severity score of 7 or greater: raise remediation priority if deployment contains privileged containers and is open to Internet; lower if in test environment supporting non-critical app.

![Kubernetes Architecture](../assets/Kubernetes_Architecture.png)

## References

- Kubernetes: Securing a Cluster
- Kubernetes Security Checklist
