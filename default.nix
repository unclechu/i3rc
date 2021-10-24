# Author: Viacheslav Lotsmanov
# License: MIT https://raw.githubusercontent.com/unclechu/i3rc/master/LICENSE-MIT
#
# This module is intended to be called with ‘nixpkgs.callPackage’.
# This module provides just a i3 config file derivation.
#
# Here is how you use it in your NixOS ‘configuration.nix’ (minimal example):
#
#   { pkgs, ... }:
#   let
#     i3-config = pkgs.callPackage (pkgs.fetchFromGitHub {
#       owner  = "unclechu";
#       repo   = "i3rc";
#       rev    = "0000000000000000000000000000000000000000";
#       sha256 = "0000000000000000000000000000000000000000000000000000";
#     }) {};
#   in
#   {
#     services.xserver.windowManager.i3 = {
#       enable     = true;
#       configFile = i3-config;
#     };
#   }
#
# These dependencies are left up to you to provide or not in your PATH:
#   - place-cursor-at
#   - gnome-screenshot
#   - gnome-calculator
#   - audacious
#
let sources = import nix/sources.nix; in
{ callPackage
, lib
, writeTextFile
, jq
, procps
, xdotool

# Overridable dependencies
, __nix-utils ? callPackage sources.nix-utils {}

# ↓ Build options ↓

, __configFile ? ./config

, # A script that runs each time i3 just starts
  # or restarts within the same session.
  autostartScript ? null

, # Script names to replace with custom paths to them
  # (for instance with paths to somewhere in Nix store).
  # This is an attribute set where the attribute name is the name of a script
  # and attribute value is the new path to that script.
  # See the asserts below for available script names for overriding.
  scriptsPaths ? {}

, terminalDark  ? null # Optional path to an executable of terminal emulator (dark  color scheme)
, terminalLight ? null # Optional path to an executable of terminal emulator (light color scheme)
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
  inherit (__nix-utils) shellCheckers mapStringAsLines;

  isFilePath = path:
    builtins.isString path ||
    (builtins.isPath path && lib.pathIsRegularFile path);

  replacePathsToExecutables = lib.flip lib.pipe [
    (lib.mapAttrsToList (from: to: assert isFilePath to; { inherit from to; }))
    (lib.foldAttrs (x: a: [x] ++ a) [])
    ({ from, to }: builtins.replaceStrings from to)
  ];

  replaceTerminal =
    assert ! isNull terminalDark  -> isFilePath terminalDark;
    assert ! isNull terminalLight -> isFilePath terminalLight;
    lib.flip mapStringAsLines (map (line:
      let
        darkMatch  = builtins.match "^(set \\$terminal_dark ).*$"  line;
        lightMatch = builtins.match "^(set \\$terminal_light ).*$" line;
      in

      if terminalDark != null && darkMatch != null
      then "${builtins.elemAt darkMatch 0}\"${lib.escape ["\""] terminalDark}\""
      else

      if terminalLight != null && lightMatch != null
      then "${builtins.elemAt lightMatch 0}\"${lib.escape ["\""] terminalLight}\""
      else

      line
    ));

  patchConfig = lib.flip lib.pipe [
    (replacePathsToExecutables (dependencies // scriptsPaths))
    replaceTerminal
  ];

  dependencies = {
    jq = "${jq}/bin/jq";
    pgrep = "${procps}/bin/pgrep";
    xdotool = "${xdotool}/bin/xdotool";
  };
in
writeTextFile {
  name = "wenzels-i3-config-file";

  text = ''
    ${
      assert isFilePath __configFile;
      patchConfig (builtins.readFile __configFile)
    }
    ${
      if isNull autostartScript
         then ""
         else assert isFilePath autostartScript;
              "exec_always ${autostartScript}"
    }
  '';

  checkPhase = ''
    set -Eeuo pipefail || exit
    ${
      lib.pipe
        (builtins.attrValues dependencies)
        [
          (map shellCheckers.fileIsExecutable)
          (builtins.concatStringsSep "\n")
        ]
    }
  '';
}
