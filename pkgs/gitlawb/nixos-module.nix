{ config, lib, pkgs, inputs, ... }:

let
  cfg = config.programs.gitlawb;
  inherit (lib) mkEnableOption mkIf mkOption mkMerge types;
  gitlawbPkgs = inputs.gitlawb.packages.${pkgs.stdenv.system};
in {
  options.programs.gitlawb = {
    enable = mkEnableOption "gitlawb CLI + git remote helper";

    package = mkOption {
      type = types.package;
      default = gitlawbPkgs.default;
      defaultText = lib.literalExpression "inputs.gitlawb.packages.\${pkgs.stdenv.system}.default";
      description = ''
        gitlawb binary package. Provides `gl`, `git-remote-gitlawb`,
        and `gitlawb-node` from a single prebuilt release tarball.
      '';
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/gitlawb";
      description = ''
        Directory where gitlawb stores identity keys and node data.
        Created automatically with mode 0700 owned by the gitlawb user
        when the node service is enabled.
      '';
    };

    user = mkOption {
      type = types.str;
      default = "gitlawb";
      description = "User account under which gitlawb operates.";
    };

    group = mkOption {
      type = types.str;
      default = "gitlawb";
      description = "Primary group for the gitlawb user.";
    };

    gitRemote = {
      did = mkOption {
        type = types.str;
        default = "did:key:z6MkroUt2u1koQcx6fLmvRnyayoeuHrvzQWShqshTP5Pe5e5";
        description = "DID root used for the gitlawb remote URL.";
      };

      repo = mkOption {
        type = types.str;
        default = "nixos";
        description = "Repository path under the DID root.";
      };

      extraRemotes = mkOption {
        type = types.attrsOf types.str;
        default = {};
        example = {
          backup = "gitlawb://did:key:z6Mk.../nixos-mirror";
          fork = "gitlawb://did:key:z6Mk.../nixos-fork";
        };
        description = ''
          Additional gitlawb remotes as a name→url attrset.
          Each entry becomes a `remote "<name>"` section in the
          system gitconfig.
        '';
      };
    };

    extraConfig = mkOption {
      type = types.attrsOf types.anything;
      default = {};
      description = ''
        Extra git config entries to merge into `programs.git.config`
        alongside the gitlawb remote. Uses the same format as
        `programs.git.config`.
      '';
    };
  };

  config = mkMerge [
    (mkIf cfg.enable {
      # -----------------------------------------------------------------
      # User / group
      # -----------------------------------------------------------------
      # NOTE (2026-08-18, ported here 2026-09-20 during the Path B repoint):
      # plain declarations, no `mkIf (!config.users.users ? ...)` guard — that
      # guard is infinite recursion (the presence check evaluates the very
      # option set this definition is a member of). The module system merges
      # multiple definitions natively; declaring plainly is the correct idiom.
      users.users.${cfg.user} = {
        description = "Gitlawb service user";
        home = cfg.dataDir;
        group = cfg.group;
        isSystemUser = true;
        createHome = false;
      };

      users.groups.${cfg.group} = {};

      # -----------------------------------------------------------------
      # Packages
      # -----------------------------------------------------------------
      environment.systemPackages = [ cfg.package ];

      # Ensure git-lawb helper is discoverable by git
      environment.variables.GIT_LAWB_HELPER = "${cfg.package}/bin/git-remote-gitlawb";

      # -----------------------------------------------------------------
      # Git config: remote wiring
      # -----------------------------------------------------------------
      programs.git = {
        enable = true;
        config = mkMerge [
          {
            "remote \"gitlawb\"".url =
              "gitlawb://${cfg.gitRemote.did}/${cfg.gitRemote.repo}";
          }
          (lib.mapAttrs' (name: url:
            lib.nameValuePair "remote \"${name}\"" { inherit url; }
          ) cfg.gitRemote.extraRemotes)
          cfg.extraConfig
        ];
      };
    })
  ];

  meta.maintainers = with lib.maintainers; [ ];
}
