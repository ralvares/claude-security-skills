# Automotive Security Cheat Sheet

## Introduction

Secure vehicle ECUs, connected services, companion apps. Start w/ [threat model](Threat_Modeling.md): map external connections, diagnostic access, sensitive data, paths to safety-critical functions. Agree safe behavior during security failures w/ vehicle safety engineers; auto-shutdown of moving vehicle can add danger. NHTSA guidance = broader development framework.

## Protect Communications and Inputs

- **Separate trust zones.** Isolate infotainment, wireless connectivity, diagnostic interfaces from safety-critical controls. Gateways allow only required message flows. Segmentation limits compromise reach; ≠ authenticating messages within segment.
- **Authenticate vehicle messages.** Conventional CAN doesn't authenticate senders. Use platform-supported protection e.g. AUTOSAR Secure Onboard Communication (SecOC), w/ freshness checks to reject replay. SecOC authenticates configured message data; doesn't encrypt traffic or prevent bus flooding. Compromised sender can still produce authenticated messages.
- **Protect external connections.** [TLS](Transport_Layer_Security.md) w/ certificate validation for vehicle-to-backend and app connections. Authenticate vehicles individually; encrypted connection alone ≠ authorized commands.
- **Validate before acting.** Check message lengths, types, ranges, whether action permitted in current vehicle state, even for authenticated inputs. See [Input Validation](Input_Validation.md). Authentication ≠ sensor reading physically correct.

## Verify Software and Updates

- **Verify before execution.** Secure boot w/ protected trust root authenticates boot chain. Include recovery firmware. NIST guidance, sections 4.3–4.4 covers verification and recovery. Secure boot doesn't prevent runtime exploitation of trusted but vulnerable software.
- **Authenticate updates on ECU.** For OTA and workshop updates verify signed metadata, image hashes, target hardware, freshness, rollback policy. Follow Uptane update verification requirements; transport encryption alone can't establish update authenticity.
- **Plan safe recovery.** Activate updates only under agreed safe vehicle conditions. Recover from interrupted installation w/ authenticated software, w/o bypassing rollback protections. Signatures ≠ software free of vulnerabilities; protect [software supply chain](Software_Supply_Chain_Security.md) too.

## Restrict Access and Protect Data

- **Authorize each operation.** Enforce [authorization](Authorization.md) per vehicle and action in backend services and vehicle command handlers. Separate owner, fleet, service privileges. Revoke previous users' access when ownership or rental access ends.
- **Protect service interfaces.** Disable unnecessary production debug access; authenticate and restrict necessary diagnostic functions while preserving authorized repair. Physical access ≠ authorization. See NHTSA sections 7–8.4.
- **Protect keys and stored data.** Avoid shared fleet-wide access secrets. Hardware-backed key protection where available, w/ renewal and revocation procedures. Minimize retained location and personal data; [encrypt sensitive storage](Cryptographic_Storage.md) w/ keys protected separately from data. Encryption limits offline extraction; software authorized to decrypt can still expose data.

## Test and Maintain Security

Follow NHTSA lifecycle practices, section 4.2:

- Track component versions against deployed vehicles → targeted fixes. Agree w/ suppliers on patch ownership and support duration.
- Test rejected commands, malformed inputs, replay handling, interrupted updates on isolated benches or simulators. Verify security enforcement and safe failure behavior before vehicle deployment.
- Log authentication failures, privileged operations, update results w/o secrets. Assign responsibility for reviewing events and responding to reports.
- Unpatchable components: restrict reachable interfaces, plan replacement. Gateway filtering reduces exposure; doesn't repair vulnerable firmware.

## References

- NHTSA: Cybersecurity Best Practices for the Safety of Modern Vehicles
- AUTOSAR R25-11: Specification of Secure Onboard Communication
- Uptane Standard 2.1.0: Update Verification and Installation
