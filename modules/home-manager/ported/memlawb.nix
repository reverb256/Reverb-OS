# Memlawb — encrypted, self-hosted Hermes memory backend (Layer 2 / home-manager)
#
# Makes the native Hermes memlawb MemoryProvider work without hand-set env:
# the provider reads MEMLAWB_URL / MEMLAWB_NAMESPACE / MEMLAWB_CLI from
# os.environ (no config.yaml path), defaulting to localhost:8080 if unset.
# Emit them via environment.d so the desktop session AND the hermes TUI /
# gateway user-units inherit them.
#
# The passphrase is deliberately NOT here — the provider falls back to the
# 0600 file ~/.memlawb-passphrase.txt (secretspec-managed). Keeping it out of
# environment.d avoids exposing it in every process's environ.
#
# The provider plugin itself is symlinked into ~/.hermes/plugins/
# (install step lives in the memlawb-for-hermes repo + hermes plugins enable).
{
  config,
  pkgs,
  lib,
  ...
}: {
  # environment.d drop-in (systemd user session + desktop-launched Hermes).
  xdg.configFile."environment.d/50-memlawb.conf".text = ''
    MEMLAWB_URL=http://10.1.1.140:8080
    MEMLAWB_NAMESPACE=user:j_kro
    MEMLAWB_CLI=${config.home.homeDirectory}/.local/bin/memlawb
  '';
}
