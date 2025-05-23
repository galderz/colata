{ pkgs ? import
  (builtins.fetchTarball "https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz")
  {}
}:

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

  shellHook = ''
    export ANT_HOME="${pkgs.ant}/share/ant"
    echo "Setting ANT_HOME to $ANT_HOME"

    export BOOT_JDK_HOME="${pkgs.temurin-bin-24}"
    # export BOOT_JDK_HOME="$HOME/opt/boot-java-24"
    echo "Setting BOOT_JDK_HOME to $BOOT_JDK_HOME"

    export CAPSTONE_HOME="${pkgs.capstone}"
    echo "Setting CAPSTONE_HOME to $CAPSTONE_HOME"

    export JMH_SNAPSHOT=false
    echo "Setting JMH_SNAPSHOT to $JMH_SNAPSHOT"

    export FREETYPE_INCLUDE="${pkgs.freetype.dev}/include"
    echo "Setting FREETYPE_INCLUDE to $FREETYPE_INCLUDE"

    export FREETYPE_LIB="${pkgs.freetype}/lib"
    echo "Setting FREETYPE_LIB to $FREETYPE_LIB"

    ln -sf ${gdbInit} $HOME/.gdbinit

    unset SOURCE_DATE_EPOCH
    echo "Unsetting SOURCE_DATE_EPOCH to avoid errors running tests"
  '' ;
}
