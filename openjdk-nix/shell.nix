{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShellNoCC {
  packages = [
    pkgs.autoconf
    pkgs.jdk23
  ];
}
