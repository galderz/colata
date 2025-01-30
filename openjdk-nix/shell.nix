{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  packages = [
    pkgs.autoconf
    pkgs.jdk23
  ];
}
