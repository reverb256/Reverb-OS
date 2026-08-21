# AppImage self-updating launchers — HYBRID design (2026-08-15).
# Ported to Reverb-OS 2026-08-21 from home-manager-config (legacy NixOS).
#
# Problem: Nix-wrapped AppImage packages (appimageTools.wrapType2) pin a
# version+hash at build time. Upstream releases a new AppImage weekly; the
# cluster falls stale. The apps' own in-app updaters cannot work on a
# Nix-wrapped install. The wrap step is REQUIRED, not optional.
#
# Hybrid mechanism:
#   - Nix-wrapped baseline packages (Layer 1 systemPackages) stay as the
#     always-works fallback.
#   - A provisioner (systemd user timer) resolves the LATEST version from the
#     app's real update source (GitHub releases API / download redirect), and
#     if newer than the installed copy, downloads the raw AppImage and re-wraps
#     it locally (nix build -E with the downloaded file as src — no hash pin
#     needed, builds on nexus, ~1 min). Result is GC-rooted under
#     ~/.local/opt/<app>/current.
#   - Launcher wrappers prefer the ~/.local/opt copy; fall back to the system
#     binary. This is the "fetch latest at launch" path from the research.
#
# Omarchy/Arch notes (vs legacy NixOS):
#   - pkgs.steam-run does not exist on Arch; the stability-matrix launchCmd
#     uses it only on NixOS. On Arch, run the wrapped AppImage directly.
#   - /run/opengl-driver and /run/current-system/sw are NixOS paths; on Arch
#     the system libs are at /usr/lib and the launcher should rely on the
#     wrap's extraPkgs + FHS sandbox. The launchEnv is harmless if the paths
#     don't exist (export of a missing path is a no-op).
{
  config,
  lib,
  pkgs,
  hostName,
  ...
}: let
  cfg = config.programs.appimage-updater;
  types = lib.types;

  # Registry of apps the provisioner manages. Each entry:
  #   pname          binary name of the wrapped result (bin/<pname>)
  #   stateName      directory name under ~/.local/opt
  #   versionSource  "redirect" (follow URL, parse filename) | "github" (releases/latest)
  #   feedUrl        redirect URL or GitHub repo
  #   assetPattern   GitHub asset name regex (github source) or filename regex (redirect)
  #   archive        "zip" if the download is a zip containing the AppImage
  #   archiveFile    name of the AppImage inside the zip
  #   baseline       optional system binary to fall back to (resolved on PATH)
  #   wrapPkgs       extraPkgs passed to wrapType2, as nixpkgs ATTR PATHS
  #   launchArgs     extra args appended at launch
  #   launchEnv      env exported before launch (overlay for the local copy)
  #   launchCmd      full launch command for the LOCAL copy
  #   fallbackCmd    full fallback command when the local copy is missing
  #   desktop        desktop-entry definition (name/comment/icon/categories)
  apps = {
    freebuff-desktop = {
      pname = "freebuff-desktop";
      stateName = "freebuff-desktop";
      versionSource = "redirect";
      feedUrl = "https://freebuff.com/api/desktop/download/linux";
      # The API 302-redirects to Freebuff-<version>-linux-x86_64.AppImage on
      # GitHub releases (CodebuffAI/codebuff-community).
      assetPattern = "Freebuff-([0-9]+\\.[0-9]+\\.[0-9]+)-";
      wrapPkgs = [
        "bash"
        "glib"
        "nss"
        "nspr"
        "libGL"
        "fontconfig"
        "freetype"
        "alsa-lib"
        "cups"
        "dbus"
        "expat"
        "xorg.libX11"
        "xorg.libXcomposite"
        "xorg.libXdamage"
        "xorg.libXext"
        "xorg.libXfixes"
        "xorg.libXrandr"
        "xorg.libxcb"
        "xorg.libxkbfile"
        "xorg.libXScrnSaver"
        "xorg.libXi"
        "xorg.libXtst"
        "libxshmfence"
        "libxkbcommon"
        "libgbm"
        "pango"
        "cairo"
        "gtk3"
        "systemd"
        "udev"
        "stdenv.cc.cc.lib"
        "mesa"
        "libdrm"
        "vulkan-loader"
      ];
      # XWayland (--ozone-platform=x11), matching Vesktop's proven pattern.
      # The bwrap-sandboxed Electron GPU process cannot PRIME-import NVKMS
      # memory to the NVIDIA Wayland compositor on kernel 6.12+ (nixpkgs#382612).
      launchArgs = "--no-sandbox --disable-gpu-sandbox --ozone-platform=x11";
      launchEnv = ''
        export ELECTRON_OZONE_PLATFORM_HINT=x11
        export VK_ICD_FILENAMES="/run/opengl-driver/share/vulkan/icd.d/nvidia_icd.json"
        export __EGL_VENDOR_LIBRARY_FILENAMES="/run/opengl-driver/share/glvnd/egl_vendor.d/10_nvidia.json"
        export LIBGL_DRIVERS_PATH="/run/opengl-driver/lib/dri:/run/current-system/sw/lib/dri"
        export LD_LIBRARY_PATH="/run/current-system/sw/lib:/run/opengl-driver/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
      '';
      fallbackCmd = ''
        echo "[freebuff-desktop] local copy missing — running appimage-updater" >&2
        systemctl --user start appimage-updater 2>/dev/null || true
        if [ -x "$LOCAL/bin/freebuff-desktop" ]; then
          exec "$LOCAL/bin/freebuff-desktop" --no-sandbox --disable-gpu-sandbox --ozone-platform=x11 "$@"
        fi
        echo "[freebuff-desktop] ERROR: no runnable copy; run: systemctl --user start appimage-updater" >&2
        exit 1
      '';
      desktop = {
        name = "Freebuff";
        genericName = "Coding Agent Orchestrator";
        comment = "Freebuff Desktop — GitHub-native coding-agent orchestrator";
        icon = "freebuff";
        categories = ["Development" "Utility"];
        startupWMClass = "Freebuff";
      };
    };

    stability-matrix = {
      pname = "stability-matrix";
      stateName = "stability-matrix";
      versionSource = "github";
      feedUrl = "LykosAI/StabilityMatrix";
      assetPattern = "StabilityMatrix-linux-x64\\.zip";
      archive = "zip";
      archiveFile = "StabilityMatrix.AppImage";
      baseline = "stability-matrix";
      wrapPkgs = [
        "icu"
        "libxcrypt"
        "libxcrypt-legacy"
        "libayatana-appindicator"
      ];
      launchArgs = "";
      # Omarchy/Arch: no pkgs.steam-run — run the wrapped AppImage directly
      # with the CUDA env (the wrap's extraPkgs carry the FHS deps).
      launchCmd = ''
        exec "$LOCAL/bin/stability-matrix" "$@"
      '';
      launchEnv = ''
        export __GLX_VENDOR_LIBRARY_NAME=nvidia
        export __VK_LAYER_NV_optimus=NVIDIA_only
        export CUDA_PATH=/run/opengl-driver
        export CUDA_HOME=/run/opengl-driver
        export LD_LIBRARY_PATH=/run/opengl-driver/lib:''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
        export SETUPTOOLS_USE_DISTUTILS=stdlib
        export UV_EXCLUDE_NEWER="2099-01-01T00:00:00Z"
        export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
        export STABILITY_MATRIX_DATA="$HOME/.stabilitymatrix"
      '';
      desktop = {
        name = "Stability Matrix";
        genericName = "Stable Diffusion Package Manager";
        comment = "Multi-Platform Package Manager for Stable Diffusion";
        icon = "stability-matrix";
        categories = ["Graphics" "2DGraphics" "RasterGraphics" "Art"];
        settings.Keywords = "stable diffusion;ai;image generation;art;";
        startupWMClass = "StabilityMatrix";
      };
    };

    # LM Studio: NO public latest-version feed exists (verified 2026-08-15).
    # It stays Nix-pinned: bump the package manually. Not registered in the
    # provisioner.
  };

  # Wrap expression template. Placeholders are substituted by sed at runtime
  # (bash quoting of a nix expression is a trap — keep the template literal).
  wrapExprTemplate = name: app:
          pkgs.writeText "wrap-${name}.nix" ''
            let pkgs = import ${pkgs.path} {};
            in pkgs.appimageTools.wrapType2 {
              pname = "${name}";
              version = "__VERSION__";
              src = __APPFILE__;
              extraPkgs = pkgs: [${lib.concatMapStringsSep " " (p: "pkgs.${p}") app.wrapPkgs}];
              extraBwrapArgs = [
                "--ro-bind-try /etc/egl/egl_external_platform.d /etc/egl/egl_external_platform.d"
                "--ro-bind-try /dev/dri /dev/dri"
              ];
            }
          '';

  # Per-app check function body. Runs inside `for app in ...` so `continue`
  # stays valid. Expects $NAME (app key) and $APP (registry attr) set.
  mkAppCheck = name: app: let
    exprFile = wrapExprTemplate name app;
  in ''
    echo "── $NAME ──"
    STATE="$HOME/.local/opt/${app.stateName}"
    mkdir -p "$STATE"
    INSTALLED="$(cat "$STATE/VERSION" 2>/dev/null || echo none)"

    # Resolve latest version + download URL.
    case "${app.versionSource}" in
      redirect)
        LOC=$(curl -fsSL --max-time 60 -o /dev/null -w '%{url_effective}' -I "${app.feedUrl}" 2>/dev/null || curl -fsSL --max-time 60 -o /dev/null -w '%{url_effective}' "${app.feedUrl}" 2>/dev/null)
        VERSION=$(printf '%s' "$LOC" | grep -oE "${app.assetPattern}" | head -1 | sed -E "s/${app.assetPattern}/\1/")
        URL="${app.feedUrl}"
        ;;
      github)
        API=$(curl -fsSL --max-time 60 "https://api.github.com/repos/${app.feedUrl}/releases/latest" 2>/dev/null)
        VERSION=$(printf '%s' "$API" | jq -r '.tag_name' | sed 's/^v//')
        URL=$(printf '%s' "$API" | jq -r --arg pat "${app.assetPattern}" '.assets[] | select(.name | test($pat)) | .browser_download_url' | head -1)
        ;;
      *) VERSION=""; URL="" ;;
    esac

    if [ -z "$VERSION" ]; then
      echo "  ⚠ could not resolve latest version"
      continue
    fi
    if [ "$INSTALLED" = "$VERSION" ]; then
      echo "  ✓ up to date ($VERSION)"
      continue
    fi

    echo "  ↑ $NAME: $INSTALLED → $VERSION"
    DL="$STATE/${name}-$VERSION.AppImage"
    if [ ! -f "$DL" ]; then
      echo "  ↓ downloading"
      curl -fsSL --max-time 600 -L -o "$DL" "$URL" || {
        echo "  ✗ download failed"
        continue
      }
    fi

    APPFILE="$DL"
    ${lib.optionalString (app ? archive) ''
      ZIP="$DL"
      APPFILE="$STATE/${name}-$VERSION.AppImage.raw"
      unzip -o -p "$ZIP" "${app.archiveFile}" > "$APPFILE" || {
        echo "  ✗ unzip failed"
        continue
      }
    ''}

    echo "  🔨 wrapping via nix (src = $APPFILE)"
    EXPR=$(sed -e "s|__VERSION__|$VERSION|g" -e "s|__APPFILE__|$APPFILE|g" "${exprFile}")
    OUT=$(nix build --impure --no-link --print-out-paths --expr "$EXPR" 2>&1 | tail -1)
    if ! echo "$OUT" | grep -q '/nix/store/'; then
      echo "  ✗ wrap failed: $OUT"
      continue
    fi
    ln -sfn "$OUT" "$STATE/current"
    nix-store --add-root "$STATE/current-root" -r "$OUT" >/dev/null 2>&1 || true
    echo "$VERSION" > "$STATE/VERSION"
    echo "  ✓ installed $VERSION → $STATE/current"
  '';
in {
  options.programs.appimage-updater = {
    enable = lib.mkOption {
      type = types.bool;
      default = hostName == "zephyr";
      description = "Enable AppImage self-updating launchers (hybrid: Nix baseline + ~/.local/opt latest copies). Defaults to true only on zephyr (the desktop host).";
    };
    stateDir = lib.mkOption {
      type = types.str;
      default = "~/.local/opt";
      description = "Directory holding per-app wrapped copies (GC-rooted under <stateDir>/<app>/current).";
    };
    schedule = lib.mkOption {
      type = types.str;
      default = "Mon *-*-* 04:15:00";
      description = "systemd timer OnCalendar expression for the weekly update check.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.mapAttrsToList (name: app:
      pkgs.writeShellScriptBin "${name}-latest" ''
        set -u
        STATE="''${HOME}/.local/opt/${app.stateName}"
        LOCAL="$STATE/current"
        mkdir -p "$STATE"
        exec >"$STATE/launcher.log" 2>&1
        if [ -x "$LOCAL/bin/${app.pname}" ]; then
          ${app.launchEnv or ""}
          ${
          if app ? launchCmd
          then app.launchCmd
          else "exec \"$LOCAL/bin/${app.pname}\" ${app.launchArgs} \"$@\""
        }
        fi
        ${
        if app ? fallbackCmd
        then app.fallbackCmd
        else "exec ${app.baseline} ${app.launchArgs} \"$@\""
      }
      '')
    apps;

    xdg.enable = true;
    xdg.desktopEntries = lib.mkMerge (lib.mapAttrsToList (name: app:
      lib.optionalAttrs (app ? desktop) {
        ${name} = let
          d = app.desktop;
          wmClass = lib.optionalAttrs (d ? startupWMClass) {StartupWMClass = d.startupWMClass;};
        in {
          inherit (d) name genericName comment icon categories;
          settings = (d.settings or {}) // wmClass;
          exec = "${name}-latest %U";
          terminal = false;
          startupNotify = true;
        };
      })
    apps);

    # ── Provisioner: resolve latest → download → wrap → GC-root → swap ──
    systemd.user.services.appimage-updater = let
      checks = lib.mapAttrs (name: app: mkAppCheck name app) apps;
      updateScript = pkgs.writeShellScript "appimage-updater" ''
        set -u
        echo "=== appimage-updater: checking for updates ==="
        for NAME in ${toString (builtins.attrNames apps)}; do
          case "$NAME" in
            ${lib.concatMapStringsSep "\n" (name: "${name}) ${checks.${name}} ;;") (builtins.attrNames apps)}
          esac
        done
        echo "=== done ==="
      '';
    in {
      Unit.Description = "Fetch and wrap latest AppImage versions into ~/.local/opt";
      Service = {
        Type = "oneshot";
        TimeoutStartSec = "1800";
        Environment = ["PATH=${lib.makeBinPath (with pkgs; [nix curl jq unzip coreutils gnugrep gnused gawk gnutar])}"];
        ExecStart = "${updateScript}";
      };
    };

    systemd.user.timers.appimage-updater = {
      Unit.Description = "Weekly AppImage update check";
      Timer = {
        OnCalendar = cfg.schedule;
        Persistent = true;
        RandomizedDelaySec = "30min";
      };
      Install.WantedBy = ["timers.target"];
    };
  };
}
