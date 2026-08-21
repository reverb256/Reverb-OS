{pkgs, ...}: let
  launcher = pkgs.writeShellScript "home-manager-dynamic" ''
    #!/bin/sh
    set -eu

    # This script is installed ahead of the system command in ~/.local/bin.
    # Never resolve `home-manager` through PATH or the wrapper would recurse.
    # Home Manager is a per-user activation tool. If the user typed
    # `sudo home-manager ...`, drop back to the invoking user before reading
    # HOME or resolving the flake; otherwise root incorrectly falls through
    # to the GitHub fallback because /root has no local HM checkout.
    if [ "$(id -u)" -eq 0 ] && [ -n "''${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
      exec /run/wrappers/bin/sudo -u "$SUDO_USER" -H "$0" "$@"
    fi
    if [ "$(id -u)" -eq 0 ]; then
      echo "home-manager: do not run as root; run as the user whose home is managed" >&2
      exit 1
    fi

    user=$(id -un)
    real_home_manager=""
    # Reverb-OS (Omarchy/Arch): HM comes from the user nix profile
    # (nix profile install ...home-manager) or a NixOS system profile.
    for candidate in \
      "$HOME/.nix-profile/bin/home-manager" \
      "/nix/var/nix/profiles/default/bin/home-manager" \
      /run/current-system/sw/bin/home-manager; do
      if [ -x "$candidate" ] && [ "$candidate" != "$HOME/.local/bin/home-manager" ]; then
        real_home_manager="$candidate"
        break
      fi
    done
    if [ -z "$real_home_manager" ]; then
      echo "home-manager: no usable Home Manager binary found" >&2
      exit 127
    fi

    # Preserve informational commands exactly; they do not need a flake.
    for arg in "$@"; do
      case "$arg" in
        --help|-h|--version|generations)
          exec "$real_home_manager" "$@"
          ;;
      esac
    done

    # A bare invocation means the normal operation: switch the current host.
    if [ "$#" -eq 0 ]; then
      set -- switch
    fi

    # Never override an explicitly selected flake, including short -f.
    for arg in "$@"; do
      case "$arg" in
        -f|--flake|--flake=*)
          exec "$real_home_manager" "$@"
          ;;
      esac
    done

    flake_source=$(printenv HM_CONFIG_FLAKE 2>/dev/null || true)
    if [ -z "$flake_source" ] && [ -d "$HOME/Projects/Reverb-OS" ]; then
      flake_source="$HOME/Projects/Reverb-OS"
    fi
    if [ -z "$flake_source" ]; then
      flake_source="github:reverb256/Reverb-OS"
    fi

    host=$(hostname -s)
    target=""

    # Enumerate target names without evaluating a target configuration.
    targets=$(nix eval --raw "$flake_source#homeConfigurations" \
      --apply 'x: builtins.concatStringsSep "\n" (builtins.attrNames x)') || {
      echo "home-manager: could not read homeConfigurations from $flake_source" >&2
      exit 2
    }

    # Host names are canonical. User-name targets remain supported for wrapper
    # flakes that expose one, such as j_kro -> zephyr.
    for candidate in "$host" "$user"; do
      if [ -z "$candidate" ]; then
        continue
      fi
      case "$candidate" in
        *[!A-Za-z0-9_-]*) continue ;;
      esac
      if printf '%s\n' "$targets" | grep -Fqx "$candidate"; then
        target="$candidate"
        break
      fi
    done

    if [ -z "$target" ]; then
      echo "home-manager: no homeConfigurations target for host '$host' or user '$user'" >&2
      echo "home-manager: set HM_CONFIG_FLAKE or pass --flake explicitly" >&2
      exit 2
    fi

    exec "$real_home_manager" --flake "$flake_source#$target" "$@"
  '';
in {
  home.file.".local/bin/home-manager" = {
    source = launcher;
    executable = true;
  };
}
