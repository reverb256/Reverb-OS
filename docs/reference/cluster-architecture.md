# Cluster architecture reference

> **Target base:** upstream Omarchy/Arch with standalone Home Manager from Reverb-OS.

**Last Verified:** 2026-08-20
**Status:** Reference / migration transition
**Owner:** j_kro

Reference for the current NixOS host wiring, target Omarchy ownership,
repository layout, build architecture, and the self-hosted CI runner. The live
fleet remains NixOS until the target profiles pass isolated tests. Task
procedures live in `agents/skills/`.

## Target authority model

```text
Omarchy/Arch  → base OS, packages, updates, migrations, snapshots, hardware, Quickshell
Home Manager  → additive user config and supported Omarchy extensions
Nix/Lix       → packages, cache, checks, flakes, manifests, test artifacts
Kubernetes    → portable cluster services by default
NixOS         → transitional evaluator and rollback path
```

Omarchy remains the coherent product authority. Preserve its shell, update
transaction, and ownership boundaries. Do not make a root reconciler overwrite
`/usr/share/omarchy` or other Omarchy-owned state. See [`../plans/2026-08-20-omarchy-hm-cluster-vision.md`](../plans/2026-08-20-omarchy-hm-cluster-vision.md).

## Hosts

| Host | IP | Role | RAM | GPUs |
|------|-----|------|-----|------|
| Zephyr | 10.1.1.110 | Workstation, development source, control plane, gaming | 31GB | 2x NVIDIA |
| Nexus | 10.1.1.120 | Primary server, AI gateway, storage | 46GB | 1x NVIDIA |
| Forge | 10.1.1.130 | GPU computing, mining | 15GB | 2x NVIDIA + 2x AMD |
| Sentry | 10.1.1.140 | Monitoring, Vulkan AI inference | 31GB | 1x AMD RX 5600 XT (6GB) |

Resources: 78 cores, 123GB RAM, 7 GPUs, ~8.4TB. K3s roles run on Nexus, Forge,
and Sentry; Zephyr is not a K3s node.

## Repository layout

The current tree is still shaped as a NixOS evaluator. During migration,
`packages/`, `pkgs/`, `overlays/`, `kubernetes/`, `contracts/`, `tests/`, and
CI remain valuable. `hosts/` and most NixOS modules are transitional until
replaced by explicit Omarchy host profiles.

```
/etc/nixos/
├── flake.nix                  # inputs/outputs/checks; hosts come from modules/hosts/
├── colmena.nix                # multi-host deployment; shares the dendritic evaluator
├── common-modules-list.nix    # shared module list (inputs + modules/default.nix + overlays)
├── lib/dendritic-host.nix     # shared mkHost/mkSpecialArgs evaluator
├── justfile                   # deploy, check, rollback, and maintenance tasks
├── hosts/<host>/              # per-host NixOS bodies (never edit hardware-configuration.nix)
├── modules/                   # reusable modules
│   ├── hosts/                 # dendritic host registry (two-layer wiring per host)
│   ├── system/  services/  desktop/  home-manager/  profiles/
│   ├── hardware/  development/  gaming/  network/  security/
├── kubernetes/                # K8s Nix modules via easykubenix
├── kubernetes-manifests/      # raw K8s YAML (legacy + security + GPU examples)
├── scripts/  packages/  tests/  secrets/
└── .github/workflows/         # CI/CD (SHA-pinned actions)
```

## Host wiring (dendritic)

Each host is wired through two layers:

- **Content** — `modules/hosts/<host>/default.nix` imports the host body from
  `hosts/<host>/configuration.nix`.
- **Evaluator** — the same file builds `nixosConfigurations.<host>` via
  `lib/dendritic-host.nix` `mkHost`, composing `commonModules ++ [hostConfig] ++ extraModules`.

Colmena uses the same evaluator and `contracts/host-inventory.nix` — no duplicate
host declarations. Adding a host = one entry in `contracts/host-inventory.nix` +
`hosts/<host>/configuration.nix` + `modules/hosts/<host>/default.nix` (and `./machines`).

## Build architecture

Nix remains the package/build/cache/test toolchain for the target platform; it
is not the target Omarchy host activation authority. The current NixOS system
build remains available as the migration rollback path.

- System target is generic `x86_64-linux`; not a global `-march=x86-64-v3` userspace.
- CachyOS kernel packages are x86-64-v3; only selected llama.cpp packages add it.
- `big-parallel` is a builder capability label, not an arch target or thread count.
- Nexus is the sole build executor (`max-jobs=6`). Zephyr/Forge/Sentry run
  `max-jobs=0` and dispatch to Nexus. Sentry publishes cachix only.
- `modules/system/distributed-builds.nix` generates `/etc/nix/machines` and
  excludes the current host.

## Service placement policy

Kubernetes is the default home for portable long-running services. Keep a
service on the host only when it is required for boot/recovery, storage,
network identity, SSH, k3s, physical GPU/VFIO access, or operation during a
Kubernetes outage. Home Manager is not a root service manager.

## Self-hosted GitHub Actions runner

- Host: nexus, user `runner`, workdir `/var/lib/runner/_work/`.
- Service: `github-actions-runner-nixos-config.service` (per-repo; sibling units
  exist for other repos). `github-actions-runner-setup-nixos-config.service`
  refreshes registration from `/run/secrets/github-runner-pat`.
- The runner needs a NixOS-safe PATH and these env vars for dotnet/HTTPS:
  `LD_LIBRARY_PATH`, `NIX_ICU_DATA`, `SSL_CERT_FILE`, `REQUESTS_CA_BUNDLE`,
  `NODE_EXTRA_CA_CERTS`.

## Extracted projects

Standalone flakes under `/data/projects/own/`, consumed as flake inputs:

| Project | Flake input |
|---------|-------------|
| ai-inference-gateway | `ai-gateway` |
| compute-market | `compute-market` |
| gpu-proxy | `gpu-proxy` |
| knowledge-fabric | `knowledge-fabric` |
| llama-cpp-turboquant | `llama-turboquant` |
| mcp-registry | `mcp-registry` |
| vllm-turboquant | `vllm-turboquant` |

Check `/data/projects/own/` first for AI/ML service implementations — many
cluster services live there, not in `/etc/nixos/modules`.
