# Building OpenJDK for Darwin with Nix packages

## Useful links

https://github.com/NixOS/nixpkgs/blob/master/doc/stdenv/platform-notes.chapter.md
https://github.com/nixos/nixpkgs/blob/master/pkgs/os-specific/darwin/xcode/default.nix

## Create a JDK macOS devkit

```shell
cd jdk/make/devkit
bash ./createMacosxDevkit.sh /Applications/Xcode.app
```

## Install devkit to nix

```shell
$ cd jdk/build/devkit
$ nix-store --add-fixed --recursive sha256 Xcode16.2-MacOSX15
/nix/store/vhsix1jn849mpxggwbw2zh1nbxpy0grc-Xcode16.2-MacOSX15
```

## Build JDK

### Configure

Run `nix-shell` and call the configure script:

```shell
nix-shell
./configure.sh
```

Output should be something like:

```bash
A new configuration has been successfully created in
/Users/galder/1/colata/nix-darwin/jdk/build/macosx-aarch64-server-release
using configure arguments '--with-boot-jdk=/nix/store/wm5rma6x2527qmypzj7rwml8vf9vprgj-zulu-ca-jdk-23.0.0/zulu-23.jdk/Contents/Home --with-devkit=/nix/store/vhsix1jn849mpxggwbw2zh1nbxpy0grc-Xcode16.2-MacOSX15'.

Configuration summary:
* Name:           macosx-aarch64-server-release
* Debug level:    release
* HS debug level: product
* JVM variants:   server
* JVM features:   server: 'cds compiler1 compiler2 dtrace epsilongc g1gc jfr jni-check jvmci jvmti management parallelgc serialgc services shenandoahgc vm-structs zgc'
* OpenJDK target: OS: macosx, CPU architecture: aarch64, address length: 64
* Version string: 25-internal-adhoc.galder.jdk (25-internal)
* Source date:    315532800 (1980-01-01T00:00:00Z)

Tools summary:
* Boot JDK:       openjdk version "23" 2024-09-17 OpenJDK Runtime Environment Zulu23.28+85-CA (build 23+37) OpenJDK 64-Bit Server VM Zulu23.28+85-CA (build 23+37, mixed mode, sharing) (at /nix/store/wm5rma6x2527qmypzj7rwml8vf9vprgj-zulu-ca-jdk-23.0.0/zulu-23.jdk/Contents/Home)
* Toolchain:      clang (clang/LLVM from Xcode 16.2)
* Devkit:         Xcode 16.2 (devkit) (/nix/store/vhsix1jn849mpxggwbw2zh1nbxpy0grc-Xcode16.2-MacOSX15)
* C Compiler:     Version 16.0.0 (at /nix/store/vhsix1jn849mpxggwbw2zh1nbxpy0grc-Xcode16.2-MacOSX15/Xcode/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang)
* C++ Compiler:   Version 16.0.0 (at /nix/store/vhsix1jn849mpxggwbw2zh1nbxpy0grc-Xcode16.2-MacOSX15/Xcode/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang++)

Build performance summary:
* Build jobs:     14
* Memory limit:   49152 MB
```

### Build

Run the build:

```shell
./build.sh
```

Error:

```bash
/nix/store/vhsix1jn849mpxggwbw2zh1nbxpy0grc-Xcode16.2-MacOSX15/Xcode/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/mig: line 171: error: unable to find sdk: '/nix/store/lsjl29pwp5if71jfgxlv8fifsrpax805-apple-sdk-11.3/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk': No such file or directory
Compiling up to 2 files for COMPILE_DEPEND
mig: fatal: "<no name yet>", line -1: no SubSystem declaration
make[3]: *** [/Users/galder/1/colata/nix-darwin/jdk/build/macosx-aarch64-server-release/support/gensrc/jdk.hotspot.agent/mach_excServer.c] Error 1
make[2]: *** [jdk.hotspot.agent-gensrc-src] Error 2
make[2]: *** Waiting for unfinished jobs....
```
