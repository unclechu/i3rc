# Author: Viacheslav Lotsmanov
# License: MIT https://raw.githubusercontent.com/unclechu/i3rc/master/LICENSE-MIT

# This module is intended to be called with ‘nixpkgs.callPackage’
let sources = import ../sources.nix; in
{ callPackage
, bash
, pulseaudio
, gnugrep
, gnused
, gawk
, findutils

# Overridable dependencies
, __utils ? callPackage ../utils.nix {}

# Build options
, __srcScript ? ../../apps/pamng.sh
}:
let
  inherit (__utils)
    esc nameOfModuleFile shellCheckers isDerivationLike
    writeCheckedExecutable wrapExecutable;
in
assert isDerivationLike __srcScript || builtins.isString __srcScript;
let
  name = nameOfModuleFile (builtins.unsafeGetAttrPos "a" { a = 0; }).file;
  bash-exe = "${bash}/bin/bash";

  # Name is executable name and value is a derivation
  dependencies = {
    pactl = pulseaudio;
    grep = gnugrep;
    sed = gnused;
    awk = gawk;
    xargs = findutils;
  };

  checkPhase = ''
    ${shellCheckers.fileIsExecutable bash-exe}
    ${
      builtins.concatStringsSep "\n" (
        map
          (k: shellCheckers.fileIsExecutable "${dependencies.${k}}/bin/${k}")
          (builtins.attrNames dependencies)
      )
    }
  '';

  script = writeCheckedExecutable name checkPhase ''
    #! ${bash-exe}
    ${
      if isDerivationLike __srcScript
      then builtins.readFile __srcScript
      else __srcScript
    }
  '';
in
wrapExecutable "${script}/bin/${name}" {
  deps = builtins.attrValues dependencies;
}
