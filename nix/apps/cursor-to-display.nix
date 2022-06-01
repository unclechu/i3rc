# Author: Viacheslav Lotsmanov
# License: MIT https://raw.githubusercontent.com/unclechu/i3rc/master/LICENSE-MIT

# This module is intended to be called with ‘nixpkgs.callPackage’
let sources = import ../sources.nix; in
{ callPackage
, perl
, xorg # Just for ‘xrandr’
, xdotool

# Overridable dependencies
, __utils ? callPackage ../utils.nix {}

# Build options
, __srcScript ? ../../apps/cursor-to-display.pl
}:
let
  inherit (__utils)
    esc writeCheckedExecutable nameOfModuleFile shellCheckers isDerivationLike;
in
assert isDerivationLike __srcScript || builtins.isString __srcScript;
let
  name = nameOfModuleFile (builtins.unsafeGetAttrPos "a" { a = 0; }).file;
  perl-exe = "${perl}/bin/perl";

  dependencies = {
    xrandr = xorg.xrandr;
    xdotool = xdotool;
  };

  checkPhase = ''
    ${shellCheckers.fileIsExecutable perl-exe}
    ${
      builtins.concatStringsSep "\n" (
        map
          (k: shellCheckers.fileIsExecutable "${dependencies.${k}}/bin/${k}")
          (builtins.attrNames dependencies)
      )
    }
  '';
in
writeCheckedExecutable name checkPhase ''
  #! ${perl-exe}
  use v5.10; use strict; use warnings;
  ${
    builtins.concatStringsSep "\n" (
      map
        (v: "$ENV{PATH} = q<${v}/bin:>.$ENV{PATH};")
        (builtins.attrValues dependencies)
    )
  }
  ${
    if isDerivationLike __srcScript
    then builtins.readFile __srcScript
    else __srcScript
  }
''
