# Network segmentation Cheat Sheet

## Introduction

Network segmentation = core of multi-layer defense in depth for modern services. Slows attacker if he cannot implement attacks such as:

- SQL-injections, see [SQL Injection Prevention Cheat Sheet](SQL_Injection_Prevention.md);
- compromise of workstations of employees with elevated privileges;
- compromise of another server in organization perimeter;
- compromise of target service via compromise of LDAP directory, DNS server, other corporate services + sites published on Internet.

Goal: basics of network segmentation to counter attacks by building secure, maximally isolated service network architecture.

Segmentation avoids:

- arbitrary command execution on public web server (NginX, Apache, Internet Information Service) giving attacker direct database access;
- attacker w/ unauthorized database server access reaching CnC on Internet.

## Content

- Schematic symbols;
- Three-layer network architecture;
- Interservice interaction;
- Network security policy;
- Useful links.

## Schematic symbols

Elements used in network diagrams:

[Diagram: Schematic symbols]

Crossing rectangle border = crossing firewall:
[Diagram: Traffic passes through two firewalls]

Above: traffic passes through two firewalls named FW1 and FW2

[Diagram: Traffic passes through one firewall]

Above: traffic passes through one firewall, behind which two VLANs

Later schemes omit firewall icons to avoid overload

## Three-layer network architecture

Information systems should by default consist of ≥3 components (**security zones**):

1. [FRONTEND](Network_Segmentation.md#FRONTEND);
2. [MIDDLEWARE](Network_Segmentation.md#MIDDLEWARE);
3. [BACKEND](Network_Segmentation.md#BACKEND).

### FRONTEND

FRONTEND - set of segments with network elements:

- balancer;
- application layer firewall;
- web server;
- web cache.

[Diagram: FRONTEND]

### MIDDLEWARE

MIDDLEWARE - set of segments for network elements:

- web applications implementing information system logic (processing requests from clients, other company services, external services; executing requests);
- authorization services;
- analytics services;
- message queues;
- stream processing platform.

[Diagram: MIDDLEWARE]

### BACKEND

BACKEND - set of network segments for network elements:

- SQL database;
- LDAP directory (Domain controller);
- storage of cryptographic keys;
- file server.

[Diagram: BACKEND]

### Example of Three-layer network architecture

[Diagram: BACKEND]
Example: organization's local network, organization "Сontoso".

Edge firewall contains 2 VLANs of **FRONTEND** security zone:

- _DMZ Inbound_ - segment hosting services/apps accessible from Internet; must be protected by WAF;
- _DMZ Outgoing_ - segment hosting services inaccessible from Internet but with access to external networks (firewall has no rules allowing traffic from external networks).

Internal firewall contains 4 VLANs:

- **MIDDLEWARE** security zone: one VLAN _APPLICATIONS_ - segment hosting information system apps that interact with each other (interservice communication) and other services;
- **BACKEND** security zone:
    - _DATABASES_ - segment delimiting various databases of automated system;
    - _AD SERVICES_ - segment hosting Active Directory services; example shows one server with domain controller Contoso.com;
    - _LOGS_ - segment hosting servers that centrally store application logs of automated system.

## Interservice interaction

Company information systems usually interact. Define firewall policy for such interactions.
Base allowed interactions = green arrows in image below:
[Diagram: Interservice interaction]
Image also shows allowed access from FRONTEND and MIDDLEWARE segments to external networks (e.g., Internet).

Image implies:

1. Access between FRONTEND and MIDDLEWARE segments of different information systems prohibited;
2. Access from MIDDLEWARE segment to BACKEND segment of another service prohibited (no access to foreign database bypassing application server).

Forbidden accesses = red arrows in image below:
[Diagram: Prohibited Interservice Communication]

### Many applications on the same network

To have fewer networks + more apps per network, acceptable to host load balancer on those networks; balances traffic to apps on network.
Then open one port to such network; balancing e.g. based on HTTP request parameters.
Example:
[Diagram: Interservice Communication with balancing]

Only one incoming access per network, opened to balancer in network. But segmentation no longer works: access control between apps from different network segments done at 7th level of OSI model by balancer.

## Network security policy

Organization must define "paper" policy describing firewall rules + basic allowed network access.
Useful at least for:

- network administrators;
- security representatives;
- IT auditors;
- architects of information systems and software;
- developers;
- IT administrators.

Convenient to describe policy with similar images. Present info as concisely + simply as possible.

### Examples of individual policy provisions

Examples help colleagues quickly understand what access is potentially allowed + can be requested.

#### Permissions for CI/CD

Policy may define e.g. basic permissions allowed for software development system. Example:
[Diagram: CI-CD]

#### Secure logging

If any information system compromised, attacker must not later modify its logs. Copy logs to separate server, e.g., via syslog protocol, which only allows appending new events, not modifying logs.
Network security policy for this:
[Diagram: Logging]

Example also covers application logs that may contain security events + potentially important events indicating attack.

#### Permissions for monitoring systems

Company uses Zabbix as IT monitoring system; policy might look like:
[Diagram: Zabbix-Example]

## Useful links

- Full network segmentation cheat sheet by sergiomarotco.

## References

- NIST SP 800-41 Rev. 1: Guidelines on Firewalls and Firewall Policy
- NIST SP 800-215: Guide to a Secure Enterprise Network Landscape
