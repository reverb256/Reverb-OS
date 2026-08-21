# Caprine Home Manager Configuration
# Elegant Facebook Messenger desktop app
# Uses Nixpkgs instead of Flatpak for better Wayland integration
# Auto-detects best backend (Wayland or XWayland)
{
  config,
  lib,
  pkgs,
  ...
}: {
  options.caprine.enable = lib.mkEnableOption "Caprine Facebook Messenger";

  config = lib.mkIf config.caprine.enable {
    # Install Caprine package
    home.packages = with pkgs; [caprine];

    # Autostart Caprine on login
    # Global ELECTRON_OZONE_PLATFORM_HINT=auto handles backend selection
    systemd.user.services.caprine-autostart = {
      Unit = {
        Description = "Caprine - Facebook Messenger autostart";
        # Keep the running Caprine instance alive across `home-manager switch`.
        # ExecStart embeds caprine's store path, which churns on rebuild ->
        # HM would restart the unit every switch, dropping the Messenger
        # session. keep-old leaves the live instance untouched (same pattern
        # as vesktop-autostart).
        X-SwitchMethod = "keep-old";
        # Cluster runs niri ONLY — no plasma-plasmashell.service exists, so
        # ordering against graphical-session-pre.target suffices.
        After = [
          "graphical-session-pre.target"
        ];
        PartOf = ["graphical-session.target"];
      };
      Service = {
        Type = "simple";
        # niri-only: skip the Steam gamescope console (no desktop surface).
        ExecCondition = "${import ./niri-session-guard.nix pkgs}";
        ExecStart = lib.getExe' pkgs.caprine "caprine";
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install = {
        WantedBy = ["graphical-session.target"];
      };
    };
  };
}
