{lib, ...}: {
  # programs.ssh writes ~/.ssh/config as a store symlink chain owned by
  # nobody (multi-user nix daemon). OpenSSH rejects the config on ownership
  # ("Bad owner or permissions") and a GC'd intermediate store path breaks
  # the chain entirely, taking ssh-from-this-host down until manually
  # flattened. Flatten the file into a real user-owned 0600 copy on every
  # activation so the symlink can never wedge ssh again.
  #
  # Moved here from modules/standalone.nix (2026-08-16): standalone.nix is
  # called as a plain function, so its top-level home.activation blocks never
  # see home-manager's extended lib (no lib.hm.dag). As a real module in the
  # leafModules set, lib.hm.dag resolves correctly.
  home.activation.flattenSshConfig = lib.hm.dag.entryAfter ["writeBoundary"] ''
    if [ -e "$HOME/.ssh/config" ] || [ -L "$HOME/.ssh/config" ]; then
      # Resolve through any store symlink chain first (readlink -f), then
      # replace the (possibly symlinked) path with a real owned file.
      SRC="$(readlink -f "$HOME/.ssh/config" 2>/dev/null || echo "$HOME/.ssh/config")"
      if [ "$SRC" != "$HOME/.ssh/config" ] || [ -L "$HOME/.ssh/config" ]; then
        cp --remove-destination "$SRC" "$HOME/.ssh/config"
      fi
      chmod 600 "$HOME/.ssh/config"
      chown "$(id -u):$(id -g)" "$HOME/.ssh/config" 2>/dev/null || true
    fi
  '';
}
