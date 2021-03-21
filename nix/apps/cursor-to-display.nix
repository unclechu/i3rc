# Author: Viacheslav Lotsmanov
# License: MIT https://raw.githubusercontent.com/unclechu/i3rc/master/LICENSE-MIT
let sources = import ../sources.nix; in
{ pkgs ? import sources.nixpkgs {}
, src  ? ../../apps/cursor-to-display.pl
}:
let
  utils = import ../utils.nix { inherit pkgs; };
  inherit (utils) esc writeCheckedExecutable nameOfModuleFile isDerivationLike;
in
assert isDerivationLike src || builtins.isString src;
let
  name = nameOfModuleFile (builtins.unsafeGetAttrPos "a" { a = 0; }).file;
  perl = "${pkgs.perl}/bin/perl";

  checkPhase = ''
    ${utils.shellCheckers.fileIsExecutable perl}
    ${utils.shellCheckers.fileIsExecutable "${pkgs.xlibs.xrandr}/bin/xrandr"}
    ${utils.shellCheckers.fileIsExecutable "${pkgs.xdotool}/bin/xdotool"}
  '';
in
writeCheckedExecutable name checkPhase ''
  #! ${perl}
  use v5.10; use strict; use warnings;
  $ENV{PATH} = q<${pkgs.xlibs.xrandr}/bin:>.$ENV{PATH};
  $ENV{PATH} = q<${pkgs.xdotool}/bin:>.$ENV{PATH};
  ${if isDerivationLike src then builtins.readFile src else src}
''
