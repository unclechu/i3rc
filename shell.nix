# Author: Viacheslav Lotsmanov
# License: MIT https://raw.githubusercontent.com/unclechu/i3rc/master/LICENSE-MIT
let sources = import nix/sources.nix; in
args@
{ pkgs ? import sources.nixpkgs {}

# ↓ Forwarded arguments ↓

, nix-utils ? pkgs.callPackage sources.nix-utils {} # Just ‘sources.nix-utils’
, utils ? pkgs.callPackage nix/utils.nix { __nix-utils = nix-utils; } # See ‘nix/utils.nix’

# Forwarded for ‘invert-window-colors-nim’ only
, __nim-dbus-src ? null

# Forwarded for ‘default.nix’ only

, __configFile ? null

, # A script that runs each time i3 just starts
  # or restarts within the same session.
  autostartScript ? null

, # Script names to replace with custom paths to them
  # (for instance with paths to somewhere in Nix store).
  # This is an attribute set where the attribute name is the name of a script
  # and attribute value is the new path to that script.
  # See the asserts below for available script names for overriding.
  scriptsPaths ? null

, terminalDark  ? null # Optional path to an executable of terminal emulator (dark  color scheme)
, terminalLight ? null # Optional path to an executable of terminal emulator (light color scheme)

# ↓ Local options ↓
, with-i3-config ? true
, with-cursor-to-display ? false
, with-invert-window-colors-nim ? false
, with-pamng ? false
}:
let
  inherit (utils) esc writeCheckedExecutable shellCheckers;
  appArgs = if builtins.hasAttr "utils" args then { __utils = utils; } else {};

  i3-config = pkgs.callPackage ./. (
    { __nix-utils = nix-utils; }
    // (if builtins.hasAttr "__configFile" args then { inherit __configFile; } else {})
    // (if builtins.hasAttr "autostartScript" args then { inherit autostartScript; } else {})
    // (if builtins.hasAttr "scriptsPaths" args then { inherit scriptsPaths; } else {})
    // (if builtins.hasAttr "terminalDark" args then { inherit terminalDark; } else {})
    // (if builtins.hasAttr "terminalLight" args then { inherit terminalLight; } else {})
  );

  dash = "${pkgs.dash}/bin/dash";

  show-i3-config =
    let name = "show-i3-config"; in
    writeCheckedExecutable name ''
      ${shellCheckers.fileIsExecutable dash}
    '' ''
      #! ${dash}
      set -eu
      if [ $# -eq 0 ]; then
        cat -- ${esc i3-config}
      elif [ $# -eq 1 ] && [ $1 = file ]; then
        printf '%s\n' ${esc i3-config}
      else
        >&2 echo 'Incorrect arguments'
        >&2 printf 'Usage: %s [file]\n' ${esc name}
        exit 1
      fi
    '';

  cursor-to-display = pkgs.callPackage nix/apps/cursor-to-display.nix { __utils = utils; };
  pamng = pkgs.callPackage nix/apps/pamng.nix { __utils = utils; };

  invert-window-colors-nim = pkgs.callPackage nix/apps/invert-window-colors-nim.nix (
    { __nix-utils = nix-utils; } //
    (if builtins.hasAttr "__nim-dbus-src" args then { inherit __nim-dbus-src; } else {})
  );
in
pkgs.mkShell {
  buildInputs =
    (if with-i3-config then [ show-i3-config ] else []) ++
    (if with-cursor-to-display then [ cursor-to-display ] else []) ++
    (if with-invert-window-colors-nim then [ invert-window-colors-nim ] else []) ++
    (if with-pamng then [ pamng ] else []);
}
