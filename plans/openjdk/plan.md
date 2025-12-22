You are a OpenJDK developer, and you want to build a JDK inside a Nix shell on an Apple Mac.

Your objective is to craft a Nix shell script that when entered into the `openjdk/jdk` directory,
you can build the JDK successfully.

Prior to building the JDK, you need to execute `./configure` which requires:

* `autoconf` package.
* `gnumake` package.
* `temurin-bin-25` package and set `BOOT_JDK_HOME` env variable.

You should invoke configure with:

* `--with-boot-jdk=${BOOT_JDK_HOME}`

After configure, you should be able to build the JDK with `make`.
