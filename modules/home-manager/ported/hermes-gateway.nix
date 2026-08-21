# Hermes Agent Gateway — declarative user unit
#
# NOTE (issue #334): hermes is installed via the user nix profile
#   `nix profile install github:NousResearch/hermes-agent`
# so the store path of hermes-agent-env changes on EVERY profile upgrade.
# The previous unit (a plain file at ~/.config/systemd/user/hermes-gateway.service)
# hardcoded a store path and silently went stale — after the 0.18.2 → 0.19.1
# upgrade the unit pinned the old env which lacks hermes_state_common.py,
# and the TUI-spawned gateway crashed with `ModuleNotFoundError` until the
# stale processes were killed.
#
# Fix: exec through %h/.nix-profile, which systemd resolves to
# /home/<user>/.nix-profile — a symlink to the CURRENT profile generation.
# The unit therefore always runs the up-to-date env and self-heals across
# `nix profile upgrade` with zero maintenance. The messaging gateway
# (`hermes_cli.main gateway run`) is declared here (the TUI launches its own
# gateway child from its own interpreter); this module ALSO ships the
# HERMES_TUI_DIR fish conf.d export below (the split-profile install's raw
# bin/hermes lacks the upstream wrapper's TUI wiring).
{
  config,
  lib,
  hostName,
  pkgs,
  ...
}: let
  cfg = config.programs.hermes-gateway;
  # Self-healing entry point: %h/.nix-profile/bin/hermes is a symlink to the
  # current profile generation, so it tracks `nix profile upgrade` with zero
  # maintenance (the old %h/.nix-profile/bin/python no longer ships in the
  # split-package install — only bin/hermes does).
  hermesBin = "%h/.nix-profile/bin/hermes";

  # PROPER voice support (replaces the old hand-written ~/.local/bin/hermes
  # wrapper + manual GC-root symlink to a nix-built sounddevice).
  #
  # hermesVoice is a real Nix derivation: a shell script that execs the profile's
  # bin/hermes with PYTHONPATH set to nixpkgs' python312Packages.sounddevice.
  # That derivation PATCHES sounddevice's compiled extension to hardcode the
  # portaudio store path at build time (same mechanism nixpkgs uses), so NO
  # LD_LIBRARY_PATH is needed and portaudio resolves from the nix store directly.
  #
  # We use writeShellScriptBin (not makeWrapper) because the hermes binary lives
  # at $HOME/.nix-profile/bin/hermes, which does NOT exist on the remote build
  # host — makeWrapper validates the target at build time and would refuse. A
  # plain script resolves the path at RUNTIME ($HOME), so it works on zephyr.
  #
  # Because hermesVoice is installed via home.packages, sounddevice becomes part
  # of the HM profile closure -> it is GC-safe (never collected) and reproducible.
  # The TUI wrapper (~/.local/bin/hermes) and the gateway unit both use this
  # derivation for voice dependencies; only the gateway unit enables voice
  # behavior explicitly.
  hermesVoice = pkgs.writeShellScriptBin "hermes-voice" ''
    export PYTHONPATH="${pkgs.python312Packages.sounddevice}/lib/python3.12/site-packages"
    # Voice is enabled explicitly by the persistent gateway unit below. The
    # interactive/ephemeral TUI stays quiet by default and can opt in through
    # its own supported voice controls without inheriting gateway audio.
    exec "$HOME/.nix-profile/bin/hermes" "$@"
  '';
in {
  options.programs.hermes-gateway.enable = lib.mkOption {
    type = lib.types.bool;
    default = hostName == "zephyr" || hostName == "sentry" || hostName == "nexus" || hostName == "forge";
    description = ''
      Whether to run the Hermes messaging gateway as a user systemd service.
      Defaults to true on zephyr (the coordination hub), sentry (the
      site-agency pipeline host, which needs a permanent gateway + A2A
      endpoint for cross-agent coordination), nexus (builder, A2A mesh node)
      and forge (mining, A2A mesh node); other hosts run hermes via
      the TUI on demand.
    '';
  };

  config = lib.mkIf cfg.enable {
    # Voice-enabled Hermes: a real Nix derivation (hermesVoice, defined in `let`)
    # that wraps the profile's bin/hermes with nixpkgs' portaudio-patched
    # sounddevice on PYTHONPATH. Installing it via home.packages puts sounddevice
    # in the HM profile closure -> GC-safe and reproducible (no manual GC-root).
    home.packages = [ hermesVoice ];

    # TUI entry point: ~/.local/bin/hermes is generated (not hand-written) as the
    # quiet hermesVoice wrapper. It still includes the voice dependency path for
    # explicit on-demand voice controls, but does not inherit gateway TTS by
    # default. HM owns this file -> self-healing across `home-manager switch`.
    home.file.".local/bin/hermes".source = "${hermesVoice}/bin/hermes-voice";

    # Hermes owns most of config.yaml imperatively, but this audio setting is
    # deliberately declarative: the upstream thinking-sound loop opens a
    # short-lived 16 kHz PortAudio output stream roughly every second, which
    # perturbs Bluetooth A2DP playback. Merge only this key so user-managed
    # providers, channels, MCP servers, and voice settings remain untouched.
    home.activation.hermesDisableThinkingSound = lib.hm.dag.entryAfter ["writeBoundary"] ''
      config="$HOME/.hermes/config.yaml"
      if [ ! -f "$config" ]; then
        echo "home-manager: Hermes config.yaml not present; skipping thinking-sound setting"
      elif [ -L "$config" ]; then
        echo "home-manager: Hermes config.yaml is a symlink; skipping thinking-sound setting"
      else
        voice_type=$(${pkgs.yq-go}/bin/yq -r '.voice | type' "$config" 2>/dev/null || echo "unknown")
        case "$voice_type" in
          '!!map'|'!!null')
            current=$(${pkgs.yq-go}/bin/yq -r '.voice.thinking_sound' "$config" 2>/dev/null || echo "null")
            if [ "$current" != "false" ]; then
              if tmp=$(mktemp "$config.tmp.XXXXXX"); then
                trap 'rm -f "$tmp"' EXIT
                if ${pkgs.yq-go}/bin/yq '.voice.thinking_sound = false' "$config" > "$tmp" \
                  && chmod --reference="$config" "$tmp" \
                  && mv -f "$tmp" "$config"; then
                  trap - EXIT
                  echo "home-manager: disabled Hermes thinking sound"
                else
                  rm -f "$tmp"
                  trap - EXIT
                  echo "home-manager: could not update Hermes config.yaml; leaving it unchanged" >&2
                fi
              else
                echo "home-manager: could not create Hermes config temporary file; leaving it unchanged" >&2
              fi
            fi
            ;;
          *)
            echo "home-manager: Hermes voice section is not a mapping; skipping thinking-sound setting" >&2
            ;;
        esac
      fi
    '';

    # The profile installs the wrapped hermes-agent `default` package which

    systemd.user.services.hermes-gateway = {
      Unit = {
        Description = "Hermes Agent Gateway - Messaging Platform Integration";
        After = ["network-online.target"];
        Wants = ["network-online.target"];
        StartLimitIntervalSec = 0;
      };

      Service = {
        Type = "simple";
        # Use the HM-managed wrapper (~/.local/bin/hermes). It self-heals across
        # `home-manager switch` and provides the voice dependency path; the
        # gateway's explicit Environment entries below enable gateway voice.
        ExecStart = "%h/.local/bin/hermes gateway run";
        WorkingDirectory = "%h/.hermes";
        Environment = [
          "PATH=%h/.nix-profile/bin:/etc/profiles/per-user/j_kro/bin:%h/.local/bin:%h/.npm-global/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
          "VIRTUAL_ENV=%h/.nix-profile"
          "HERMES_HOME=%h/.hermes"
          # Voice mode + TTS are intentionally enabled for the persistent
          # gateway only. The interactive wrapper does not inherit these flags.
          "HERMES_VOICE=1"
          "HERMES_VOICE_TTS=1"
        ];
        Restart = "always";
        RestartSec = 5;
        RestartForceExitStatus = 75;
        KillMode = "mixed";
        KillSignal = "SIGTERM";
        ExecReload = "/bin/kill -USR1 $MAINPID";
        TimeoutStopSec = 90;
        StandardOutput = "journal";
        StandardError = "journal";
        # Vault passphrase for the hermes vault feature. Previously injected via
        # an unmanaged plain-file drop-in (vault.conf); folded in so HM owns the
        # whole unit. The `-` prefix tolerates a missing file.
        EnvironmentFile = "-%h/.hermes/hermes-vault-passphrase";
      };

      Install.WantedBy = ["default.target"];
    };
  };
}
