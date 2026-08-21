# Vesktop launcher harmonization — SINGLE SOURCE OF TRUTH for how Vesktop
# launches on niri.
#
# Every launcher must use the SAME command so behavior is identical:
#   - niri spawn-at-startup (login autostart)   → niri-spawn.nix
#   - Mod+G keybind (via launch-or-focus)       → niri-keybinds.nix
#   - .desktop file Exec                        → xdg.desktopEntries below
#   - Noctalia pinned app                       → resolves the .desktop entry
#
# Why the wrapper exists:
#   - NVIDIA + Wayland-native crashes (Vulkan TRAP) → force XWayland
#     (--ozone-platform=x11) + NVIDIA VA-API for screen sharing.
#   - A Vesktop instance hidden to tray (minimizeToTray) holds Electron's
#     single-instance lock; any launcher that starts a *second* instance hits
#     "Vesktop is already running. Quitting..." and shows nothing. So the
#     wrapper is also a focus-or-restart entry: if a window exists → focus it;
#     if a windowless zombie holds the lock → kill it and start fresh.
{
  config,
  lib,
  pkgs,
  ...
}: let
  # Exposed to sibling modules (niri-spawn.nix, niri-keybinds.nix) via
  # _module.args so all launchers reference the same derivation.
  vesktopWrapper = pkgs.writeShellScriptBin "vesktop-uwsm-wrapper" ''
    set -u

    export XDG_CURRENT_DESKTOP=KDE
    export LIBVA_DRIVER_NAME=nvidia
    export NVD_BACKEND=direct

    # 1) Window already mapped → focus it (launchers act as focus-or-launch).
    if [ -n "''${NIRI_SOCKET:-}" ]; then
      WID=$(${pkgs.niri}/bin/niri msg --json windows 2>/dev/null | ${pkgs.jq}/bin/jq -r \
        --arg p vesktop \
        '[.[] | select((.app_id // "" | ascii_downcase) | contains($p))] | sort_by(.is_focused | not) | .[0].id // empty' \
        2>/dev/null || true)
      if [ -n "$WID" ]; then
        ${pkgs.niri}/bin/niri msg action focus-window --id "$WID" >/dev/null 2>&1 || true
        exit 0
      fi
    fi

    # 2) Windowless zombie (tray-hidden) → restart so the window appears.
    #    Electron's singleton lock would otherwise make this launch quit with
    #    "already running" and the launcher would appear dead.
    if ${pkgs.procps}/bin/pgrep -f "[Vv]esktop.*resources/app\.asar" >/dev/null 2>&1; then
      ${pkgs.procps}/bin/pkill -f "[Vv]esktop.*resources/app\.asar" >/dev/null 2>&1 || true
      ${pkgs.coreutils}/bin/sleep 2
    fi

    # 3) Fresh start with the NVIDIA/XWayland flags.
    exec ${pkgs.vesktop}/bin/vesktop --no-sandbox --ozone-platform=x11
  '';
in {
  _module.args.vesktopWrapper = vesktopWrapper;

  # Make the wrapper callable by bare name (mirrors launch-or-focus) and
  # shadow the package's plain `Exec=vesktop` entry so .desktop / Noctalia
  # launches go through the same focus-or-restart path.
  home.packages = [vesktopWrapper];

  xdg.enable = true;
  xdg.desktopEntries.vesktop = lib.mkIf config.nixcord-config.enable {
    name = "Vesktop";
    genericName = "Internet Messenger";
    comment = "A snappier Discord Experience";
    exec = "${vesktopWrapper}/bin/vesktop-uwsm-wrapper %U";
    icon = "vesktop";
    terminal = false;
    startupNotify = false;
    mimeType = ["x-scheme-handler/discord"];
    categories = ["Network" "InstantMessaging" "Chat"];
  };
}
