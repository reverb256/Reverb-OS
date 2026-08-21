# Reverb-OS Current State and Omarchy Migration Boundary

> **Target base:** upstream Omarchy/Arch with standalone Home Manager from Reverb-OS.

> **Status:** Active reference
> **Last Verified:** 2026-08-20 (checked-in architecture and target design)
> **Owner:** j_kro
> **Live-state rule:** This document describes checked-in configuration and migration intent. Verify host health and deployed generations with live commands before making claims about runtime state.

> **Migration notice:** The live cluster is still NixOS. Upstream Omarchy/Arch plus standalone Home Manager is the target runtime, not yet a claim about deployed hosts.

## Purpose

This is the short current-state reference for humans and agents. It separates checked-in
configuration, migration target, and live cluster observations so stale generated
snapshots and historical audits are not mistaken for the current deployment.

The target architecture is documented in
[`docs/plans/2026-08-20-omarchy-hm-cluster-vision.md`](plans/2026-08-20-omarchy-hm-cluster-vision.md).
The Omarchy design evidence is in
[`../.research/omarchy-design-philosophy-2026-08-20.md`](../.research/omarchy-design-philosophy-2026-08-20.md).

- **Configuration truth:** the checked-out Git revision in `/etc/nixos`, the
  Reverb-OS flake outputs, and the separately pinned legacy
  `home-manager-config` profile only where a NixOS host still consumes it.
- **Deployment truth:** the active NixOS generation and service state on each host.
- **Kubernetes truth:** the live API server for runtime state; the applicable
  Nix/Easykubenix source, raw/bootstrap manifest, Helm chart, or operator configuration
  for the corresponding deployment source.
- **Historical truth:** dated incident reports, audits, migration plans, and research in
  the archive or explicitly dated documents. Historical documents are not procedures
  unless re-verified.

## Repository and workflow

This repository is currently the NixOS evaluator and cluster declaration for a
four-host cluster. During migration it is also the preserved package, test,
Kubernetes, contract, and rollback source. It is not the permanent authority for
the Omarchy desktop.

Target workflow:

```text
Omarchy installer/update → base OS, packages, migrations, snapshots, Quickshell
standalone Home Manager → additive user layer and supported extensions
Nix/Lix CI → packages, HM evaluation, cache, manifests, tests, provenance
Kubernetes → portable cluster services by default
```

Current NixOS workflow remains:

```text
issue → dedicated worktree → change → parse/check/test → PR → merge to main
→ guarded deployment only when explicitly authorized → provenance and health verification
```

Do not use this documentation change to deploy or to claim that a host has migrated.

Operational commands are defined in `justfile`. In particular:

```bash
just status          # local Git/worktree overview
just check           # flake evaluation/checks
just health          # SSH reachability and Kubernetes node summary
just provenance      # deployed generation/commit/drift evidence
just deploy-canary   # rolling deployment with post-switch probes
just deploy-async    # disconnect-safe Nexus dispatch
just docs-audit      # documentation verification suite
```

Zephyr is the authoring/source-of-truth host and should not perform heavy local Nix
builds. Nexus is the deployment dispatcher and primary builder. Use the Nexus dispatcher
rather than an unguarded direct Colmena apply.

## Hosts

| Host | Primary role | Checked-in identity |
|---|---|---|
| **Zephyr** | workstation, control plane, gaming, desktop/Niri, local cluster authority | `hosts/zephyr/`, shared modules under `modules/` |
| **Nexus** | primary builder/dispatcher, storage, ingress, AI services | `hosts/nexus/`, shared modules under `modules/` |
| **Forge** | GPU compute and mining | `hosts/forge/`, shared modules under `modules/` |
| **Sentry** | monitoring, logging, AMD/Vulkan inference and recovery target | `hosts/sentry/`, shared modules under `modules/` |

Host addresses, roles, scheduling facts, and deployment metadata are defined in
[`contracts/host-inventory.nix`](../contracts/host-inventory.nix) and
[`kubernetes/cluster.nix`](../kubernetes/cluster.nix). These are checked-in inventory
facts, not live hardware discovery. Do not treat an address in an old report as
authoritative.

## Configuration boundaries

### Target authority

- **Omarchy/Arch:** base OS, package/update lifecycle, migrations, snapshots,
  boot, hardware, Hyprland, and Quickshell.
- **Home Manager:** this flake's `homeConfigurations.omarchy`, activated standalone
  on upstream Omarchy. It owns only additive user packages, portable dotfiles,
  user services, and Niri configuration that Omarchy does not provide. The
  separate `home-manager-config` repository remains transitional for legacy hosts.
- **Nix/Lix:** packages, overlays, development shells, cache policy, HM evaluation,
  checks, manifests, contracts, and test artifacts. It must not silently overwrite
  Omarchy-owned paths.
- **Kubernetes:** portable long-running services by default.
- **Host platform layer:** boot, hardware, storage, networking, SSH/recovery, k3s,
  GPU/VFIO, and other privileged operations that cannot move into Kubernetes or HM.
- **NixOS:** current live evaluator and rollback path until each host replacement is
  tested. Do not add new permanent Omarchy desktop ownership here.

### Shared boundaries

- **Secrets:** SecretSpec is the runtime resolution path; sops-nix remains a compatibility
  path until the planned Phase 3 removal. Never put plaintext secrets in documentation.
- **PKI and SSH:** the checked-in CA certificate is the fleet trust anchor; private
  signing keys are provisioned at runtime. SSH host trust is CA-based where configured.
- **Kubernetes:** prefer Nix/Easykubenix modules and typed service/host contracts. Raw
  manifests must identify whether they are live, bootstrap-only, test, generated, vendor,
  or archived.
- **Persistence/recovery:** preserve user data independently from Omarchy root snapshots;
  Omarchy rollback restores the root filesystem but deliberately does not roll back `/home`.

## Documentation routing

| Need | Read first | Authority boundary |
|---|---|---|
| Safety rules and agent behavior | [`AGENTS.md`](../AGENTS.md) | Canonical policy |
| Contribution/worktree/PR workflow | [`CONTRIBUTING.md`](../CONTRIBUTING.md) | Canonical workflow |
| Repository navigation | [`../DOCUMENTATION_INDEX.md`](../DOCUMENTATION_INDEX.md) | Canonical catalog |
| Current checked-in architecture and migration boundary | This document | Current reference |
| Unified Reverb-OS Home Manager target architecture | [`docs/plans/2026-08-20-omarchy-hm-cluster-vision.md`](plans/2026-08-20-omarchy-hm-cluster-vision.md) | Active design target |
| Omarchy design evidence | [`../.research/omarchy-design-philosophy-2026-08-20.md`](../.research/omarchy-design-philosophy-2026-08-20.md) | Cited research |
| Live host/Kubernetes health | `just health`, `just status`, `just provenance` | Runtime state, not prose |
| Deployment procedure | `justfile`, `docs/ci-cd/README.md`, verified rescue/deploy runbooks | Commands must match source |
| Secrets architecture | [`../SOPS-NIX.md`](../SOPS-NIX.md), `secretspec.toml`, and host SecretSpec wiring | Verify before rotation |
| Open remediation backlog | [`../ACTION-ITEMS.md`](../ACTION-ITEMS.md), GitHub issues/PRs | Reconcile dates/status |
| Historical audit or incident | Dated audit/incident document | Historical only unless re-verified |
| Archived material | `docs/archive/` | Historical material is preserved under `docs/archive/legacy/`; do not follow blindly |

## Verification commands

Run these before claiming that the cluster is healthy or that a deployment is complete:

```bash
just status
just health
just provenance
kubectl get nodes -o wide
kubectl get pods -A
```

For a configuration-only claim:

```bash
nix flake check
nix-instantiate --parse hosts/<host>/configuration.nix
```

For a Niri configuration claim, validate with the compositor package selected for the
host rather than an unrelated system binary. For a deployment claim, record the commit,
flake lock state, active generation, and health-probe result.

## Freshness and history

- Active/reference documents require `Status`, `Last Verified`, and an owner or source.
- Generated documents must name their generator and source-of-truth file; their timestamp
  is not proof that the underlying cluster was reachable.
- Historical documents retain their original dates and must be marked historical or
  archived. Do not silently rewrite incident timelines.
- `STATUS.md` is a generated snapshot and may be stale; do not use it as a substitute for
  live commands until its snapshot timestamp and generator result are checked.
- `ROADMAP.md` is migration/roadmap history plus remaining hardening context, not a live
  health dashboard.
- The 2026-07-27 multi-area audit is the latest broad audit currently indexed, but its
  findings still require live verification before operator action.

## 2026-08-13 cluster state changes

Session-verified changes (commits on `origin/main`):

- **nix-csi removed entirely** (`ad405b34`) — driver never registered (csinode lacked
  `nix.csi.store`), build inputs GC'd from all stores, no production consumers. 6 manifests
  moved to `kubernetes-manifests/archive/nix-csi/`; live DS/STS/jobs/SC/CSIDriver deleted.
  Closes #213. #191/#205 superseded.
- **nvidia-device-plugin fixed** (`7119ff89`, `88606d98`) — nodeSelector aligned to real
  k3s label (`accelerator=nvidia-gpu`), driver lib path refreshed (had GC'd 595.45.04),
  NVML lib dir corrected (610.43.03 main lib, not lib32). `nvidia.com/gpu: 1` advertised
  on nexus. GPU workloads schedulable again.
- **k8s-secret-sync namespace-ensure** (`cac6b4e4`) — unit now creates target namespaces
  (`automation`, `orchestration`) before syncing; unblocked nexus deploys (was exit 4).
- **nixos-sync openssh in PATH** (`5dbd999f`) — git fetch over SSH needed `pkgs.openssh`;
  also `HOME=/root` env + FLAKE ordering (documented in `modules/services/nixos-sync.nix`).
- **dcgm RuntimeDirectory** (`9d53c2ce`) — podman cidfile dir exists at start.
- **bonsai sentry DSpark removal** (`e91d8133`) — mainline Vulkan cannot load `dspark` arch.

Open follow-ups filed 2026-08-13: #463 qdrant admission-policy block, #464 gateway
placeholder keys, #465 orphaned HPAs, #466 maplespike secrets re-wiring (cross-linked
with quill PR #826).

## 2026-08-13 PR merge session

Merged to `origin/main` (all sibling PRs reviewed, eval-verified):

- **#457** nixos-sync non-destructive (`merge --ff-only`, skip dirty/non-main trees,
  per-command safe.directory) — supersedes the earlier hard-reset approach.
- **#459** zephyr cgroups (issue #453) — `use-cgroups`, idle daemon CPU/IO scheduling.
- **#460** CI Layer-2 lock guard — deploy aborts if home-manager-config flake.lock is
  behind master.
- **#461** ai-inference parse coverage — restored `}` in kubernetes/modules/ai-inference.nix.
- **#462** nim-proxy concurrency — ThreadingHTTPServer + BoundedSemaphore (issue #313).
- **#467** portable pure-eval (#309) — cherry-picked from auto-closed #458 (GitHub closed
  it during the #457 merge race; content identical, 4 files: cache.yml timeout guard,
  portable-usb modelAvailable gate, flake.nix check, new test).
- **flake.lock** bumped to home-manager-config `af29c5037` (Alt+Tab + KDE/MIME fix) —
  keeps the #460 guard green.

Not merged (coordination): **quill PR reverb256/maplespike#826** — sibling agent has
in-flight dev-mode work on the same files (nix/saas-manifests.nix, AGENTS.md). Merging
now would force their rebase; land it after their dev-mode namespace work commits.

See [`../DOCS-MAINTENANCE.md`](../DOCS-MAINTENANCE.md) for the classification and
freshness policy. The documentation cleanup manifest records completed and planned
migration batches without rewriting historical evidence.
