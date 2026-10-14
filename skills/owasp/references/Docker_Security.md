# Docker Security Cheat Sheet

## Introduction

Docker = most popular containerization technology. Used correctly, can improve security vs running apps directly on host. Misconfigurations can reduce security or introduce vulnerabilities.

Straightforward list of common security errors + best practices for securing Docker containers.

## Rules

### RULE \#0 - Keep Host and Docker up to date

Protect vs known container escape vulnerabilities like Leaky Vessels (typically attacker gains host root): keep host and Docker up to date. Regularly update host kernel and Docker Engine.

Containers share host kernel; vulnerable host kernel → vulnerable containers. E.g. kernel privilege escalation exploit Dirty COW run inside well-insulated container still yields root on vulnerable host.

### RULE \#1 - Do not expose the Docker daemon socket (even to the containers)

Docker socket _/var/run/docker.sock_ = UNIX socket Docker listens on; primary entry point of Docker API. Owner: root. Access to it = unrestricted root access to host.

**Do not enable _tcp_ Docker daemon socket.** Running daemon with `-H tcp://0.0.0.0:XXX` or similar exposes unencrypted, unauthenticated direct daemon access; if host internet connected, anyone on public internet can use your daemon.
If you really, **really** must, secure it per Docker official documentation.

**Do not expose _/var/run/docker.sock_ to other containers**. Running image with `-v /var/run/docker.sock://var/run/docker.sock` or similar: change it. Read-only socket mount doesn't make Docker API read-only: process connecting to socket can still send requests modifying containers or host. Docker grants access to all daemon commands by default; filesystem mount flags don't replace API authorization. Docker compose equivalent:

```yaml
volumes:
  - "/var/run/docker.sock:/var/run/docker.sock"
```

### RULE \#2 - Set a user

Unprivileged container user = best prevention of privilege escalation. Three ways:

1. At runtime w/ `-u` option of `docker run` e.g.:

```bash
docker run -u 4000 alpine
```

2. At build time: add user in Dockerfile and use it. E.g.:

```dockerfile
FROM alpine
RUN groupadd -r myuser && useradd -r -g myuser myuser
#    <HERE DO WHAT YOU HAVE TO DO AS A ROOT USER LIKE INSTALLING PACKAGES ETC.>
USER myuser
```

3. Enable user namespace support (`--userns-remap=default`) in Docker daemon

More: Docker official documentation. For extra security run rootless, see [Rule \#11](#rule-11---run-docker-in-rootless-mode).

Kubernetes: configure in Security Context using `runAsUser` field w/ user ID e.g:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: example
spec:
  containers:
    - name: example
      image: gcr.io/google-samples/node-hello:1.0
      securityContext:
        runAsUser: 4000 # <-- This is the pod user ID
```

Cluster admins: hardened default via `Restricted` level w/ built-in Pod Security admission controller; for greater customization use Admission Webhooks or third party alternative.

### RULE \#3 - Limit capabilities (Grant only specific capabilities, needed by a container)

Linux kernel capabilities = set of privileges usable by privileged. Docker by default runs w/ only subset. Drop some (`--cap-drop`) to harden, or add some (`--cap-add`) if needed.
Never run containers with `--privileged` flag - adds ALL Linux kernel capabilities.

Most secure: drop all capabilities `--cap-drop all`, add only required. E.g.:

```bash
docker run --cap-drop all --cap-add CHOWN alpine
```

**Do not run containers with the _--privileged_ flag!!!**

Kubernetes: configure in Security Context using `capabilities` field e.g:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: example
spec:
  containers:
    - name: example
      image: gcr.io/google-samples/node-hello:1.0
      securityContext:
        capabilities:
          drop:
            - ALL
          add: ["CHOWN"]
```

Cluster admins: hardened default via `Restricted` level w/ built-in Pod Security admission controller; for greater customization use Admission Webhooks or third party alternative.

### RULE \#4 - Prevent in-container privilege escalation

Always run images with `--security-opt=no-new-privileges` to prevent privilege escalation; stops container gaining new privileges via `setuid` or `setgid` binaries.

Kubernetes: configure in Security Context using `allowPrivilegeEscalation` field e.g.:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: example
spec:
  containers:
    - name: example
      image: gcr.io/google-samples/node-hello:1.0
      securityContext:
        allowPrivilegeEscalation: false
```

Cluster admins: hardened default via `Restricted` level w/ built-in Pod Security admission controller; for greater customization use Admission Webhooks or third party alternative.

### RULE \#5 - Be mindful of Inter-Container Connectivity

Inter-Container Connectivity (icc) enabled by default: all containers communicate through `docker0` bridged network. Rather than `--icc=false` on Docker daemon (disables all inter-container communication), define specific network configurations: create custom Docker networks, specify which containers attach. More granular control.

Docker network configuration for container communication: see Docker Documentation.

Kubernetes: Network Policies define rules regulating pod interactions in cluster; robust control of pod-to-pod and pod-to-endpoint communication. Network Policy Editor eases creating/managing policies.

### RULE \#5a - Be careful when mapping container ports to the host with firewalls like UFW

UFW (Uncomplicated Firewall) = popular host-based Linux firewall. Misconception: firewall rules protect all inbound traffic incl. to Docker containers. **Docker manages own `iptables` and `nftables` rules directly and bypasses UFW entirely**. Other tools using `iptables` or `nftables` can conflict similarly; verify other firewall tools work correctly.

Publishing port with `-p 8000:8000` makes Docker insert `iptables` rules opening port to **all interfaces and all source addresses**, typically accepted before explicit firewall `DENY` rules. Traffic may pass regardless of `DENY` rules → unintentionally exposes container services to public internet.

#### Recommended Mitigations

**Option 1 — Bind published ports to localhost only:**

Bind host side of port mapping to `127.0.0.1`: service reachable only locally, not from external networks:

```bash
# Vulnerable: exposes port on all interfaces
docker run -p 8000:8000 myimage

# Safe: binds only to localhost
docker run -p 127.0.0.1:8000:8000 myimage
```

Docker Compose file:

```yaml
services:
  web:
    image: myimage
    ports:
      - "127.0.0.1:8000:8000"  # safe — localhost only
```

**Option 2 — Use `ufw-docker` (or equivalent) to enforce firewall rules over Docker networks:**

UFW: ufw-docker project provides script + supplemental `iptables` rules patching Docker networking to respect UFW policies; use standard UFW commands to control container traffic:

```bash
# Install ufw-docker integration rules
sudo ufw-docker install

# Allow external access to a specific container port
sudo ufw-docker allow mycontainer 8000/tcp
```

Docker and iptables documentation explains Docker/host firewall interaction in depth.

### RULE \#6 - Use Linux Security Module (seccomp, AppArmor, or SELinux) for Runtime Security

**Do not disable default security profile!** Always start from Docker's or host's default profile as baseline.

**Security Profile Recommendations:**

- **Seccomp**: restrict syscalls to minimum required. Start from Docker's default seccomp profile; customize per workload. Docker Seccomp

- **AppArmor**: per-container AppArmor profiles enforce mandatory access controls. Docker AppArmor

- **SELinux**: enable on host; label containers properly. Enforce SELinux policies to prevent unauthorized host resource access. SELinux Guide for Docker

**Runtime Security Improvements:**

- **Behavioral Monitoring**: tools like Falco, Tetragon, Cilium eBPF detect unexpected/malicious container activity. Examples: unexpected exec calls, privilege escalation attempts, unusual network connections.  

- **Anomaly Detection**: continuously monitor container processes, filesystem changes, network activity for abnormal patterns in real time.  

- **Kubernetes Security Context**: configure pods/containers w/ seccomp and AppArmor profiles. Configure a Security Context for a Pod or Container

### RULE \#7 - Limit resources (memory, CPU, file descriptors, processes, restarts)

Limiting resources = best DoS avoidance. Limit memory, CPU, max restarts (`--restart=on-failure:<number_of_restarts>`), max file descriptors (`--ulimit nofile=<number>`), max processes (`--ulimit nproc=<number>`).

See documentation for ulimits details.

Kubernetes: Assign Memory Resources to Containers and Pods, Assign CPU Resources to Containers and Pods, Assign Extended Resources to a Container

### RULE \#8 - Set filesystem and volumes to read-only

**Run containers with read-only filesystem** using `--read-only` flag. E.g.:

```bash
docker run --read-only alpine sh -c 'echo "whatever" > /tmp'
```

If app in container must save something temporarily, combine `--read-only` with `--tmpfs`:

```bash
docker run --read-only --tmpfs /tmp alpine sh -c 'echo "whatever" > /tmp/file'
```

Docker Compose `compose.yml` equivalent:

```yaml
version: "3"
services:
  alpine:
    image: alpine
    read_only: true
```

Kubernetes equivalent in Security Context:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: example
spec:
  containers:
    - name: example
      image: gcr.io/google-samples/node-hello:1.0
      securityContext:
        readOnlyRootFilesystem: true
```

Also, volume mounted only for reading: **mount read-only**
Append `:ro` to `-v`:

```bash
docker run -v volume-name:/path/in/container:ro alpine
```

Or use `--mount` option:

```bash
docker run --mount source=volume-name,destination=/path/in/container,readonly alpine
```

### RULE \#9 - Integrate container scanning tools into your CI/CD pipeline

[CI/CD pipelines](CI_CD_Security.md) crucial in software development lifecycle; include security checks: lint checks, static code analysis, container scanning.

Many issues preventable via Dockerfile best practices; security linter in build pipeline avoids further headaches. Commonly checked:

- Ensure `USER` directive specified
- Ensure base image version pinned
- Ensure OS package versions pinned
- Avoid `ADD`; prefer `COPY`
- Avoid curl bashing in `RUN` directives

References:

- Docker Baselines on DevSec
- Use the Docker command line
- Overview of Docker Compose v2 CLI
- Configuring Logging Drivers
- View logs for a container or service
- Dockerfile Security Best Practices

Container scanning tools essential to successful security strategy: detect known vulnerabilities, secrets, misconfigurations in images; report findings w/ fix recommendations. Popular tools:

- Free
    - Clair
    - Grype
    - Trivy
- Commercial
    - Snyk **(open source and free option available)**
    - Anchore **(open source and free option available)**
    - Docker Scout **(open source and free option available)**
    - JFrog XRay
    - Qualys

Detect secrets in images:

- ggshield **(open source and free option available)**
- Gitleaks **(open source)**
- TruffleHog **(open source)**

Detect misconfigurations in Kubernetes:

- kubeaudit
- kubesec.io
- kube-bench

Detect misconfigurations in Docker:

- inspec.io
- dev-sec.io
- Docker Bench for Security

### RULE \#10 - Keep the Docker daemon logging level at `info`

Docker daemon base logging level default: `info`. Verify via daemon configuration file `/etc/docker/daemon.json`, key `log-level`; absent → default `info`. Daemon started with `--log-level` option overrides configuration file `log-level` value. Check whether daemon runs with different log level:

```bash
ps aux | grep '[d]ockerd.*--log-level' | awk '{for(i=1;i<=NF;i++) if ($i ~ /--log-level/) print $i}'
```

Appropriate log level makes daemon log events worth later review. Base level 'info' and above captures all logs except debug. Don't run daemon at 'debug' unless required.

### Rule \#11 - Run Docker in rootless mode

Rootless mode runs Docker daemon + containers without host-root privileges, reducing impact of daemon/runtime compromise. Doesn't guarantee protection vs host privilege escalation through kernel vulnerabilities; shared kernel remains part of security boundary. Unlike rootless mode, `userns-remap` leaves daemon running with root privileges.

Evaluate [specific requirements](Attack_Surface_Analysis.md) and [security posture](Threat_Modeling.md) to decide if rootless mode fits. Where security paramount and limitations of rootless mode don't interfere with operations: strongly recommended. Alternatively consider [Podman](#podman-as-an-alternative-to-docker).

> Rootless mode allows running the Docker daemon and containers as a non-root user to mitigate potential vulnerabilities in the daemon and the container runtime.
> Rootless mode does not require root privileges even during the installation of the Docker daemon, as long as the prerequisites are met.

Limitations, installation, usage: Docker documentation page.

### RULE \#12 - Utilize Docker Secrets for Sensitive Data Management

Docker Secrets = secure storage/management of sensitive data (passwords, tokens, SSH keys). Avoids exposing sensitive data in images or runtime commands.

```bash
docker secret create my_secret /path/to/super-secret-data.txt
docker service create --name web --secret my_secret nginx:latest
```

Local Docker Compose: file-backed secrets are bind mounts. Protect source files on host w/ appropriate access permissions + storage encryption; declaring Compose secret doesn't encrypt these files. Differs from Swarm-managed secrets (distributed over mutual TLS, stored in encrypted Raft log):

```yaml
version: "3.8"
secrets:
  my_secret:
    file: ./super-secret-data.txt
services:
  web:
    image: nginx:latest
    secrets:
      - my_secret
```

Docker Secrets generally secure in Docker environments, but not recommended for Kubernetes, where secrets stored plaintext by default. Kubernetes: consider additional measures e.g. etcd encryption or third-party tools. See [Secrets Management Cheat Sheet](Secrets_Management.md) and [Kubernetes Security Cheat Sheet](Kubernetes_Security.md).

### RULE \#13 - Enhance Supply Chain Security

Building on [Rule \#9](#rule-9---integrate-container-scanning-tools-into-your-cicd-pipeline): secure entire container image lifecycle, creation to deployment. Key practices:

- Image Provenance: document origin + history of images for traceability + integrity.
- SBOM Generation: create Software Bill of Materials (SBOM) per image detailing all components, libraries, dependencies for transparency + vulnerability management.
- Image Signing: digitally sign images to verify integrity + authenticity.
- Trusted Registry: store documented, signed images with SBOMs in secure registry enforcing strict [access controls](Authorization.md) and supporting metadata management.
- Secure Deployment: implement secure deployment polices e.g. image validation, runtime security, continuous monitoring.

## Podman as an alternative to Docker

Podman = OCI-compliant open-source container management tool by Red Hat; Docker-compatible CLI + desktop application. More secure, lightweight Docker alternative, esp. where secure defaults preferred. Security benefits:

1. Daemonless Architecture: Docker needs central daemon (dockerd) to create/run/manage containers; Podman uses fork-exec model. On container start request Podman forks from current process; child execs into container's runtime.
2. Rootless Containers: fork-exec model lets Podman run containers w/o root privileges. Non-root user starting container: Podman forks and execs under user's permissions.
3. SELinux Integration: built to work with SELinux; extra layer enforcing mandatory access controls on containers + host interactions.

## References

- Docker Engine Security
- Docker Build Attestations
