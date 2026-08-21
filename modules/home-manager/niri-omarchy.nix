{ config, lib, pkgs, ... }:
let
  niriPackage =
    if pkgs ? niri-unstable
    then pkgs.niri-unstable
    else pkgs.niri;
  niri = lib.getExe niriPackage;
  actions = config.lib.niri.actions;
in
{
  # Niri is an additive compositor option. Omarchy's Hyprland and Quickshell
  # remain untouched, and no root display-manager configuration is emitted.
  home.packages = [niriPackage];

  programs.niri.package = niriPackage;
  programs.niri.settings = {
    # Keep the generic profile hardware-neutral. Omarchy and Niri discover
    # outputs; host-specific layouts belong in a later explicit profile.
    input = {
      mod-key = "Super";
      keyboard = {
        repeat-delay = 300;
        repeat-rate = 50;
        numlock = true;
      };
      touchpad = {
        tap = true;
        natural-scroll = true;
        dwt = true;
      };
    };

    layout = {
      gaps = 8;
      default-column-width = { proportion = 0.5; };
      center-focused-column = "never";
    };

    cursor = {
      hide-on-key-press = true;
      hide-after-inactive-ms = 3000;
    };

    hotkey-overlay = {
      skip-at-startup = false;
      hide-not-bound = true;
    };

    prefer-no-csd = true;

    window-rules = [
      {
        matches = [
          { app-id = "pavucontrol"; }
          { app-id = "nm-connection-editor"; }
          { app-id = "org.gnome.Calculator"; }
        ];
        open-floating = true;
      }
    ];

    binds = {
      "Mod+Return" = {
        action = actions.spawn "alacritty";
      };
      "Mod+Space" = {
        action = actions.spawn "fuzzel";
      };
      "Mod+Shift+E" = {
        action = actions.spawn "niri" "msg" "action" "quit";
      };
      "Mod+Q" = {
        action = actions.close-window;
      };
      "Mod+Left" = {
        action = actions.focus-column-left;
      };
      "Mod+Right" = {
        action = actions.focus-column-right;
      };
      "Mod+Up" = {
        action = actions.focus-window-up;
      };
      "Mod+Down" = {
        action = actions.focus-window-down;
      };
      "Mod+Shift+Left" = {
        action = actions.move-column-left;
      };
      "Mod+Shift+Right" = {
        action = actions.move-column-right;
      };
    };
  };

  # Keep the helper available to future user services without hard-coding a
  # NixOS store path. It is intentionally not used to manage the session.
  home.sessionVariables.NIRI_BIN = niri;
}
