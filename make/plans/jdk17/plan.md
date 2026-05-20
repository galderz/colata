You are a OpenJDK developer, and you want to build JDK 17 inside a Nix shell on an Apple Mac.

Your objective is to craft a Nix shell script that when entered into the `jdk` directory here,
you can build the JDK successfully.

Prior to building the JDK, you need to execute `./configure` which requires:

* `autoconf` package.
* `gnumake` package.
* a boot JDK, you will figure out which version and then set `BOOT_JDK_HOME` env variable to it.

You should invoke configure with:

* `--with-boot-jdk=${BOOT_JDK_HOME}`

After configure, you should be able to build the JDK with `make`.
