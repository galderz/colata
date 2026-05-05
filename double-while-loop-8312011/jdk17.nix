{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    temurin-bin-17
  ];

  JDK_17_HOME="${pkgs.temurin-bin-17}";

  shellHook = ''
    echo "ANT_HOME set to $ANT_HOME"
    echo "BOOT_JDK_HOME set to $BOOT_JDK_HOME"
    echo "CAPSTONE_HOME set to $CAPSTONE_HOME"
    echo "IGV_JDK_HOME set to $IGV_JDK_HOME"
    echo "MAVEN_HOME set to $MAVEN_HOME"
    echo "STUB_DIR set to $STUB_DIR"

    echo "JDK_17_HOME set to $JDK_17_HOME"
  '' ;
}
