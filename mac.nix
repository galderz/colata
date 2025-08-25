{ pkgs ? import <nixpkgs> {} }:

let
  devkit = "/nix/store/ddwccf951n51ng61zql8y6wcvs65vzli-Xcode16.3-MacOSX15";
  devdir="${devkit}/Xcode/Contents/Developer";
in
pkgs.mkShell {
  packages = [
    pkgs.ant
    pkgs.autoconf
    pkgs.capstone
    pkgs.maven
    pkgs.pigz
    pkgs.temurin-bin-24
    pkgs.temurin-bin-21

    devkit
  ];

  # Requirements:
  # DEVKIT_ROOT set so that JDK build configure picks it up
  # DEVELOPER_DIR set so that tools such as xctrace are resolved
  # MIGCC overriden because xcrun cannot still locate it even though DEVELOPER_DIR is set:
  #   xcrun: error: unable to find Xcode installation from active developer path "/nix/store/ddwccf951n51ng61zql8y6wcvs65vzli-Xcode16.3-MacOSX15/Xcode/Contents/Developer", use xcode-select to change

  ANT_HOME="${pkgs.ant}/share/ant";
  BOOT_JDK_HOME="${pkgs.temurin-bin-24}";
  CAPSTONE_HOME="${pkgs.capstone}";
  DEVELOPER_DIR="${devdir}";
  DEVKIT_ROOT="${devkit}";
  IGV_JDK_HOME="${pkgs.temurin-bin-21}";
  MAVEN_HOME="${pkgs.maven}";
  MIGCC="${devdir}/Toolchains/XcodeDefault.xctoolchain/usr/bin/cc";

  shellHook = ''
    echo "ANT_HOME set to $ANT_HOME"
    echo "BOOT_JDK_HOME set to $BOOT_JDK_HOME"
    echo "CAPSTONE_HOME set to $CAPSTONE_HOME"
    echo "DEVELOPER_DIR set to $DEVELOPER_DIR"
    echo "DEVKIT_ROOT set to $DEVKIT_ROOT"
    echo "IGV_JDK_HOME set to $IGV_JDK_HOME"
    echo "MIGCC set to $MIGCC"
    echo "MAVEN_HOME set to $MAVEN_HOME"

    unset SOURCE_DATE_EPOCH
    echo "Unsetting SOURCE_DATE_EPOCH to avoid errors running tests"
  '' ;
}
