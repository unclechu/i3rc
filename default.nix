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
{ pkgs  ? import sources.nixpkgs {}
, utils ? import sources.nix-utils { inherit pkgs; }

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
    "invert-window-colors"
  ];
in builtins.all (x: builtins.elem x scripts) (builtins.attrNames scriptsPaths);

let
  isFilePath = path:
    builtins.isString path ||
    (
      builtins.isPath path &&
      pkgs.lib.pathIsRegularFile path
    );

  pipeline = pkgs.lib.flip (builtins.foldl' (acc: fn: fn acc));

  patchArgs = pipeline [
    (pkgs.lib.mapAttrsToList (from: to:
      assert isFilePath to; { inherit from to; }))
    (pkgs.lib.foldAttrs (x: a: [x] ++ a) [])
  ];

  patchFn =
    let inherit (patchArgs (scriptsPaths // extraScriptsPaths)) from to;
    in  builtins.replaceStrings from to;

  pgrep = "${pkgs.procps}/bin/pgrep";
  extraScriptsPaths = { inherit pgrep; };

  config = pkgs.writeTextFile {
    name = "wenzels-i3-config-file";

    text = ''
      ${assert isFilePath configFile; patchFn (builtins.readFile configFile)}
      ${
        if isNull autostartScript
           then ""
           else assert isFilePath autostartScript;
                "exec_always ${autostartScript}"
      }
    '';

    checkPhase = ''
      set -Eeuo pipefail
      ${utils.shellCheckers.fileIsExecutable pgrep}
    '';
  };
in
{
  services.xserver.windowManager.i3 = {
    enable     = true;
    configFile = config;
  };
}
