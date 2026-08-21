# Reverb-OS Omarchy + Home Manager vision

> **Target:** upstream Omarchy/Arch plus the standalone Reverb-OS Home Manager flake.

> **Status:** Active design / migration target
> **Last Verified:** 2026-08-20
> **Owner:** j_kro
> **Runtime status:** The live cluster remains NixOS during the migration. This document defines the target architecture and must not be used as a deployment procedure.

## Decision

The cluster is being reshaped around **upstream Omarchy/Arch as the workstation and host substrate**, with **standalone Home Manager from Reverb-OS as the additive user layer**. Reverb-OS does not fork Omarchy; it defers to Omarchy wherever Omarchy already provides a capability or supported configuration mechanism.

The migration must preserve the valuable Nix work, but it must stop treating NixOS modules as the permanent authority over the Omarchy desktop. Nix remains a build, package, cache, test, and declaration tool. Kubernetes remains the default home for portable cluster services.

```text
Target authority model

Omarchy / Arch
  owns the base OS, package/update lifecycle, boot, hardware, Hyprland,
  Quickshell, migrations, snapshots, and supported workstation contracts

Home Manager
  owns the user's additive layer: packages, shells, editors, dotfiles,
  user services, themes, hooks, menu extensions, and selected plugins

Nix
  owns reproducible package builds, flakes, dev shells, HM evaluation,
  cache policy, tests, manifests, and non-conflicting generated artifacts

Kubernetes
  owns portable long-running cluster services by default

NixOS
  remains the checked-in legacy runtime and rollback path until each host
  has a tested replacement; it is not the target desktop authority
```

## Omarchy principles we must preserve

1. **Opinionated product, not generic Arch.** Upstream Omarchy is a coherent developer workstation, and Reverb-OS must preserve that product model rather than becoming a competing package/bootstrap layer.
2. **One integrated shell.** Quickshell, the menu, IPC, notifications, panels, and services are one extension surface.
3. **One blessed update transaction.** Use `omarchy update` for Omarchy/system updates, migrations, snapshots, hooks, and restart handling.
4. **Mutable but recoverable.** Preserve Omarchy's mutable model and Btrfs/Limine snapshot rollback instead of replacing it with a competing immutable reconciler.
5. **Package-owned versus user-owned paths.** Do not edit or declaratively overwrite `/usr/share/omarchy`; use supported user paths and extension mechanisms.
6. **Narrow hardware fixes.** Gate hardware behavior on observed hardware and keep fixes idempotent.
7. **Small supported matrix.** Do not preserve every historical desktop permutation without an explicit profile and test.
8. **Real test boundaries.** Keep fast shell/CLI tests separate from headless guest tests and graphical acceptance tests.

Primary evidence is captured in [`../../.research/omarchy-design-philosophy-2026-08-20.md`](../../.research/omarchy-design-philosophy-2026-08-20.md) and [`../../.research/omarchy-home-manager-microvm-patterns-2026-08-20.md`](../../.research/omarchy-home-manager-microvm-patterns-2026-08-20.md).

## Ownership matrix

| Area | Target authority | Boundary |
|---|---|---|
| Arch kernel, boot, drivers, firmware | Omarchy/Arch + host profile | Follow upstream Omarchy's ISO/package/update model. |
| Omarchy packages and migrations | Upstream Omarchy | Do not replace with Nix or a generic reconciler. |
| Hyprland and Quickshell | Upstream Omarchy | Extend only through supported user files, IPC, JSON/TOML, hooks, themes, and plugins. |
| User shell, editor, terminal | Home Manager | One owner per path; start with additive, non-conflicting files. |
| User packages | Home Manager or Omarchy, per package | Do not install duplicate competing copies without an explicit policy. |
| Omarchy themes and generated state | Upstream Omarchy extension model | HM may own custom themes/templates only after path ownership is proven. |
| User services | Home Manager | Only when root, early boot, and physical-device access are unnecessary. |
| k3s, storage, networking, GPU/VFIO, SSH recovery | Host platform layer | Not Home Manager; keep recoverable during Kubernetes outages. |
| Quill, AI, MCP, auth, monitoring, dashboards | Kubernetes | Kubernetes by default, with explicit privileged/persistent exceptions. |
| Secrets and trust bootstrap | Host/bootstrap + SecretSpec/SOPS policy | Never bake reusable credentials into images or Nix store paths. |
| Packages, cache, checks, manifests | Nix | Build and validate artifacts; do not silently activate Omarchy-owned state. |
| Current NixOS system | NixOS | Transitional rollback path only until a host replacement is tested. |

## Host profiles

The migration must not claim that every machine is the same workstation. Each profile needs an explicit contract, test, and recovery path.

- **Omarchy workstation:** complete upstream Omarchy desktop with additive HM layer. Zephyr is the first candidate.
- **Omarchy compute:** upstream Omarchy/Arch-compatible base with GPU, k3s, and compute prerequisites. Desktop/session behavior must be explicitly defined rather than assumed.
- **Omarchy control/storage:** only use the full workstation base if its operational cost is acceptable. Otherwise document this as a downstream Arch-derived profile.
- **Omarchy test guest:** disposable upstream ISO installation, test-only credentials, standalone HM activation, and automatic cleanup.

A profile must not be called “standard Omarchy” if it removes or replaces core upstream behavior. Reverb-OS changes must remain additive, clearly separated from upstream-owned behavior, and upstreamable where practical.

## Home Manager contract

Phase 1 is additive. Home Manager may own:

- shell and prompt configuration;
- user packages that do not duplicate Omarchy-owned system packages;
- editor and terminal configuration after path ownership is checked;
- user services;
- MIME and desktop-entry additions;
- user themes, templates, hooks, menu extensions, and reviewed plugins;
- user-owned environment files.

Phase 1 must not own:

- `/usr/share/omarchy`;
- Omarchy package files or update hooks;
- generated theme state under `~/.local/state/omarchy/current/`;
- the complete `~/.config/hypr/` tree;
- the complete `~/.config/quickshell/` tree;
- Omarchy's migrations, snapshots, or package database.

Every transferred path requires one declared owner, an upgrade test, an activation test, and a rollback decision.

## Nix contract

Preserve and continue using:

- package derivations and overlays;
- Lix/Nix development shells and cache policy;
- standalone Home Manager evaluation;
- Kubernetes/Easykubenix declarations;
- service contracts and host inventory;
- SecretSpec/SOPS declarations;
- CI checks and provenance reports;
- VM/microVM test artifacts;
- generated manifests that do not compete with Omarchy's system authority.

Do not use Nix to regenerate Omarchy's package-owned desktop as a first step. A NixOS port may remain available for rollback and comparison, but it is not the target implementation.

## Kubernetes policy

Kubernetes is the default destination for portable long-running services. Keep a service on the host only when it is required for:

- boot or recovery;
- storage or filesystem operation;
- networking or firewall identity;
- k3s itself;
- physical GPU/VFIO/libvirt access;
- SSH or emergency access;
- operation during a Kubernetes control-plane outage.

This policy applies to the target platform, not to an unreviewed live migration. Existing NixOS services remain until their Kubernetes or host-profile replacement is tested.

## Migration sequence

1. Keep the current NixOS evaluator and deployment path intact as rollback.
2. Consolidate `home-manager-config` into a portable `omarchy` profile in Reverb-OS without NixOS-only assumptions.
3. Build a disposable upstream Omarchy ISO guest using the unattended `cidata` provisioning contract.
4. Install Nix and standalone Home Manager inside the guest.
5. Activate only the additive HM layer and generate a file-ownership report.
6. Validate the Omarchy CLI/shell contract, HM idempotence, user services, and Omarchy update compatibility.
7. Define workstation, compute, control/storage, and test-guest host contracts.
8. Reproduce host-level prerequisites one category at a time.
9. Migrate one non-production host at a time with an explicit rollback path.
10. Retire the corresponding NixOS host authority only after the replacement is tested and accepted.

## Test boundary

The first isolated test must prove:

- real Omarchy ISO installation;
- unattended provisioning and disposable SSH access;
- standalone HM evaluation and activation;
- no takeover of Omarchy-owned paths;
- user package/service behavior;
- idempotent repeated activation;
- non-graphical Omarchy test compatibility;
- complete logs, ownership manifests, and cleanup.

A headless guest must not claim to prove Quickshell rendering, Hyprland visual parity, GPU behavior, audio, input, or hardware-specific recovery. Those require a later graphical or passthrough acceptance class.

## Non-goals

- Reimplementing Omarchy in Nix.
- Making Home Manager a root/system configuration manager.
- Creating a second update or snapshot system.
- Converting every current NixOS module mechanically.
- Migrating live hosts as part of this documentation change.
