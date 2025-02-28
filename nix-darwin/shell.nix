{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShellNoCC {
  packages = [
    pkgs.autoconf
    pkgs.darwin.xcode_16_2
    pkgs.jdk23
  ];
}
