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
    { __nix-utils = nix-utils; } //
    (if builtins.hasAttr "__configFile" args then { inherit __configFile; } else {}) //
    (if builtins.hasAttr "autostartScript" args then { inherit autostartScript; } else {}) //
    (if builtins.hasAttr "scriptsPaths" args then { inherit scriptsPaths; } else {})
  );

  dash = "${pkgs.dash}/bin/dash";

  show-i3-config = writeCheckedExecutable "show-i3-config" ''
    ${shellCheckers.fileIsExecutable dash}
  '' ''
    #! ${dash}
    cat -- ${esc (i3-config.services.xserver.windowManager.i3.configFile)}
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
