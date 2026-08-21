# Hermes Agent — user-level HM module (Omarchy target).
#
# Authority boundary (omarchy-profile-contract.nix):
#   - home-files:   ~/.hermes directory skeleton (sessions, memories, skills,
#                   cron, logs, profiles) — Omarchy does not manage Hermes,
#                   so this is HM-legit additive state.
#   - session vars: HERMES_HOME exported for user shells.
#
# Defers to Omarchy/Hermes:
#   - the hermes BINARY comes from the user nix profile
#     (`nix profile install github:NousResearch/hermes-agent`) — NOT managed
#     here, NOT a home.package.
#   - config.yaml, auth, providers, A2A peers: Hermes owns its runtime config
#     (tokens never belong in the Nix store). This module does NOT emit
#     config.yaml sections — Hermes itself is the authority for its own
#     runtime state.
#   - shell completions / shell integration: Omarchy owns the shell; the
#     user's shell profile sources `hermes completion` as needed.
{
  config,
  lib,
  ...
}: let
  cfg = config.programs.hermes;
in {
  options.programs.hermes = {
    enable = lib.mkEnableOption "Hermes Agent user state (skeleton dirs + HERMES_HOME)";

    hermesHome = lib.mkOption {
      type = lib.types.path;
      default = "~/.hermes";
      description = "Hermes state directory (HERMES_HOME).";
    };

    profileNames = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "analyst"
        "researcher"
        "infra"
        "software-factory"
        "site-agency"
      ];
      description = "Hermes profile directories to create under HERMES_HOME/profiles.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.sessionVariables = {
      HERMES_HOME = cfg.hermesHome;
    };

    # Directory skeleton — additive, non-conflicting with Omarchy or Hermes.
    home.file = lib.mkMerge [
      (lib.mkIf (cfg.hermesHome != null) {
        ".hermes/sessions" = {d = {};};
        ".hermes/memories" = {d = {};};
        ".hermes/skills" = {d = {};};
        ".hermes/cron" = {d = {};};
        ".hermes/logs" = {d = {};};
      })
      (lib.listToAttrs (map (p: {
          name = ".hermes/profiles/${p}";
          value = {d = {};};
        })
        cfg.profileNames))
    ];
  };
}
