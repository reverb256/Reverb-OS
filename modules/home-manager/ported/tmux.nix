{
  pkgs,
  config,
  lib,
  ...
}: let
  # herdr is a direct binary (~/.local/bin/herdr), NOT in nixpkgs.
  herdrBin = "/home/j_kro/.local/bin/herdr";
in {
  programs.tmux = {
    enable = true;
    mouse = true;
    prefix = "C-a";
    baseIndex = 1;
    keyMode = "emacs";
    terminal = "tmux-256color";
    extraConfig = ''
      set -ga terminal-overrides ",*256col*:Tc"
      set -g renumber-windows on
      set -g escape-time 0
      set -g history-limit 50000
    '';
  };

  # herdr — the primary terminal (AGENTS.md). The server is a detached daemon
  # whose socket (~/.config/herdr/herdr.sock) is a filesystem socket, so it
  # survives DE/compositor restarts. Start it at login so panes persist across
  # niri restarts (linger is on, so even logouts keep it).
  systemd.user.services.herdr-server = {
    Unit = {
      Description = "herdr persistent terminal server (survives DE restarts)";
      After = ["graphical-session.target"];
      # Prevent `home-manager switch` from restarting this unit. herdr owns a
      # long-lived session (pane state, running processes); an automatic
      # restart during a switch races the still-alive old server (stale
      # socket) and hits start-limit-hit. Keep the old unit running; only a
      # real crash (Restart=on-failure) restarts it.
      "X-RestartIfChanged" = false;
    };
    Service = {
      Type = "simple";
      Restart = "on-failure";
      # Remove a stale socket before starting so a crashed/orphaned server
      # doesn't block the next start with "already running".
      ExecStartPre = "${pkgs.coreutils}/bin/rm -f %h/.config/herdr/herdr.sock";
      ExecStart = "${herdrBin} server";
    };
    Install = {WantedBy = ["graphical-session.target"];};
  };
}
