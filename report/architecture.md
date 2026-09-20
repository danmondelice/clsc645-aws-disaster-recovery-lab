# Architecture figures

These diagrams describe the enhanced Terraform design, not an observed deployment.

## Figure 1. Primary Region, us-east-1

```mermaid
flowchart LR
  U[Browser] --> A[Public ALB across two AZs]
  subgraph P[us-east-1 VPC]
    A --> T[Two WordPress Fargate tasks]
    T --> D[Private MariaDB 10.11]
    T --> E[Encrypted EFS wp-content]
    T --> L[CloudWatch logs]
  end
  A --> M[CloudWatch metrics and alarms]
  D --> M
  M --> N[SNS notifications]
```

Fargate tasks use public IPs for outbound image/log/SSM connectivity. Their security
 group permits inbound HTTP only from the ALB; no NAT gateway or EC2 host is created.

## Figure 2. Recovery Region, us-west-2

```mermaid
flowchart LR
  R[Optional Route 53 secondary alias] --> A[DR ALB across two AZs]
  subgraph W[us-west-2 VPC]
    A --> T[One WordPress Fargate task]
    T --> D[Private MariaDB restored from copied snapshot]
    T --> E[Restored EFS content access point]
  end
  B[Copied RDS backups] -. restore .-> D
  V[DR AWS Backup vault] -. restore .-> E
  T --> C[Regional CloudWatch and SNS]
```

Initially the DR DB and EFS are empty independent stores. Restore and validate
content before enabling DNS failover. Database and EFS recovery are coordinated
procedures; the diagram does not imply synchronous replication.

## Figure 3. Backup and replication flow

```mermaid
flowchart TD
  S[Primary versioned S3 bucket] -->|New object versions, asynchronous CRR| R[DR versioned S3 bucket]
  D[Primary MariaDB] -->|Snapshots and transaction logs| B[Cross-Region automated backups]
  D -->|Manual snapshot-copy helper| C[Destination manual snapshot]
  E[Primary EFS wp-content] -->|Daily backup| V[Primary backup vault]
  V -->|Copy action| W[DR backup vault]
  C -->|Reviewed restore plan| DB[DR MariaDB]
  W -->|AWS Backup restore job| F[Recovery directory on new EFS]
  F -->|Verified access point path| WP[DR WordPress]
  DB --> WP
```

The RPO of the complete application is constrained by its least-current compatible
recovery component. For the lab, stop application writes while creating the paired
RDS/EFS recovery points; retain timestamps and verify both destination copies.
