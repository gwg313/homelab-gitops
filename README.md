# Homelab Kubernetes – GitOps Repository

**Currently in process of major overhaul, so things may be a bit messy for a few days**
This repository contains the Kubernetes manifests and Helm configurations used to operate my self-hosted infrastructure.

The cluster runs on **Talos OS** and is fully managed using **ArgoCD** with the App-of-Apps pattern.

---

## Overview

All infrastructure and applications are declaratively defined in this repository.

Core components:

- Talos OS (Kubernetes distribution)
- ArgoCD (GitOps controller)
- Sealed Secrets (encrypted secret management)
- cert-manager (certificate automation)
- Istio (Gateways for ingress and reverse proxy)
- MetalLB (bare-metal load balancing)

---

## Repository Structure

```
├── bootstrap/
│   └── root-app-of-apps.yaml   # parent ArgoCD application, applied once by hand
├── management/
│   └── platform-apps/          # one ArgoCD Application per platform component / app
├── platform/                   # cluster platform: argocd, cert-manager, kyverno, monitoring, ...
├── apps/                       # self-hosted applications and Tekton CI
└── .tekton/                    # Pipelines-as-Code pipeline for this repository
```

Each application directory contains the manifests or Helm values required to deploy the service.

---

## GitOps Structure

- `bootstrap/root-app-of-apps.yaml` defines the parent ArgoCD application (`task bootstrap`).
- It syncs `management/platform-apps/`, which defines a child Application per component.
- Child Applications point at directories under `platform/` and `apps/`.
- The repository represents the desired state of the cluster.

---

## Secrets Management

Secrets are managed using **Bitnami Sealed Secrets**.

- Plain Kubernetes Secrets are sealed using `kubeseal`.
- Only encrypted SealedSecret resources are committed to Git.
- The Sealed Secrets controller decrypts them inside the cluster.

No unencrypted secrets are stored in this repository.

---

## Networking

### Load Balancing

MetalLB provides external IP addresses for services in the bare-metal cluster.

### Ingress & Reverse Proxy

Istio Gateways are used to expose services externally and handle reverse proxy functionality.

### TLS

cert-manager manages certificate issuance and renewal using configured ClusterIssuers.
