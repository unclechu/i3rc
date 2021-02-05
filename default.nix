#
# This module is supposed to be added to the imports of ‘configuration.nix’.
#
# For instance (in ‘configuration.nix’):
#   { pkgs, ... }:
#   {
#     imports = [
#       (import (pkgs.fetchFromGitHub {
#         owner  = "unclechu";
#         repo   = "i3rc";
#         rev    = "0000000000000000000000000000000000000000";
#         sha256 = "0000000000000000000000000000000000000000000000000000";
#       }) { inherit pkgs; })
#     ];
#   }
#
let sources = import nix/sources.nix; in
{ pkgs ? import sources.nixpkgs {}

, configFile ? ./config

, # A script that runs each time i3 just starts
  # or restarts within the same session.
  autostartScript ? null

, # Script names to replace with custom paths to them
  # (for instance with paths to somewhere in Nix store).
  # This is an attribute set where the attribute name is the name of a script
  # and attribute value is the new path to that script.
  # See the asserts below for available script names for overriding.
  scriptsPaths ? {}
}:
let isFilePath = path: builtins.isString path || builtins.isPath path; in

# May potentially give you infinite recursion.
# assert isFilePath configFile;

# Gives infinite recursion. Depends on value. Let’s keep it lazy.
# assert ! isNull autostartScript -> isFilePath autostartScript;

assert builtins.isAttrs scriptsPaths;

# Available scripts to override paths of.
assert let
  scripts = [
    "autostart.sh"
    "input.sh"
    "cursor-to-display.pl"
    "gpaste-gui.pl"
    "pamng.sh"
    "screen-backlight.sh"
  ];
in builtins.all (x: builtins.elem x scripts) (builtins.attrNames scriptsPaths);

# Gives infinite recursion. Depends on value. Let’s keep it lazy.
# assert builtins.all isFilePath (builtins.attrValues scriptsPaths);

let
  patchArgs =
    builtins.foldl'
      (acc: from: {
        from = acc.from ++ [ from                 ];
        to   = acc.to   ++ [ scriptsPaths.${from} ];
      })
      { from = []; to = []; }
      (builtins.attrNames scriptsPaths);

  patchFn = builtins.replaceStrings patchArgs.from patchArgs.to;

  config = pkgs.writeText "wenzels-i3-config-file" ''
    ${patchFn (builtins.readFile configFile)}
    ${if isNull autostartScript then "" else "exec_always ${autostartScript}"}
  '';
in
{
  services.xserver.windowManager.i3 = {
    enable     = true;
    configFile = config;
  };
}
