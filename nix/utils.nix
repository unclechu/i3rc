# Author: Viacheslav Lotsmanov
# License: MIT https://raw.githubusercontent.com/unclechu/i3rc/master/LICENSE-MIT

# This module is intended to be called with ‘nixpkgs.callPackage’
let sources = import ./sources.nix; in
{ callPackage
, lib

# Overridable dependencies
, __nix-utils ? callPackage sources.nix-utils {}
}:
__nix-utils // {
  isDerivationLike = x:
    let f = x: builtins.isPath x || lib.isDerivation x; in f x || (
      builtins.isAttrs x &&
      builtins.hasAttr "outPath" x &&
      (builtins.isString x.outPath || f x.outPath)
    );
}
