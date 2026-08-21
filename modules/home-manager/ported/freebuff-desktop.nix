# Freebuff Desktop launcher — provenance + ownership notes (2026-08-15, updated 2026-08-18).
#
# The runnable Freebuff binary is the self-wrapped copy under
# ~/.local/opt/freebuff-desktop/current, produced by `appimage-updater.nix`
# (a weekly systemd user timer wraps the latest AppImage with
# appimageTools.wrapType2). That module is the SINGLE source of truth for the
# launcher: its `xdg.desktopEntries` emits freebuff-desktop.desktop with
# `Exec=freebuff-desktop-latest %U`, and its wrapper prefers the ~/.local/opt
# copy.
#
# There is NO Layer-1 package in nixos-config (packages/freebuff-desktop.nix
# does not exist). nixos-config's `services.freebuff-desktop` module installs
# only the hicolor icon asset. The old freebuff-flake wrapper
# (freebuff-desktop-launcher, v0.0.42) is being retired — it forced
# ELECTRON_OZONE_PLATFORM_HINT=wayland + GDK_BACKEND=wayland + LD_PRELOAD,
# the nixpkgs#382612 GPU-session hang pattern (see issue #14).
#
# This module previously emitted a static .desktop with the plain
# `Exec=freebuff-desktop` (the pre-hybrid arrangement). Removed 2026-08-15:
# two desktop entries for one app = duplicate launchers (the "only correct
# entry points" rule). The wrapper module is the single source of truth, so
# this module is now intentionally a no-op placeholder.
{lib, ...}: {
  # Intentionally empty. Kept so shared-leaf-modules.nix import stays stable
  # and the provenance story above survives grep.
}
