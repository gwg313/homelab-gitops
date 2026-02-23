# Homelab Kubernetes – GitOps Repository

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
├── apps/
├── audiobookshelf/
├── bytestash/
├── cert-manager/
├── cluster-issuer/
├── focalboard/
├── forgejo/
├── harbor-config/
├── hedgedoc/
├── karakeep/
├── linkwarden/
├── metallb/
├── minio/
├── navidrome/
├── sealed-secrets/
├── security/
├── stirling-pdf/
├── woodpecker/
├── yopass/
└── root-app.yaml
```

Each application directory contains the manifests or Helm values required to deploy the service.

`root-app.yaml` bootstraps all applications via ArgoCD.

---

## GitOps Structure

- `root-app.yaml` defines the parent ArgoCD application.
- Child applications are defined under `apps/`.
- Infrastructure components and services are separated by directory.
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
