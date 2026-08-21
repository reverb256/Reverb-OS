# Portable rclone sync jobs (Home Manager, Omarchy target).
#
# Wraps upstream Home Manager's `programs.rclone` (remotes + secrets +
# generated ~/.config/rclone/rclone.conf) and adds the scheduled sync layer
# that upstream does not provide: one systemd USER service + timer per job.
#
# Authority boundary (omarchy-profile-contract.nix):
#   - user-packages:  home.packages adds rclone
#   - user-services:  systemd.user.* sync jobs + timers
#   - home-files:     nothing root-owned, nothing under /etc, no environment.*
#
# The legacy NixOS services.rclone-sync module (nixos-config
# modules/services/rclone.nix) is NOT the authority for this profile; this
# module supersedes it for the Omarchy/Arch target. The legacy module remains
# only as the NixOS rollback path.
#
# Secrets:
#   Each sync job declares envVars: list of { var, secretPath }. The generated
#   script reads the decrypted secret file at /run/secrets/<name> (or any path
#   that exists at activation) and exports it before invoking rclone. This
#   matches the legacy NixOS module's sopsSecretEnvs semantics and keeps
#   credentials OUT of the world-readable Nix store (upstream's `secrets`
#   option writes them into rclone.conf via `rclone config update` at
#   activation — fine for the remote config itself, but the sync job needs
#   env-style injection for the AWS_* variables used with env_auth).
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.rclone-sync;
  rclone = lib.getExe cfg.package;
  rcloneConf = "${config.xdg.configHome}/rclone/rclone.conf";

  # One writeShellScriptBin per job. The script:
  #   1. exports each declared secret (reads the file, tolerates absence with
  #      a clear error)
  #   2. runs rclone with the declared mode
  #   3. applies --config so the job uses the HM-generated config path
  syncScript = job: let
    secretExports = lib.concatStringsSep "\n" (
      map (s: ''
        if [ -f ${s.secretPath} ]; then
          export ${s.var}="$(cat ${s.secretPath})"
        else
          echo "rclone-sync-${job.name}: missing secret ${s.secretPath}" >&2
          exit 1
        fi
      '') job.envVars
    );

    # Modes that take exactly ONE remote argument (no source->dest pair).
    singleRemoteModes = [
      "ls"
      "lsd"
      "lsl"
      "lsf"
      "md5sum"
      "sha1sum"
      "cat"
      "size"
      "checksum"
    ];

    modeBranch = if (builtins.elem job.mode singleRemoteModes) then ''
      ${rclone} "${job.mode}" "${job.source}" \
        --config "${rcloneConf}" \
        --progress \
        ${lib.concatStringsSep " " (map (o: "--${o}") (job.extraFlags or []))} \
        ${lib.optionalString (job.options != null) job.options}
    '' else ''
      ${rclone} "${job.mode}" "${job.source}" "${job.destination}" \
        --config "${rcloneConf}" \
        --progress \
        --transfers ${toString job.transfers} \
        --checkers ${toString job.checkers} \
        ${lib.optionalString (job.exclude != null) "--exclude=${job.exclude}"} \
        ${lib.optionalString (job.include != null) "--include=${job.include}"} \
        ${lib.concatStringsSep " " (map (o: "--${o}") (job.extraFlags or []))} \
        ${lib.optionalString (job.options != null) job.options}
    '';
  in
    pkgs.writeShellScriptBin "rclone-sync-${job.name}" ''
      set -euo pipefail

      ${secretExports}

      echo "[INFO] rclone job: ${job.name} (mode=${job.mode})"
      ${modeBranch}
    '';
in {
  options.programs.rclone-sync = {
    enable = lib.mkEnableOption "rclone scheduled sync jobs (wraps programs.rclone)";

    package = lib.mkPackageOption pkgs "rclone" {};

    syncJobs = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            description = "Job name (used for unit/timer names)";
          };
          source = lib.mkOption {
            type = lib.types.str;
            description = "Source path (remote: or /local/path)";
          };
          destination = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = "Destination path (remote: or /local/path)";
          };
          mode = lib.mkOption {
            type = lib.types.enum [
              "sync"
              "copy"
              "move"
              "check"
              "ls"
              "lsl"
              "lsd"
              "lsf"
              "md5sum"
              "sha1sum"
              "cat"
              "size"
            ];
            default = "sync";
            description = "Rclone operation mode";
          };
          transfers = lib.mkOption {
            type = lib.types.int;
            default = 4;
            description = "Number of parallel file transfers";
          };
          checkers = lib.mkOption {
            type = lib.types.int;
            default = 8;
            description = "Number of checkers to run in parallel";
          };
          exclude = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Exclude files matching pattern";
          };
          include = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Include files matching pattern";
          };
          options = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Additional options string";
          };
          extraFlags = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            description = "Extra command-line flags (without -- prefix)";
          };
          envVars = lib.mkOption {
            type = lib.types.listOf (lib.types.submodule {
              options = {
                var = lib.mkOption {
                  type = lib.types.str;
                  description = "Environment variable name to export";
                };
                secretPath = lib.mkOption {
                  type = lib.types.str;
                  description = "Absolute path to decrypted secret file";
                };
              };
            });
            default = [];
            description = "Secret files to export as env vars before the rclone run";
          };
          startAt = lib.mkOption {
            type = lib.types.str;
            default = "02:00";
            description = "systemd timer OnCalendar for this job";
          };
          enableTimer = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable the systemd user timer for this job";
          };
        };
      });
      default = [];
      description = "Scheduled rclone sync jobs";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [cfg.package];

    # The sync layer depends on the upstream-generated config (and the
    # upstream rclone-config unit that renders it + injects secrets). Each
    # sync service Requires rclone-config, so the config exists before the
    # job runs whether it was started by hand or by its timer.
    systemd.user.services = lib.listToAttrs (map (job:
      lib.nameValuePair "rclone-sync-${job.name}" {
        Unit = {
          Description = "Rclone sync: ${job.name}";
          After = ["rclone-config.service" "network-online.target"];
          Requires = ["rclone-config.service"];
          Wants = ["network-online.target"];
        };
        Service = {
          Type = "oneshot";
          ExecStart = "${syncScript job}/bin/rclone-sync-${job.name}";
          # Portable PATH for the Omarchy target: HM profile + system
          # binaries. NixOS-only paths are forbidden by the
          # omarchy-profile-contract check.
          Environment = ["PATH=%h/.nix-profile/bin:/etc/profiles/per-user/%u/bin:%h/.local/bin:/usr/local/bin:/usr/bin:/bin"];
          # A dead/misconfigured endpoint can hang rclone forever; fail fast.
          TimeoutStartSec = "300";
        };
        # Only attach the service to timers.target when the timer is enabled;
        # otherwise it remains a manual-only unit.
        Install = lib.mkIf job.enableTimer {WantedBy = ["timers.target"];};
      }) cfg.syncJobs);

    systemd.user.timers = lib.listToAttrs (
      map (job:
        lib.nameValuePair "rclone-sync-${job.name}" (lib.mkIf job.enableTimer {
          Unit = {
            Description = "Rclone sync timer: ${job.name}";
            Wants = ["rclone-config.service"];
            After = ["rclone-config.service"];
          };
          Timer = {
            OnCalendar = job.startAt;
            Persistent = true;
            Unit = "rclone-sync-${job.name}.service";
          };
          Install.WantedBy = ["timers.target"];
        }))
        cfg.syncJobs
    );
  };
}
