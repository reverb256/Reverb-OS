# Reverb-OS — Cluster Platform

> **Target desktop:** upstream Omarchy/Arch with the standalone Reverb-OS Home Manager profile.

> **Status:** Canonical project entry point / migration in progress
> **Last Verified:** 2026-08-20
> **Owner:** j_kro

Reverb-OS is a 4-host cluster platform being reshaped around the
upstream Omarchy/Arch with standalone Home Manager layered above it. Reverb-OS
adds only capabilities that Omarchy does not already provide and does not fork
or replace Omarchy's runtime. The live fleet remains
NixOS during the migration; this repository preserves the current evaluator as
a rollback path while the target profiles are built and tested.

Read the target architecture first:

- [`docs/plans/2026-08-20-omarchy-hm-cluster-vision.md`](docs/plans/2026-08-20-omarchy-hm-cluster-vision.md)
- [`docs/current-state.md`](docs/current-state.md)
- [`.research/omarchy-design-philosophy-2026-08-20.md`](.research/omarchy-design-philosophy-2026-08-20.md)

## Quick Start

```bash
# Rebuild local host
just switch

# Deploy to all nodes
just deploy

# Deploy to specific node
just deploy <hostname>

# Build and test activation without switching permanently
just test-apply

# Fast flake validation without a build
just check
```

## Cluster Architecture

### Target authority model

```text
Omarchy/Arch  →  base OS, updates, migrations, snapshots, hardware, Quickshell
Home Manager  →  additive user layer and supported Omarchy extensions
Nix/Lix       →  packages, cache, checks, flakes, manifests, test artifacts
Kubernetes    →  portable cluster services by default
NixOS         →  transitional live evaluator and rollback path
```

Omarchy remains the coherent product authority, not a collection of files to
reimplement in Nix. Reverb-OS defers to Omarchy wherever Omarchy already
provides a capability or supported configuration mechanism. Do not edit `/usr/share/omarchy`, replace `omarchy update`,
or let Home Manager overwrite Omarchy-owned desktop state.

**Nodes:**
- **Zephyr** (10.1.1.110) - Control plane, gaming, AI inference
- **Nexus** (10.1.1.120) - Storage, GPU computing, Hermes Agent gateway
- **Forge** (10.1.1.130) - GPU computing, mining
- **Sentry** (10.1.1.140) - Monitoring, logging

**Checked-in inventory totals:** 78 cores, 123GB RAM, 7 GPUs, 8.4TB storage.
These are planning/inventory values; verify live hardware before operational decisions.

## Build Architecture

The current NixOS evaluator remains available during migration. The target
Omarchy platform is an Arch/Omarchy runtime; Nix is retained as the reproducible
package, cache, test, and artifact toolchain rather than the target desktop
activation authority.

For the current NixOS path, the target is generic `x86_64-linux`. This repository
does **not** apply `-march=x86-64-v3` globally to the complete userspace.

- All hosts use the CachyOS `linuxPackages-...-x86_64-v3` kernel package.
- Selected llama.cpp packages are explicitly compiled with
  `-march=x86-64-v3` (see `modules/development/llama-cpp-optimization.nix` and
  `packages/llama-cpp-ik.nix`).
- The rest of the system uses each package's normal nixpkgs compiler settings.
- `big-parallel` is a Nix builder capability label, not an architecture target
  or a thread count.

Distributed-build policy is declared in
`modules/system/distributed-builds.nix`. Deployment dispatch is separate from
Nix's builder capability list: `just deploy` and `just deploy-async` invoke
`/etc/nixos/scripts/deploy/nexus-dispatch.sh`, which runs the canonical
Colmena apply on Nexus. Zephyr remains the authoring/source-of-truth host.


| Host | Local max jobs | Role |
|------|----------------|------|
| Zephyr | 0 | Authoring/source-of-truth host; no local build jobs |
| Nexus | 6 | Deployment dispatcher and exclusive primary builder |
| Sentry | 0 | Monitoring/inference host; not a build target |
| Forge | 0 in the distributed-build module | GPU/mining host; deployment builds on the target when required |

The module generates `/etc/nix/machines` from its own host list and excludes
the current host. The root `machines` file is the Nix machines file supplied to Colmena via
`colmena.nix`; it is not a global `-march` policy. Verify deployed runtime
settings with `nix show-config` and `/etc/nix/machines` before treating live
state as current.

## Project Architecture

### Ownership rules

- Omarchy owns its package/update/migration/snapshot lifecycle and Quickshell runtime.
- Home Manager owns only explicitly declared user-owned paths.
- Kubernetes owns portable long-running services by default.
- Host-level configuration is reserved for boot, hardware, storage, networking,
  SSH, k3s, GPUs/VFIO, and emergency recovery.
- Nix packages and generated artifacts must not compete with Omarchy's system authority.


**⚠️ IMPORTANT:** Reverb-OS is becoming the canonical combined flake. Its
`homeConfigurations.omarchy` output is the standalone Home Manager profile for
Omarchy. The separate `home-manager-config` repository remains a transitional
source for existing NixOS host outputs until its portable modules are migrated
and classified.

| Project | Location | Purpose |
|---------|----------|---------|
| ai-inference-gateway | `/data/projects/own/ai-inference-gateway` | AI gateway service |
| compute-market | `/data/projects/own/compute-market` | GPU time-slicing |
| caddy-ingress | `/data/projects/own/caddy-ingress` | Custom Caddy build |
| gpu-proxy | `/data/projects/own/gpu-proxy` | Stratum mining proxy |
| knowledge-fabric | `/data/projects/own/knowledge-fabric` | Knowledge base system |
| llama-cpp-turboquant | `/data/projects/own/llama-cpp-turboquant` | TurboQuant llama.cpp |
| mcp-registry | `/data/projects/own/mcp-registry` | MCP server management |

These are referenced as **flake inputs** in `flake.nix` - each project maintains its own versioning and build process.

See [`docs/current-state.md`](docs/current-state.md) for the repository's current configuration boundaries and verification workflow.

## Configuration Structure

```text
Reverb-OS/
├── flake.nix                  # Nix packages, checks, current NixOS outputs, inputs
├── hosts/                     # transitional NixOS host configurations
├── modules/                   # legacy NixOS modules and retained reusable logic
├── packages/ pkgs/ overlays/  # reusable Nix packages and build inputs
├── kubernetes/                # Kubernetes/Easykubenix declarations
├── contracts/                 # host and service contracts
├── tests/                     # checks and migration validation
├── docs/plans/                # active architecture and migration plans
└── .research/                 # cited design research

Target runtime ownership is split across this repo, the upstream Omarchy
installation, and the standalone `homeConfigurations.omarchy` output. This tree
now contains the installable user-profile entry point while NixOS outputs remain
transitional.
```

> Portable Home Manager modules, including the Omarchy Niri composition, live
> under `modules/home-manager/` and are exposed through
> `homeConfigurations.omarchy`. Existing host-specific leaf modules remain in
> `home-manager-config` during the migration.

## Key Documentation

- **[`docs/current-state.md`](docs/current-state.md)** - Current checked-in architecture and documentation routing
- **[`DOCUMENTATION_INDEX.md`](DOCUMENTATION_INDEX.md)** - Full documentation catalog
- **AGENTS.md** - Universal cluster patterns and workflows
- **CONTRIBUTING.md** - Worktree, PR, and contribution workflow
- **DOCS-MAINTENANCE.md** - Documentation freshness and classification policy
- **ROADMAP.md** - Historical Kubernetes migration roadmap and hardening context
- **[`docs/audit-2026-07-27.md`](docs/audit-2026-07-27.md)** - Dated multi-area audit; verify findings against live state before acting

## Safety First

⚠️ **Before making changes to shared modules:**
1. Read CLAUDE.md "Critical Agent Safety Constraints"
2. Use `lib.mkOptionDefault` for extensible options
3. Test on nodes with custom configs (nexus, forge) before deploying
4. Verify SSH port 22 is never blocked

## Home Manager

User configuration for Omarchy is managed by the standalone
`homeConfigurations.omarchy` output from this flake. The target is standalone
Home Manager on upstream Omarchy, not the current NixOS module bridge.

Home Manager may own:

- shell, prompt, editor, and terminal configuration;
- additive user packages;
- user services;
- application configuration outside Omarchy-owned paths;
- user themes, templates, hooks, menu extensions, and reviewed plugins.

Home Manager must not initially own `/usr/share/omarchy`, Omarchy migrations,
package updates, generated theme state, or the complete Hyprland/Quickshell
configuration trees.

The standalone profile is now available for isolated testing:

```bash
# Build without activating
nix build .#homeConfigurations.omarchy.activationPackage

# Bootstrap or activate on an Omarchy host
home-manager switch --flake /home/j_kro/Projects/Reverb-OS#omarchy
```

The legacy `home-manager-config` repository remains available for existing
NixOS host profiles while its unique modules are migrated and classified.

## See Also

- [Upstream Omarchy Quattro repository](https://github.com/basecamp/omarchy/tree/quattro)
- [Omarchy manual](https://github.com/basecamp/omarchy/tree/quattro/manual)
- [Omarchy ISO project](https://github.com/omacom-io/omarchy-iso/tree/quattro)
- [Home Manager Manual](https://nix-community.github.io/home-manager/)
- [Nix Flakes Guide](https://nixos.wiki/wiki/Flakes)
- [Unified Reverb-OS Home Manager design](docs/superpowers/specs/2026-08-21-unified-omarchy-home-manager-flake-design.md)
