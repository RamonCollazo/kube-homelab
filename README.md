# 🏡 Kubernetes Homelab

This repository is the **single source of truth** for my personal Kubernetes homelab cluster, managed entirely through **GitOps**. Every piece of infrastructure, every operator, and every application is defined as code right here.

## Introduction

As a Kubernetes enthusiast, my homelab is where I:

  * **Test and validate** modern, production-grade tools.
  * **Take ownership** of the entire application lifecycle, from deployment to backup and security.
  * **Enforce best practices** like infrastructure immutability, GitOps principles, and automated dependency management.

If you are on your own homelab journey, I hope this repository serves as a valuable resource and source of inspiration\!

-----

## Cluster Architecture

This repository manages **two clusters**: a multi-node **staging** cluster running at home, and a lightweight **racknerd** VPS cluster in the cloud. Both are managed by the same Flux GitOps workflow from this monorepo.

### ⚙️ Core Technologies & Principles

| Category | Tool / Technology | Purpose |
| :--- | :--- | :--- |
| **Operating System** | **Talos Linux** | Immutable, minimal, and secure OS designed specifically for Kubernetes. |
| **GitOps Engine** | **FluxCD** | Continuously reconciles the cluster state with this repository. |
| **CNI & Gateway** | **Cilium** | eBPF-based networking, and acting as the **Gateway Controller**. |
| **Storage (CSI)** | **Rook-Ceph** | Provides highly available, distributed storage across my nodes. |
| **Database** | **CloudNativePG** | Postgres operator for reliable, declarative PostgreSQL clusters. |
| **Cache / Queue** | **DragonflyDB** | Redis-compatible in-memory store for cache, queues, and sessions. |
| **Zero Trust Access** | **Cloudflare Zero Trust** | Secure remote access/tunneling to internal services without exposing the network. |
| **Identity & Access** | **Authentik** | SSO/IdP for centralized authentication and fine-grained authorization. |
| **Secrets Management** | **SOPS** | Encrypts sensitive data directly in Git using an Age key. |
| **TLS** | **cert-manager** | Automated certificate issuance and renewal. |

### 📂 Repository Structure (Monorepo)

The cluster state is defined using a **monorepo** structure, which allows for a clear separation between core cluster components and end-user applications.

```
.
├── apps/
│   ├── base/          # App HelmRelease + HelmRepository definitions
│   └── staging/       # Staging overlays: secrets, DB clusters, routes, values
├── infrastructure/
│   ├── controllers/   # Operators and controllers (Cilium, CNPG, Rook-Ceph, etc.)
│   ├── configs/       # Cluster-specific configuration (gateway, cloudflared, etc.)
│   └── crds/          # Custom Resource Definitions (e.g. Gateway API)
├── monitoring/
│   ├── controllers/   # Monitoring stack (kube-prometheus-stack, smartctl-exporter)
│   └── configs/       # Monitoring configuration and dashboards
└── clusters/
    └── staging/       # Flux entrypoint: bootstraps all kustomizations
```

### 🔒 Secrets Management

All sensitive configuration data is committed to this public repository in an **encrypted** state using **SOPS (Secrets OPerationS)** with **Age Encryption**. The Flux controllers securely decrypt these files at runtime using a private key stored only within the cluster.

---

## 💻 Hardware

### Staging Cluster (Home)

A hybrid architecture balancing a low-power control plane with dedicated worker nodes for stateful and resource-intensive workloads.

| Device | CPU & Memory | Storage | OS | Role |
| :--- | :--- | :--- | :--- | :--- |
| **Raspberry Pi 4** | 8GB RAM | 1 x 256GB SD | **Talos Linux** | **Control Plane** |
| **Raspberry Pi 4** | 8GB RAM | 1 x 256GB SD | **Talos Linux** | **Control Plane** |
| **Raspberry Pi 4** | 8GB RAM | 1 x 256GB SD | **Talos Linux** | **Control Plane** |
| **Lenovo ThinkStation Mini P330** | i7-8700T / 64GB RAM | 1 x 128GB NVME, 1 x 1TB NVME | **Talos Linux** | **Worker Node** |
| **Lenovo ThinkStation Mini P330** | i7-8700T / 16GB RAM | 1 x 128GB NVME, 1 x 1TB NVME | **Talos Linux** | **Worker Node** |
| **Lenovo ThinkStation Mini P330** | i7-8700T / 16GB RAM | 1 x 128GB NVME, 1 x 1TB NVME | **Talos Linux** | **Worker Node** |

### Racknerd Cluster (VPS)

A single-node cloud VPS used to work around CGNAT limitations at home. It hosts applications that require direct public IP access (which Cloudflare tunnels cannot provide, e.g. UDP-based protocols) and services that must stay online independently of the home network.

| Device | CPU & Memory | OS | Role |
| :--- | :--- | :--- | :--- |
| **KVM VPS (RackNerd)** | 6 vCPU / 8GB RAM | **Ubuntu 24.04** | **Single-node k3s** |

---

## 🚀 Installed Apps & Infrastructure

### Staging Apps

These are the end-user applications currently deployed on the staging cluster.

| Name | Description |
| :--- | :--- |
| **ActualBudget** | Local-first personal finance and budgeting tool. |
| **Forgejo** | Self-hosted Git forge with OIDC login via Authentik. |
| **FreshRSS** | Lightweight, multi-user RSS aggregator and reader. |
| **GrampsWeb** | Web frontend for the Gramps genealogy application. |
| **Homepage** | Self-hosted homelab dashboard with service tiles, widgets, and health checks. |
| **Kavita** | Self-hosted digital library for manga, comics, and books. |
| **Kiwix** | Offline reader for Wikipedia and other ZIM content. |
| **Linkwarden** | Self-hosted, collaborative bookmark manager with archiving and tags. |
| **Mattermost** | Open-source team messaging and collaboration platform. |
| **n8n** | Workflow automation platform with a visual node editor. |
| **NetBox** | Network source of truth for IPAM, DCIM, and infrastructure documentation. |
| **Open WebUI** | AI chat interface backed by Ollama with GPU acceleration. |

### Racknerd Apps

Applications running on the VPS cluster, requiring a direct public IP or high-availability independent of the home network.

| Name | Description |
| :--- | :--- |
| **Unifi Network Application** | Manages and monitors Unifi network devices at home over a direct public IP (bypasses CGNAT). |
| **SmartrEnergy** | WordPress-based capstone portfolio site, always-on and independent of the home network. |

### Infrastructure

These are the essential cluster-wide services and operators that enable the entire environment.

| Name | Category | Description |
| :--- | :--- | :--- |
| **Cilium** | Networking/Gateway | Provides CNI capabilities and acts as the **Gateway Controller** for all incoming traffic via eBPF. |
| **Rook-Ceph** | Storage | Manages highly available, distributed storage layer using the disks on the worker nodes. |
| **CloudNativePG** | Database | Kubernetes-native PostgreSQL operator and HA clusters. |
| **DragonflyDB** | Cache/Queue | Redis-compatible in-memory store used for cache, session, and queue workloads. |
| **cert-manager** | TLS | Automated TLS certificate management for internal and external services. |
| **NVIDIA Device Plugin** | GPU | Exposes GPU resources to Kubernetes workloads (used by Ollama). |
| **kube-prometheus-stack** | Monitoring/Observability | Full Prometheus metrics and alerting stack with Grafana for visualization. |
| **smartctl-exporter** | Monitoring/Observability | Exports NVMe/disk SMART health metrics to Prometheus. |
| **Cloudflare Zero Trust** | Networking/Security | Secure, identity-aware access to internal apps over Cloudflare Tunnels. |
| **Authentik** | Identity/Access | SSO/IdP for apps; OIDC/SAML providers with policy-driven access. |
| **Renovate** | Automation | Dependency discovery and automatic update PRs for charts, images, and manifests. |
| **Reloader** | Automation | Triggers rolling restarts of workloads when ConfigMaps or Secrets change. |
