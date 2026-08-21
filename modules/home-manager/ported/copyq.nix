{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.copyq;
in {
  options.programs.copyq = {
    enable = lib.mkEnableOption "CopyQ - Advanced clipboard manager";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [pkgs.copyq];

    # Start CopyQ as a systemd user service - run as daemon directly
    systemd.user.services.copyq = {
      Unit = {
        Description = "CopyQ Clipboard Manager";
        # Keep the running CopyQ daemon alive across `home-manager switch`.
        # ExecStart embeds copyq's store path, which churns on rebuild -> HM
        # would restart the unit every switch, wiping clipboard history.
        # keep-old leaves the live instance untouched (same pattern as
        # vesktop-autostart).
        X-SwitchMethod = "keep-old";
        # Start after graphical session
        After = ["graphical-session.target"];
      };
      Service = {
        Type = "simple";
        # Only run under niri. Nexus boots its console into the Steam
        # gamescope session (SDDM defaultSession = "steam"); there CopyQ has
        # no desktop clipboard surface and SIGABRTs into a Restart=on-failure
        # loop (447 restarts observed). ExecCondition exits non-zero outside
        # niri, which SKIPS (not fails) the unit, so Restart does not loop —
        # CopyQ just stays out of the gamescope console and auto-starts under
        # niri (zephyr/sentry, or nexus's alternate session).
        ExecCondition = "${import ./niri-session-guard.nix pkgs}";
        # Run copyq directly - it will fork to background as daemon
        ExecStart = "${lib.getExe pkgs.copyq}";
        # Restart on failure
        Restart = "on-failure";
        RestartSec = 5;
        # Environment for X11 (Wayland causes SIGABRT crash loop in gamescope console)
        Environment = "QT_QPA_PLATFORM=xcb";
      };
      Install = {
        WantedBy = ["graphical-session.target"];
      };
    };
  };
}
