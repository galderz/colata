{ pkgs ? import <nixpkgs> {} }:

let
  devkit = "/nix/store/ddwccf951n51ng61zql8y6wcvs65vzli-Xcode16.3-MacOSX15";
in
pkgs.mkShell {
  packages = [
    pkgs.ant
    pkgs.autoconf
    pkgs.capstone
    pkgs.pigz
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

    export SDKROOT="${devkit}/Xcode/Contents/Developer"
    echo "Setting SDKROOT to $SDKROOT"

    export MIGCC="$SDKROOT/Toolchains/XcodeDefault.xctoolchain/usr/bin/cc"
    echo "Setting MIGCC to $MIGCC"

    unset SOURCE_DATE_EPOCH
    echo "Unsetting SOURCE_DATE_EPOCH to avoid errors running tests"
  '' ;
}
