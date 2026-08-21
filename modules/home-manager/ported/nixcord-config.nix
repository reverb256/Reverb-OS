{
  pkgs,
  config,
  lib,
  ...
}: {
  options.nixcord-config.enable = lib.mkEnableOption "Nixcord Vesktop configuration";

  config = lib.mkIf config.nixcord-config.enable {
    programs.nixcord = {
      enable = true;
      discord.enable = false;
      vesktop = {
        enable = true;
        package = pkgs.vesktop;
        # Declarative seed for Vesktop settings. nixcord hardcodes the
        # generated settings.json as a READ-ONLY symlink into /nix/store
        # (modules/lib/files.nix: mkSettingsSpecs forces writable=false and
        # no per-client option can flip it). Vesktop rewrites settings.json
        # on every UI change, so the ro symlink caused EROFS crashes (and a
        # downstream EPIPE main-process error when launched via uwsm, which
        # pipes stderr to a socket that closes). The home.activation entry
        # below materializes a real writable copy seeded from nixcord's
        # template after each switch, so the in-app Settings UI can mutate it
        # freely. These values are only the *initial* seed; edit in-app.
        settings = {
          tray = true;
          minimizeToTray = true;
          # Spellcheck needs hunspell dicts in the env; verify before enabling.
          # enableSpellcheck = true;
          # spellcheckLanguage = "en-US";
          # Optional branded tray icon (Quill/MapleSpike mark).
          # trayIcon = "/home/j_kro/.local/share/icons/quill-vesktop.png";
        };
      };

      config = {
        useQuickCss = true;
        plugins = {
          # Existing plugins
          xsOverlay = {
            enable = true;
            dmNotifications = true;
            groupDmNotifications = true;
            serverNotifications = true;
            callNotifications = true;
            channelPingColor = "#8a2be2";
            pingColor = "#7289da";
            timeout = 3;
            volume = 0.2;
            opacity = 1.0;
          };
          fakeNitro = {
            enable = true;
            enableEmojiBypass = true;
            enableStickerBypass = true;
            enableStreamQualityBypass = true;
            emojiSize = 48.0;
          };
          usrbg = {
            enable = true;
            nitroFirst = true;
            voiceBackground = true;
          };
          reviewDb = {
            enable = true;
          };

          # Quality of life
          voiceMessages = {
            enable = true;
          };
          pictureInPicture = {
            enable = true;
          };
          callTimer = {
            enable = true;
          };
          silentTyping = {
            enable = true;
          };
          notificationVolume = {
            enable = true;
            notificationVolume = 0.5;
          };
          readAllNotificationsButton = {
            enable = true;
          };

          # Privacy / security
          clearUrls = {
            enable = true;
          };
          consoleJanitor = {
            enable = true;
          };
          noDevtoolsWarning = {
            enable = true;
          };
          crashHandler = {
            enable = true;
          };

          # Media / embeds
          fixYoutubeEmbeds = {
            enable = true;
          };
          fixSpotifyEmbeds = {
            enable = true;
          };
          dearrow = {
            enable = true;
          };
          shikiCodeblocks = {
            enable = true;
          };
          imageZoom = {
            enable = true;
            size = 500.0;
            zoom = 1.0;
          };

          # UI improvements
          betterFolders = {
            enable = true;
          };
          memberCount = {
            enable = true;
          };
          roleColorEverywhere = {
            enable = true;
          };
          showTimeoutDuration = {
            enable = true;
          };
          serverListIndicators = {
            enable = true;
          };
          messageLinkEmbeds = {
            enable = true;
          };
          replyTimestamp = {
            enable = true;
          };

          # Game / streaming
          streamerModeOnStream = {
            enable = true;
          };
          gameActivityToggle = {
            enable = true;
          };
        };
      };
    };

    # niri-aware xdg-desktop-portal config so Vesktop (and any app) can
    # capture the screen. The stock config requests gtk;gnome portals, which
    # provide no wlroots screen-capture backend on niri -> "share screen"
    # silently fails. Prefer the wlr portal (binary already in the store).
    xdg.configFile."xdg-desktop-portal/portals.conf".text = ''
      [preferred]
      default=wlr;gtk;gnome
    '';

    # 2026-08-14: vesktop autostart moved to niri spawn-at-startup (niri-spawn.nix).
    # The systemd unit had a race condition: ExecCondition evaluated before niri
    # was ready at boot, causing the unit to be skipped every time. Niri's
    # spawn-at-startup spawns children AFTER the compositor is fully initialized.
    # 2026-08-15: the NVIDIA env vars + --ozone-platform=x11 + focus-or-restart
    # logic now live in ONE place — modules/vesktop.nix (vesktop-uwsm-wrapper),
    # shared via _module.args with niri-spawn.nix, niri-keybinds.nix, and the
    # xdg.desktopEntries.vesktop override below. All four launchers use it.

    # HM's checkFilesChanged/checkLinkTargets abort the switch after the first
    # activation: vesktopWritableSettings converts the settings.json store
    # symlink into a real writable file, and on the next switch HM sees that
    # plain file as "would be clobbered". force=true makes HM overwrite it
    # instead of aborting. nixcord maps the settings file to a homeMain config
    # (home.file, not xdg.configFile), so override force there.
    home.file."${config.home.homeDirectory}/.config/vesktop/settings.json".force = true;
    # nixcord also emits this legacy nested path; force it during migration so
    # stale .backup files cannot abort future standalone HM switches.
    home.file."${config.home.homeDirectory}/.config/vesktop/settings/settings.json".force = true;
    # Vencord theme: stylix links a symlink that our activation converts to a
    # stable file (see vesktopWritableSettings below). Stylix itself sets
    # force=false on this path, so use mkForce true or HM aborts on the next
    # switch when it sees the plain file where a symlink is expected.
    home.file."${config.home.homeDirectory}/.config/Vencord/themes/stylix.theme.css".force = lib.mkForce true;

    # Materialize a writable Vesktop settings.json. nixcord links
    # ~/.config/vesktop/settings/settings.json into /nix/store (read-only);
    # Vesktop rewrites it on every UI change, so the ro symlink caused EROFS
    # crashes (and a downstream EPIPE when launched via uwsm's stderr pipe).
    # This resolves the nixcord symlink to its store seed and replaces the
    # symlink with a real writable file seeded from it. Idempotent: if the
    # target is already a regular file (user-mutated), it is left untouched.
    #
    # nixcord's vesktop.settings option does NOT serialize tray/minimizeToTray
    # into the generated seed (verified: every store seed lacks the "tray" key),
    # so Vesktop launches with its tray disabled and never publishes a
    # StatusNotifierItem -> Noctalia's Tray widget has nothing to show/click.
    # Merge those keys here so the tray icon actually appears and is usable.
    home.activation.vesktopWritableSettings = lib.hm.dag.entryAfter ["linkGeneration"] ''
      # Nixcord has emitted both layouts across versions; normalize either
      # path after HM links the generation so Vesktop can always write it.
      for dest in \
        "$HOME/.config/vesktop/settings.json" \
        "$HOME/.config/vesktop/settings/settings.json"; do
        if [ -L "$dest" ]; then
          seed="$(${lib.getExe' pkgs.coreutils "readlink"} -f "$dest")"
          rm -f "$dest"
          ${lib.getExe' pkgs.coreutils "install"} -Dm644 "$seed" "$dest"
        fi
        # Preserve user settings while ensuring the tray is usable.
        if [ -f "$dest" ]; then
          ${lib.getExe pkgs.jq} '. + {tray: true, minimizeToTray: true, clickTrayToShowHide: true}' "$dest" \
            > "$dest.tmp" && mv "$dest.tmp" "$dest"
        fi
      done

      # Vencord theme stability (2026-08-12): stylix symlinks
      # ~/.config/Vencord/themes/stylix.theme.css into a NEW nix store path on
      # every HM switch. Vencord's main process fs.watch-es that dir with a
      # 50ms debounce and calls webContents.postMessage("VencordThemeUpdate").
      # If the window is closed/minimized when the switch re-links the theme,
      # the timer fires against a disposed frame -> Electron uncaught
      # exception dialog ("Render frame was disposed before WebFrameMain
      # could be accessed"). Copy the theme into a STABLE file instead so the
      # watcher sees no change across switches. Follow the real file (not the
      # symlink) so a live user edit is preserved.
      theme_src="$HOME/.config/Vencord/themes/stylix.theme.css"
      if [ -L "$theme_src" ]; then
        real="$(${lib.getExe' pkgs.coreutils "readlink"} -f "$theme_src")"
        rm -f "$theme_src"
        ${lib.getExe' pkgs.coreutils "install"} -Dm644 "$real" "$theme_src"
      fi
    '';
  };
}
