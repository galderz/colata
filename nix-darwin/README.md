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

```
$ export MIGCC=/nix/store/0jd4fjnnrfz0dfxbc5lgfyxjfay73i77-clang-wrapper-19.1.7/bin/cc
```

And now the following command runs fine:

```
$ /nix/store/vhsix1jn849mpxggwbw2zh1nbxpy0grc-Xcode16.2-MacOSX15/Xcode/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/mig -isysroot /nix/store/vhsix1jn849mpxggwbw2zh1nbxpy0grc-Xcode16.2-MacOSX15/Xcode/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX15.sdk -server /Users/galder/1/colata/nix-darwin/jdk/build/macosx-aarch64-server-release/support/gensrc/jdk.hotspot.agent/mach_excServer.c -user /Users/galder/1/colata/nix-darwin/jdk/build/macosx-aarch64-server-release/support/gensrc/jdk.hotspot.agent/mach_excUser.c -header /Users/galder/1/colata/nix-darwin/jdk/build/macosx-aarch64-server-release/support/gensrc/jdk.hotspot.agent/mach_exc.h /nix/store/vhsix1jn849mpxggwbw2zh1nbxpy0grc-Xcode16.2-MacOSX15/Xcode/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX15.sdk/usr/include/mach/mach_exc.defs
```

It works!

```
[nix-shell:~/1/colata/nix-darwin]$ ./jdk/build/macosx-aarch64-server-release/jdk/bin/java --version
openjdk 25-internal 2025-09-16
OpenJDK Runtime Environment (build 25-internal-adhoc.galder.jdk)
OpenJDK 64-Bit Server VM (build 25-internal-adhoc.galder.jdk, mixed mode)
```
