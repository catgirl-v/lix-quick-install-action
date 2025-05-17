{
  lib,
  callPackage,
  pkgs,

  editline,
  lixVersions,
  ncurses,
}:

let
  pins = import ../npins;

  inherit (lib) listToAttrs nameValuePair replaceStrings;

  makeStoreArchive = callPackage ./make-store-archive.nix { };

  # Makes a set of Lix packages, where the version is the key and the package is the value.
  #
  # Accepts:
  # - f: A function that accepts a system, and a Lix package scope, that produces the final value assigned to the
  #   version in the set.
  # - lixPackagesListForSystem: A function that accepts a system, and returns a list of Lix package scopes to include in
  #   the set.
  # - system: The system to produce a set for.
  mkLixSet =
    f: lixPackagesListForSystem: system:
    let
      lixPackagesList = lixPackagesListForSystem system;
    in
    listToAttrs (
      map (
        lixPkgs: nameValuePair "v${replaceStrings [ "." ] [ "_" ] lixPkgs.lix.version}" (f system lixPkgs)
      ) lixPackagesList
    );

  # Accepts a system, and returns a list of Lix package scopes that are supported on that system.
  # Currently there's no variation between systems (ie. all systems support all versions), but that may change in the
  # future.
  lixPackagesListForSystem =
    let
      disableLixLtoOnDarwin =
        finalLixPackages: prevLixPackages:
        let
          inherit (pkgs) lib;
        in
        {
          lix = prevLixPackages.lix.overrideAttrs (
            finalAttrs: prevAttrs:
            let
              inherit (lib.lists) filter;
              inherit (lib.strings) hasPrefix mesonBool versionAtLeast;
              isLLVMOnly = versionAtLeast finalAttrs.version "2.92";
              # GCC 13.2 is known to miscompile Lix coroutines (introduced in 2.92).
              lixStdenv = if versionAtLeast finalAttrs.version "2.92" then pkgs.clangStdenv else pkgs.stdenv;
            in
            {
              mesonFlags = map (
                mesonFlag:
                # https://git.lix.systems/lix-project/lix/issues/832
                if hasPrefix "-Db_lto=" mesonFlag then
                  mesonBool "b_lto" (
                    !lixStdenv.hostPlatform.isStatic
                    && !lixStdenv.hostPlatform.isDarwin
                    && (isLLVMOnly || lixStdenv.cc.isGNU)
                  )
                else
                  mesonFlag
              ) prevAttrs.mesonFlags or [ ];
            }
          );
        };
    in
    system:
    [
      (pkgs.lixPackageSets.lix_2_93.overrideScope disableLixLtoOnDarwin)
      (pkgs.lixPackageSets.lix_2_92.overrideScope disableLixLtoOnDarwin)
      pkgs.lixPackageSets.lix_2_91
    ];
in
rec {
  # Accepts a system, and returns an attribute set from supported versions to Lix package derivations.
  lixPackagesFor = mkLixSet (_: lixPackages: lixPackages) lixPackagesListForSystem;
  # Accepts a system, and returns an attribute set from supported versions to Lix derivations.
  lixVersionsFor = mkLixSet (_: lixPackages: lixPackages.lix) lixPackagesListForSystem;
  # Accepts a system, and returns an attribute set from supported versions to a Lix archive for that version.
  lixArchivesFor = mkLixSet makeStoreArchive lixPackagesListForSystem;

  # Accepts a system, and returns a derivation producing a folder containing Lix archives for all Lix versions
  # supported by the given system.
  combinedArchivesFor =
    system:
    pkgs.symlinkJoin {
      name = "lix-archives";
      paths = builtins.attrValues (lixArchivesFor system);
    };
}
