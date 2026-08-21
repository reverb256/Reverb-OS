# gl desktop entry with gitlawb:// scheme handler registration.
#
# Background: Home-Manager's xdg.mimeApps is STRICT — it only writes a
# Default Applications / Added Associations entry when the target .desktop's
# own MimeType= line includes that type (freedesktop "a default must be
# associated" rule). gl has no .desktop file on its own, so without this
# entry the gitlawb:// handler would be silently ignored.
#
# Declaring x-scheme-handler/gitlawb here lets mime-apps.nix legitimately
# route gitlawb:// URIs to `gl %u`.
#
# The binary lives at ~/.local/bin/gl (outside the Nix store), so the exec
# path is resolved through $HOME to keep the entry portable across hosts.
{ config, pkgs, lib, ... }:

{
  xdg.enable = true;

  xdg.desktopEntries.gl = {
    name = "gitlawb";
    genericName = "Decentralized Git";
    comment = "gitlawb CLI — identity, repos, MCP server, and git remote helper";
    exec = "${config.home.homeDirectory}/.local/bin/gl %u";
    terminal = true;
    type = "Application";
    categories = [ "Development" "RevisionControl" ];
    mimeType = [
      "x-scheme-handler/gitlawb"
    ];
  };
}
