{ pkgs }:
let
  lib = pkgs.lib;
  classification = import ../modules/home-manager/module-classification.nix;
  sourceFiles = [
    ../modules/home-manager/omarchy.nix
    ../modules/home-manager/niri-omarchy.nix
  ];
  forbidden = [
    "environment.systemPackages"
    "environment.etc"
    "nix.settings"
    "/run/current-system"
    "/usr/share/omarchy"
    "services.displayManager"
    "networking.firewall"
  ];
  sourceViolations = lib.concatMap
    (sourceFile: map
      (pattern: {
        file = toString sourceFile;
        inherit pattern;
      })
      (lib.filter
        (pattern: lib.hasInfix pattern (builtins.readFile sourceFile))
        forbidden))
    sourceFiles;

  classes = [
    classification.deferToOmarchy
    classification.portableAdditive
    classification.niriModules
    classification.hostOrSystemOnly
  ];
  classified = lib.concatLists classes;
  duplicateClassifications = lib.filter
    (name: lib.length (lib.filter (candidate: candidate == name) classified) > 1)
    (lib.unique classified);
  unclassifiedLegacyModules = lib.subtractLists
    classification.legacyModuleFiles
    classified;
  staleClassificationEntries = lib.subtractLists
    classified
    classification.legacyModuleFiles;
  profileModules = classification.profileModules.omarchy;
  profileOutsideAllowlist = lib.subtractLists
    profileModules
    classification.profileOwnedModules;

  failures =
    (map
      (violation: "${violation.file}: forbidden pattern ${violation.pattern}")
      sourceViolations)
    ++ (map
      (name: "legacy module has no ownership classification: ${name}")
      unclassifiedLegacyModules)
    ++ (map
      (name: "classification names no longer present in legacy source: ${name}")
      staleClassificationEntries)
    ++ (map
      (name: "duplicate ownership classification: ${name}")
      duplicateClassifications)
    ++ (map
      (name: "profile module is not in the approved profile allowlist: ${name}")
      profileOutsideAllowlist);
in {
  passed = failures == [];
  inherit failures;
}
