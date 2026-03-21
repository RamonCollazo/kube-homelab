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
│   ├── staging/       # Staging overlays: secrets, DB clusters, routes, values
│   └── racknerd/      # Racknerd overlays: VPS-specific apps and staging proxy
├── infrastructure/
│   ├── controllers/
│   │   ├── base/      # Shared operators (Cilium, CNPG, Rook-Ceph, cert-manager, etc.)
│   │   ├── staging/   # Staging-specific controller overrides
│   │   └── racknerd/  # Racknerd-specific controller overrides
│   ├── configs/
│   │   ├── staging/   # Staging cluster config (gateway, cloudflared, RBAC, etc.)
│   │   └── racknerd/  # Racknerd cluster config (gateway, TLS, etc.)
│   └── crds/
│       ├── base/      # Shared CRDs
│       ├── staging/   # Staging CRD overrides
│       └── racknerd/  # Racknerd CRD overrides (e.g. Gateway API v1.4.1 experimental)
├── monitoring/
│   └── controllers/
│       ├── base/      # Monitoring stack (kube-prometheus-stack, smartctl-exporter)
│       └── staging/   # Staging-specific monitoring values and overrides
├── omni/
│   └── staging/       # Talos machine config patches managed via Omni
└── clusters/
    ├── staging/       # Flux entrypoint for the staging cluster
    └── racknerd/      # Flux entrypoint for the racknerd cluster
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

| | Name | Description |
| :---: | :--- | :--- |
| <img src="https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/actual-budget.png" height="40"/> | **ActualBudget** | Local-first personal finance and budgeting tool. |
| <img src="https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/forgejo.png" height="40"/> | **Forgejo** | Self-hosted Git forge with OIDC login via Authentik. |
| <img src="https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/freshrss.png" height="40"/> | **FreshRSS** | Lightweight, multi-user RSS aggregator and reader. |
| <img src="https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/gramps.png" height="40"/> | **GrampsWeb** | Web frontend for the Gramps genealogy application. |
| <img src="https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/homepage.png" height="40"/> | **Homepage** | Self-hosted homelab dashboard with service tiles, widgets, and health checks. |
| <img src="https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/immich.png" height="40"/> | **Immich** | Self-hosted photo and video backup with ML-powered search and face recognition. |
| <img src="https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/kavita.png" height="40"/> | **Kavita** | Self-hosted digital library for manga, comics, and books. |
| <img src="https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/kiwix.png" height="40"/> | **Kiwix** | Offline reader for Wikipedia and other ZIM content. |
| <img src="https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/linkwarden.png" height="40"/> | **Linkwarden** | Self-hosted, collaborative bookmark manager with archiving and tags. |
| <img src="https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/mattermost.png" height="40"/> | **Mattermost** | Open-source team messaging and collaboration platform. |
| <img src="https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/n8n.png" height="40"/> | **n8n** | Workflow automation platform with a visual node editor. |
| <img src="https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/netbox.png" height="40"/> | **NetBox** | Network source of truth for IPAM, DCIM, and infrastructure documentation. |
| <img src="https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/nextcloud.png" height="40"/> | **Nextcloud** | Self-hosted file sync, sharing, and collaboration platform. |
| <img src="https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/open-webui.png" height="40"/> | **Open WebUI** | AI chat interface backed by Ollama with GPU acceleration. |

### Racknerd Apps

Applications running on the VPS cluster, requiring a direct public IP or high-availability independent of the home network.

| | Name | Description |
| :---: | :--- | :--- |
| <img src="https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/unifi.png" height="40"/> | **Unifi Network Application** | Manages and monitors Unifi network devices at home over a direct public IP (bypasses CGNAT). |
| <img src="https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/wordpress.png" height="40"/> | **SmartrEnergy** | WordPress-based capstone portfolio site, always-on and independent of the home network. |

### Infrastructure

These are the essential cluster-wide services and operators that enable the entire environment.

| | Name | Category | Description |
| :---: | :--- | :--- | :--- |
| <img src="https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/cilium.png" height="40"/> | **Cilium** | Networking/Gateway | Provides CNI capabilities and acts as the **Gateway Controller** for all incoming traffic via eBPF. |
| <img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/rook.png" height="40"/> | **Rook-Ceph** | Storage | Manages highly available, distributed storage layer using the disks on the worker nodes. |
| <img src="https://cdn.brandfetch.io/id-MW8B1On/theme/dark/logo.svg?c=1bxid64Mup7aczewSAYMX&t=1771339352046" width="40"/> | **CloudNativePG** | Database | Kubernetes-native PostgreSQL operator and HA clusters. |
| <img src="https://cdn.brandfetch.io/idwKzhLusM/theme/light/logo.svg?c=1bxid64Mup7aczewSAYMX&t=1766534924983" width="40"/> | **DragonflyDB** | Cache/Queue | Redis-compatible in-memory store used for cache, session, and queue workloads. |
| <img src="https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/cert-manager.png" height="40"/> | **cert-manager** | TLS | Automated TLS certificate management for internal and external services. |
| <img src="https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/nvidia.png" height="40"/> | **NVIDIA Device Plugin** | GPU | Exposes GPU resources to Kubernetes workloads (used by Ollama). |
| <img src="https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/prometheus.png" height="40"/> | **kube-prometheus-stack** | Monitoring/Observability | Full Prometheus metrics and alerting stack with Grafana for visualization. |
| <img src="https://cdn.brandfetch.io/idY88QL3WO/w/150/h/40/theme/light/logo.png?c=1bxid64Mup7aczewSAYMX&t=1766799454821" width="40"/> | **smartctl-exporter** | Monitoring/Observability | Exports NVMe/disk SMART health metrics to Prometheus. |
| <img src="https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/cloudflare.png" height="40"/> | **Cloudflare Zero Trust** | Networking/Security | Secure, identity-aware access to internal apps over Cloudflare Tunnels. |
| <img src="https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/authentik.png" height="40"/> | **Authentik** | Identity/Access | SSO/IdP for apps; OIDC/SAML providers with policy-driven access. |
| <img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/rustfs.png" height="40"/> | **RustFS** | Storage | S3-compatible object storage for database backups and application data. |
| <img src="https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/renovate.png" height="40"/> | **Renovate** | Automation | Dependency discovery and automatic update PRs for charts, images, and manifests. |
| <img src="https://raw.githubusercontent.com/stakater/Reloader/master/assets/web/reloader.jpg" height="40"/> | **Reloader** | Automation | Triggers rolling restarts of workloads when ConfigMaps or Secrets change. |
