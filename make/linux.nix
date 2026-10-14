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

  temurin27 = pkgs.stdenvNoCC.mkDerivation rec {
    pname = "temurin";
    version = "27+35";

    src = pkgs.fetchurl {
      url = "https://github.com/adoptium/temurin27-binaries/releases/download/jdk-27+35/OpenJDK27U-jdk_x64_linux_hotspot_27_35.tar.gz";
      # hash obtained with:
      # $ export ADOPTIUM_URL=...
      # $ curl -L "$ADOPTIUM_URL" -o OpenJDK.tar.gz
      # $ nix hash file --sri OpenJDK.tar.gz
      hash = "sha256-HPaaSEj/tyizsmDf1FIGpRVmq1caAqMAkicdTFgLzLw=";
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
    numactl
    rr
    temurin-bin-17
    temurin-bin-21
    unzip
    xorg.libXtst
    xorg.libXt
    xorg.libXrender
    xorg.libXi
    xorg.libXrandr
    zip
  ] ++ [
    temurin27
  ];

  ANT_HOME="${pkgs.ant}/share/ant";
  CAPSTONE_HOME="${pkgs.capstone}";
  FREETYPE_INCLUDE="${pkgs.freetype.dev}/include";
  FREETYPE_LIB="${pkgs.freetype}/lib";
  JAVA_17_HOME="${pkgs.temurin-bin-17}";
  JAVA_21_HOME="${pkgs.temurin-bin-21}";
  JAVA_LATEST_HOME="${temurin27}";

  shellHook = ''
    echo "ANT_HOME set to $ANT_HOME"
    echo "CAPSTONE_HOME set to $CAPSTONE_HOME"
    echo "FREETYPE_INCLUDE set to $FREETYPE_INCLUDE"
    echo "FREETYPE_LIB set to $FREETYPE_LIB"
    echo "JAVA_17_HOME set to $JAVA_17_HOME"
    echo "JAVA_21_HOME set to $JAVA_21_HOME"
    echo "JAVA_LATEST_HOME set to $JAVA_LATEST_HOME"

    ln -sf ${gdbInit} $HOME/.gdbinit

    unset SOURCE_DATE_EPOCH
    echo "Unsetting SOURCE_DATE_EPOCH to avoid errors running tests"
  '' ;
}
