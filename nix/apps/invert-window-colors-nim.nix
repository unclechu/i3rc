# Author: Viacheslav Lotsmanov
# License: MIT https://raw.githubusercontent.com/unclechu/i3rc/master/LICENSE-MIT
let sources = import ../sources.nix; in
{ pkgs ? import sources.nixpkgs {}

, src ?
    let
      filter = fileName: fileType:
        pkgs.lib.cleanSourceFilter fileName fileType && (
          fileType == "directory" ||
          ! isNull (builtins.match "^.*/license[.]txt$" fileName) ||
          ! isNull (builtins.match "^.*/[^/]+[.]nim$" fileName)
        );

      clean =
        pkgs.nix-gitignore.gitignoreFilterRecursiveSource filter
          [ ../../.gitignore ];
    in
      clean ../../apps/invert-window-colors-nim

, nim-dbus-src ? sources.nim-dbus
}:
let
  utils = import ../utils.nix { inherit pkgs; };
  inherit (utils) esc wrapExecutable;

  invert-window-colors = pkgs.stdenv.mkDerivation rec {
    name = "invert-window-colors";
    inherit src;

    # Build dependencies
    nativeBuildInputs = [
      pkgs.nim
    ];

    # Runtime dependencies
    buildInputs = [
      pkgs.dbus
      pkgs.pcre
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
    pkgs.xdotool
    pkgs.xlibs.xwininfo
  ];
}
