{ pkgs ? import <nixpkgs> {} }:

let
  devkit = "/nix/store/vhsix1jn849mpxggwbw2zh1nbxpy0grc-Xcode16.2-MacOSX15";
in
pkgs.mkShell {
  packages = [
    pkgs.autoconf
    pkgs.clang
    pkgs.temurin-bin-23

    devkit
  ];

  shellHook = ''
    echo "Setting DEVKIT_ROOT to path of the devkit in the Nix store."
    export DEVKIT_ROOT=${devkit}

    echo "Setting MIGCC to clang compiler cc binary."
    export MIGCC="${pkgs.clang}/bin/cc"
  '' ;
}
