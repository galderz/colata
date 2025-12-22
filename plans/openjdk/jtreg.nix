{ pkgs ? import <nixpkgs> {}
, jtreg_version ? "7.5+1"
}:

let
  # Fetch pre-built jtreg from builds.shipilev.net (Aleksey Shipilëv's CI)
  # This is a well-known source for jtreg builds used by the community
  jtreg_zip = pkgs.fetchurl {
    url = "https://builds.shipilev.net/jtreg/jtreg-${jtreg_version}.tar.gz";
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

in pkgs.stdenv.mkDerivation {
  pname = "jtreg";
  version = jtreg_version;

  src = jtreg_zip;

  nativeBuildInputs = with pkgs; [
    makeWrapper
  ];

  buildInputs = with pkgs; [
    temurin-bin-21  # jtreg requires JDK to run
  ];

  sourceRoot = ".";

  unpackPhase = ''
    tar xzf $src
  '';

  installPhase = ''
    # Install jtreg to output directory
    mkdir -p $out
    cp -r jtreg/* $out/ || cp -r */ $out/

    # Ensure bin scripts are executable
    chmod +x $out/bin/* || true

    # Wrap jtreg scripts to use correct JAVA_HOME
    for script in $out/bin/*; do
      if [ -f "$script" ] && [ -x "$script" ]; then
        wrapProgram $script \
          --prefix PATH : ${pkgs.temurin-bin-21}/bin \
          --set JAVA_HOME ${pkgs.temurin-bin-21}
      fi
    done
  '';

  meta = with pkgs.lib; {
    description = "Java Regression Test Harness";
    homepage = "https://openjdk.org/jtreg/";
    license = licenses.gpl2;
    platforms = platforms.unix;
  };
}
