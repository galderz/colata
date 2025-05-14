{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  hardeningDisable = [ "all" ]; # Disable all hardening

  packages = with pkgs; [
    ant
    alsa-lib
    autoconf
    cups
    capstone
    fontconfig
    freetype
    xorg.libXtst
    xorg.libXt
    xorg.libXrender
    xorg.libXi
    xorg.libXrandr

    # temurin-bin-23
  ];

  shellHook = ''
    export ANT_HOME="${pkgs.ant}/share/ant"
    echo "Setting ANT_HOME to $ANT_HOME"

    # export BOOT_JDK_HOME="${pkgs.temurin-bin-23}"
    export BOOT_JDK_HOME="$HOME/opt/boot-java-24"
    echo "Setting BOOT_JDK_HOME to $BOOT_JDK_HOME"

    export CAPSTONE_HOME="${pkgs.capstone}"
    echo "Setting CAPSTONE_HOME to $CAPSTONE_HOME"

    export JMH_SNAPSHOT=false
    echo "Setting JMH_SNAPSHOT to $JMH_SNAPSHOT"

    export FREETYPE_INCLUDE="${pkgs.freetype.dev}/include"
    echo "Setting FREETYPE_INCLUDE to $FREETYPE_INCLUDE"

    export FREETYPE_LIB="${pkgs.freetype}/lib"
    echo "Setting FREETYPE_LIB to $FREETYPE_LIB"

    unset SOURCE_DATE_EPOCH
    echo "Unsetting SOURCE_DATE_EPOCH to avoid errors running tests"
  '' ;
}
