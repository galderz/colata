{ pkgs ? import <nixpkgs> {} }:

let
  unstable = import (builtins.fetchTarball
    "https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz") {};

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

  temurin26 = pkgs.stdenvNoCC.mkDerivation rec {
    pname = "temurin-26";
    version = "26+35";

    src = pkgs.fetchurl {
      url = "https://github.com/adoptium/temurin26-binaries/releases/download/jdk-26+35/OpenJDK26U-jdk_x64_linux_hotspot_26_35.tar.gz";
      hash = "sha256-aOGbpTt/H3RjXBP4CeXbNs68zzrp51JCPdktKtfYMe8=";
    };

    dontUnpack = true;

    nativeBuildInputs = [
      pkgs.autoPatchelfHook
      pkgs.makeWrapper
    ];

    buildInputs = with pkgs; [
      stdenv.cc.cc.lib
      zlib
      freetype
      fontconfig
      alsa-lib
      cups
      nss
      nspr
      xorg.libX11
      xorg.libXext
      xorg.libXi
      xorg.libXrender
      xorg.libXtst
      xorg.libXrandr
    ];

    installPhase = ''
      mkdir -p $out
      tar -xzf $src --strip-components=1 -C $out
    '';

    postFixup = ''
      wrapProgram $out/bin/java \
        --set-default JAVA_HOME $out
    '';
  };
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
    rr
    temurin-bin-21
    unzip
    xorg.libXtst
    xorg.libXt
    xorg.libXrender
    xorg.libXi
    xorg.libXrandr
    zip
  ] ++ [
    # unstable.temurin-bin-25
    temurin26
  ];

  ANT_HOME="${pkgs.ant}/share/ant";
  # BOOT_JDK_HOME="${unstable.temurin-bin-25}";
  BOOT_JDK_HOME="${temurin26}";
  CAPSTONE_HOME="${pkgs.capstone}";
  FREETYPE_INCLUDE="${pkgs.freetype.dev}/include";
  FREETYPE_LIB="${pkgs.freetype}/lib";
  IGV_JDK_HOME="${pkgs.temurin-bin-21}";

  shellHook = ''
    echo "ANT_HOME set to $ANT_HOME"
    echo "BOOT_JDK_HOME set to $BOOT_JDK_HOME"
    echo "CAPSTONE_HOME set to $CAPSTONE_HOME"
    echo "FREETYPE_INCLUDE set to $FREETYPE_INCLUDE"
    echo "FREETYPE_LIB set to $FREETYPE_LIB"

    ln -sf ${gdbInit} $HOME/.gdbinit

    unset SOURCE_DATE_EPOCH
    echo "Unsetting SOURCE_DATE_EPOCH to avoid errors running tests"
  '' ;
}
