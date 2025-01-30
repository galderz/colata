{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShellNoCC {
  packages = [
    pkgs.autoconf
    pkgs.darwin.xcode
    pkgs.jdk23
  ];
}
