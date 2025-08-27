{ pkgs ? import <nixpkgs> {} }:

let
  gdbInit = pkgs.writeText ".gdbinit" ''
    set auto-load safe-path /local
    add-auto-load-safe-path /

    handle 11 nostop
    handle 4 noprint nostop
    set print thread-events off
    set step-mode on

    set height 0

    set debuginfod enabled on
  '';
in
pkgs.mkShell {
  hardeningDisable = [ "all" ]; # Disable all hardening

  packages = with pkgs; [
    ant
    alsa-lib
    autoconf
    capstone
    cups
    fontconfig
    freetype
    gdb
    temurin-bin-24
    unzip
    xorg.libXtst
    xorg.libXt
    xorg.libXrender
    xorg.libXi
    xorg.libXrandr
    zip
  ];

  ANT_HOME="${pkgs.ant}/share/ant";
  BOOT_JDK_HOME="${pkgs.temurin-bin-24}";
  CAPSTONE_HOME="${pkgs.capstone}";
  FREETYPE_INCLUDE="${pkgs.freetype.dev}/include";
  FREETYPE_LIB="${pkgs.freetype}/lib";

  shellHook = ''
    echo "ANT_HOME set to $ANT_HOME"
    echo "BOOT_JDK_set HOME to $BOOT_JDK_HOME"
    echo "CAPSTONE_HOME set to $CAPSTONE_HOME"
    echo "FREETYPE_INCLUDE set to $FREETYPE_INCLUDE"
    echo "FREETYPE_LIB set to $FREETYPE_LIB"

    ln -sf ${gdbInit} $HOME/.gdbinit

    unset SOURCE_DATE_EPOCH
    echo "Unsetting SOURCE_DATE_EPOCH to avoid errors running tests"
  '' ;
}
