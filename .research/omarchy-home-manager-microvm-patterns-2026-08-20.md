# Arch Omarchy + Home Manager: isolated test patterns

**Research date:** 2026-08-20

**Question:** How are comparable projects testing Arch/Omarchy-like systems, standalone Home Manager, and microVM guests—and what should Reverb-OS use for its first isolated prototype?

## Executive conclusion

There are two different problems that are easy to conflate:

1. **Testing the real Omarchy base:** requires the Omarchy ISO/install flow, an Arch userspace, systemd, the package/update layout, and enough virtual hardware for the base to boot.
2. **Testing a portable Home Manager profile:** only requires a Linux userspace, Nix, a user account, a writable home, and a controlled activation environment.

The strongest existing implementation is Omarchy's own headless QEMU/KVM harness. It boots the actual ISO, installs it through the real installer, uses a reusable qcow2 base plus throwaway overlays, provisions SSH, and runs guest-side acceptance tests. That is the pattern to copy for the first **Omarchy + HM** test.

`microvm.nix` is not the right guest builder for this target: its project scope is lightweight **NixOS** virtual machines, and its configuration model is built around `nixosConfigurations` and NixOS modules. It can remain useful for separate NixOS or artifact tests, but using it to claim that an Arch Omarchy guest was tested would be incorrect.

Firecracker and other strict microVM runtimes are also not the right first target. Firecracker expects a prepared Linux kernel and root filesystem; it does not provide the ISO/UEFI/desktop/install surface that Omarchy's own harness exercises. It is appropriate later for a minimal Arch/HM activation gate, not for validating Omarchy installation or desktop substrate.

## 1. First-party Omarchy pattern: headless QEMU/KVM

### Official ISO repository

The official ISO project is [`omacom-io/omarchy-iso`](https://github.com/omacom-io/omarchy-iso), currently using the `quattro` branch. Its README documents:

- the ISO as the supported Omarchy installation path;
- unattended installation through a second `cidata`/NoCloud drive;
- SSH authorized-key provisioning;
- a reusable installed base image;
- headless QEMU acceptance testing;
- qcow2 overlays so individual scenarios do not mutate the base;
- QMP screen dumps, OCR, and virtual keyboard input;
- guest-side SSH-based test execution;
- screenshots, serial logs, and failure artifacts.

Sources:

- [Omarchy ISO README](https://github.com/omacom-io/omarchy-iso/blob/quattro/README.md)
- [Unattended installs manual](https://github.com/basecamp/omarchy/blob/quattro/manual/51-unattended-installs.md)
- [Official acceptance-test guide](https://github.com/basecamp/omarchy/blob/quattro/agents/skills/acceptance-tests.md)
- [ISO acceptance harness](https://github.com/omacom-io/omarchy-iso/blob/quattro/bin/omarchy-iso-test)

The official harness currently launches a headless QEMU/KVM guest with the important characteristics roughly equivalent to:

```text
CPU:       host + KVM
Machine:   q35
Firmware:  UEFI/OVMF
Disk:      virtio block + qcow2
Display:   virtio-vga, host display disabled
Network:   user networking + forwarded SSH port
Control:   QMP socket + serial log
Memory:    8 GiB default for full acceptance
```

It drives the real interactive installer rather than replacing it with a synthetic root filesystem. For fast iteration, it installs once, saves the base, then boots throwaway overlays. This is particularly valuable for Omarchy because installation, finalization, user creation, SDDM/session setup, and migrations are part of the product contract.

### Omarchy's test separation

Omarchy's own [`docs/testing.md`](https://github.com/basecamp/omarchy/blob/quattro/docs/testing.md) separates:

- fast CLI and shell tests that run without a compositor;
- compositor-dependent tests that skip safely when no reachable Wayland session exists;
- graphical acceptance tests that run only in a disposable VM.

The contributor guide makes the same distinction: graphical acceptance tests must not run in the active development session, and changes to the ISO/install/defaults require a fresh ISO and a VM run.

**Lesson:** Reverb-OS should not make a headless guest report “desktop parity.” It should report the narrower facts it can prove: Omarchy installation, Arch/Nix/HM activation, user services, file ownership, SSH/bootstrap, and selected system contracts.

## 2. Omarchy unattended install is already designed for disposable guests

The unattended-install design is unusually useful for our prototype. The ISO recognizes a second filesystem labeled `cidata` and reads:

- `user_configuration.json`;
- `user_credentials.json`;
- optional full name and email;
- optional `authorized_keys`;
- optional Tailscale enrollment data.

The ISO README says the same mechanism is suitable for Proxmox, libvirt, Packer, and disposable development environments. It provides a documented `genisoimage` flow and a Proxmox example.

Important security constraints:

- encrypted unattended installs still require a person to enter the LUKS passphrase at first boot;
- the encrypted configuration carries the passphrase in plaintext and must be treated as a secret;
- reusable images must not contain cluster credentials;
- Tailscale keys and SSH material must be test-only and host-specific.

**Recommended Reverb use:** use an unencrypted disposable test disk for the first HM ownership experiment, provision only a throwaway SSH key, and keep the resulting qcow2 image outside tracked source. Add encryption testing later as a separate scenario.

## 3. `microvm.nix`: excellent tool, wrong guest abstraction here

[`microvm-nix/microvm.nix`](https://github.com/microvm-nix/microvm.nix) describes itself as a flake for building and running lightweight **NixOS** virtual machines on NixOS/Linux or macOS. Its guest definitions use NixOS configurations and exported NixOS modules.

Relevant capabilities:

- QEMU, Cloud Hypervisor, Firecracker, crosvm, kvmtool, Stratovirt, Alioth, and vfkit backends;
- read-only squashfs/EROFS roots containing a NixOS closure;
- optional host `/nix/store` sharing;
- virtio block/network/filesystem devices;
- port forwarding and serial consoles;
- experimental graphics support;
- declarative systemd integration on a NixOS host.

Sources:

- [microvm.nix README](https://github.com/microvm-nix/microvm.nix)
- [microvm.nix handbook](https://microvm-nix.github.io/microvm.nix/)
- [microvm.nix options reference](https://microvm-nix.github.io/microvm.nix/microvm-options.html)

The project’s own scope is the decisive limitation: it builds NixOS guests, not arbitrary Arch/Omarchy installations. A custom Arch rootfs might be booted with a separately authored runner, but that would be our own integration and would bypass the normal Omarchy ISO/install/update path.

**Use in our architecture:**

- keep it for existing NixOS CI and future artifact/service isolation;
- optionally use it for a fast Nix-side HM module/evaluation test;
- do not use it as the authoritative test of Arch Omarchy + standalone HM.

## 4. Firecracker and strict microVMs

[Firecracker's rootfs/kernel documentation](https://github.com/firecracker-microvm/firecracker/blob/main/docs/rootfs-and-kernel-setup.md) requires a prepared guest kernel and root filesystem. Its examples build an ext4 rootfs and install an init system directly into it. This is intentionally lower-level than an ISO-based desktop distribution install.

Firecracker is a good fit for:

- a tiny Arch or Alpine guest image;
- SSH/bootstrap checks;
- Nix daemon/cache checks;
- a fast standalone Home Manager activation test;
- host-contract or service-process tests.

It is a poor fit for the first Omarchy test because it does not naturally prove:

- the Omarchy ISO/configurator;
- Limine/UEFI installation behavior;
- Btrfs/Snapper/Limine snapshot workflow;
- systemd/desktop login setup as shipped by Omarchy;
- virtual input and graphical shell behavior;
- Quickshell/Wayland integration.

The correct conclusion is not “microVMs cannot work.” It is:

> A strict microVM can test the portable Arch/HM slice, while a headless KVM guest is needed to test the real Omarchy installation slice.

## 5. Incus and container approaches

[Incus instance documentation](https://linuxcontainers.org/incus/docs/main/explanation/instances/) distinguishes:

- system containers, which run a Linux userspace while sharing the host kernel;
- application containers;
- full virtual machines implemented through QEMU.

A system container is useful for quick Home Manager activation and file-ownership tests. It is not sufficient to test Omarchy as a base because it does not provide an independent kernel, bootloader, firmware, or hardware environment. An Incus VM is effectively another QEMU-based full VM and may be useful operationally, but it is not a fundamentally lighter guest than the official headless QEMU path.

**Use in our architecture:** Incus containers can be a fast Tier-1 HM harness; Incus VMs can be an alternate runner if the workspace already standardizes on Incus. Neither should replace the official ISO/QEMU flow for the first real Omarchy test.

## 6. Standalone Home Manager on Arch: observed patterns

Home Manager's own README says standalone mode is the only supported installation mode on platforms other than NixOS and Darwin. It manages user-specific packages and dotfiles, not the global operating system.

Source:

- [Home Manager README](https://github.com/nix-community/home-manager/blob/master/README.md)
- [Home Manager manual](https://nix-community.github.io/home-manager/)

The public Arch/non-NixOS examples follow a consistent pattern:

### KnightChaser/linux-nix-hm-config

Repository: <https://github.com/KnightChaser/linux-nix-hm-config>

This explicitly supports Arch/Fedora with standalone Home Manager. Its flake exposes a `homeConfigurations.<username>` output, imports `home-manager.lib.homeManagerConfiguration`, passes an explicit `pkgs`, and activates with:

```bash
home-manager switch -b hm-bak --flake .#username
```

The first activation uses a backup suffix because Home Manager may replace existing shell files. The repository also keeps username and home-directory facts separate from the public configuration so those values are not accidentally committed.

### AljGe/ArchliNix

Repository: <https://github.com/AljGe/ArchliNix>

This is an Arch Linux WSL configuration using flakes and standalone Home Manager. It pins a stable `nixpkgs` input, pins Home Manager to the corresponding release branch, and uses a separate unstable input for selected packages. Its output is a standalone `homeConfigurations` entry rather than a NixOS system.

### hakan-demirli/dotfiles

Repository: <https://github.com/hakan-demirli/dotfiles>

This is primarily a NixOS configuration, but it documents a useful separation: Home Manager is rootless and independent from NixOS, with explicit profiles for desktop/headless/VPS use. It also exposes a portable Home Manager artifact/deployment path for Linux targets without Nix. That is relevant to a later cluster phase, but it should not be confused with a full Arch host-management solution.

### What these examples do not do

The examples do not make Home Manager an Arch system manager. They do not declaratively own the kernel, package database, system firewall, mounts, k3s, or root services. They consistently treat HM as a user-layer tool activated by the target user.

That aligns with Omarchy’s own package/user boundary and supports the additive approach already chosen for Reverb-OS.

## 7. Omarchy/Nix ports: useful evidence, but different architecture

### henrysipp/omarchy-nix

Repository: <https://github.com/henrysipp/omarchy-nix>

This is an opinionated NixOS reimplementation/launch pad inspired by Omarchy. Its README explicitly says it is not intended to achieve full feature parity and that the author moved back to regular Arch Omarchy. It is useful evidence that a direct NixOS rewrite creates maintenance and parity costs, but it is not a model for Arch Omarchy plus standalone HM.

### zicochaos/omarchy-nix

Repository: <https://github.com/zicochaos/omarchy-nix>

This newer project takes the opposite approach: vendor the real upstream Omarchy tree into NixOS instead of rewriting it. Its README documents VM builds and automated NixOS checks, and explicitly identifies a VM graphics limitation for Quickshell. The testing discipline and “vendor upstream, do not rewrite” rule are valuable for us; the NixOS host module is not our target architecture.

### Key lesson

The successful-looking Nix ports either:

- reimplement Omarchy on NixOS, accepting parity debt; or
- vendor Omarchy into NixOS, accepting a NixOS-specific runtime glue layer.

Neither demonstrates that Omarchy’s system layer can be replaced by standalone Home Manager. They strengthen the case for keeping the real Arch Omarchy base and placing HM strictly above it.

## 8. Recommended phase-1 test architecture

Because the project decision is **microVM-only**, define “microVM-only” as an isolated guest gate with no live-host desktop changes, but use two explicitly named guest modes if needed:

### Mode A: real Omarchy base gate — primary

Use the official Omarchy ISO and a headless KVM/QEMU guest:

```text
Omarchy ISO
  → unattended cidata install
  → Arch/Omarchy first boot
  → SSH bootstrap
  → install Nix + standalone Home Manager
  → additive HM activation
  → ownership/drift assertions
  → shutdown and discard overlay
```

This is the only mode in phase 1 that can claim to test the real Omarchy base.

### Mode B: fast standalone-HM gate — optional optimization

Use an Arch cloud/rootfs image in Firecracker, Cloud Hypervisor, or an Incus system container:

```text
Arch rootfs
  → Nix bootstrap
  → standalone HM activation
  → fake/isolated HOME ownership tests
  → user service and package assertions
```

This is faster, but it must be labeled **Arch + HM**, not **Omarchy + HM**, unless the Omarchy packages and required runtime contract are actually present.

For the current request, start with Mode A only. Add Mode B only after the real Omarchy path works and its test assertions are stable.

## 9. Proposed Reverb-OS acceptance contract

The first microVM-only test should prove:

1. The real Omarchy ISO installs unattended from a generated `cidata` drive.
2. The guest reaches a reachable SSH/user state using a disposable key.
3. Nix installs and can evaluate the `home-manager-config` Omarchy profile.
4. Home Manager activates as the target user with an explicit backup policy.
5. HM-owned files are outside the initial Omarchy-owned paths.
6. `~/.config/hypr`, `~/.config/quickshell`, `~/.config/omarchy`, Omarchy theme state, and Omarchy update files are not replaced by HM in phase 1.
7. User-only packages and services are present after activation.
8. A second activation is idempotent.
9. The guest can run Omarchy’s non-graphical CLI/shell tests where applicable.
10. The guest is destroyed after the test, leaving no live host or production deployment changes.

The test should produce:

- the guest serial log;
- the exact Omarchy ISO/release and source revision;
- the Home Manager flake revision and evaluated profile;
- an ownership manifest before and after activation;
- activation logs;
- a machine-readable pass/fail summary;
- the disposable guest overlay path for cleanup.

It should explicitly **not** claim:

- Quickshell rendering correctness;
- Hyprland visual parity;
- GPU/input/audio behavior;
- Limine interaction beyond successful guest boot;
- hardware-specific cluster behavior.

Those require a later graphical/passthrough acceptance class, not a broader claim about this headless gate.

## Recommendation

Proceed with an **official-harness-compatible headless QEMU/KVM guest**, not `microvm.nix` and not Firecracker, for the first real Omarchy + standalone Home Manager prototype. Keep the guest disposable, use the real ISO and unattended `cidata` flow, and layer HM only after SSH/user bootstrap. Treat strict microVMs and containers as future fast tests for the portable HM/Arch layer, not as substitutes for Omarchy installation testing.

This preserves the user’s “microVM only” isolation requirement while choosing the implementation that the Omarchy maintainers themselves use for their own install and acceptance boundary.
