# AGENTS.md

Rules for anyone working in this repo, human or AI agent. Personal tools and preferences belong
in your own user-level agent config, not here.

## What this repo is

The single GitOps source of truth for two Kubernetes clusters, reconciled by FluxCD:

- `staging`: home cluster, Talos Linux managed through Omni.
- `racknerd`: single-node k3s VPS.

## Layout

| Path | Holds |
|---|---|
| `clusters/{staging,racknerd}/` | Flux entrypoints and each cluster's `.sops.yaml` |
| `apps/base/<app>/` | Base app definitions (HelmRelease, repository, shared manifests) |
| `apps/{staging,racknerd}/<app>/` | Cluster overlays: secrets, databases, routes, values |
| `apps/<cluster>/kustomization.yaml` | Which apps are enabled. A commented-out entry is disabled |
| `infrastructure/{controllers,configs,crds}/` | Operators, cluster configuration, CRDs |
| `monitoring/{controllers,configs}/` | Monitoring stack and its configuration |
| `omni/` | Omni cluster templates and patches for the Talos cluster |
| `machines/` | Non-Kubernetes hosts (Docker compose stacks and their deploy units) |
| `scripts/` | Repo helpers, e.g. the SOPS check used by the pre-commit hook |

Do not reorganize the top level.

## Rules

- **GitOps only.** Every change to cluster state goes through Git and Flux. Read-only `kubectl` and
  `flux` commands and `flux reconcile` are fine; `kubectl apply/edit/patch/delete` to change state is not.
- **No plaintext secrets.** Secrets are SOPS + age encrypted using the cluster's `.sops.yaml`. The
  `sops-encrypted` pre-commit hook rejects unencrypted secrets.
- **Renovate owns versions.** Do not bump chart or image versions by hand unless the task is exactly that.
- **Base and overlay.** Shared definitions in `apps/base/`, cluster-specific values in the overlay.
- **Config rollout.** Environment variables go in a plain static ConfigMap. File-based config (mounted
  files, Helm values) goes through the overlay's `configMapGenerator`, so a content change renames the
  ConfigMap and rolls the pod. Do not add Reloader annotations: Reloader is scoped to `unifi` only.
- **Talos is API-only.** Use `talosctl` and `omnictl`; nodes have no SSH.

## Tools

`mise install` provides the project tools (`kubectl`, `flux`, `kustomize`, `helm`, `talosctl`,
`omnictl`, `cilium`, `sops`, `age`, `gh`, `pre-commit`/`prek`) at `latest`. Python is the exception:
it is pinned because it runs the commit hooks (pre-commit, commitizen via pipx), so a Python
release cannot break committing; it moves only through a Renovate PR. mise loads workspace secrets
from a gitignored `.env`; `mise run kubeconfig` builds kubeconfigs from it. Never commit `.env`.

## Making a change

1. Branch from `origin/main`.
2. Validate: run `kustomize build` on every overlay you touched.
3. Commit with Conventional Commits (`feat(app): ...`, `fix(app): ...`); a commitizen `commit-msg` hook enforces it.
4. Open a pull request. PRs are **squash-merged**.
5. After merge, confirm Flux reconciled (`flux get kustomizations`, `flux get helmreleases -A`) and check
   the app actually works, not only that it reports Ready.

## Known traps

- Cilium's Gateway API leaves the Envoy route timeout unset, so the 15 s default applies. Long requests
  (LLM, MCP, uploads) need `rules[].timeouts.request` on the HTTPRoute.
- A Service named `<app>` injects `<APP>_PORT=tcp://...` env vars into pods in its namespace, which can
  override the app's own setting. Set `enableServiceLinks: false` when the app reads `<APP>_*` variables.
- agentgateway CEL `mcp.tool.name` is the target's unprefixed tool name. Verify tool rules with a live
  `tools/list` and a direct `tools/call`.
