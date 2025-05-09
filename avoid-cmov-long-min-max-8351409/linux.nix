{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  packages = [
    pkgs.ant
    pkgs.autoconf
    pkgs.capstone
    pkgs.pigz
    # pkgs.temurin-bin-23
  ];

  shellHook = ''
    export ANT_HOME="${pkgs.ant}/share/ant"
    echo "Setting ANT_HOME to $ANT_HOME"

    # export BOOT_JDK_HOME="${pkgs.temurin-bin-23}"
    export BOOT_JDK_HOME="$HOME/opt/boot-java-24"
    echo "Setting BOOT_JDK_HOME to $BOOT_JDK_HOME"

    export CAPSTONE_HOME="${pkgs.capstone}"
    echo "Setting CAPSTONE_HOME to $CAPSTONE_HOME"

    unset SOURCE_DATE_EPOCH
    echo "Unsetting SOURCE_DATE_EPOCH to avoid errors running tests"

    export JMH_SNAPSHOT=false
    echo "Setting JMH_SNAPSHOT to $JMH_SNAPSHOT"
  '' ;
}
