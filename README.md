# Homelab Kubernetes – GitOps Repository

This repository contains the Kubernetes manifests and Helm configurations used to operate my self-hosted infrastructure.

The cluster runs on **Talos Linux** and is fully managed by **Argo CD** with the App-of-Apps pattern. Nothing is applied by hand except the root application.

---

## Overview

| Layer | Components |
|-------|------------|
| OS / Kubernetes | Talos Linux, Kubernetes 1.36 (3 control planes, 4 workers on Proxmox) |
| Networking | Cilium: CNI, kube-proxy replacement, BGP, Gateway API, WireGuard encryption, Hubble |
| GitOps | Argo CD, Argo CD Image Updater |
| Policy & security | Kyverno, Tetragon, Cilium network policies, Sealed Secrets |
| Certificates | cert-manager |
| Storage | TrueNAS: NFS (nfs-subdir-external-provisioner) and static iSCSI volumes |
| Observability | kube-prometheus-stack (Prometheus, Alertmanager, Grafana) |
| CI/CD | Tekton Pipelines-as-Code, Shipwright, Harbor, Forgejo – see [ci/README.md](ci/README.md) |

Cilium and the Talos machine configuration are installed outside this repository (Talos patches and a Taskfile for day-2 operations live in the separate `homelab` repo under `talos-cilium/`).

---

## Repository Structure

```
├── bootstrap/
│   └── root-app-of-apps.yaml   # parent Argo CD application, applied once by hand
├── management/
│   └── platform-apps/          # one Argo CD Application (or ApplicationSet) per component / app
├── platform/                   # cluster platform: argocd, cert-manager, kyverno, monitoring, tekton, shipwright, ...
├── apps/                       # self-hosted applications (including Forgejo and Harbor)
├── ci/                         # CI platform: shared Tekton task catalog, ci-project chart, per-project config
├── .tekton/                    # Pipelines-as-Code pipeline for this repository
└── Taskfile.yaml               # local checks and helpers (task --list)
```

Each application directory contains the manifests or Helm values required to deploy the service.

---

## GitOps Structure

- `bootstrap/root-app-of-apps.yaml` defines the parent Argo CD application (`task bootstrap`).
- It syncs `management/platform-apps/`, which defines a child Application per component.
- Child Applications point at directories under `platform/`, `apps/` and `ci/`.
- Apps whose manifests live in their own repository (e.g. `soulsync`) use a multi-source Application: the app repo's kustomize overlay pinned to a commit, plus this repo for cluster-specific resources (sealed secrets, volumes, routes).
- The `ci-projects` ApplicationSet creates one CI project per `ci/projects/<name>/values.yaml`.
- The repository represents the desired state of the cluster.

---

## Applications

| App | Purpose |
|-----|---------|
| audiobookshelf | Audiobooks and podcasts |
| bytestash | Code snippet storage |
| forgejo | Git hosting and generic package registry |
| harbor | Container registry, including a Docker Hub proxy cache |
| homebox | Home inventory |
| homepage | Dashboard |
| it-tools | Developer utilities |
| karakeep | Bookmarks |
| mealie | Recipes |
| navidrome | Music streaming |
| plane | Project management |
| soulsync | Music library automation (slskd behind a ProtonVPN gluetun sidecar) |
| stirling-pdf | PDF tools |
| tuwunel | Matrix homeserver |
| vikunja | Tasks |
| yopass | One-time secret sharing |

---

## Secrets Management

Secrets are managed using **Bitnami Sealed Secrets**.

- Plain Kubernetes Secrets are sealed using `kubeseal` (`task seal INPUT=... OUTPUT=...`).
- Only encrypted SealedSecret resources are committed to Git.
- The Sealed Secrets controller decrypts them inside the cluster.

No unencrypted secrets are stored in this repository; `gitleaks` runs locally (`task secrets`) and in CI.

---

## Security Policies

**Kyverno** mutates every pod to secure defaults (non-root, all capabilities dropped, `RuntimeDefault` seccomp, default resource requests/limits) and enforces:

- non-root containers
- dropping all capabilities
- no privilege escalation
- no `:latest` image tags (digest-only references are allowed)
- no hostPath volumes

Exceptions are opt-in per namespace label (`policy.home.arpa/allow-root-optin`, `allow-hostpath`) plus a pod label, so a namespace label alone grants nothing. Read-only root filesystems are audited, not enforced.

**Tetragon** audits process executions and network connections at runtime.

---

## Networking

### Network Policies

Kyverno generates a baseline `CiliumNetworkPolicy` in every namespace (default-deny ingress, DNS egress). Each app ships `CiliumNetworkPolicy` resources for the traffic it needs; outbound internet access is allowed per FQDN (Cilium DNS proxy). Note that Cilium's `*` in an FQDN pattern matches a single DNS label.

### Ingress & Reverse Proxy

A shared Cilium **Gateway API** gateway exposes services through `HTTPRoute`s on `*.gwg313.xyz` (plus `local.` and `zerotier.` variants). Cilium BGP announces the gateway's LoadBalancer IP to the router.

Because the gateway's Envoy runs in the Cilium agent, policies are enforced against the *original* client pod: an in-cluster client reaching another app through its public hostname needs egress to the backend pod, and the backend needs ingress from it.

### TLS

cert-manager issues certificates through a Cloudflare DNS-01 ClusterIssuer, including the shared gateway's wildcard certificate.

---

## Storage

Storage comes from a TrueNAS server.

- **NFS** via nfs-subdir-external-provisioner with the classes `nfs-client`, `nfs-retain` and `nfs-ephemeral`. There is no default StorageClass, so every PVC names one. The NFS share maps all files to UID 1000, so workloads that check ownership (e.g. Postgres) run as 1000.
- **iSCSI** static PersistentVolumes (CHAP-authenticated) for workloads that need a real block device, such as SQLite databases, which lock up on NFS.

---

## CI/CD

Every repository – this one included – is built and tested in-cluster by Tekton Pipelines-as-Code. Images are built by Shipwright (kaniko or ko), pushed to Harbor and deployed by Argo CD; build artifacts such as firmware zips go to Forgejo's package registry. Base images are pulled through Harbor's Docker Hub proxy cache, both by builds and by every node's container runtime.

See [ci/README.md](ci/README.md) for the design, security model and how to onboard a project.

---

## Local Development

The dev shell (devenv) provides the tooling; `task` runs the same checks as CI:

```sh
task          # lint, validate, secrets scan
task lint     # yamllint + shellcheck
task validate # kubeconform
task diff FILE=path/to/manifest.yaml
```
