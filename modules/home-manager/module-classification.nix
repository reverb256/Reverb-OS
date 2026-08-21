{
  # Modules that must remain out of the Omarchy profile because Omarchy owns
  # the corresponding desktop capability or provides its supported mechanism.
  deferToOmarchy = [
    "alacritty.nix"
    "btop.nix"
    "desktop-utilities.nix"
    "dolphin.nix"
    "firefox-pwa-apps.nix"
    # hermes-skin.nix (2026-08-21): stylix-dependent → Omarchy owns theming.
    # A future Omarchy-theme → Hermes-skin bridge can restore it.
    "hermes-skin.nix"
    "icon-theme.nix"
    "mime-apps.nix"
    "mime-fix.nix"
    "noctalia-stylix.nix"
    "starship.nix"
    "stylix-bridges.nix"
    "zsh.nix"
  ];

  # User-scoped capabilities that may be migrated after an individual review.
  # They are deliberately not imported by the first generic profile until
  # their package/config ownership and Omarchy interaction are verified.
  portableAdditive = [
    "appimage-updater.nix"
    "caprine.nix"
    "copyq.nix"
    "editorconfig.nix"
    "freebuff-desktop.nix"
    "git.nix"
    "gl-desktop-entry.nix"
    "helix-desktop-entry.nix"
    "hermes-gateway.nix"
    # hermes-skin.nix moved to deferToOmarchy 2026-08-21: it generates the
    # Hermes skin from stylix colors; stylix is deferred to Omarchy theming.
    "home-manager-launcher.nix"
    "lazygit.nix"
    "memlawb.nix"
    "nixcord-config.nix"
    "opencode.nix"
    "ssh-flatten.nix"
    "tmux.nix"
    "tui-apps.nix"
    "vesktop.nix"
    "zen-browser.nix"
  ];

  # Niri is additive, but these existing modules carry host-specific or
  # compositor/runtime assumptions. The generic profile uses its own portable
  # composition instead of importing them wholesale.
  niriModules = [
    "niri-config.nix"
    "niri-keybinds.nix"
    "niri-outputs.nix"
    "niri-session-guard.nix"
    "niri-spawn.nix"
  ];

  # These modules are retained for legacy host profiles and require explicit
  # host/system prerequisites; they must never enter standalone Omarchy HM.
  hostOrSystemOnly = [
    "chatterbox-tts.nix"
    "fbt-cameras.nix"
    "fleet-deck.nix"
    "llama-swap.nix"
    "pin-poe2-launchopts.py"
    "standalone-forge.nix"
    "standalone-nexus.nix"
    "standalone-sentry.nix"
    "standalone-zephyr.nix"
    "zephyr-gaming-hdr.nix"
    "zephyr-gpu-workloads.nix"
  ];

  # The first profile only admits the new generic HM identity and Niri module.
  # Every future addition must be classified before it is added here.
  profileModules = {
    omarchy = [
      "omarchy.nix"
      "niri-omarchy.nix"
      "rclone.nix"
      # Ported portableAdditive modules (2026-08-21)
      "ported/caprine.nix"
      "ported/copyq.nix"
      "ported/editorconfig.nix"
      "ported/freebuff-desktop.nix"
      "ported/git.nix"
      "ported/gl-desktop-entry.nix"
      "ported/helix-desktop-entry.nix"
      "ported/hermes-gateway.nix"
      "ported/lazygit.nix"
      "ported/memlawb.nix"
      "ported/nixcord-config.nix"
      "ported/opencode.nix"
      "ported/ssh-flatten.nix"
      "ported/tmux.nix"
      "ported/tui-apps.nix"
      "ported/vesktop.nix"
      "ported/zen-browser.nix"
    ];
  };
  profileOwnedModules = [
    "omarchy.nix"
    "niri-omarchy.nix"
    "rclone.nix"
  ];

  # Snapshot of the legacy module names used by the migration check. This
  # prevents a new source module from disappearing from the review matrix.
  legacyModuleFiles = [
    "alacritty.nix"
    "appimage-updater.nix"
    "btop.nix"
    "caprine.nix"
    "chatterbox-tts.nix"
    "copyq.nix"
    "desktop-utilities.nix"
    "dolphin.nix"
    "editorconfig.nix"
    "fbt-cameras.nix"
    "firefox-pwa-apps.nix"
    "fleet-deck.nix"
    "freebuff-desktop.nix"
    "git.nix"
    "gl-desktop-entry.nix"
    "helix-desktop-entry.nix"
    "hermes-gateway.nix"
    "hermes-skin.nix"
    "home-manager-launcher.nix"
    "icon-theme.nix"
    "lazygit.nix"
    "llama-swap.nix"
    "memlawb.nix"
    "mime-apps.nix"
    "mime-fix.nix"
    "niri-config.nix"
    "niri-keybinds.nix"
    "niri-outputs.nix"
    "niri-session-guard.nix"
    "niri-spawn.nix"
    "nixcord-config.nix"
    "noctalia-stylix.nix"
    "opencode.nix"
    "pin-poe2-launchopts.py"
    "ssh-flatten.nix"
    "starship.nix"
    "standalone-forge.nix"
    "standalone-nexus.nix"
    "standalone-sentry.nix"
    "standalone-zephyr.nix"
    "stylix-bridges.nix"
    "tmux.nix"
    "tui-apps.nix"
    "vesktop.nix"
    "zen-browser.nix"
    "zephyr-gaming-hdr.nix"
    "zephyr-gpu-workloads.nix"
    "zsh.nix"
  ];
}
