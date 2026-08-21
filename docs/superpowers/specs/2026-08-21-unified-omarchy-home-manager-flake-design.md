# Unified Reverb-OS Home Manager flake

> **Status:** Design specification
> **Date:** 2026-08-21
> **Owner:** j_kro
> **Scope:** Reverb-OS and home-manager-config consolidation for standalone Omarchy use
> **Deployment status:** Design only; no live host or deployment changes

## Decision

Reverb-OS will become the canonical combined flake for the cluster's Nix work and
standalone Home Manager user profiles. The flake will be installable on an
Omarchy host without activating NixOS.

The existing `home-manager-config` repository is being migrated into the Reverb-OS
flake as the source of the portable user layer. It remains transitional for
legacy NixOS host outputs but is no longer an independent Omarchy authority.

This is not an Omarchy fork. Upstream Omarchy remains the base runtime and the
authority for every capability it already provides.

## Governing rule

> If Omarchy has a built-in option, package, command, update path, configuration
> surface, or supported mechanism for installing, managing, or configuring a
> capability, the Reverb-OS Home Manager profile must defer to Omarchy and must
> not duplicate or override it.

The flake preserves our work by retaining only additive capabilities that are:

1. not already provided by Omarchy;
2. compatible with Omarchy's ownership model; and
3. useful as user-level configuration on an Omarchy host.

Every migrated module receives an ownership classification before it is included
in the Omarchy profile.

## Authority model

```text
Omarchy
  owns the base Arch system, packages it provides, Hyprland, Quickshell,
  themes, update transaction, migrations, snapshots, hardware, and defaults

Standalone Home Manager from Reverb-OS
  owns only additive user packages, user services, dotfiles, application
  configuration, and Niri configuration that Omarchy does not own

Nix/Lix
  builds and evaluates the flake, packages, checks, and test artifacts

NixOS outputs in Reverb-OS
  remain transitional compatibility and rollback outputs; they are not used
  by standalone Home Manager activation on Omarchy

Kubernetes and host services
  remain separate Reverb-OS infrastructure outputs
```

Home Manager must not own `/usr/share/omarchy`, Omarchy's generated state,
Omarchy's Hyprland or Quickshell trees, Omarchy update hooks, or Omarchy's
package/update/migration/snapshot lifecycle.

## Flake shape

Reverb-OS will expose independent output domains from one flake:

```nix
{
  homeConfigurations.omarchy = ...;
  homeConfigurations.omarchy-zephyr = ...;

  packages = ...;
  checks = ...;

  # Transitional infrastructure outputs remain available.
  nixosConfigurations = ...;
  colmenaHive = ...;
  kubernetes = ...;
}
```

The first standalone installation target is the generic profile:

```bash
nix run github:nix-community/home-manager -- \
  switch --flake github:reverb256/Reverb-OS#omarchy
```

Once Home Manager is bootstrapped, the normal form is:

```bash
home-manager switch --flake github:reverb256/Reverb-OS#omarchy
```

The profile supplies explicit user identity and home-directory values. It does
not depend on NixOS module evaluation, Colmena, `/run/current-system`, or
cluster reachability.

## Profile strategy

### `omarchy`

The generic profile is the first acceptance target. It contains:

- standalone Home Manager activation;
- additive user packages not supplied by Omarchy;
- portable shell, editor, terminal, and application configuration after
  ownership review;
- user services that do not require root, early boot, or physical devices;
- Niri and its user-scoped configuration;
- reviewed Reverb-specific integrations that have no Omarchy equivalent.

It does not contain hardware-specific monitor layouts, gaming output routing,
GPU/VFIO logic, cluster daemons, or host-specific paths.

### `omarchy-zephyr`

This profile is added only after the generic profile passes. It may add Zephyr-
specific user packages, monitor data, gaming helpers, and GPU integrations that
are not already provided by Omarchy. It must not turn those additions into
system ownership.

Existing NixOS host profiles remain separate and continue to use their current
host names until the migration is accepted.

## Module classification

Every module currently in `home-manager-config` is classified into one of four
sets:

### 1. Defer to Omarchy

Drop from the standalone Omarchy profile when Omarchy already provides the
capability or its supported customization surface. Examples include:

- Omarchy package installation and update helpers;
- Omarchy themes and generated theme state;
- Hyprland defaults and the Quickshell desktop shell;
- Omarchy-provided terminal, shell, prompt, launcher, notification, and
  application defaults;
- Omarchy migrations, hooks, snapshots, and system integration.

The upstream Omarchy manual and source docs are the authority for this
classification, not assumptions based on package names.

### 2. Portable additive Home Manager modules

Keep modules that provide independent user capabilities and do not overwrite
Omarchy-owned paths. They must be free of NixOS-only options and use portable
profile paths. Examples may include editors, application preferences, user-only
services, and unique Reverb tooling after audit.

### 3. NixOS-only compatibility modules

Keep in the repository for transitional NixOS outputs, but exclude from the
standalone Omarchy composition. These include root services, `environment.*`,
`nix.settings`, hardware, boot, display-manager, firewall, k3s, storage, and
system-level package declarations.

### 4. Cluster/infrastructure outputs

Keep in Reverb-OS but never import into Home Manager activation. This includes
Colmena, Kubernetes, container images, cluster daemons, host contracts, and
privileged recovery tooling.

The classification must be recorded in a machine-checkable manifest or test so
new modules cannot silently cross the boundary.

## Niri integration

Niri is not an Omarchy-owned capability, so it is an explicit additive feature
of the Reverb-OS Home Manager flake.

The portable Niri composition will:

- import the `niri-flake` Home Manager module;
- configure `programs.niri.settings`;
- install the Niri package and user-scoped helper commands through Home Manager;
- manage Niri user configuration and user services;
- use the Nix profile's Niri executable rather than
  `/run/current-system/sw/bin/niri`;
- use generic monitor/session defaults in `omarchy`;
- keep Zephyr-specific monitor and gaming rules in `omarchy-zephyr`;
- provide an explicit user-session entry or documented UWSM launch path without
  modifying Omarchy's root display-manager configuration.

The Niri module must not emit or require NixOS-only options such as:

- `environment.systemPackages`;
- `environment.etc`;
- `nix.settings`;
- root display-manager services;
- root portal, firewall, GPU, or kernel configuration.

If a Niri prerequisite requires root or system configuration, it becomes a
separate host prerequisite and is not silently installed by Home Manager.

## Dependency direction

The standalone Home Manager composition must not import the full NixOS flake
or use `nixos-config` as a package provider. This avoids pulling cluster
infrastructure into an Omarchy user activation and removes the current
cross-repository dependency.

Packages required by the portable user layer must be handled in one of these
ways:

1. use an existing nixpkgs package;
2. move a genuinely user-facing derivation into Reverb-OS's reusable package
   set; or
3. remove the feature from the generic profile when Omarchy already provides it.

Cluster-only derivations and NixOS modules remain available to their existing
outputs but are not dependencies of `homeConfigurations.omarchy`.

## Migration sequence

1. Import the existing Home Manager source into Reverb-OS without changing the
   old NixOS outputs.
2. Create a standalone `omarchy` composition with no `nixos-config` input.
3. Add the module ownership classification and enforce it with checks.
4. Remove or exclude modules that duplicate Omarchy capabilities.
5. Refactor the Niri composition into an HM-native, generic profile.
6. Add the `omarchy-zephyr` profile only after generic activation passes.
7. Test evaluation and activation in the disposable Arch/Omarchy guest.
8. Compare generated files against the ownership manifest and verify repeated
   activation is idempotent.
9. Migrate unique user features from the old HM repo one group at a time.
10. Freeze `home-manager-config` as a compatibility reference, then retire it
    only after the combined flake has equivalent or intentionally deferred
    behavior.

No live host migration is part of this sequence.

## Acceptance tests

The first implementation is accepted only when:

- `homeConfigurations.omarchy` evaluates without NixOS-only inputs;
- standalone Home Manager builds on `x86_64-linux`;
- activation works on an Arch/Omarchy guest;
- a second activation is idempotent;
- no managed path is under `/usr/share/omarchy` or Omarchy-generated state;
- the module classification check passes;
- the Niri configuration is generated from the user profile and does not
  reference `/run/current-system`;
- Omarchy's CLI, update, migration, theme, and Quickshell behavior remain
  available;
- existing NixOS and Kubernetes checks remain evaluable;
- user data and credentials are not copied into the Nix store;
- the guest can be discarded without affecting any live host.

A headless guest proves activation and file ownership only. Graphical Niri
session behavior remains a later graphical acceptance test.

## Non-goals

- Forking Omarchy.
- Reimplementing Omarchy's desktop or update system in Nix.
- Installing every existing Reverb-OS feature into the generic profile.
- Moving root, hardware, storage, networking, k3s, or Kubernetes ownership into
  Home Manager.
- Deleting NixOS rollback outputs before the Omarchy profile is accepted.
