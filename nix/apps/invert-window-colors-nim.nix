# Author: Viacheslav Lotsmanov
# License: MIT https://raw.githubusercontent.com/unclechu/i3rc/master/LICENSE-MIT

# This module is intended to be called with ‘nixpkgs.callPackage’
let sources = import ../sources.nix; in
{ callPackage
, lib
, nix-gitignore
, stdenv
, nim
, dbus
, pcre
, xdotool
, xlibs # Just for ‘xwininfo’

# Overridable dependencies
, __nix-utils ? callPackage sources.nix-utils {}
, nim-dbus-src ? sources.nim-dbus

# Build options
, __src ?
    let
      filter = fileName: fileType:
        lib.cleanSourceFilter fileName fileType && (
          fileType == "directory" ||
          ! isNull (builtins.match "^.*/license[.]txt$" fileName) ||
          ! isNull (builtins.match "^.*/[^/]+[.]nim$" fileName)
        );

      clean =
        nix-gitignore.gitignoreFilterRecursiveSource filter
          [ ../../.gitignore ];
    in
      clean ../../apps/invert-window-colors-nim
}:
let
  inherit (__nix-utils) esc wrapExecutable;

  invert-window-colors = stdenv.mkDerivation rec {
    name = "invert-window-colors";
    src = __src;

    # Build dependencies
    nativeBuildInputs = [
      nim
    ];

    # Runtime dependencies
    buildInputs = [
      dbus
      pcre
    ];

    buildPhase = ''
      set -Eeuo pipefail

      ARGS=(
        --nimcache:nimcache
        -p:${esc nim-dbus-src}
        -o:${esc name}
        --threads:on
        -d:nimOldCaseObjects
        main.nim
      )

      nim c "''${ARGS[@]}"
    '';

    installPhase = ''
      set -Eeuo pipefail
      mkdir -p -- "$out"/bin
      cp -- ${esc name} "$out"/bin
    '';
  };
in
wrapExecutable "${invert-window-colors}/bin/invert-window-colors" {
  deps = [
    xdotool
    xlibs.xwininfo
  ];
}
