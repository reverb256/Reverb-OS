# Home Harmonization Plan

> **Target base:** upstream Omarchy/Arch with standalone Home Manager from Reverb-OS.

> **Status:** Active migration plan
> **Last Verified:** 2026-08-20
> **Owner:** j_kro
> **Runtime status:** The live hosts remain NixOS until the standalone Omarchy profiles pass isolated tests.

## Goal

Provide a consistent user environment across the cluster while preserving
Omarchy's ownership model:

```text
Omarchy/Arch
  owns the base OS, package/update lifecycle, Hyprland, Quickshell, migrations,
  snapshots, and hardware integration

Standalone Home Manager
  owns the additive user layer and supported Omarchy extensions

Preserved data
  remains outside declarative replacement and is backed up independently
```

This plan does not make Home Manager a NixOS replacement or a root/system
configuration manager.

## Ownership rules

### Omarchy owns

- `/usr/share/omarchy`;
- Omarchy package files and update hooks;
- `omarchy update`, migrations, snapshots, and package lifecycle;
- generated theme state under `~/.local/state/omarchy/current/`;
- the base Hyprland and Quickshell runtime;
- boot, drivers, system services, hardware, and networking.

### Home Manager may own

- `~/.bashrc` and prompt configuration;
- editor and terminal configuration after path ownership is verified;
- user-only packages;
- user services that do not need root, early boot, or physical devices;
- application configuration outside Omarchy-owned paths;
- user themes, templates, hooks, menu extensions, and reviewed plugins;
- explicit user-owned Omarchy files after an ownership-transfer decision.

### Home Manager must not initially own

- `/usr/share/omarchy`;
- the complete `~/.config/hypr/` tree;
- the complete `~/.config/quickshell/` tree;
- Omarchy migrations or update configuration;
- generated theme state;
- system-wide secrets, mounts, firewalls, k3s, GPUs, or storage.

## Data preservation

The following remain data, not Home Manager-generated replacement targets:

- `~/models`;
- project checkouts and working trees;
- caches;
- browser profiles and user application state;
- SSH keys;
- GPG keys;
- agent state;
- wallet and credential material;
- cluster backups and operational artifacts.

Backups and restoration procedures must remain separate from HM activation and
must be tested against the current storage layout. Never put private keys or
plaintext credentials in a profile, image, Nix store output, or documentation.

## Profile shape

The Reverb-OS flake should expose explicit Omarchy target profiles rather than
assuming that every host has the same desktop:

```text
omarchy                    generic Omarchy additive layer with Niri
omarchy-zephyr              Zephyr-specific additive layer after generic acceptance
omarchy-nexus               server/compute compatibility layer
omarchy-forge               GPU/compute compatibility layer
omarchy-sentry              monitoring/recovery compatibility layer
```

The names describe intended target profiles. They do not mean that the live
hosts have migrated or that a non-workstation profile is official upstream
Omarchy. Each profile needs an explicit package, service, data, and recovery
contract.

## Migration sequence

1. Keep the NixOS Home Manager bridge as rollback-only compatibility.
2. Create a standalone `omarchy` HM composition in the Reverb-OS flake with no NixOS-only options.
3. Test it in the disposable upstream Omarchy guest.
4. Record the writer set for every proposed managed path.
5. Activate shell, editor, terminal, user packages, and non-conflicting services.
6. Add supported Omarchy extensions one at a time: themes, templates, hooks,
   menu extensions, and reviewed plugins.
7. Transfer ownership of an Omarchy user file only when its update and rollback
   behavior is tested.
8. Build host-specific profiles for Zephyr, Nexus, Forge, Sentry, and the test
   guest.
9. Migrate one host at a time only after host prerequisites and Kubernetes
   dependencies have independent rollback paths.

## Acceptance criteria

A profile is ready for wider use only when it proves:

- standalone HM evaluation on upstream Omarchy;
- first activation with an explicit backup policy;
- no replacement of Omarchy-owned paths;
- idempotent repeated activation;
- user services start and stop cleanly;
- Omarchy's CLI and update behavior remain intact;
- file ownership is documented;
- preserved data is not treated as disposable configuration;
- rollback behavior is understood;
- the test guest is destroyed after validation.

A headless guest does not prove Quickshell rendering, Hyprland visual parity,
GPU behavior, audio, or hardware recovery. Those require a later graphical or
passthrough test class.

## Related documents

- [`docs/plans/2026-08-20-omarchy-hm-cluster-vision.md`](docs/plans/2026-08-20-omarchy-hm-cluster-vision.md)
- [`docs/current-state.md`](docs/current-state.md)
- [`../home-manager-config/README.md`](../home-manager-config/README.md)
- [`./.research/omarchy-design-philosophy-2026-08-20.md`](./.research/omarchy-design-philosophy-2026-08-20.md)
- [`./.research/omarchy-home-manager-microvm-patterns-2026-08-20.md`](./.research/omarchy-home-manager-microvm-patterns-2026-08-20.md)
