{
  runCommand,
  closureInfo,

  gnutar,
  zstd,
}:

system: lixPackages:
let
  inherit (lixPackages)
    lix
    nix-eval-jobs
    nix-fast-build
    ;
in

# Produces an archive for a Lix version that gets installed on runners with the action. The archive contains a minimal
# Nix store containing just the closure over the Lix derivation and some supporting files to setup the Nix store
# database, and get Lix installed in the global profile.
runCommand "lix-${lix.version}-archive"
  {
    buildInputs = [
      lix
      gnutar
      zstd
    ];

    closureInfo = closureInfo {
      rootPaths = [
        lix
        nix-eval-jobs
        nix-fast-build
      ];
    };
    fileName = "lix-${lix.version}-${system}.tar.zstd";
    inherit (lix) version;
  }
  ''
    mkdir -p "$out" root/nix/var/{nix,lix-quick-install-action}
    ln -s ${lix} root/nix/var/lix-quick-install-action/lix
    ln -s ${nix-eval-jobs} root/nix/var/lix-quick-install-action/nix-eval-jobs
    ln -s ${nix-fast-build} root/nix/var/lix-quick-install-action/nix-fast-build
    cp "$closureInfo/registration" root/nix/var/lix-quick-install-action
    tar -cvT "$closureInfo/store-paths" -C root nix | zstd -o "$out/$fileName"
  ''
