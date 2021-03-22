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
, injectDependencies ? []
, injectScriptPre ? ""
, __srcScript ? ../../apps/pamng.sh
, injectScriptPost ? ""
, injectCheckPhase ? ""
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
    ${injectCheckPhase}
  '';

  script = writeCheckedExecutable name checkPhase ''
    #! ${bash-exe}
    ${injectScriptPre}
    ${
      if isDerivationLike __srcScript
      then builtins.readFile __srcScript
      else __srcScript
    }
    ${injectScriptPost}
  '';
in
wrapExecutable "${script}/bin/${name}" {
  deps =
    let localDependencies = builtins.attrValues dependencies; in
    assert builtins.isList localDependencies;
    assert builtins.isList injectDependencies;
    assert builtins.all isDerivationLike localDependencies;
    assert builtins.all isDerivationLike injectDependencies;
    localDependencies ++ injectDependencies;
}
