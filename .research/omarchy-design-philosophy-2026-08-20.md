# Omarchy design philosophy and implications for Reverb-OS

**Research date:** 2026-08-20

**Scope:** First-party Omarchy documentation and source, the official GitHub repository's active issues, pull requests, discussions, release notes, and the implications for making the cluster Omarchy-based with Home Manager layered above it.

## Executive conclusion

Omarchy is not intended to be a minimal Arch base, an immutable operating system, or a generic server distribution. Its stated goal is an opinionated, beautiful, batteries-included **developer workstation**: Arch plus Hyprland plus Quickshell, with a carefully selected application set, an integrated desktop, and a terminal-forward workflow.

The strongest architecture-compatible interpretation for this cluster is therefore:

```text
Omarchy/Arch base
  ├── owns the workstation substrate, system packages, boot, hardware integration,
  │   Hyprland, Quickshell, update channels, snapshots, and Omarchy UX
  ├── remains mutable and is updated through the Omarchy transaction
  └── is installed/configured per host role, not treated as a generic NixOS clone

Home Manager
  ├── owns the user's reproducible layer
  ├── manages packages and files outside Omarchy-owned paths first
  ├── can add user services, hooks, menu extensions, themes, and application config
  └── must not silently replace Omarchy's shell, update, migration, or ownership model

Cluster platform
  ├── keeps Kubernetes as the default home for portable long-running services
  └── retains only boot, hardware, storage, network, privileged access, k3s,
      GPU/VFIO, and emergency-recovery responsibilities at host level

Nix
  ├── remains valuable for packages, dev shells, checks, cache policy,
  │   Kubernetes declarations, host-role data, and generated non-root artifacts
  └── should not initially pretend to be the activation system for Omarchy's Arch host
```

This preserves the valuable Nix work without imposing a philosophy Omarchy's maintainers explicitly rejected: replacing a mutable developer system with an immutable/reconciled OS core.

## Source quality and current state

The primary sources are:

- [Omarchy website](https://omarchy.org/) — official project entry point. The site did not expose readable text through the research fetcher, so conclusions below do not depend on unverified website copy.
- [Omarchy repository](https://github.com/basecamp/omarchy) — upstream source and authoritative repository documentation.
- [Official `AGENTS.md`](https://github.com/basecamp/omarchy/blob/quattro/AGENTS.md) — contributor contract covering architecture-oriented task guides, package/user path conventions, runtime invariants, privilege boundaries, command naming, and test/visual-verification requirements.
- [Omarchy manual](https://github.com/basecamp/omarchy/tree/quattro/manual) — the repository README identifies `manual/` as authoritative and says it is mirrored to [learn.omacom.io](https://learn.omacom.io/2/the-omarchy-manual). 
- [Omarchy v4.0.0 release](https://github.com/basecamp/omarchy/releases/tag/v4.0.0) — current Quattro release at research time.
- [Omarchy Quattro PR #6231](https://github.com/basecamp/omarchy/pull/6231) — detailed release rationale and implementation direction.
- The repository's [design/reference docs](https://github.com/basecamp/omarchy/tree/quattro/docs), especially `file-layout.md`, `update-process.md`, `theming.md`, `omarchy-shell.md`, and `testing.md`.

The upstream repository was actively changing at research time. The latest release endpoint reported `v4.0.0`, published 2026-08-14, while new issues and pull requests continued to arrive immediately afterward. Omarchy should therefore be consumed through an explicit channel/release strategy rather than assumed to be a static package snapshot.

The official `AGENTS.md` is not an end-user philosophy document, but it is strong evidence of how the project expects contributors and downstream work to interact with the code. It separates task procedures (`agents/skills/`), internal reference (`docs/`), and published user guidance (`manual/`); requires focused tests and VM-based graphical acceptance tests; treats default commands as runtime invariants; and directs contributors toward Omarchy helpers instead of bypassing them with raw package-manager or notification commands. It also makes `$OMARCHY_PATH` a runtime invariant and preserves the package-owned versus user-owned configuration distinction.

## Explicit principles from Omarchy's own writing

### 1. Omakase, opinionated, and batteries included

The welcome manual describes Omarchy as an Arch-based distribution built around Hyprland and Quickshell. It says the system is a complete environment, not merely a package grab-bag, and explicitly frames its selection as the author's working set: productive immediately, aesthetically coherent, and without unnecessary bloat.

The same page says Omarchy is not trying to imitate Windows or macOS. It intentionally embraces Linux, terminal use, manual configuration, TUIs, tiling, and a different way of working.

**Interpretation:** “No bloat” means curated defaults, not “install almost nothing.” The maintainer response in [discussion #535](https://github.com/basecamp/omarchy/discussions/535#discussioncomment-14058161) is explicit: if someone wants a bare installation, they should install Arch and Hyprland themselves; a batteries-included environment is the project's point.

**Implication:** Do not redesign the cluster around an Omarchy “minimal bootstrap” that strips the workstation base down until it is effectively Arch. That would be a different product. Use host roles and package choices where needed, but preserve the coherent Omarchy base on machines intended to provide the Omarchy experience.

### 2. Mutable developer system, not immutable OS

In [discussion #648, “Immutable Omarchy”](https://github.com/basecamp/omarchy/discussions/648), the maintainer rejected an immutable/libostree direction: Omarchy is for developers, the possibility of breaking things is part of the package, and the project would explore Btrfs snapshots and rollbacks instead. The maintainer later stated that immutability is not compatible with Omarchy's specific goal.

The manual describes the corresponding compromise:

- updates take a snapshot before changing the system;
- the snapshot can be booted and restored from Limine;
- root can be rolled back without changing `/home`;
- user configuration is intentionally retained during rollback, so incompatible user config may need manual repair.

**Interpretation:** Omarchy values recoverable mutability over transactional immutability. Rollback is a safety net around a mutable developer environment, not a replacement for that environment.

**Implication:** A root `platform-reconciler` that continually enforces an immutable desired host generation would conflict with upstream's model if it becomes the primary OS authority. A smaller, opt-in bootstrap or artifact installer can still be useful for cluster-specific host prerequisites, but it must not overwrite Omarchy's package-owned state or turn ordinary Omarchy updates into an external reconciliation fight.

### 3. One blessed, integrated update transaction

The manual says Omarchy packages and Arch packages are updated through `omarchy update`. The update transaction combines package updates, migrations, snapshots, hooks, restart checks, and firmware/update indicators. Direct `pacman -Syu` is guarded and points users back to the Omarchy path, with an explicit bypass for experienced users.

The current source documents four channels:

- **stable:** release packages and a deliberately delayed Omarchy mirror;
- **RC:** final validation before a major release;
- **edge:** current development packages for experienced users;
- **dev:** a source checkout linked into the runtime, combined with edge packages.

**Interpretation:** The project is opinionated not only about what is installed, but about how the system changes. The update pipeline is a product feature and a compatibility boundary.

**Implication:** Home Manager must not independently update or replace Omarchy's package-owned desktop internals. Cluster automation should call the supported Omarchy update mechanism, pin a channel/release deliberately, and treat snapshots plus reboot/health verification as part of the update contract. The cluster's CI should validate HM and Nix artifacts separately from the Omarchy package transaction unless we deliberately build a downstream Omarchy package channel.

### 4. Clear package-owned versus user-owned state

The current Quattro manual says `/usr/share/omarchy` belongs to Omarchy and `~/.config` belongs to the user. Users should override defaults in user configuration instead of editing package-owned files. The source layout describes a more detailed split:

- `omarchy` and `omarchy-settings` are Arch packages;
- `/etc/skel` seeds defaults for new users;
- a finalize step handles runtime-dependent user setup;
- explicit resync is destructive and can reset user configuration;
- generated active theme state is kept under `~/.local/state/omarchy/current/`;
- user themes, hooks, shell layout, plugins, and template overrides live under `~/.config/omarchy/`.

The upstream discussion around [issue #619](https://github.com/basecamp/omarchy/issues/619) is especially important. The maintainer describes the intended split as Omarchy defaults in the package-owned area and user-editable material in `~/.config`; the hard problem is allowing the user-editable copy to evolve without losing user changes. The issue was ultimately closed as not planned rather than solved by a general lock/reconciliation mechanism.

**Interpretation:** Omarchy's ownership model is additive and override-oriented, but not a general declarative merge engine. It expects users to understand which files they own and to manually reconcile some changes.

**Implication for Home Manager:**

- HM should manage files that are clearly outside Omarchy's ownership boundary.
- For files in `~/.config/omarchy/`, HM should use supported extension points: `shell.json`, `shell.toml`, hooks, themes, plugin checkouts, and menu extensions.
- HM should not initially manage the complete `~/.config/hypr`, `~/.config/quickshell`, or generated Omarchy state tree.
- If HM later owns a particular file, it should be a deliberate ownership transfer with an update/rollback policy, not a silent overwrite.
- Use `home.file`/`xdg.configFile` only where the destination is known not to be rewritten by Omarchy, or where the design explicitly chooses HM over Omarchy for that path.

### Contributor contract: follow the project’s extension and verification surfaces

The official [AGENTS.md](https://github.com/basecamp/omarchy/blob/quattro/AGENTS.md) adds an important implementation-level principle: Omarchy is not just a set of files to copy. Its commands, environment variables, helper binaries, package boundaries, migration scripts, and test runners are runtime contracts.

It requires contributors to:

- use the task-specific guides under `agents/skills/`;
- keep `agents/skills/`, `docs/`, and `manual/` separate by audience;
- preserve `$OMARCHY_PATH` as the session/runtime source of truth;
- use Omarchy's package, notification, hardware, and command-presence helpers where appropriate;
- add shell tests under `test/shell.d/`;
- run CLI and shell tests, with graphical acceptance tests in a disposable VM;
- visually verify changes that affect the running UI.

**Implication:** Our Home Manager layer should consume Omarchy's documented interfaces and preserve its runtime invariants. If we add a downstream helper, it should be an explicit Reverb tool rather than silently shadowing an `omarchy-*` command or changing `OMARCHY_PATH`. Our VM test plan should mirror Omarchy's own separation between headless tests and graphical acceptance tests.

### 5. Integrated UX instead of a loose collection of components

Quattro's release description says the bar, launcher, menus, notifications, OSDs, panels, lock screen, and polkit agent were reimplemented as one long-running Quickshell process with plugins. This replaced several independent components with a coherent, themed, IPC-scriptable shell.

The source docs show the same design in implementation terms:

- one shell process hosts first-party services and on-demand plugins;
- a plugin manifest declares bar widgets, bars, panels, overlays, menus, and services;
- IPC is the canonical CLI-to-shell interface;
- third-party plugins are git repositories, are disabled initially for review, and run unsandboxed after explicit enablement;
- `shell.json` is canonical for shell layout/config once customized;
- `shell.toml` provides live machine-level overrides over theme values.

**Interpretation:** Omarchy prefers a small number of coherent, inspectable integration surfaces over many independently configured daemons.

**Implication:** We should integrate HM with Omarchy through stable interfaces, not fork or recreate Quickshell services in Nix. Good HM integration targets are shell exports, application configuration, theme data, supported shell JSON/TOML, menu extensions, plugin checkouts, and user services. Replacing Quickshell with another status bar or creating a parallel shell should be a consciously separate fork direction.

### 6. Aesthetic consistency is functional, not cosmetic

The welcome manual says beauty is motivating and productivity follows motivation. Quattro extends this through semantic theme colors, generated Neovim/VS Code/btop configurations, shared shell tokens, coordinated text scaling, and synchronized retint/reload behavior.

**Interpretation:** Theme coherence is part of the product's productivity model. It is not merely wallpaper or a color preset.

**Implication:** HM should consume Omarchy's semantic theme boundary rather than independently impose a competing Stylix/theme stack on Omarchy-owned applications. A Reverb theme layer can provide values to supported Omarchy extension files and to applications Omarchy does not own, but it should avoid fighting `omarchy-theme-set` and its generated state.

### 7. Hardware support is pragmatic, explicit, and scoped

Omarchy's install and hardware code uses small scripts, migrations, udev rules, package files, and device-specific detection. Recent active work illustrates the pattern:

- [PR #7044](https://github.com/basecamp/omarchy/pull/7044) gates an Intel MacBook Thunderbolt fix on Apple DMI and a specific PCI ID.
- [PR #7644](https://github.com/basecamp/omarchy/pull/7644) proposes a Broadcom Mac Bluetooth fix with matching hardware detection and idempotent migrations.
- [PR #7641](https://github.com/basecamp/omarchy/pull/7641) keeps an AMD xHCI workaround opt-in because default-on behavior would increase laptop power draw.
- [Issue #6671](https://github.com/basecamp/omarchy/issues/6671) catches a technically plausible but ineffective modprobe configuration because the kernel component is built in.

**Interpretation:** The project favors narrow fixes based on observed hardware behavior, with explicit power/compatibility trade-offs, rather than broad global defaults.

**Implication:** Existing Reverb-OS hardware knowledge should be preserved as host-role and hardware-profile data. Do not translate every NixOS hardware module directly into HM. Where a fix belongs upstream, contribute it upstream; where it is cluster-specific, keep it in the host/platform layer with hardware gating and rollback.

### 8. Security is opinionated but workstation-oriented

The security manual makes full-disk LUKS encryption mandatory for the standard install, enables a default-deny firewall, keeps SSH disabled until explicitly enabled, limits Docker exposure, and relies on Arch/Omarchy package updates. It documents passwordless sudo as a temporary, explicit convenience for AI-agent work, with a warning that the user's processes can then become root.

The unattended-install manual supports a `cidata` configuration drive, authorized keys, Tailscale enrollment, and deferred provisioning. It explicitly describes unattended installs as useful for disposable development environments and VM/Packer/Proxmox workflows.

**Interpretation:** Omarchy takes workstation security seriously while accepting developer convenience and explicit user responsibility. The unattended path is a strong automation hook, but not evidence that Omarchy is a headless server distribution.

**Implication:** The cluster bootstrap should preserve LUKS/firewall/SSH/secret boundaries and use unattended installation only in controlled imaging or VM workflows. Do not place cluster credentials in reusable images or `cidata` media. Tailscale and SSH provisioning must remain secret-aware and host-specific.

### 9. Simplification is a recurring design choice

[PR #2242](https://github.com/basecamp/omarchy/pull/2242) documents dropping alternate bootloader support in favor of Limine, adding guards for unsupported combinations, and simplifying the boot/session permutations. This is representative of Omarchy's direction: choose a supported path, automate it well, and make unsupported combinations the user's responsibility.

The project also centralizes controls in the Omarchy menu, chooses one default terminal/editor/application path, and uses package boundaries to keep installation and update behavior understandable.

**Implication:** Reverb-OS should not preserve every historical NixOS permutation in the Omarchy layer. Define a small supported matrix for host roles, hardware classes, and HM profiles. Keep experimental Niri, server/headless, and unusual GPU combinations as explicit profiles or downstream forks until they have tests and recovery paths.

## What active GitHub work reveals

The active queue is not just cosmetic polish. It shows the project values a tight feedback loop from real machines into focused, test-backed fixes:

- [PR #7653](https://github.com/basecamp/omarchy/pull/7653) fixes a Quickshell menu empty-state overflow and includes CLI/shell testing notes.
- [Issue #7652](https://github.com/basecamp/omarchy/issues/7652) investigates a long-running Quickshell process failure that stops display blank/wake behavior after roughly a day.
- [PR #7651](https://github.com/basecamp/omarchy/pull/7651) proposes a user-session CPU weight so builds cannot starve Hyprland input; it includes a runtime migration, package companion work, and tests.
- [Issue #7650](https://github.com/basecamp/omarchy/issues/7650) identifies an idempotency bug where repeated keyboard-backlight blanking saves zero as the restoration value.
- [Issue #7645](https://github.com/basecamp/omarchy/issues/7645) reports a Quickshell/PAM fingerprint crash under overlapping retries.
- [PR #7649](https://github.com/basecamp/omarchy/pull/7649) updates the Codex collector for a breaking upstream CLI change and adds regression coverage.
- [PR #7643](https://github.com/basecamp/omarchy/pull/7643) makes lock-screen blank timing configurable through the supported shell configuration rather than forcing users to clone the lock plugin.

These changes reinforce several principles: real hardware and real workflows drive the roadmap; fixes are narrowly scoped; defaults are conservative; user-visible configuration is preferred over source forks; and tests are expected at the CLI, shell, migration, and live-session boundaries.

## Consequences for the cluster migration

### The proposed minimal-bootstrap/reconciler needs a correction

The earlier minimal-bootstrap idea remains useful as a **cluster service-placement policy**, but not as a claim that Omarchy itself should become a tiny immutable host OS.

Keep the following:

- Kubernetes by default for portable long-running services.
- Host-level ownership only for boot, hardware, storage, networking, SSH/recovery, k3s, GPU/VFIO, and services that must survive Kubernetes failure.
- Nix packages, dev shells, checks, Kubernetes declarations, host-role data, cache policy, and secret specifications.
- VM/microVM testing before changing a live host.

Change the following:

- Do not make a continuously enforcing root reconciler the authority over Omarchy's full `/etc`, package database, `/usr/share/omarchy`, or user desktop files.
- Do not replace Omarchy's update/snapshot/channel workflow with a generic artifact-generation transaction in phase 1.
- Do not use HM to recreate NixOS system modules or to write files that Omarchy refreshes.
- Do not assume a headless node is automatically an official Omarchy use case; model it as a supported downstream host profile and test it.

### Ownership matrix

| Responsibility | Primary owner | Rule |
|---|---|---|
| Arch kernel, boot, firmware, GPU drivers | Omarchy/Arch + host profile | Use Omarchy's installer/package/update model; keep hardware-specific additions narrow. |
| Hyprland and Quickshell runtime | Omarchy | HM integrates through documented extension points; no parallel compositor shell initially. |
| Omarchy package updates and migrations | Omarchy | Use `omarchy update`, channels, snapshots, and migrations. |
| User shell, prompt, CLI tools | Home Manager | Additive first; do not replace Omarchy's shell bootstrap accidentally. |
| Neovim/editor config | Home Manager or Omarchy, one owner per path | Choose HM ownership only after deciding whether Omarchy theme synchronization is retained. |
| `~/.config/omarchy/shell.json` and `shell.toml` | Shared contract, HM may own explicitly | HM can render these only once their supported schema and update behavior are tested. |
| Omarchy themes/plugins/hooks | Omarchy extension model, optionally HM | Manage through documented paths and commands; avoid writing package-owned state. |
| k3s and privileged node runtime | Host platform layer | Not Home Manager; requires root and must remain recoverable during cluster outages. |
| Quill, AI gateway, MCP, auth, monitoring, dashboards | Kubernetes | Kubernetes by default, with explicit persistent-storage/GPU exceptions. |
| Secrets and trust bootstrap | Host/bootstrap + SecretSpec/SOPS policy | Never bake reusable credentials into images or user profiles. |
| Nix packages and cache policy | Nix flake | Preserve as build artifacts and development tooling; do not confuse with OS activation. |
| CI/CD | GitHub Actions | Test HM, Nix artifacts, Kubernetes declarations, and VM images; gate production separately. |

### Host profiles

Use an explicit profile taxonomy rather than pretending every machine has the same desktop:

1. **Omarchy workstation:** full Omarchy desktop and Quickshell experience; HM adds user configuration.
2. **Omarchy compute node:** Omarchy/Arch base with a documented non-interactive or reduced-session profile, k3s/GPU/runtime prerequisites, and no accidental desktop ownership conflicts.
3. **Omarchy control/storage node:** only if the base is operationally acceptable; otherwise this is a downstream Arch/Omarchy-derived profile, not a claim about upstream's workstation target.
4. **Omarchy VM test image:** unattended install with disposable credentials, test-only secrets, and automated HM activation.

The profile names should be backed by tests and recovery documentation before migration. Zephyr is the natural first workstation prototype. A non-workstation node should not be migrated merely because the installer can technically run there.

### Home Manager adoption sequence

1. Activate HM on an Omarchy VM without managing Omarchy-owned desktop paths.
2. Install user packages and manage shell/editor/terminal files that are not updated by Omarchy.
3. Add user services through HM where the service does not need root, a physical device, or early boot.
4. Add supported Omarchy extension files one at a time: menu extensions, hooks, user themes, shell TOML/JSON, and plugins.
5. For every candidate path, record the writer set: Omarchy package, seed/finalize, migration, theme switcher, HM, or user command.
6. Transfer ownership only when one owner is designated and an upgrade/rollback test exists.
7. Keep Hyprland/Quickshell full ownership with Omarchy until the Niri/fork design is mature and can preserve Quickshell IPC/theme behavior.

## Research-informed decisions

### Adopt

- Omarchy-first base, Home Manager additive layer.
- Kubernetes by default for cluster services.
- Mutable Omarchy with Btrfs/Limine snapshot rollback, not an immutable replacement.
- Explicit release/channel pinning and controlled update windows.
- One owner per user configuration path.
- Nix preserved for packages, cache hits, tests, manifests, and reproducible artifacts.
- VM/microVM acceptance tests before host migration.
- Small host profiles with explicit hardware and recovery contracts.

### Reject

- Calling a stripped Arch host “full Omarchy” while removing the batteries-included workstation design.
- Making Home Manager manage `/usr/share/omarchy`, generated Omarchy state, or all of `~/.config` by default.
- Replacing `omarchy update` with a generic Nix reconciler before proving the interaction with package hooks, migrations, snapshots, and channels.
- Treating Omarchy as a server distribution without a tested downstream profile.
- Rebuilding Quickshell and its services from scratch in the HM layer.
- Putting cluster secrets in unattended-install media, golden images, or Nix store outputs.

## Open questions for implementation planning

1. Which hosts are required to expose the complete Omarchy desktop, and which are downstream compute/control profiles?
2. Should non-workstation hosts run the Omarchy packages and base services with the graphical session disabled, or use a separately defined Arch profile that consumes Omarchy packages selectively?
3. Which current NixOS services truly need to remain host-level after the Kubernetes-by-default review?
4. Will Home Manager own Neovim, shell, terminal, and theme files immediately, or will some remain Omarchy-owned until the first VM test?
5. What exact Omarchy channel/release policy applies to each host profile: stable, RC, edge, or dev?
6. Which Nix-generated outputs are safe as non-root artifacts, and which would improperly duplicate Omarchy's package/update authority?
7. What is the rollback story for an Omarchy update plus an HM activation that changes user config? Root snapshot rollback deliberately does not roll back `/home`.
8. How will CI test GPU, k3s, storage, and privileged host contracts without making GitHub runners production authorities?

## Practical next step

Build a disposable Omarchy Quattro VM using the documented unattended-install path, activate the additive HM profile, and collect a file-ownership report before changing any live host. The first experiment should intentionally leave Hyprland, Quickshell, Omarchy themes, and Omarchy update files untouched. The output should be a tested ownership matrix and a host-profile decision, not a deployment.
