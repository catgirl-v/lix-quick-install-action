let
  pkgs = import (import ./nix/sources.nix).nixpkgs { };
in

pkgs.hello
