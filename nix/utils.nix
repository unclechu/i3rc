# Author: Viacheslav Lotsmanov
# License: MIT https://raw.githubusercontent.com/unclechu/i3rc/master/LICENSE-MIT
let sources = import ./sources.nix; in
{ pkgs ? import sources.nixpkgs {}
}:
let utils = import sources.nix-utils { inherit pkgs; }; in
utils // {
  isDerivationLike = x:
    let f = x: builtins.isPath x || pkgs.lib.isDerivation x; in f x || (
      builtins.isAttrs x &&
      builtins.hasAttr "outPath" x &&
      (builtins.isString x.outPath || f x.outPath)
    );
}
