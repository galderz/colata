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

The `MacOSX.sdk` folder should be resolved from the devkit root:

```bash
galder@m25:/nix/store/lsjl29pwp5if71jfgxlv8fifsrpax805-apple-sdk-11.3/ > find . -iname "MacOSX.sdk"
./Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk
```

Running command individually:

```bash
[nix-shell:~/1/colata/nix-darwin]$ /nix/store/vhsix1jn849mpxggwbw2zh1nbxpy0grc-Xcode16.2-MacOSX15/Xcode/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/mig -isysroot /nix/store/vhsix1jn849mpxggwbw2zh1nbxpy0grc-Xcode16.2-MacOSX15/Xcode/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX15.sdk -server /Users/galder/1/colata/nix-darwin/jdk/build/macosx-aarch64-server-release/support/gensrc/jdk.hotspot.agent/mach_excServer.c -user /Users/galder/1/colata/nix-darwin/jdk/build/macosx-aarch64-server-release/support/gensrc/jdk.hotspot.agent/mach_excUser.c -header /Users/galder/1/colata/nix-darwin/jdk/build/macosx-aarch64-server-release/support/gensrc/jdk.hotspot.agent/mach_exc.h /nix/store/vhsix1jn849mpxggwbw2zh1nbxpy0grc-Xcode16.2-MacOSX15/Xcode/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX15.sdk/usr/include/mach/mach_exc.defs
/nix/store/vhsix1jn849mpxggwbw2zh1nbxpy0grc-Xcode16.2-MacOSX15/Xcode/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/mig: line 171: error: unable to find sdk: '/nix/store/lsjl29pwp5if71jfgxlv8fifsrpax805-apple-sdk-11.3/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk': No such file or directory
mig: fatal: "<no name yet>", line -1: no SubSystem declaration
```

`ls` for different folders:

```bash
[nix-shell:~/1/colata/nix-darwin]$ ls -al /nix/store/lsjl29pwp5if71jfgxlv8fifsrpax805-apple-sdk-11.3/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/
total 16
dr-xr-xr-x 7 root nixbld  224 Jan  1  1970 .
dr-xr-xr-x 5 root nixbld  160 Jan  1  1970 ..
-r--r--r-- 1 root nixbld  127 Jan  1  1970 Entitlements.plist
-r--r--r-- 1 root nixbld 4512 Jan  1  1970 SDKSettings.json
-r--r--r-- 1 root nixbld 3691 Jan  1  1970 SDKSettings.plist
dr-xr-xr-x 4 root nixbld  128 Jan  1  1970 System
dr-xr-xr-x 5 root nixbld  160 Jan  1  1970 usr

[nix-shell:~/1/colata/nix-darwin]$ ls -al /nix/store/vhsix1jn849mpxggwbw2zh1nbxpy0grc-Xcode16.2-MacOSX15/Xcode/Contents/Developer
total 0
dr-xr-xr-x  9 root nixbld 288 Jan  1  1970 .
dr-xr-xr-x 11 root nixbld 352 Jan  1  1970 ..
dr-xr-xr-x  3 root nixbld  96 Jan  1  1970 Applications
dr-xr-xr-x  6 root nixbld 192 Jan  1  1970 Library
dr-xr-xr-x  6 root nixbld 192 Jan  1  1970 Makefiles
dr-xr-xr-x  3 root nixbld  96 Jan  1  1970 Platforms
dr-xr-xr-x  3 root nixbld  96 Jan  1  1970 Toolchains
dr-xr-xr-x  8 root nixbld 256 Jan  1  1970 Tools
dr-xr-xr-x  6 root nixbld 192 Jan  1  1970 usr
```

No references to `/nix/store/lsjl29pwp5if71jfgxlv8fifsrpax805-apple-sdk-11.3` in the command line, but the `env` shows:

```bash
DEVELOPER_DIR=/nix/store/lsjl29pwp5if71jfgxlv8fifsrpax805-apple-sdk-11.3
```

I wonder if `DEVELOPER_DIR` needs to be overriden to point to `/nix/store/vhsix1jn849mpxggwbw2zh1nbxpy0grc-Xcode16.2-MacOSX15/Xcode/Contents/Developer`.

```bash
$ export DEVELOPER_DIR=${DEVKIT_ROOT}/Xcode.app/Contents/Developer
$ echo $DEVELOPER_DIR
/nix/store/vhsix1jn849mpxggwbw2zh1nbxpy0grc-Xcode16.2-MacOSX15/Xcode.app/Contents/Developer
```

Then I get issues locating `xcodebuild`:

```bash
$ /nix/store/vhsix1jn849mpxggwbw2zh1nbxpy0grc-Xcode16.2-MacOSX15/Xcode/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/mig -isysroot /nix/store/vhsix1jn849mpxggwbw2zh1nbxpy0grc-Xcode16.2-MacOSX15/Xcode/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX15.sdk -server /Users/galder/1/colata/nix-darwin/jdk/build/macosx-aarch64-server-release/support/gensrc/jdk.hotspot.agent/mach_excServer.c -user /Users/galder/1/colata/nix-darwin/jdk/build/macosx-aarch64-server-release/support/gensrc/jdk.hotspot.agent/mach_excUser.c -header /Users/galder/1/colata/nix-darwin/jdk/build/macosx-aarch64-server-release/support/gensrc/jdk.hotspot.agent/mach_exc.h /nix/store/vhsix1jn849mpxggwbw2zh1nbxpy0grc-Xcode16.2-MacOSX15/Xcode/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX15.sdk/usr/include/mach/mach_exc.defs
xcrun: error: unable to locate xcodebuild, please make sure the path to the Xcode folder is set correctly!
xcrun: error: You can set the path to the Xcode folder using /usr/bin/xcode-select -switch
/nix/store/vhsix1jn849mpxggwbw2zh1nbxpy0grc-Xcode16.2-MacOSX15/Xcode/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/mig: line 171: : command not found
mig: fatal: "<no name yet>", line -1: no SubSystem declaration
```

Looking at the path I see `xcodebuild` is still pointing to the one in `/usr/bin`:

```bash
$ which xcodebuild
/usr/bin/xcodebuild
```

The devkit has got an `xcodebuild` so I tried to set `PATH` to that:

```bash
[nix-shell:/nix/store/vhsix1jn849mpxggwbw2zh1nbxpy0grc-Xcode16.2-MacOSX15/Xcode.app/Contents/Developer/usr/bin]$ ls
2to3		  actool		  convertRichTextToAscii	   g++		    ibtool	       lldb	       pip3.9		 safari-web-extension-converter  stapler     xcindex-test
2to3-3.9	  agvtool		  copySceneKitAssets		   gamepolicyctl    ibtool3	       lldb-dap        placeholderutil	 sample				 stringdups  xcodebuild
DeRez		  altool		  copypng			   gatherheaderdoc  ibtoold	       logdump	       pngcrush		 scalar				 swinfo      xcresulttool
GetFileInfo	  amlint		  coremlc			   gcc		    ictool	       make	       pydoc3		 scntool			 symbols     xcsigningtool
ResMerger	  appleProductTypesTool   crashlog			   genstrings	    instrumentbuilder  malloc_history  pydoc3.9		 sdef				 vmmap	     xcstringstool
Rez		  atos			  desdp				   gnumake	    intentbuilderc     mapc	       python3		 sdp				 xarsigner   xctest
SetFile		  backgroundassets-debug  devicectl			   hdxml2manxml     ipatool	       momc	       python3.9	 simctl				 xccov	     xctrace
SplitForks	  bitcode-build-tool	  embeddedBinaryValidationUtility  headerdoc2html   iphoneos-optimize  notarytool      realitytool	 ssu-cli			 xcdebug     xed
TextureAtlas	  cktool		  extractLocStrings		   heap		    ld		       opendiff        referenceobjectc  ssu-cli-app			 xcdevice    xml2man
TextureConverter  compileSceneKitShaders  filtercalltree		   iTMSTransporter  leaks	       pip3	       resolveLinks	 ssu-cli-nlu			 xcdiagnose

$ export PATH=/nix/store/vhsix1jn849mpxggwbw2zh1nbxpy0grc-Xcode16.2-MacOSX15/Xcode.app/Contents/Developer/usr/bin:$PATH

$ which xcodebuild
/nix/store/vhsix1jn849mpxggwbw2zh1nbxpy0grc-Xcode16.2-MacOSX15/Xcode.app/Contents/Developer/usr/bin/xcodebuild
```

But the same error happens:

```bash
$ /nix/store/vhsix1jn849mpxggwbw2zh1nbxpy0grc-Xcode16.2-MacOSX15/Xcode/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/mig -isysroot /nix/store/vhsix1jn849mpxggwbw2zh1nbxpy0grc-Xcode16.2-MacOSX15/Xcode/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX15.sdk -server /Users/galder/1/colata/nix-darwin/jdk/build/macosx-aarch64-server-release/support/gensrc/jdk.hotspot.agent/mach_excServer.c -user /Users/galder/1/colata/nix-darwin/jdk/build/macosx-aarch64-server-release/support/gensrc/jdk.hotspot.agent/mach_excUser.c -header /Users/galder/1/colata/nix-darwin/jdk/build/macosx-aarch64-server-release/support/gensrc/jdk.hotspot.agent/mach_exc.h /nix/store/vhsix1jn849mpxggwbw2zh1nbxpy0grc-Xcode16.2-MacOSX15/Xcode/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX15.sdk/usr/include/mach/mach_exc.defs
xcrun: error: unable to locate xcodebuild, please make sure the path to the Xcode folder is set correctly!
xcrun: error: You can set the path to the Xcode folder using /usr/bin/xcode-select -switch
/nix/store/vhsix1jn849mpxggwbw2zh1nbxpy0grc-Xcode16.2-MacOSX15/Xcode/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/mig: line 171: : command not found
mig: fatal: "<no name yet>", line -1: no SubSystem declaration
```

A message pops up saying: `“Xcode.app” is damaged and can’t be opened.`

I've run with `sh -x` and I see:

```
+ '[' -n /nix/store/lsjl29pwp5if71jfgxlv8fifsrpax805-apple-sdk-11.3/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk ']'
+ sdkRoot=/nix/store/lsjl29pwp5if71jfgxlv8fifsrpax805-apple-sdk-11.3/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk
+ '[' -z '' ']'
+ xcrunPath=/usr/bin/xcrun
+ '[' -x /usr/bin/xcrun ']'
++ /usr/bin/xcrun -sdk /nix/store/lsjl29pwp5if71jfgxlv8fifsrpax805-apple-sdk-11.3/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk -find cc
xcrun: error: unable to locate xcodebuild, please make sure the path to the Xcode folder is set correctly!
xcrun: error: You can set the path to the Xcode folder using /usr/bin/xcode-select -switch
+ MIGCC=
+ C=
+ M=/nix/store/vhsix1jn849mpxggwbw2zh1nbxpy0grc-Xcode16.2-MacOSX15/Xcode/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/libexec/migcom
```

The `mig` script hardcodes using `/usr/bin/xcrun`, not sure how

```bash
if [ -z "${MIGCC}" ]; then
  xcrunPath="/usr/bin/xcrun"
  if [ -x "${xcrunPath}" ]; then
    MIGCC=`"${xcrunPath}" -sdk "$sdkRoot" -find cc`
  else
    MIGCC=$(realpath "${scriptRoot}/cc")
  fi
fi
```

Maybe I need/can set `MIGCC` and avoid that path? Any other solution?

I'm unsure the error that makes it stop, but the execution ends with:

```
+ case "$1" in
+ file=/nix/store/vhsix1jn849mpxggwbw2zh1nbxpy0grc-Xcode16.2-MacOSX15/Xcode/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX15.sdk/usr/include/mach/mach_exc.defs
+ shift
++ basename /nix/store/vhsix1jn849mpxggwbw2zh1nbxpy0grc-Xcode16.2-MacOSX15/Xcode/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX15.sdk/usr/include/mach/mach_exc.defs .defs
+ base=mach_exc
+ temp=/private/tmp/nix-shell-61851-0/mig.AxdU6X/mach_exc.62557
++ dirname /nix/store/vhsix1jn849mpxggwbw2zh1nbxpy0grc-Xcode16.2-MacOSX15/Xcode/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX15.sdk/usr/include/mach/mach_exc.defs
+ sourcedir=/nix/store/vhsix1jn849mpxggwbw2zh1nbxpy0grc-Xcode16.2-MacOSX15/Xcode/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX15.sdk/usr/include/mach
+ '[' -n /nix/store/vhsix1jn849mpxggwbw2zh1nbxpy0grc-Xcode16.2-MacOSX15/Xcode/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX15.sdk ']'
+ iSysRootParm=("-isysroot" "${sdkRoot}")
+ '[' '!' -r /nix/store/vhsix1jn849mpxggwbw2zh1nbxpy0grc-Xcode16.2-MacOSX15/Xcode/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX15.sdk/usr/include/mach/mach_exc.defs ']'
+ rm -f /private/tmp/nix-shell-61851-0/mig.AxdU6X/mach_exc.62557.c /private/tmp/nix-shell-61851-0/mig.AxdU6X/mach_exc.62557.d
+ echo '#line 1 "/nix/store/vhsix1jn849mpxggwbw2zh1nbxpy0grc-Xcode16.2-MacOSX15/Xcode/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX15.sdk/usr/include/mach/mach_exc.defs"'
+ cat /nix/store/vhsix1jn849mpxggwbw2zh1nbxpy0grc-Xcode16.2-MacOSX15/Xcode/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX15.sdk/usr/include/mach/mach_exc.defs
+ '' -E -arch arm64 -D__MACH30__ -I /nix/store/vhsix1jn849mpxggwbw2zh1nbxpy0grc-Xcode16.2-MacOSX15/Xcode/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX15.sdk/usr/include/mach -isysroot /nix/store/vhsix1jn849mpxggwbw2zh1nbxpy0grc-Xcode16.2-MacOSX15/Xcode/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX15.sdk /private/tmp/nix-shell-61851-0/mig.AxdU6X/mach_exc.62557.c
/nix/store/vhsix1jn849mpxggwbw2zh1nbxpy0grc-Xcode16.2-MacOSX15/Xcode/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/mig: line 171: : command not found
+ /nix/store/vhsix1jn849mpxggwbw2zh1nbxpy0grc-Xcode16.2-MacOSX15/Xcode/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/libexec/migcom -server /Users/galder/1/colata/nix-darwin/jdk/build/macosx-aarch64-server-release/support/gensrc/jdk.hotspot.agent/mach_excServer.c -user /Users/galder/1/colata/nix-darwin/jdk/build/macosx-aarch64-server-release/support/gensrc/jdk.hotspot.agent/mach_excUser.c -header /Users/galder/1/colata/nix-darwin/jdk/build/macosx-aarch64-server-release/support/gensrc/jdk.hotspot.agent/mach_exc.h
mig: fatal: "<no name yet>", line -1: no SubSystem declaration
+ '[' 1 -ne 0 ']'
+ rm -rf /private/tmp/nix-shell-61851-0/mig.AxdU6X/mach_exc.62557.c /private/tmp/nix-shell-61851-0/mig.AxdU6X/mach_exc.62557.d /private/tmp/nix-shell-61851-0/mig.AxdU6X
+ exit 1
```

I've also tried running with `xcrun` added by nix but that doesn't work either:

```
$ /nix/store/prpzadksziwxb1w7x9y57iqnai22ybbx-xcbuild-0.1.1-unstable-2019-11-20-xcrun/bin/xcrun -sdk /nix/store/lsjl29pwp5if71jfgxlv8fifsrpax805-apple-sdk-11.3/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk -find cc
warning: unhandled Platform key FamilyDisplayName
error: unable to find sdk: '/nix/store/lsjl29pwp5if71jfgxlv8fifsrpax805-apple-sdk-11.3/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk'
```

Also, the command not found error is coming from:

```bash
"$C" -E -arch ${arch} "${target[@]}" "${cppflags[@]}" -I "${sourcedir}" "${iSysRootParm[@]}" "${temp}.c" | "$M" "${migflags[@]}"
```

In the debug run it shows as:

```bash
+ '' -E -arch arm64 -D__MACH30__ -I /nix/store/vhsix1jn849mpxggwbw2zh1nbxpy0grc-Xcode16.2-MacOSX15/Xcode/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX15.sdk/usr/include/mach -isysroot /nix/store/vhsix1jn849mpxggwbw2zh1nbxpy0grc-Xcode16.2-MacOSX15/Xcode/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX15.sdk /private/tmp/nix-shell-61851-0/mig.AxdU6X/mach_exc.62557.c
/nix/store/vhsix1jn849mpxggwbw2zh1nbxpy0grc-Xcode16.2-MacOSX15/Xcode/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/mig: line 171: : command not found
```

It's failing to resolve `$C`. Which `$C` should it be using here?

```bash
$ which cc
/usr/bin/cc
```

That doesn't look like the right C compiler.

Switched from `pkgs.mkShellNoCC` to `pkgs.mkShell` and then:

```bash
$ export MIGCC=/nix/store/0jd4fjnnrfz0dfxbc5lgfyxjfay73i77-clang-wrapper-19.1.7/bin/cc
```

And now the following command runs fine:

```bash
$ /nix/store/vhsix1jn849mpxggwbw2zh1nbxpy0grc-Xcode16.2-MacOSX15/Xcode/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/mig -isysroot /nix/store/vhsix1jn849mpxggwbw2zh1nbxpy0grc-Xcode16.2-MacOSX15/Xcode/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX15.sdk -server /Users/galder/1/colata/nix-darwin/jdk/build/macosx-aarch64-server-release/support/gensrc/jdk.hotspot.agent/mach_excServer.c -user /Users/galder/1/colata/nix-darwin/jdk/build/macosx-aarch64-server-release/support/gensrc/jdk.hotspot.agent/mach_excUser.c -header /Users/galder/1/colata/nix-darwin/jdk/build/macosx-aarch64-server-release/support/gensrc/jdk.hotspot.agent/mach_exc.h /nix/store/vhsix1jn849mpxggwbw2zh1nbxpy0grc-Xcode16.2-MacOSX15/Xcode/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX15.sdk/usr/include/mach/mach_exc.defs
```

The build works fine now:
```bash
[nix-shell:~/1/colata/nix-darwin]$ pushd jdk && make
Building target 'default (exploded-image)' in configuration 'macosx-aarch64-server-release'
Compiling up to 1 files for jdk.jdwp.agent
Compiling up to 53 files for jdk.incubator.vector
Compiling up to 27 files for jdk.management
Compiling up to 4 files for jdk.jsobject
Compiling up to 1545 files for jdk.localedata
Compiling up to 26 files for jdk.sctp
Compiling up to 3 files for jdk.nio.mapmode
Compiling up to 9 files for jdk.net
Compiling up to 94 files for jdk.xml.dom
Compiling up to 9 files for jdk.unsupported
Compiling up to 301 files for jdk.jfr
Compiling up to 18 files for java.prefs
Compiling up to 118 files for jdk.internal.le
Compiling up to 30 files for java.security.sasl
Compiling up to 77 files for java.sql
Compiling up to 15 files for jdk.attach
Compiling up to 368 files for jdk.compiler
Compiling up to 105 files for java.rmi
Compiling up to 272 files for java.xml.crypto
Compiling up to 1 files for jdk.graal.compiler
Compiling up to 67 files for jdk.dynalink
Compiling up to 1 files for jdk.graal.compiler.management
Compiling up to 28 files for jdk.jartool
Compiling up to 204 files for java.naming
Compiling up to 40 files for jdk.jcmd
Compiling up to 254 files for jdk.jdi
Compiling up to 11 files for jdk.jstatd
Creating support/modules_libs/java.base/libverify.dylib from 1 file(s)
Creating support/modules_libs/java.base/libjava.dylib from 66 file(s)
Creating support/modules_libs/java.base/libzip.dylib from 20 file(s)
Creating support/modules_libs/java.base/libjimage.dylib from 6 file(s)
Creating support/modules_libs/java.base/libjli.dylib from 15 file(s)
Creating support/modules_libs/java.base/libnet.dylib from 14 file(s)
Creating support/modules_libs/java.base/libnio.dylib from 24 file(s)
Creating support/modules_libs/java.base/libosxsecurity.dylib from 1 file(s)
Creating support/modules_libs/java.base/libjsig.dylib from 1 file(s)
Creating support/modules_libs/java.base/libsyslookup.dylib from 1 file(s)
Compiling up to 15 files for jdk.management.jfr
Compiling up to 16 files for java.management.rmi
Compiling up to 211 files for java.security.jgss
Compiling up to 16 files for jdk.naming.dns
Compiling up to 8 files for jdk.naming.rmi
Compiling up to 56 files for java.sql.rowset
Compiling up to 30 files for jdk.management.agent
Compiling up to 16 files for jdk.security.jgss
Compiling up to 30 files for jdk.security.auth
Compiling up to 145 files for jdk.internal.md
Compiling up to 144 files for jdk.jdeps
Compiling up to 2715 files for java.desktop
Compiling up to 102 files for jdk.jshell
Compiling up to 213 files for jdk.javadoc
Compiling up to 95 files for jdk.jlink
Creating support/modules_libs/java.prefs/libprefs.dylib from 1 file(s)
Creating support/modules_libs/java.instrument/libinstrument.dylib from 12 file(s)
Creating support/modules_cmds/java.rmi/rmiregistry from 1 file(s)
Creating support/modules_libs/java.rmi/librmi.dylib from 1 file(s)
Creating support/modules_libs/jdk.attach/libattach.dylib from 1 file(s)
Creating support/modules_libs/java.smartcardio/libj2pcsc.dylib from 2 file(s)
Creating support/modules_cmds/java.scripting/jrunscript from 1 file(s)
Creating support/modules_cmds/jdk.hotspot.agent/jhsdb from 1 file(s)
Creating support/modules_libs/java.management/libmanagement.dylib from 9 file(s)
Creating support/modules_libs/java.security.jgss/libj2gss.dylib from 3 file(s)
Creating support/modules_cmds/jdk.compiler/javac from 1 file(s)
Creating support/modules_libs/java.security.jgss/libosxkrb5.dylib from 2 file(s)
Creating support/modules_libs/jdk.crypto.cryptoki/libj2pkcs11.dylib from 14 file(s)
Creating support/modules_cmds/jdk.compiler/serialver from 1 file(s)
Creating support/modules_cmds/java.base/java from 1 file(s)
Creating support/modules_cmds/java.base/keytool from 1 file(s)
Creating support/modules_libs/java.base/jspawnhelper from 1 file(s)
Creating support/modules_cmds/jdk.httpserver/jwebserver from 1 file(s)
Creating support/modules_cmds/jdk.javadoc/javadoc from 1 file(s)
Creating support/modules_cmds/jdk.jartool/jar from 1 file(s)
Creating support/modules_cmds/jdk.jartool/jarsigner from 1 file(s)
Creating support/modules_libs/jdk.management.agent/libmanagement_agent.dylib from 1 file(s)
Creating support/modules_libs/jdk.management/libmanagement_ext.dylib from 8 file(s)
Creating support/modules_cmds/jdk.jconsole/jconsole from 1 file(s)
Creating support/modules_cmds/jdk.jcmd/jinfo from 1 file(s)
Creating support/modules_cmds/jdk.jcmd/jmap from 1 file(s)
Creating support/modules_cmds/jdk.jcmd/jps from 1 file(s)
Creating support/modules_cmds/jdk.jcmd/jstack from 1 file(s)
Creating support/modules_cmds/jdk.jcmd/jstat from 1 file(s)
Creating support/modules_cmds/jdk.jcmd/jcmd from 1 file(s)
Creating support/modules_cmds/jdk.jdeps/javap from 1 file(s)
Creating support/modules_cmds/jdk.jdeps/jdeps from 1 file(s)
Creating support/modules_cmds/jdk.jdeps/jdeprscan from 1 file(s)
Creating support/modules_cmds/jdk.jdeps/jnativescan from 1 file(s)
Creating support/modules_cmds/jdk.jdi/jdb from 1 file(s)
Creating support/modules_libs/jdk.jdwp.agent/libdt_socket.dylib from 2 file(s)
Creating support/modules_libs/jdk.jdwp.agent/libjdwp.dylib from 43 file(s)
Creating support/modules_cmds/jdk.jfr/jfr from 1 file(s)
Creating support/modules_cmds/jdk.jpackage/jpackage from 1 file(s)
Creating support/modules_cmds/jdk.jlink/jimage from 1 file(s)
Creating support/modules_cmds/jdk.jlink/jlink from 1 file(s)
Creating support/modules_cmds/jdk.jshell/jshell from 1 file(s)
Creating support/modules_cmds/jdk.jlink/jmod from 1 file(s)
Creating support/modules_cmds/jdk.jstatd/jstatd from 1 file(s)
Creating support/modules_libs/jdk.net/libextnet.dylib from 1 file(s)
Creating support/modules_libs/jdk.security.auth/libjaas.dylib from 1 file(s)
Compiling up to 68 files for COMPILE_CREATE_SYMBOLS
Compiling up to 1 files for java.se
Compiling up to 8 files for jdk.unsupported.desktop
Compiling up to 18 files for jdk.accessibility
Compiling up to 3 files for jdk.editpad
Compiling up to 64 files for jdk.jconsole
Compiling up to 69 files for jdk.jpackage
Compiling up to 904 files for jdk.hotspot.agent
Creating jdk/modules/jdk.jpackage/jdk/jpackage/internal/resources/jpackageapplauncher from 16 file(s)
Creating support/modules_libs/java.desktop/libawt.dylib from 70 file(s)
Creating support/modules_libs/java.desktop/libawt_lwawt.dylib from 126 file(s)
Creating support/modules_libs/java.desktop/libosxapp.dylib from 6 file(s)
Creating support/modules_libs/java.desktop/libjawt.dylib from 1 file(s)
Creating support/modules_libs/java.desktop/libmlib_image.dylib from 50 file(s)
Creating support/modules_libs/java.desktop/liblcms.dylib from 27 file(s)
Creating support/modules_libs/java.desktop/libjavajpeg.dylib from 46 file(s)
Creating support/modules_libs/java.desktop/libsplashscreen.dylib from 81 file(s)
Creating support/modules_libs/java.desktop/libfreetype.dylib from 106 file(s)
Creating support/modules_libs/java.desktop/libfontmanager.dylib from 61 file(s)
Creating support/modules_libs/java.desktop/libosxui.dylib from 7 file(s)
Creating support/modules_libs/java.desktop/libjsound.dylib from 17 file(s)
Creating support/modules_libs/java.desktop/libosx.dylib from 1 file(s)
Compiling up to 4 files for COMPILE_CREATE_SYMBOLS
Creating support/modules_libs/jdk.hotspot.agent/libsaproc.dylib from 8 file(s)
Creating ct.sym classes
Compiling up to 4 files for BUILD_JIGSAW_TOOLS
Optimizing the exploded image
Stopping javac server
Finished building target 'default (exploded-image)' in configuration 'macosx-aarch64-server-release'
```

And the `java` binary behaves as expected:
```bash
[nix-shell:~/1/colata/nix-darwin]$ ./jdk/build/macosx-aarch64-server-release/jdk/bin/java --version
openjdk 25-internal 2025-09-16
OpenJDK Runtime Environment (build 25-internal-adhoc.galder.jdk)
OpenJDK 64-Bit Server VM (build 25-internal-adhoc.galder.jdk, mixed mode)
```
