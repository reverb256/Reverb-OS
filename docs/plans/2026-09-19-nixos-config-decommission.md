# nixos-config decommission — Path B (rehome → repoint → archive)

> Status: IN PROGRESS · started 2026-09-19 · owner: Hermes (default profile) directly, per j_kro
> Tracking issue: reverb256/Reverb-OS#12

## Context (measured 2026-09-19)

- All hosts run **Omarchy**. No `/etc/nixos` on nexus/forge/sentry; zephyr keeps a clean checkout tracking `main` (last sync Sep 17) purely as the legacy edit loop.
- The NixOS-era deploy chain is a **zombie**: nexus has no `/etc/nixos` checkout, no `/run/nixos-deploy` state, no tmux deploy sessions, no deploy logs; **no self-hosted runners** are registered on either repo; Cluster Status has nothing to report.
- Agents still commit to nixos-config (k3s/calico/firewall/secretspec, Sep 15–17) via muscle memory — every legacy skill and AGENTS.md still points there.
- **Live code-level consumer**: Reverb-OS flake input `pkgs/gitlawb` (redundant — `pkgs/gitlawb` already exists locally in Reverb-OS).
- `home-manager-config` declares itself transitional; no `~/.config/home-manager` exists on any host → droppable, archiveable.

## End state

| Concern | Now (legacy) | Target |
|---|---|---|
| Host profiles / HM / kubernetes / deploy | split across nixos-config + Reverb-OS | **Reverb-OS** |
| Ops scripts, runbooks, workflows, mcp | nixos-config (+ partially homelab-ops) | **homelab-ops** |
| nixos-config / home-manager-config | active-but-zombie | **archived (read-only, history preserved)** |

## Phases

- **P0 (done 2026-09-19):** freeze signals — this doc, Reverb-OS#12, README + AGENTS.md banners.
- **P1:** drop the `gitlawb` input in Reverb-OS (use local `pkgs/gitlawb`); `nix flake check` + host eval verify on nexus; PR.
- **P2:** port live ops → homelab-ops: CI Doctor + Cluster Status workflows (rewrite for Omarchy reality; decide runners), `scripts/ci-doctor.sh`, monitoring/backup bits still in use.
- **P3:** port live pkgs → Reverb-OS: `caddy-with-modules`, `nix-cache-proxy`, `secretspec/`, `memlawb.nix`, `peakminer.nix`, `*-image` builders — each with a who-consumes check + eval/build verify.
- **P4:** repoint consumers + sweeps: hermes-skills-live, local skills, infrastructure-docs, site-agency profiles, AGENTS.md files, memlawb-for-hermes refs.
- **P5:** drop `home-manager-config` input in Reverb-OS; archive home-manager-config.
- **P6:** archive nixos-config; final report.

## Ground rules

- Never touch the live Omarchy layer or the running k3s cluster in this project.
- Confirm the applied reality of the Sep 15–17 calico/firewall changes (imperative + oplog) before archiving; port anything still needed into the Omarchy ops flow — do not resurrect the zombie deploy chain.
- Do not archive until Reverb-OS evaluates clean with zero nixos-config inputs.
