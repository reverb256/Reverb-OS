# Reverb-OS — Agent Guidelines

> **Target base:** upstream Omarchy/Arch with standalone Home Manager from Reverb-OS.

> **Last reviewed:** 2026-08-20 · Source branch: `main` · Verify live state with `just health`.

This repository is migrating a 4-host cluster (Zephyr, Nexus, Forge, Sentry)
from NixOS-first operation to upstream Omarchy/Arch with standalone Home Manager.
The live fleet remains NixOS until each host has a tested replacement. This file
holds universal rules, style, and authority boundaries. Task procedures live in
`agents/skills/`; deep reference lives in `docs/reference/` and
`docs/current-state.md`.

Read the target architecture in
[`docs/plans/2026-08-20-omarchy-hm-cluster-vision.md`](docs/plans/2026-08-20-omarchy-hm-cluster-vision.md)
before changing desktop, host, or Home Manager ownership.

The design principles are non-negotiable: preserve Omarchy's opinionated
workstation model, Quickshell integration, supported update transaction,
mutable-but-recoverable system, and package-owned/user-owned path split.
Do not turn Omarchy into a generic NixOS-style artifact reconciler.
Read the matching guide before starting work.

## 🔴 HARD RULE: preserve the active authority boundary

**During the migration, all persistent NixOS state remains in `.nix` files under
git.** Shell commands on a running NixOS host are acceptable only for reading
state. They are never acceptable for configuring services, fixing bugs, attaching
devices, changing networking, editing secrets, or patching running daemons.

For target Omarchy hosts, use the authority appropriate to the layer:

- Omarchy owns its package/update/migration/snapshot lifecycle; Reverb-OS defers to it.
- Home Manager owns only declared user-owned paths.
- Nix builds and validates artifacts; it does not silently replace Omarchy-owned state.
- Kubernetes owns portable cluster services by default.
- Root host configuration is limited to boot, hardware, storage, networking, SSH,
  k3s, privileged devices, and emergency recovery.

The live host is never the source of truth. If the first instinct is to SSH in and
patch a service, stop and find the declarative source or supported upstream Omarchy command.

## Quick start

```bash
just check              # quick flake validation (no build)
just build              # build the current host toplevel
just switch             # apply to the local host
just test-apply         # build + test activation without a permanent switch
just deploy [<host>]    # build + deploy to all or one host
just rollback           # roll back the current host
just status             # git branch/commit/worktree state
just health             # SSH reachability + kubectl get nodes
just new-worktree <NNN> # create a worktree for issue NNN
```

> `just test` does not exist. Use `just test-apply`, `just check`, or `just full-check`.

## Configuration layers

| Layer | Target authority | Owns |
|-------|------------------|------|
| 1 — Omarchy/Arch | upstream Omarchy + explicit host profile | OS substrate, packages, updates, migrations, snapshots, hardware, Hyprland, Quickshell |
| 2 — Home Manager | this flake's `homeConfigurations.omarchy` | additive user packages, portable dotfiles, user services, and Niri; defer to Omarchy for built-ins |
| 3 — Nix/Lix | this repo and reusable package flakes | package builds, cache policy, HM evaluation, checks, manifests, development shells |
| 4 — Kubernetes | `kubernetes/` and manifests | portable cluster services by default |
| Legacy — NixOS | this repo during migration | current live host evaluator and rollback path; not the target desktop authority |

`just hm-switch` and `just hm-build <host>` remain legacy NixOS-host helpers.
Use `home-manager switch --flake .#omarchy` for the standalone Omarchy profile.
Do not add new NixOS-only desktop ownership while this migration is in progress.

## Safety rules

### `mkOptionDefault` for extensible options (mandatory)

```nix
# ❌ replaces node configs — can break SSH cluster-wide
networking.firewall.allowedTCPPorts = [22 53 6443];

# ✅ merges with node-level overrides
networking.firewall.allowedTCPPorts = lib.mkOptionDefault [22 53 6443];
```

Use `mkOptionDefault` for lists and mergeable attrs. Direct assignment is fine
for booleans and single strings (`hostName`).

### Workload scheduling — Zephyr OOM prevention

Zephyr has 31GB and constant RAM pressure. Default **all** non-infrastructure,
non-mining workloads to Nexus (46GB). Priority: **Nexus > Forge > Sentry > Zephyr**.
See `agents/skills/add-k8s-workload.md`.

### GPU isolation limitation

`nvidia-container-runtime` is broken on NixOS (libnvidia-ml.so.1 dlopen fails).
`CUDA_VISIBLE_DEVICES` is a hint, not isolation. Use
`mining-inference-coordinator` to shift mining while inference runs.

### Stop immediately if

- SSH breaks on any node.
- Multiple nodes are affected.
- `nix flake check` fails.
- `just deploy` preflight fails.

## Code style

- 2-space indent, trailing semicolons, kebab-case filenames.
- Line length 80–100 chars (soft 120).
- `lib.getExe` for `ExecStart`; `pkgs.writeShellScript` for multi-line scripts;
  `lib.makeBinPath` for PATH; `lib.pipe` for transforms; `types.either` for
  flexible options.
- Module template and namespaces: see `agents/skills/add-service.md`.

| Namespace | Usage |
|-----------|-------|
| `services.*` | background daemons |
| `programs.*` | interactive GUI apps |
| `hardware.*` | hardware config |
| `profiles.*` | composable profiles |

## Supply chain

- 7-day package cooldown (npm, bun, uv/pnpm); nixpkgs input age gate.
- No `:latest` container tags (admission policy enforces).
- GitHub Actions pinned to full commit SHAs.

## Task guides (`agents/skills/`)

| Guide | When |
|-------|------|
| `deploy.md` | running `just deploy` / rollback / activation |
| `add-service.md` | adding a NixOS service or `.lan` route |
| `add-k8s-workload.md` | adding or moving a Kubernetes workload |
| `secrets.md` | secretspec / sops-nix secret wiring |
| `worktree-and-pr.md` | issue → worktree → PR → merge → deploy |
| `docs-maintenance.md` | doc freshness (Pocock Rule) |
| `oom-safety.md` | memory limits and OOM defense |

## Reference

| Document | Purpose |
|----------|---------|
| `docs/current-state.md` | checked-in architecture and authority boundaries |
| `docs/reference/cluster-architecture.md` | host wiring, layout, build architecture, CI runner |
| `docs/reference/services-and-auth.md` | SSO/OIDC, service bridge, Caddy/DNS, cluster-mesh, DE VM |
| `docs/reference/mcp-and-agents.md` | MCP servers, model endpoints, agent principles |
| `docs/reference/known-issues.md` | hardening, incidents, deployment lessons |
| `docs/DECISION_LOG.md` | architectural decisions and rationale |
| `DOCUMENTATION_INDEX.md` | full documentation catalog |
| `docs/HARDWARE.md` | checked-in hardware inventory |

## Workflow

`main` is integration **and** production for the current NixOS deployment path.
All work goes through issue → worktree → PR → squash-merge → controlled deployment.
Do not deploy as part of the Omarchy migration design or test work. The target
workflow will use Omarchy's supported update path for the base, standalone HM for
user state, and Kubernetes for portable services. Full current procedure is in
`agents/skills/worktree-and-pr.md`.

## Writing style

User-facing prose follows ASD-STE100 plus Zinsser: imperative mood, one idea per
sentence, plain words, conclusion first. "Use, do, run, make, check, show" — not
"utilize, execute, perform, demonstrate." When unsure, say so; never fabricate.
