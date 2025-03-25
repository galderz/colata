{ pkgs ? import <nixpkgs> {} }:

let
  devkit = "/nix/store/vhsix1jn849mpxggwbw2zh1nbxpy0grc-Xcode16.2-MacOSX15";
in
pkgs.mkShell {
  packages = [
    pkgs.ant
    pkgs.autoconf
    pkgs.capstone
    pkgs.temurin-bin-23

    devkit
  ];

  shellHook = ''
    export ANT_HOME="${pkgs.ant}/share/ant"
    echo "Setting ANT_HOME to $ANT_HOME"

    export BOOT_JDK_HOME="${pkgs.temurin-bin-23}"
    echo "Setting BOOT_JDK_HOME to $BOOT_JDK_HOME"

    export CAPSTONE_HOME="${pkgs.capstone}"
    echo "Setting CAPSTONE_HOME to $CAPSTONE_HOME"

    export DEVKIT_ROOT=${devkit}
    echo "Setting DEVKIT_ROOT to $DEVKIT_ROOT"

    export MIGCC="${devkit}/Xcode/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/cc"
    echo "Setting MIGCC to $MIGCC"
  '' ;
}
