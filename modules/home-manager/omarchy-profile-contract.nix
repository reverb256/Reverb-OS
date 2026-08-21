{
  profile = "omarchy";
  owner = "standalone-home-manager";

  # Only user-owned, additive paths may be emitted by the profile.
  managedPathClasses = [
    "home-files"
    "user-packages"
    "user-services"
    "niri-user-configuration"
  ];

  deferredToOmarchy = [
    "base-arch-system"
    "omarchy-packages"
    "omarchy-update"
    "omarchy-migrations"
    "omarchy-snapshots"
    "hyprland"
    "quickshell"
    "omarchy-themes"
    "hardware"
    "boot"
    "networking"
    "display-manager"
  ];

  forbiddenSourcePatterns = [
    "environment.systemPackages"
    "environment.etc"
    "nix.settings"
    "/run/current-system"
    "/usr/share/omarchy"
    "services.displayManager"
    "hardware."
    "boot."
    "networking.firewall"
  ];
}
