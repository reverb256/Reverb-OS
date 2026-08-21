# Unified Reverb-OS Home Manager flake implementation plan

## Scope

Add a standalone Home Manager profile to Reverb-OS that can be activated on
Omarchy/Arch, with Niri as an additive user feature and Omarchy retaining
ownership of built-in capabilities. Preserve the current NixOS and legacy
Home Manager outputs during the migration.

## Work packages

### 1. Standalone output

- Add a standalone `homeConfigurations.omarchy` output to Reverb-OS.
- Use only Reverb-OS, nixpkgs, Home Manager, and the Niri Home Manager module
  for the new composition.
- Keep the existing host outputs available as compatibility outputs until their
  modules are migrated.
- Expose a second `homeConfigurations.omarchy-zephyr` alias only when it is
  semantically safe; do not copy Zephyr hardware assumptions into the generic
  profile.

### 2. Omarchy ownership gate

- Add a machine-readable classification for the new profile's managed paths.
- Add an evaluation check that rejects Omarchy-owned paths, NixOS-only options,
  `/run/current-system` references, and root/system activation declarations in
  the portable composition.
- Document that Omarchy-provided capabilities are intentionally omitted rather
  than reimplemented.

### 3. Niri HM composition

- Create a portable Niri module under Reverb-OS.
- Import `niri-flake`'s Home Manager module.
- Configure generic keyboard, layout, input, window rules, and basic keybinds.
- Install user-scoped helpers through `home.packages`.
- Avoid NixOS-only `environment.*`, `nix.settings`, root display-manager,
  portal, firewall, GPU, and kernel options.
- Do not manage Quickshell or Hyprland configuration.

### 4. Legacy migration boundary

- Keep the old `home-manager-config` input for existing NixOS host outputs.
- Mark it as transitional in the Reverb-OS flake and documentation.
- Migrate unique modules only after each module is classified as deferred,
  portable additive, NixOS compatibility, or cluster infrastructure.
- Remove the input only after all required host outputs have moved or been
  intentionally retired.

### 5. Verification

- Evaluate `homeConfigurations.omarchy`.
- Run the new portable-profile check.
- Run existing Reverb-OS checks without deployment.
- Run the old Home Manager repository checks independently where possible.
- Run `git diff --check` and inspect generated output paths.

## Non-deployment constraint

No `nixos-rebuild`, Colmena apply, SSH activation, Kubernetes apply, or live host
mutation is part of this implementation slice.
