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
    pkgs.temurin-bin-24

    devkit
  ];

  # Requirements:
  # DEVKIT_ROOT set so that JDK build configure picks it up
  # DEVELOPER_DIR set so that tools such as xctrace are resolved
  # MIGCC overriden because xcrun cannot still locate it even though DEVELOPER_DIR is set:
  #   xcrun: error: unable to find Xcode installation from active developer path "/nix/store/ddwccf951n51ng61zql8y6wcvs65vzli-Xcode16.3-MacOSX15/Xcode/Contents/Developer", use xcode-select to change
  shellHook = ''
    export ANT_HOME="${pkgs.ant}/share/ant"
    echo "Setting ANT_HOME to $ANT_HOME"

    export BOOT_JDK_HOME="${pkgs.temurin-bin-24}"
    echo "Setting BOOT_JDK_HOME to $BOOT_JDK_HOME"

    export CAPSTONE_HOME="${pkgs.capstone}"
    echo "Setting CAPSTONE_HOME to $CAPSTONE_HOME"

    export DEVKIT_ROOT="${devkit}"
    echo "Setting DEVKIT_ROOT to $DEVKIT_ROOT"

    export DEVELOPER_DIR="${devkit}/Xcode/Contents/Developer"
    echo "Setting DEVELOPER_DIR to $DEVELOPER_DIR"

    export MIGCC="$DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain/usr/bin/cc"
    echo "Setting MIGCC to $MIGCC"

    unset SOURCE_DATE_EPOCH
    echo "Unsetting SOURCE_DATE_EPOCH to avoid errors running tests"
  '' ;
}
