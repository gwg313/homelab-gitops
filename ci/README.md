# CI platform

Tekton Pipelines-as-Code runs pipelines, Shipwright builds images, Harbor
stores them and Argo CD deploys them. Other build artifacts (e.g. firmware
zips) go to Forgejo's generic package registry. Everything here is deployed by
Argo CD; project repositories only contain their code and `.tekton/`
pipelines.

```
push / PR ──> PaC ──> PipelineRun (ci-<project>)
                        ├─ tekton-catalog Tasks (lint, test, ...)
                        └─ shipwright-build ──> BuildRun (build-<project>)
                                                  └─ kaniko / ko ──> Harbor
                        └─ forgejo-upload ──> Forgejo packages
new image tag ──> commit to homelab-gitops ──> Argo CD sync
```

Rolling out a new image is still a manual commit here (soulsync: the
Application's `targetRevision` and `kustomize.images`); Image Updater is
deployed but not wired up yet.

| Path | What |
|------|------|
| `platform/tekton` | Tekton Pipelines, dashboard, Pipelines-as-Code (pinned) |
| `platform/shipwright` | Shipwright controller + `kaniko` and `ko` ClusterBuildStrategies (kaniko pulls Docker Hub images through Harbor's `dockerhub` proxy cache) |
| `platform/argocd-image-updater` | Image Updater, Harbor registry config |
| `ci/catalog` | Shared Tasks in `tekton-catalog` (only namespace the cluster resolver serves), see below |
| `ci/charts/ci-project` | Chart for a project's namespaces, SAs, RBAC, quotas, network policy, PaC Repository |
| `ci/projects/<name>/` | One directory per project; picked up by the `ci-projects` ApplicationSet |

Catalog tasks:

| Task | What |
|------|------|
| `git-clone` | Clone a revision into the workspace |
| `yamllint`, `kubeconform`, `gitleaks` | YAML lint, manifest schema validation, secret scan |
| `kustomize-build`, `helm-template` | Render every kustomization / chart |
| `go-test`, `golangci-lint`, `govulncheck` | Go checks |
| `pnpm` | Install with pnpm and run package.json scripts (lint, test, ...) |
| `shipwright-build` | Create a BuildRun and wait for it (needs the `build-trigger` SA) |
| `content-tag` | Tag from a hash of some files + whether the registry has it, to rebuild toolchain images only when their inputs change |
| `zmk-build` | Build ZMK keyboard firmware (.uf2) for a board/shield |
| `archive` | Zip a directory |
| `forgejo-upload` | Upload a file to Forgejo's generic package registry |

`helm-template` renders every chart it finds; a chart that needs values to
render can ship a `ci-values.yaml` next to its `Chart.yaml`. This repository's
own CI is `ci/projects/homelab-gitops` + `.tekton/ci.yaml`. Other projects:
`soulsync` (Go/Next.js, 9 images) and `zmk-configs` (firmware zip on Forgejo).

## Security model

- PipelineRuns run in `ci-<project>` as the `pipeline` SA (no API token).
  Pipeline definitions are always read from the default branch
  (`pipelinerun_provenance: default_branch`), so a PR can't change what runs.
- Only the `shipwright-build` task uses the `build-trigger` SA, which can do
  nothing but create/watch BuildRuns in `build-<project>`.
- Builds run in `build-<project>`, which holds the Harbor push secret. That
  namespace is the only one labelled to allow root + extra capabilities;
  `kaniko` uses the PSA-baseline capability set without privileged
  mode or privilege escalation.
- Egress is limited to the git provider, the registry (via the shared
  gateway) and any FQDNs listed in the project's values.
- CI never writes to this repo or the cluster's workloads; Argo CD deploys.

## Onboarding a project

1. In Harbor, create a project and a robot account with push rights on it.
2. Create `ci/projects/<name>/values.yaml`:

   ```yaml
   name: myapp
   repository:
     url: https://git.gwg313.xyz/gwg313/myapp   # as the provider reports it
     provider: forgejo                          # or github
   # egressFQDNs: [proxy.golang.org]            # package registries etc.; Docker Hub
   #                                            # images come through Harbor
   ```

3. Seal the secrets into the same directory:

   ```sh
   # PaC: git provider token + webhook secret (namespace ci-<name>)
   kubectl create secret generic pac-git-token -n ci-myapp \
     --from-literal=token=... --from-literal=webhook-secret=... \
     --dry-run=client -o yaml | kubeseal -o yaml > ci/projects/myapp/pac-git-token-sealed.yaml

   # Harbor robot account (namespace build-<name>)
   kubectl create secret docker-registry harbor-push -n build-myapp \
     --docker-server=registry.gwg313.xyz --docker-username='robot$myapp+ci' --docker-password=... \
     --dry-run=client -o yaml | kubeseal -o yaml > ci/projects/myapp/harbor-push-sealed.yaml
   ```

4. Point the provider's webhook at Pipelines-as-Code with the same webhook
   secret (Forgejo: `http://pipelines-as-code-controller.pipelines-as-code.svc.cluster.local:8080`).
5. Add `.tekton/` to the project repo, e.g.:

   ```yaml
   apiVersion: tekton.dev/v1
   kind: PipelineRun
   metadata:
     name: build
     annotations:
       pipelinesascode.tekton.dev/on-event: "[push]"
       pipelinesascode.tekton.dev/on-target-branch: "[main]"
       pipelinesascode.tekton.dev/max-keep-runs: "5"
   spec:
     taskRunTemplate:
       serviceAccountName: pipeline
     taskRunSpecs:
       - pipelineTaskName: image
         serviceAccountName: build-trigger
     workspaces:
       - name: source
         volumeClaimTemplate:
           spec:
             accessModes: [ReadWriteOnce]
             resources: { requests: { storage: 1Gi } }
     pipelineSpec:
       workspaces:
         - name: source
       tasks:
         - name: clone
           taskRef:
             resolver: cluster
             params:
               - { name: kind, value: task }
               - { name: namespace, value: tekton-catalog }
               - { name: name, value: git-clone }
           params:
             - { name: url, value: "{{ repo_url }}" }
             - { name: revision, value: "{{ revision }}" }
           workspaces:
             - { name: output, workspace: source }
         - name: image
           runAfter: [clone]
           taskRef:
             resolver: cluster
             params:
               - { name: kind, value: task }
               - { name: namespace, value: tekton-catalog }
               - { name: name, value: shipwright-build }
           params:
             - { name: build-namespace, value: build-myapp }
             - { name: git-url, value: "{{ repo_url }}" }
             - { name: revision, value: "{{ revision }}" }
             - { name: image, value: "registry.gwg313.xyz/myapp/myapp:{{ revision }}" }
   ```

6. Deploy the app with an Argo CD Application under
   `management/platform-apps/` that references the built image tag.

## Not done yet / verify on first use

- Harbor proxy-cache projects for ghcr.io/quay.io. Docker Hub is done: the
  `dockerhub` project (Harbor UI), kaniko's `--registry-map`, and a Talos
  registry mirror on every node.
- `harbor-image-updater` pull secret in `argocd`, and git write-back
  credentials for Image Updater.
- Whether the gateway is reached via the `ingress` entity or the registry
  FQDN rule in `build-egress` (keep whichever Hubble shows matching).
- Kubernetes user namespaces (`hostUsers: false`) for build pods, so root in
  the build container isn't root on the node. The cluster version supports
  it; check the Talos `user.max_user_namespaces` sysctl first.
- Public route for Pipelines-as-Code, only needed for GitHub-hosted projects.
