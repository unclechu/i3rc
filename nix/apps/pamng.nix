# Author: Viacheslav Lotsmanov
# License: MIT https://raw.githubusercontent.com/unclechu/i3rc/master/LICENSE-MIT
let sources = import ../sources.nix; in
{ pkgs ? import sources.nixpkgs {}
, src  ? ../../apps/pamng.sh
}:
let
  utils = import ../utils.nix { inherit pkgs; };
  inherit (utils) esc writeCheckedExecutable nameOfModuleFile isDerivationLike;
in
assert isDerivationLike src || builtins.isString src;
let
  name = nameOfModuleFile (builtins.unsafeGetAttrPos "a" { a = 0; }).file;
  bash = "${pkgs.bash}/bin/bash";

  checkPhase = ''
    ${utils.shellCheckers.fileIsExecutable bash}
    ${utils.shellCheckers.fileIsExecutable "${pkgs.pulseaudio}/bin/pactl"}
    ${utils.shellCheckers.fileIsExecutable "${pkgs.gnugrep}/bin/grep"}
    ${utils.shellCheckers.fileIsExecutable "${pkgs.gnused}/bin/sed"}
    ${utils.shellCheckers.fileIsExecutable "${pkgs.gawk}/bin/awk"}
    ${utils.shellCheckers.fileIsExecutable "${pkgs.findutils}/bin/xargs"}
  '';
in
writeCheckedExecutable name checkPhase ''
  #! ${bash}
  set -eu

  export PATH=${esc pkgs.pulseaudio}/bin:$PATH
  export PATH=${esc pkgs.gnugrep}/bin:$PATH
  export PATH=${esc pkgs.gnused}/bin:$PATH
  export PATH=${esc pkgs.gawk}/bin:$PATH
  export PATH=${esc pkgs.findutils}/bin:$PATH

  ${if isDerivationLike src then builtins.readFile src else src}
''
