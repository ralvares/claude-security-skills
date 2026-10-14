# Drone Security Cheat Sheet

## Introduction

Drone security crucial: widespread adoption in military, construction, community services. Drone swarms → even minor lapses cause significant risks.

Overview of vulnerable endpoints in drone systems + mitigation strategies.

## Drone System Components

Typical architecture, three components:

1. **Unmanned Aircraft (UmA)** – physical drone, incl. sensors + onboard systems.
2. **Ground Control Station (GCS)** – interface to control/monitor drone operations.
3. **Communication Data-Link (CDL)** – network connection between drone and GCS.

Drone-GCS communication vulnerable to interception + attacks. Peripherals attached to drone may be vulnerable too. **Vulnerable endpoints** below.

## Vulnerable Endpoints & Security Risks

### 1. Communication Security

- **Insecure Communication Links** – data between drone and GCS interceptable if not properly encrypted. Use standard protocols to encrypt all data sent.

- **Command Spoofing and Replay Attacks** – authenticate command messages; reject replayed messages using protocol's freshness checks. MAVLink: use message signing and timestamp validation; encryption alone doesn't provide these controls.

- **Wi-Fi Weaknesses** – weak authentication or unprotected channels allow unauthorized access. Possible even via simple microcontrollers like ESP8266!

    - Use **802.11w MFP (Management Frame Protection)** to prevent Wi-Fi deauthentication attacks. Default protocol now on up-to-date Wi-Fi systems.

### 2. Authentication & Access Control

Most drone controllers use 2 sets of computers,

1. Main chip: performs PID control, handles motors

2. Additional SoC (**companion computer**): manages peripherals (cameras, LiDARs etc.), sends telemetry data.

Their security matters too. Risks:

- **Companion Computers** – open ports (e.g., SSH, FTP) exploitable if not securely configured.

- **User Error and Misconfiguration** – misconfigured security settings expose drone.

### 3. Data Protection

Drones handle sensitive info (e.g., mission details, sensor logs, edge AI models); high risk of loss/capture. Protect onboard data:

- **Storage Encryption** - secures data at rest, even if someone gains physical access while powered off. Examples: LUKS (block-level encryption), gocryptfs (filesystem in userspace), age (file encryption).
- **Sensitive Data in RAM** - store highly sensitive info (e.g, encryption keys, credentials, intellectual property) in RAM; clear after use. Provide before mission start via secure channels.

### 4. Physical Security

Captured/lost drone: ensure data can't be stolen physically. Conditions:

- **Insufficient Physical Security** – unsecured USB ports or exposed hardware → data theft/tampering.

- **Insecure Supply Chain** – compromised supplier components introduce hidden vulnerabilities.

- **End-of-Life Decommissioning Risks** – improperly decommissioned drones may retain sensitive data or be repurposed maliciously.

### 5. System Integrity

Drone shares many properties with classical IoT device re protecting integrity vs unauthorized firmware, software, configuration modification. Without protections attackers inject malicious firmware or modify control stack → persistent, often invisible access, esp. with physical access (e.g., in storage).

IoT security controls apply:

- **Secure Boot** – drone starts only with trusted software:
    - Every firmware piece signed with cryptographic key. Only signed software runs.
    - First-stage bootloader immutable (ROM or eFuse-locked code); verifies signature on second bootloader.
    - Each component verifies next (e.g., second stage bootloader -> kernel -> application).

- **Measured Boot** – extends Secure Boot by recording what software loaded at each stage. Remote systems (fleet manager, ground station) verify drone runs only trusted code. Also authorizes actions locally, e.g. releasing decryption keys only on proper boot.

- **Firmware Signing** – sign firmware + configuration updates cryptographically. Implement rollback protection vs loading older vulnerable firmware. Also encrypt firmware packages, esp. with sensitive IP.

### 6. Sensor Security

Control logic depends on proximity to other drones/aerial vehicles; manipulated sensor data can be disastrous.

Attackers can manipulate sensors (GPS, cameras, altimeters) to feed incorrect data. Like stuxnet changing Iranian Uranium centrifuge speed while reporting normal speed.

Mitigation research: **watermarked signals** whose **entropy** determines whether sensor values correct.

### 7. Logging & Monitoring

- **Inadequate Logging and Monitoring** – insufficient monitoring → breaches/operational anomalies undetected.

- **Integration Issues** – some cameras need webserver configurations; poorly integrated web servers on cameras/telemetry systems may expose vulnerabilities leaking sensitive info.

Ensure strong credentials.

## Secure Communication Protocols

Protocols drone systems use to communicate (drone-to-drone in horde, or with ground stations); what can go wrong + recommendations.

1. **MAVLink 2.0** – widely used protocol between drones and ground control stations (GCS).

   - Require valid MAVLink 2 message signatures for commands over untrusted links. Reject unsigned/incorrectly signed commands. Protect shared signing key; persist signing timestamps across restarts so replay checks remain effective.

   - Heartbeat messages advertise component's presence, type, state. Heartbeat receipt = liveness signal, not authorization to execute commands.

   - **ArduPilot** and **PX4** support MAVLink 2.0 security enhancements; thoroughly tested, recommended.

   - Use **end-to-end encryption**: TLS or DTLS.

Recent CVEs show risk of unauthenticated MAVLink. Absent default authentication produced critical, remotely-reachable vulnerabilities in both dominant open-source autopilots:

- CVE-2026-1579 (PX4, CVSS 9.8, CISA ICSA-26-090-02, CWE-306): MAVLink 2 message signing disabled → unauthenticated party sends SERIAL_CONTROL to get interactive shell access.

- CVE-2026-38971 (ArduPilot ArduPlane ≤ 4.6.3, CVSS 9.1, CWE-125): out-of-bounds read in SERIAL_CONTROL handler (GCS_serial_control.cpp), reachable over MAVLink by unauthenticated attacker — flight-controller memory disclosure + denial of service.

- CVE-2026-32743 and related PX4 issues (CWE-121): MAVLink-reachable stack buffer overflows in log handler → denial of service.

- CVE-2020-10283 (MAVLink): earlier authentication downgrade issue — long-standing weakness.

Defense-in-depth beyond message signing. Signing frequently disabled in field, and software mitigation runs in same trust domain attacker may have compromised; consider enforcing protocol integrity out-of-band:

- Header validation — system-ID allowlists + packet sequence numbers detect unexpected senders + packet loss. Fields don't authenticate unsigned messages; can't replace signature + timestamp validation.

- Typed-payload validation — reject non-finite parameter values (PARAM_SET); bound FTP path lengths vs malformed-value and buffer-overflow classes.

- Hardware-enforced enforcement point — where autopilot firmware can't be modified/trusted, bump-in-the-wire validation device between companion computer and flight controller applies above checks in separate hardware domain, independent of possibly compromised software stack.

2. **CAN (Controller Area Network) Bus** – protocol between internal drone components (e.g., flight controllers, ESCs, GPS modules).

   - Most attacks need **physical access**. Differential signal; hardware hacking possible by tapping.

   - Don't rely on DroneCAN alone to authenticate CAN senders. Its multi-frame cyclic redundancy check (CRC) = unkeyed checksum, not message authentication code. Protect physical bus access; isolate bus from untrusted components.

3. **ZigBee** – low-power wireless protocol, often for telemetry + sensor communication in backup systems.

   - Enable **AES-128 encryption** for transmissions.

   - Deploy **network keys with frequent rotation** to prevent key compromise.

   - Monitor for **ZigBee packet sniffing attacks** using SDR-based tools like **HackRF** or **YARD Stick One**.

4. **Bluetooth** – device connections, e.g. drone controllers or mobile apps.

   - Enforce **Strict Pairing Modes**: LE (Low Energy) Secure Connections over Bluetooth 4.2+. Uses Elliptic curve Diffie-Hellman for key generation; state of the art.

   - Pairing methods such as _Just works_ vulnerable to MITM attacks! Don't use when setting up own Bluetooth adapters.

5. **Wi-Fi (802.11a/b/g/n/ac/ax)** – common for FPV (First Person View) video transmission + drone control.

   - Use **WPA3 encryption** for highest security. Protocols like **WEP** vulnerable!

   - Use **802.11w Management Frame Protection (MFP)** vs deauthentication attacks (crafted packets emulating server, causing deauthentication).

   - Don't rely on hiding Wi-Fi network name or media access control (MAC) address filtering: hidden networks remain discoverable, MAC addresses can be spoofed. Use Wi-Fi authentication + encryption as above.

These measures significantly reduce cyberattack/unauthorized-access risk to UAV communication systems.

## Summary

Table maps common attacks to controls. Choose controls for interfaces actually present on drone and GCS; impact depends on implementation. Radio interference, forged messages, software vulnerabilities need different defenses.

| Attack or exposure | Security measures and limitations |
| --- | --- |
| Malware | Install firmware + GCS software from trusted sources, keep updated; restrict scripts/plugins. Follow GCS hardening guidance. |
| Backdoor access | Restrict administrative interfaces; use verified firmware. Login authentication alone can't prevent access via backdoor bypassing it. |
| Social engineering | Train operators to verify suspicious requests through trusted contact channel, esp. requests for credentials or software installation. |
| Baiting | Restrict untrusted removable media + peripherals on GCS and companion computer; combine operator training with device access controls. |
| Message injection or modification | Authenticate messages; validate contents before acting; apply [MAVLink controls above](#secure-communication-protocols). Valid signature doesn't make unsafe command safe. |
| Fabricated commands | Require authenticated commands from trusted controllers. MAVLink: reject unsigned commands on untrusted links, protect shared signing key; any holder of key can sign messages. |
| Reconnaissance | Reduce exposed interfaces; protect sensitive telemetry. Encryption doesn't conceal all traffic metadata. |
| Network scanning | Disable unused interfaces, restrict network access. Encrypting traffic doesn't close reachable ports. |
| TCP SYN flooding | Exposed TCP services: use platform's SYN-flood protections, e.g. SYN cookies. Normal three-way handshake isn't attack. |
| Eavesdropping | Encrypt sensitive telemetry + control traffic using [secure communication protocols above](#secure-communication-protocols). Message signing alone doesn't provide confidentiality. |
| Traffic analysis | Evaluate protocol-supported padding when packet lengths expose sensitive info. Ordinary encryption doesn't hide traffic timing/volume; padding costs bandwidth + latency. |
| Man-in-the-middle | Authenticate communicating peers, encrypt connection; validate certificates or provisioned keys. See [TLS Cheat Sheet](Transport_Layer_Security.md). |
| Password guessing or cracking | Strong unique passwords, login rate limits, multifactor authentication where supported; see [Authentication Cheat Sheet](Authentication.md). Don't rely on periodic password changes. |
| Wi-Fi credential attacks | Use WPA3 + strong network password where supported. Avoid WEP and other deprecated security modes; intrusion detection system doesn't repair weak authentication. |
| Wi-Fi radio jamming | Configure + test link-loss failsafes for vehicle and mission. Reduce consequences of lost link; don't prevent radio interference. |
| Forged Wi-Fi deauthentication | Require 802.11w Management Frame Protection on compatible endpoints. Protects vs forged management frames, not radio jamming. |
| Replay | Authenticate messages + validate freshness; maintain replay state, incl. across restarts. See [MAVLink signing guidance above](#secure-communication-protocols). |
| Buffer overflow | Use memory-safe components or enforce buffer bounds checks; patch vulnerable parsers. Changing radio frequencies doesn't fix memory corruption. |
| Denial of service through resource exhaustion | Bound message sizes + processing resources, apply rate limits, isolate critical control functions. See [Denial of Service Cheat Sheet](Denial_of_Service.md); radio changes don't resolve application resource exhaustion. |
| Address Resolution Protocol (ARP) cache poisoning | IP networks: isolate untrusted participants; use dynamic ARP inspection with trusted address bindings where supported. Local network attack, not radio jamming. |
| Ping-of-Death / malformed IP packets | Keep network stack patched; use supported malformed-packet filtering. Changing radio frequencies doesn't correct packet-processing vulnerabilities. |
| GPS spoofing | Use navigation consistency checks; evaluate non-GPS navigation as backup. Don't assume return-to-home safe when position estimate untrusted; test vehicle's navigation failsafes. |

GitHub repos for drone attack simulations (Damn-Vulnerable-Drone) and actual exploits (dronesploit); useful for deeper understanding.

## References

- NIST SP 800-193: Platform Firmware Resiliency Guidelines
- MAVLink: Message Signing (Authentication)
