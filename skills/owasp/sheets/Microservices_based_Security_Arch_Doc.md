# Microservices based Security Arch Doc Cheat Sheet

## Introduction

Microservice architecture increasingly used in cloud + on-premise systems. Many security challenges in design + implementation; addressing some needs security-specific architecture info. Goal: concrete proposal for collecting microservice architecture info to secure app.

## Context

Securing microservice apps, architects/engineers face these questions (mostly referenced in OWASP Application Security Verification Standard, ASVS, section V1 "Architecture, Design and Threat Modeling Requirements"):

1. Threat modeling + least privilege:
    - Minimal scopes/API keys microservice needs to access other microservice APIs?
    - Minimal grants microservice needs for database/message queue?
2. Data leakage analysis:
    - Which storages/message queues hold sensitive data?
    - Does microservice read/write data from/to specific database/message queue?
    - Which microservices does a given microservice invoke? What data passes between them?
3. Attack surface analysis:
    - Which microservice endpoints need security testing?

Existing architecture docs usually cannot answer these. Next sections propose security-specific architecture info to collect.

## Objective

Explain what security-specific architecture info can be collected to answer questions above; concrete approach to collect it.

## Proposition

### Collect information on the building blocks

#### Identify and describe application-functionality services

Implement one or several business processes/functions (e.g., storing customer details, product catalog). Collect parameters below per service.

| Parameter name | Description |
| :--- | :--- |
| Service name (ID) | Unique service name or ID |
| Short description | Business process/functionality implemented |
| Link to source code repository | Link to service source repo |
| Development Team | Team developing microservice |
| API definition | If external interface exposed, link to interface description (e.g., OpenAPI spec). Advisable to define security scheme, e.g., scopes/API keys needed per endpoint. |
| The microservice architecture description | Link to architecture diagram/description (if available) |
| Link to runbook | Link to microservice runbook |

#### Identify and describe infrastructure services

Infrastructure services incl. remote services may implement authentication, authorization, service registration/discovery, security monitoring, logging etc. Collect parameters below per service.

| Parameter name | Description |
| :--- | :--- |
|Service name (ID) | Unique service name or ID |
|Short description | Functionality implemented (e.g., authentication, authorization, service registration and discovery, logging, security monitoring, API gateway). |
|Link to source code repository | Link to source repo (if applicable) |
|Link to the service documentation | Link to docs incl. service API definition, operational guidance/runbook, etc. |

#### Identify and describe data storages

Collect parameters below per data storage.

| Parameter name | Description |
| :--- | :--- |
|Storage name (ID) | Unique storage name or ID |
|Software type | Software implementing storage (e.g., PostgreSQL, Redis, Apache Cassandra). |

#### Identify and describe message queues

Messaging systems (e.g., RabbitMQ, Apache Kafka) implement asynchronous microservice communication. Collect parameters below per queue.

| Parameter name | Description |
| :--- | :--- |
|Message queue (ID) | Unique queue name or ID |
|Software type | Software implementing queue (e.g., RabbitMQ, Apache Kafka). |

#### Identify and describe data assets

Identify data assets processed by microservices/services. Advisable first to identify security-valuable assets (e.g., "User information", "Payment"). Collect parameters below per asset.

| Parameter name | Description |
| :--- | :--- |
| Asset name (ID) | Unique asset name or ID |
| Protection level | Asset protection level (e.g., PII, confidential) |
| Additional info | Clarifying info |

### Collect information on relations between building blocks

#### Identify "service-to-storage" relations

Collect parameters below per relation.

| Parameter name | Description |
| :--- | :--- |
| Service name (ID) | Service name (ID) defined above |
| Storage name (ID) | Storage name (ID) defined above |
| Access type | e.g., "Read" or "Read/Write" |

#### Identify "service-to-service" synchronous communications

Collect parameters below per synchronous communication.

| Parameter name | Description |
| :--- | :--- |
| Caller service name (ID) | Caller service (ID) defined above |
| Called service name (ID) | Called service (ID) defined above |
| Protocol/framework used| Protocol/framework, e.g., HTTP (REST, SOAP), Apache Thrift, gRPC |
| Short description | Purpose (info query or state-changing business function request/command) + data passed (if possible, in terms of assets defined above) |

#### Identify "service-to-service" asynchronous communications

Collect parameters below per asynchronous communication.

| Parameter name | Description |
| :--- | :--- |
| Publisher service name (ID) | Publisher service (ID) defined above |
| Subscriber service name (ID) | Subscriber service (ID) defined above |
| Message queue (ID) | Queue (ID) defined above |
| Short description | Purpose (receiving info or commands for state-changing business function) + data passed (if possible, in terms of assets defined above) |

#### Identify "asset-to-storage" relations

Collect parameters below per relation.

| Parameter name | Description |
| :--- | :--- |
| Asset name (ID) | Asset (ID) defined above |
| Storage name (ID) | Storage (ID) defined above |
| Storage type | Storage type for asset, e.g., "golden source" or "cache" |

### Create a graphical presentation of application architecture

Advisable: graphical presentation of building blocks + relations as services call graph or data flow diagram. Tools: e.g., Enterprise Architect, DOT language (graph description language).

### Use collected information in secure software development practices

Useful for security requirements, threat modeling, security testing. Sections below: activities securing app architecture (mapped to OWASP projects) + implementation tips using collected info.

#### Attack surface analysis

##### Implementation tips

To enumerate microservice endpoints for security testing + threat modeling, analyze data under:

- Identify and describe application-functionality services (parameter "API definition")
- Identify and describe infrastructure services (parameter "Link to the service documentation")

##### Mapping to OWASP projects

- OWASP ASVS, V1 "Architecture, Design and Threat Modeling Requirements", #1.1.2
- OWASP Attack Surface Analysis Cheat Sheet

#### Data leakage analysis

##### Implementation tips

To analyze possible data leakage, analyze data under:

- Identify and describe data assets
- Identify "service-to-storage" relations
- Identify "service-to-service" synchronous communications
- Identify "service-to-service" asynchronous communications
- Identify "asset-to-storage" relations

##### Mapping to OWASP projects

- OWASP ASVS, V1 "Architecture, Design and Threat Modeling Requirements", #1.1.2
- OWASP Top 10-2017 A3-Sensitive Data Exposure

#### Application's trust boundaries, components, and significant data flows justification

##### Implementation tips

Start review of trust boundaries, components, significant data flows with inventories from:

- Identify and describe application-functionality services
- Identify and describe infrastructure services
- Identify and describe data storages
- Identify and describe message queues
- Identify "service-to-storage" relations
- Identify "service-to-service" synchronous communications
- Identify "service-to-service" asynchronous communications

Use inventories as inputs to [system model](Threat_Modeling.md#system-modeling). Mark trust boundaries + flows crossing them; justify each crossing. Record endpoint identities, authN/authZ enforcement points, protections for data in transit (see NIST SP 800-204, sections 4.1 and 4.3). Check controls against deployed config + behavior; inventories alone do not verify enforcement.

##### Mapping to OWASP projects

- OWASP ASVS, V1 "Architecture, Design and Threat Modeling Requirements", #1.1.4

#### Analysis of the application's high-level architecture

##### Implementation tips

To verify definition + security analysis of high-level architecture and all connected remote services, analyze data under:

- Identify and describe application-functionality services
- Identify and describe infrastructure services
- Identify and describe data storages
- Identify and describe message queues

##### Mapping to OWASP projects

- OWASP ASVS, V1 "Architecture, Design and Threat Modeling Requirements", #1.1.5

#### Implementation of centralized security controls verification

##### Implementation tips

To verify implementation of centralized, simple (economy of design), vetted, secure, reusable security controls (avoid duplicate, missing, ineffective, insecure controls), analyze data under "Identify and describe infrastructure services".

##### Mapping to OWASP projects

- OWASP ASVS, V1 "Architecture, Design and Threat Modeling Requirements", #1.1.6

#### Enforcement of the principle of least privilege

##### Implementation tips

To define minimal microservice permissions, analyze data under:

- Identify and describe application-functionality services (parameter "API definition")
- Identify "service-to-storage" relations
- Identify "service-to-service" synchronous communications
- Identify "service-to-service" asynchronous communications

##### Mapping to OWASP projects

- OWASP ASVS 4.0.3, V4 "Access Control", #4.1.3

#### Sensitive data identification and classification

##### Implementation tips

To verify all sensitive data identified + classified into protection levels, analyze data under:

- Identify and describe data assets
- Identify "asset-to-storage" relations

##### Mapping to OWASP projects

- OWASP ASVS, V1 "Architecture, Design and Threat Modeling Requirements", #1.8.1

#### Application components business/security functions verification

##### Implementation tips

To verify all components defined + documented by business/security functions provided, analyze data under (parameter "Short description"):

- Identify and describe application-functionality services
- Identify and describe infrastructure services

##### Mapping to OWASP projects

- OWASP ASVS, V1 "Architecture, Design and Threat Modeling Requirements", #1.11.1

## References

- NIST SP 800-204: Security Strategies for Microservices-based Application Systems
- OWASP ASVS 4: Architecture, Design and Threat Modeling
