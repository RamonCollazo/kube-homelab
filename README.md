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

My cluster uses modern, cloud-native principles to ensure it is secure, reliable, and easily reproducible.

### ⚙️ Core Technologies & Principles

| Category | Tool / Technology | Purpose |
| :--- | :--- | :--- |
| **Operating System** | **Talos Linux** | Immutable, minimal, and secure OS designed specifically for Kubernetes. |
| **GitOps Engine** | **FluxCD** | Continuously reconciles the cluster state with this repository. |
| **CNI & Gateway** | **Cilium** | eBPF-based networking, and acting as the **Gateway Controller**. |
| **Storage (CSI)** | **Rook-Ceph** | Provides highly available, distributed storage across my nodes. |
| **Database** | **CloudNativePG** | Postgres operator for reliable, declarative PostgreSQL clusters. |
| **Zero Trust Access** | **Cloudflare Zero Trust** | Secure remote access/tunneling to internal services without exposing the network. |
| **Identity & Access** | **Authentik** | SSO/IdP for centralized authentication and fine-grained authorization. |
| **Secrets Management** | **SOPS** | Encrypts sensitive data directly in Git using an Age key. |

### 📂 Repository Structure (Monorepo)

The cluster state is defined using a **monorepo** structure, which allows for a clear separation between core cluster components and end-user applications.

### 🔒 Secrets Management

All sensitive configuration data is committed to this public repository in an **encrypted** state using **SOPS (Secrets OPerationS)** with **Age Encryption**. The Flux controllers securely decrypt these files at runtime using a private key stored only within the cluster.

---

## 💻 Hardware

My homelab operates on a hybrid architecture, balancing a low-power control plane with a dedicated worker node for stateful and resource-intensive workloads.

| Device | CPU & Memory | Storage | OS | Role |
| :--- | :--- | :--- | :--- | :--- |
| **Raspberry Pi 4** | 8GB RAM | 1 x 256GB SD | **Talos Linux** | **Control Plane** |
| **Raspberry Pi 4** | 8GB RAM | 1 x 256GB SD | **Talos Linux** | **Control Plane** |
| **Raspberry Pi 4** | 8GB RAM | 1 x 256GB SD | **Talos Linux** | **Control Plane** |
| **Lenovo ThinkStation Mini P330** | i7-8700T / 64GB RAM | 1 x 128GB NVME, 1 x 1TB NVME | **Talos Linux** | **Worker Node** |
| **Lenovo ThinkStation Mini P330** | i7-8700T / 16GB RAM | 1 x 128GB NVME, 1 x 1TB NVME | **Talos Linux** | **Worker Node** |
| **Lenovo ThinkStation Mini P330** | i7-8700T / 16GB RAM | 1 x 128GB NVME, 1 x 1TB NVME | **Talos Linux** | **Worker Node** |

---

## 🚀 Installed Apps & Infrastructure

### Apps

These are the end-user applications currently deployed and managed by Flux.

| Name | Description |
| :--- | :--- |
| **Homepage** | Self-hosted homelab dashboard with service tiles, widgets, and health checks. |
| **Linkwarden** | Self-hosted, collaborative bookmark manager with archiving and tags. |
| **FreshRSS** | Lightweight, multi-user RSS aggregator/reader. |
| **linkding** | A minimal, self-hosted bookmark manager. |

### Infrastructure

These are the essential cluster-wide services and operators that enable the entire environment.

| Name | Category | Description |
| :--- | :--- | :--- |
| **Cilium** | Networking/Gateway | Provides CNI capabilities and acts as the **Gateway Controller** for all incoming traffic via eBPF. |
| **Rook-Ceph** | Storage | Manages highly available, distributed storage layer using the disks on the worker node. |
| **CloudNativePG** | Database | Kubernetes-native PostgreSQL operator and HA clusters. |
| **kube-prometheus-stack**| Monitoring/Observability | The full suite of Prometheus for metrics and alerting, and Grafana for visualization. |
| **Cloudflare Zero Trust** | Networking/Security | Secure, identity-aware access to internal apps over Cloudflare Tunnels. |
| **Authentik** | Identity/Access | SSO/IdP for apps; OIDC/SAML providers with policy-driven access. |
| **Renovate** | Automation | Dependency discovery and automatic update PRs for charts/images/manifests. |
