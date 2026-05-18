{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    maven
    temurin-bin-17
  ];

  JDK_17_HOME="${pkgs.temurin-bin-17}";

  shellHook = ''
    echo "JAVA_17_HOME set to $JAVA_17_HOME"
  '' ;
}
