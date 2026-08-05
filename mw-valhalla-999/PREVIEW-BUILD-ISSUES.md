# Building Hibernate + Quarkus with JDK 28 `--enable-preview`: Issue Reference

This document catalogues every issue encountered when running
`./build-custom-hibernate-quarkus.sh --with-clean --with-preview` to compile
Hibernate ORM and Quarkus against a locally-built JDK 28 (Valhalla) with
`--enable-preview` enabled. Issues are listed in the order they were
encountered.

---

## Table of Contents

1.  [Phase 1 — Hibernate ORM (Gradle)](#phase-1--hibernate-orm-gradle)
    - [1.1  Groovy cannot handle Java 28 class files](#11-groovy-cannot-handle-java-28-class-files)
    - [1.2  Spotless `removeUnusedImports` fails with `NoClassDefFoundError`](#12-spotless-removeunusedimports-fails-with-noclassdeffounderror)
    - [1.3  Forked javac receives invalid `-D` JVM flags as compiler arguments](#13-forked-javac-receives-invalid--d-jvm-flags-as-compiler-arguments)
    - [1.4  `--release 28` conflicts with `--add-exports` for system modules](#14---release-28-conflicts-with---add-exports-for-system-modules)
    - [1.5  Checker Framework annotation processor cannot access `jdk.compiler` internals](#15-checker-framework-annotation-processor-cannot-access-jdkcompiler-internals)
    - [1.6  Annotation-processor class files compiled with preview cannot be loaded by javac JVM](#16-annotation-processor-class-files-compiled-with-preview-cannot-be-loaded-by-javac-jvm)
    - [1.7  `generateMavenPluginDescriptor` task fails with `Unsupported class file major version 72`](#17-generatemaveplugindescriptor-task-fails-with-unsupported-class-file-major-version-72)
2.  [Phase 1½ — Preview-flag stripping](#phase-1½--preview-flag-stripping)
    - [1.8  Hibernate preview class files poison every downstream consumer](#18-hibernate-preview-class-files-poison-every-downstream-consumer)
3.  [Phase 2 — Quarkus (Maven)](#phase-2--quarkus-maven)
    - [2.1  `impsort-maven-plugin` — `No enum constant … JAVA_28`](#21-impsort-maven-plugin--no-enum-constant--java_28)
    - [2.2  `maven-compiler-plugin` — ASM `Unsupported class file major version 72`](#22-maven-compiler-plugin--asm-unsupported-class-file-major-version-72)
    - [2.3  `maven-compiler-plugin` — `patchJdkModuleVersion` ASM failure on `module-info.class`](#23-maven-compiler-plugin--patchjdkmoduleversion-asm-failure-on-module-infoclass)
    - [2.4  javac refuses to read Hibernate's preview-flagged class files](#24-javac-refuses-to-read-hibernates-preview-flagged-class-files)
    - [2.5  Kotlin `kapt` — `tools.jar is absent in the plugin classpath`](#25-kotlin-kapt--toolsjar-is-absent-in-the-plugin-classpath)
    - [2.6  Kotlin compiler — `No class roots are found in the JDK path`](#26-kotlin-compiler--no-class-roots-are-found-in-the-jdk-path)
    - [2.7  `sisu-maven-plugin` — `Unsupported class file major version 72` scanning JDK system classes](#27-sisu-maven-plugin--unsupported-class-file-major-version-72-scanning-jdk-system-classes)
    - [2.8  Kotlin test compilation fails on custom JDK](#28-kotlin-test-compilation-fails-on-custom-jdk)

---

## Phase 1 — Hibernate ORM (Gradle)

### 1.1 Groovy cannot handle Java 28 class files

| | |
|---|---|
| **When** | Gradle evaluates the `local-build-plugins` included build |
| **Build tool** | Gradle 9.5 / Groovy (bundled) |

**Error message:**

```
> Task :local-build-plugins:compileGroovy FAILED
BUG! exception in phase 'semantic analysis' in source unit
  '/…/local-build-plugins/src/main/groovy/CompilerStubsArgumentProvider.groovy'
  Unsupported class file major version 72
```

**Root cause:**

When `JAVA_HOME` points to JDK 28, Gradle's daemon runs on JDK 28 and the
Groovy compiler bundled with Gradle attempts to analyse class files produced by
that JDK. The Groovy runtime embedded in Gradle 9.5 uses an ASM version that
does not recognise major version 72 (Java 28). The `local-build-plugins`
project contains `.groovy` source files whose semantic analysis triggers this
code path.

**Fix — run Gradle on JDK 25, fork compilation to JDK 28:**

```bash
# build-custom-hibernate-quarkus.sh
build_args+=(-Dorg.gradle.java.home=$JAVA_25_HOME)
```

The Gradle daemon runs on JDK 25 (whose class files Groovy can read). The
init script `enable-preview.gradle` then configures every `JavaCompile` task
to fork to JDK 28's javac:

```groovy
// enable-preview.gradle
options.fork = true
options.forkOptions.javaHome = file(jdk28Home)
```

Additionally, the init script explicitly skips the `local-build-plugins`
project so that none of its tasks are reconfigured:

```groovy
if (project.path.startsWith(':local-build-plugins') || project.name == 'local-build-plugins') {
    return
}
```

---

### 1.2 Spotless `removeUnusedImports` fails with `NoClassDefFoundError`

| | |
|---|---|
| **When** | `spotlessJavaApply` tasks on `hibernate-graalvm`, `hibernate-agroal`, `hibernate-hikaricp` |
| **Build tool** | Gradle / Spotless plugin / Google `com.google.common.base.Predicate` |

**Error message:**

```
> Task :hibernate-graalvm:spotlessJavaApply FAILED
> There were 5 lint error(s), they must be fixed or suppressed.
  src/main/java/…/GraalVMStaticFeature.java:LINE_UNDEFINED
    removeUnusedImports(java.lang.NoClassDefFoundError)
    com/google/common/base/Predicate (…)
```

**Root cause:**

The Spotless plugin's `removeUnusedImports` step uses Google's `google-java-format`
library under the hood, which depends on `com.google.common.base.Predicate`.
Running on JDK 25 (after fix 1.1), the combination of JDK version and Guava
version available to the Spotless plugin causes a `NoClassDefFoundError`
during import analysis.

**Fix — skip all Spotless tasks:**

```bash
# build-custom-hibernate-quarkus.sh
build_args+=(-x spotlessApply -x spotlessCheck -x spotlessJava \
             -x spotlessJavaApply -x spotlessJavaCheck)
```

Spotless is a code-formatting lint tool. Skipping it has no effect on the
compiled output.

---

### 1.3 Forked javac receives invalid `-D` JVM flags as compiler arguments

| | |
|---|---|
| **When** | `:hibernate-core:compileJava` |
| **Build tool** | Gradle `JavaCompile` task with `forkOptions.javaHome` |

**Error message:**

```
> Task :hibernate-core:compileJava FAILED
error: invalid flag: -Dlog4j2.disableJmx=true
Usage: javac <options> <source files>
```

**Root cause:**

Hibernate's `JavaModulePlugin` (in `local-build-plugins`) adds JVM arguments
such as `-Dlog4j2.disableJmx=true` and `-Xmx2g` to `forkOptions.jvmArgs` via
its `addJvmArgs()` helper method. When using `forkOptions.javaHome`, Gradle
invokes `<javaHome>/bin/javac` directly and passes `forkOptions.jvmArgs` as
command-line arguments. Gradle auto-prefixes recognised patterns (like `-X…`)
with `-J` for javac, but does **not** auto-prefix `-D…` flags. The bare
`-Dlog4j2.disableJmx=true` is therefore passed directly to javac, which
rejects it as an unknown compiler flag.

**Fix — replace `forkOptions.jvmArgs` entirely:**

```groovy
// enable-preview.gradle
options.forkOptions.jvmArgs = jdkCompilerExports.collect()
```

The init script runs in `gradle.projectsEvaluated {}` and registers a
`configureEach` action that executes **after** `JavaModulePlugin`'s own
`configureEach` action. By replacing `jvmArgs` with only the arguments we
need (module exports, `--enable-preview`), the problematic `-D` and `-X` flags
from the Hibernate build plugin are discarded.

---

### 1.4 `--release 28` conflicts with `--add-exports` for system modules

| | |
|---|---|
| **When** | `:hibernate-core:compileJava` |
| **Build tool** | JDK 28 javac |

**Error message:**

```
error: exporting a package from system module jdk.compiler is not allowed with --release
error: exporting a package from system module jdk.compiler is not allowed with --release
…(9 errors)
```

**Root cause:**

The `--release N` javac flag activates cross-compilation mode, which restricts
the API surface to exactly what was available in release N and disallows
`--add-exports` directives that expose internal packages from system modules.
The Hibernate build (via the Checker Framework Gradle plugin) adds
`--add-exports jdk.compiler/…=ALL-UNNAMED` to the compiler arguments so that
annotation processors can access `com.sun.tools.javac.*` classes. These two
flags are mutually exclusive.

**Fix — use `sourceCompatibility`/`targetCompatibility` instead of `release`:**

```groovy
// enable-preview.gradle
options.release.set(null as Integer)
sourceCompatibility = "${previewVersion}"   // "28"
targetCompatibility = "${previewVersion}"   // "28"
```

Unlike `--release`, the `-source`/`-target` flags do not enforce system-module
export restrictions, so `--add-exports` directives are permitted alongside them.

---

### 1.5 Checker Framework annotation processor cannot access `jdk.compiler` internals

| | |
|---|---|
| **When** | `:hibernate-core:compileJava` |
| **Build tool** | JDK 28 javac / Checker Framework 3.x |

**Error message:**

```
An annotation processor threw an uncaught exception.
java.lang.IllegalAccessError: class org.checkerframework.javacutil.AbstractTypeProcessor
  (in unnamed module @0x…) cannot access class
  com.sun.tools.javac.processing.JavacProcessingEnvironment (in module jdk.compiler)
  because module jdk.compiler does not export
  com.sun.tools.javac.processing to unnamed module @0x…
```

**Root cause:**

The Checker Framework's `AbstractTypeProcessor.init()` method accesses
`com.sun.tools.javac.processing.JavacProcessingEnvironment`, which is an
internal class in the `jdk.compiler` module. JDK 28's strong encapsulation
blocks this access unless the module is explicitly opened. The
`--add-exports` directives set via Hibernate's Checker Framework plugin are
added as `--add-exports` javac compiler flags (affecting the *compiled code's*
module view), but the annotation processor runs inside javac's own JVM, which
needs JVM-level `--add-exports` to open the packages.

When Gradle uses `forkOptions.javaHome`, it invokes
`<javaHome>/bin/javac` and passes `forkOptions.jvmArgs` as command-line
arguments. The key insight is that **Gradle does not auto-prefix
`forkOptions.jvmArgs` with `-J`** — it passes them verbatim. The javac binary
only recognises arguments prefixed with `-J` as JVM flags; everything else is
treated as a compiler argument. This means `--add-exports=…` in `jvmArgs` is
passed as a regular javac argument (affecting compilation), not as a JVM
argument (affecting javac's own runtime).

**Fix — manually prefix each JVM arg with `-J`:**

```groovy
def jdkCompilerExports = [
    '-J--add-exports=jdk.compiler/com.sun.tools.javac.processing=ALL-UNNAMED',
    '-J--add-exports=jdk.compiler/com.sun.tools.javac.api=ALL-UNNAMED',
    '-J--add-exports=jdk.compiler/com.sun.tools.javac.code=ALL-UNNAMED',
    '-J--add-exports=jdk.compiler/com.sun.tools.javac.comp=ALL-UNNAMED',
    '-J--add-exports=jdk.compiler/com.sun.tools.javac.file=ALL-UNNAMED',
    '-J--add-exports=jdk.compiler/com.sun.tools.javac.main=ALL-UNNAMED',
    '-J--add-exports=jdk.compiler/com.sun.tools.javac.model=ALL-UNNAMED',
    '-J--add-exports=jdk.compiler/com.sun.tools.javac.tree=ALL-UNNAMED',
    '-J--add-exports=jdk.compiler/com.sun.tools.javac.util=ALL-UNNAMED',
    '-J--add-exports=jdk.compiler/com.sun.tools.javac.type=ALL-UNNAMED',
    '-J--add-opens=jdk.compiler/com.sun.tools.javac.comp=ALL-UNNAMED',
]
```

Each entry must be a **single string** with the `=` form (e.g.
`-J--add-exports=jdk.compiler/…=ALL-UNNAMED`). If split into two list elements
(`--add-exports`, `jdk.compiler/…`), Gradle treats them as separate arguments
and neither gets the `-J` prefix, so both are passed to javac as regular
compiler flags rather than JVM flags.

The actual javac command line produced by Gradle was verified via `--info`:

```
/…/jdk/bin/javac -J-Xmx896m \
  -J--add-exports=jdk.compiler/com.sun.tools.javac.processing=ALL-UNNAMED \
  -J--add-exports=jdk.compiler/com.sun.tools.javac.api=ALL-UNNAMED \
  …
```

---

### 1.6 Annotation-processor class files compiled with preview cannot be loaded by javac JVM

| | |
|---|---|
| **When** | `:hibernate-envers:compileJava`, `:hibernate-testing:compileJava` |
| **Build tool** | JDK 28 javac |

**Error message:**

```
java.lang.UnsupportedClassVersionError: Preview features are not enabled for
  org/hibernate/processor/Context (class file version 72.65535).
  Try running with '--enable-preview'
```

**Root cause:**

The `hibernate-processor` module is compiled earlier in the reactor with
`--enable-preview`, producing class files with major version 72 and minor
version 65535 (the preview flag). When downstream modules like
`hibernate-envers` compile, javac discovers `hibernate-processor` as an
annotation processor on the processor path. javac loads the processor classes
into its own JVM — but the JVM was not started with `--enable-preview`, so it
refuses to load class files that have the preview flag set.

**Fix — add `-J--enable-preview` to the forked javac JVM args:**

```groovy
def jdkCompilerExports = [
    // … module exports …
    '-J--enable-preview',
]
```

This ensures the JVM process running javac has `--enable-preview` enabled,
allowing it to load annotation-processor class files that were compiled with
preview features.

---

### 1.7 `generateMavenPluginDescriptor` task fails with `Unsupported class file major version 72`

| | |
|---|---|
| **When** | `:hibernate-maven-plugin:generateMavenPluginDescriptor` |
| **Build tool** | Gradle / `org.gradlex.maven-plugin-development` plugin |

**Error message:**

```
> Task :hibernate-maven-plugin:generateMavenPluginDescriptor FAILED
> Unsupported class file major version 72
```

**Root cause:**

The `generateMavenPluginDescriptor` task, registered by the
`org.gradlex.maven-plugin-development` Gradle plugin, runs inside the Gradle
daemon JVM (JDK 25). It scans the compiled class files of
`hibernate-maven-plugin` to generate a Maven plugin descriptor. Since those
class files were compiled with JDK 28 `--enable-preview` (version 72.65535),
the ASM library used by the plugin (running on JDK 25) cannot read them.

**Fix — skip the task:**

```bash
# build-custom-hibernate-quarkus.sh
build_args+=(-x generateMavenPluginDescriptor)
```

The Maven plugin descriptor is not needed for `publishToMavenLocal` consumers
of the Hibernate libraries.

---

## Phase 1½ — Preview-flag stripping

### 1.8 Hibernate preview class files poison every downstream consumer

| | |
|---|---|
| **When** | Between Phase 1 and Phase 2 |
| **Affects** | Every tool that reads Hibernate's published JARs |

**The fundamental problem:**

Compiling Hibernate with `--enable-preview` on JDK 28 produces class files
with:

- **Major version:** 72 (Java 28)
- **Minor version:** 65535 (0xFFFF — the preview flag)

Any tool reading these class files must:

1. Have an ASM version supporting major version 72 — **no released ASM version
   does** (ASM 9.9.1, the latest, supports up to major version 69 / Java 25).
2. Run on a JVM with `--enable-preview` enabled if they try to *load* the
   classes.

This creates a cascading incompatibility: javac refuses to read the class
files without `--enable-preview`, but enabling `--enable-preview` forces the
*output* to also be version 72.65535, breaking every Maven plugin that uses
ASM to scan those output files (sisu, maven-compiler-plugin module detection,
etc.).

**Fix — strip the preview flag from Hibernate JARs after publishing:**

```bash
# build-custom-hibernate-quarkus.sh (after publishToMavenLocal)
find . -name "*.class" | while read classfile; do
    minor=$(od -An -tx1 -j4 -N2 "$classfile" | tr -d ' ')
    if [[ "$minor" == "ffff" ]]; then
        printf '\x00\x00' | dd of="$classfile" bs=1 seek=4 count=2 conv=notrunc 2>/dev/null
    fi
done
```

A Java class file's header is:

| Offset | Size | Field |
|--------|------|-------|
| 0 | 4 bytes | Magic number (`0xCAFEBABE`) |
| 4 | 2 bytes | Minor version (`0xFFFF` for preview, `0x0000` for normal) |
| 6 | 2 bytes | Major version (`0x0048` = 72 for Java 28) |

The script patches bytes 4–5 from `0xFFFF` to `0x0000` in every `.class` file
inside every Hibernate JAR in `~/.m2/repository/org/hibernate/orm/`. After
patching:

- **Major version** remains 72 — the class files are still "Java 28".
- **Minor version** becomes 0 — the preview flag is removed.

This means javac can read them **without** `--enable-preview`. Quarkus can
then compile against Hibernate's APIs with its default `--release 21` setting.
The actual preview *features* (e.g. Valhalla value classes) are still present
in the bytecode and available at runtime when the application is started with
`--enable-preview`.

---

## Phase 2 — Quarkus (Maven)

### 2.1 `impsort-maven-plugin` — `No enum constant … JAVA_28`

| | |
|---|---|
| **When** | `sort-imports` execution on `quarkus-enforcer-rules` |
| **Build tool** | Maven / `impsort-maven-plugin` 1.13.0 / JavaParser |

**Error message:**

```
[ERROR] Failed to execute goal net.revelc.code:impsort-maven-plugin:1.13.0:sort
  (sort-imports) on project quarkus-enforcer-rules:
  Execution sort-imports of goal …:sort failed:
  No enum constant com.github.javaparser.ParserConfiguration.LanguageLevel.JAVA_28
```

**Root cause:**

The `impsort-maven-plugin` uses JavaParser to parse Java source files for
import sorting. It reads the `maven.compiler.source` property (which inherits
from `maven.compiler.release`) to determine the parser's language level. When
`maven.compiler.release=28` is set globally, the plugin constructs the enum
value `ParserConfiguration.LanguageLevel.JAVA_28` — which does not exist in
the JavaParser version (3.x) bundled with impsort 1.13.0.

This error occurs during **Mojo field injection** (before the `skip` flag is
even checked), so `-Dimpsort.skip=true` does not help.

**Fix (attempt that was superseded):**

```bash
build_args+=(-Dimpsort.compliance=21)   # override the compliance level
build_args+=(-Dmaven.compiler.release=28)
```

**Actual fix (superseding):** The entire approach of setting
`maven.compiler.release=28` and `maven.compiler.enablePreview=true` on the
Quarkus build was abandoned (see [1.8](#18-hibernate-preview-class-files-poison-every-downstream-consumer)).
Quarkus is built with its default `--release 21` on JDK 28, so this issue no
longer arises.

---

### 2.2 `maven-compiler-plugin` — ASM `Unsupported class file major version 72`

| | |
|---|---|
| **When** | `compile` goal on `arc` module (and any module producing class files) |
| **Build tool** | Maven / `maven-compiler-plugin` 3.15.0 / ASM 9.9.1 |

**Error message:**

```
[ERROR] Failed to execute goal
  org.apache.maven.plugins:maven-compiler-plugin:3.15.0:compile
  (default-compile) on project arc:
  Execution default-compile … failed: Unsupported class file major version 72
```

**Root cause:**

When `maven.compiler.release=28` and `maven.compiler.enablePreview=true` are
set, the maven-compiler-plugin compiles source code to class file version
72.65535. After compilation, the plugin performs several post-processing steps
that use ASM to read the compiled class files:

- JPMS module name detection (scanning dependency JARs)
- `patchJdkModuleVersion` (patching `module-info.class`)
- Incremental compilation change detection

ASM 9.9.1 (the version used by maven-compiler-plugin 3.15.0) supports up to
major version 69 (Java 25). Major version 72 triggers
`IllegalArgumentException: Unsupported class file major version 72`.

This error occurs even when running Maven on JDK 28 — the issue is the ASM
*library*, not the JVM.

**Fix:** Abandoned the approach of compiling Quarkus with `--enable-preview`.
See [1.8](#18-hibernate-preview-class-files-poison-every-downstream-consumer).

---

### 2.3 `maven-compiler-plugin` — `patchJdkModuleVersion` ASM failure on `module-info.class`

| | |
|---|---|
| **When** | `compile` goal on `arc` (which has a `module-info.java`) |
| **Build tool** | Maven / `maven-compiler-plugin` 3.15.0 / `ModuleInfoTransformer` |

**Error message:**

```
Caused by: java.lang.IllegalArgumentException: Unsupported class file major version 72
  at org.apache.maven.plugin.compiler.ModuleInfoTransformer.transform (ModuleInfoTransformer.java:45)
  at org.apache.maven.plugin.compiler.AbstractCompilerMojo.patchJdkModuleVersion (AbstractCompilerMojo.java:1922)
```

**Root cause:**

After a successful `javac` invocation, `maven-compiler-plugin` checks whether
the compiled output contains a `module-info.class`. If so, it reads the file
with ASM to patch the JDK module version (derived from `${project.version}`).
The `arc` runtime module has a `module-info.java`, so when compiled with
`--release 28`, the output `module-info.class` is version 72 — which ASM
cannot read.

This is a **post-compilation** step (the stack trace shows it's called from
`executeReal` after the compiler returns success). It is controlled by the
`patchJdkModuleVersion` private method, which checks:

1. Compilation was successful
2. A `module-info.java` exists in the source set
3. A `module-info.class` exists in the output directory

There is no configuration property to disable this step.

**Fix:** Abandoned the approach of compiling Quarkus with `--release 28`.
See [1.8](#18-hibernate-preview-class-files-poison-every-downstream-consumer).

---

### 2.4 javac refuses to read Hibernate's preview-flagged class files

| | |
|---|---|
| **When** | `compile` goal on `quarkus-hibernate-orm` |
| **Build tool** | JDK 28 javac (via maven-compiler-plugin) |

**Error message:**

```
[ERROR] /…/FastBootHibernatePersistenceProvider.java:
  class file for /…/hibernate-core-7.4.5.Final-custom.jar
  (/org/hibernate/service/internal/ProvidedService.class)
  uses preview features of Java SE 28.
  (use --enable-preview to allow loading of class files which contain preview features)
```

**Root cause:**

Hibernate's published class files have minor version `0xFFFF` (the preview
flag). JDK 28's javac, when compiling Quarkus modules that reference Hibernate
classes, encounters these flagged class files on the classpath and refuses to
read them unless the current compilation also uses `--enable-preview`. But
enabling `--enable-preview` produces version 72.65535 output, which triggers
issues [2.2](#22-maven-compiler-plugin--asm-unsupported-class-file-major-version-72) and [2.3](#23-maven-compiler-plugin--patchjdkmoduleversion-asm-failure-on-module-infoclass).

**Fix — strip the preview flag from Hibernate JARs:**

See [1.8](#18-hibernate-preview-class-files-poison-every-downstream-consumer).
After stripping, Hibernate's class files have minor version `0x0000`, so javac
reads them without requiring `--enable-preview`. Quarkus compiles with its
default `--release 21`, producing version 65 class files that all tooling can
handle.

---

### 2.5 Kotlin `kapt` — `tools.jar is absent in the plugin classpath`

| | |
|---|---|
| **When** | `kapt` goal on `quarkus-hibernate-orm-panache-kotlin` |
| **Build tool** | Maven / `kotlin-maven-plugin` 2.4.0 |

**Error message:**

```
[ERROR] [kapt] 'com.sun.tools.javac.util.Context' class can't be found
  ('tools.jar' is absent in the plugin classpath). Kapt won't work.
[ERROR] Failed to execute goal
  org.jetbrains.kotlin:kotlin-maven-plugin:2.4.0:kapt (kapt)
  on project quarkus-hibernate-orm-panache-kotlin: Compilation failure
```

**Root cause:**

Kotlin's `kapt` (Kotlin Annotation Processing Tool) needs access to
`com.sun.tools.javac.util.Context` and other `jdk.compiler` internal classes.
In JDK 9+, `tools.jar` was removed; these classes live in the `jdk.compiler`
module. Kotlin 2.4.0's kapt attempts to locate `tools.jar` or its equivalent
from the JDK path and fails on the custom JDK 28 build. This appears to be a
compatibility gap between Kotlin 2.4.0's kapt and JDK 28.

Pointing `kotlin.compiler.jdkHome` to JDK 25 was attempted but also failed
because kapt then couldn't reconcile the JDK 25 tools with the JDK 28 Maven
runtime environment.

**Fix — exclude the two Kotlin Panache modules that use kapt:**

```bash
EXCL_MODS+=",!io.quarkus:quarkus-hibernate-orm-panache-kotlin-parent"
EXCL_MODS+=",!io.quarkus:quarkus-hibernate-orm-panache-kotlin"
EXCL_MODS+=",!io.quarkus:quarkus-hibernate-orm-panache-kotlin-deployment"
EXCL_MODS+=",!io.quarkus:quarkus-hibernate-reactive-panache-kotlin-parent"
EXCL_MODS+=",!io.quarkus:quarkus-hibernate-reactive-panache-kotlin"
EXCL_MODS+=",!io.quarkus:quarkus-hibernate-reactive-panache-kotlin-deployment"
```

These are Kotlin-specific Panache extensions not needed for the Hibernate ORM
preview test. Only two Quarkus modules use kapt (confirmed with
`find . -name "pom.xml" -exec grep -l "kapt" {} \;`). Module exclusions must
use **artifact IDs** (`groupId:artifactId` format), not directory paths,
because Maven's `-pl` path-based exclusion only removes the referenced POM
from the reactor but not its child modules.

---

### 2.6 Kotlin compiler — `No class roots are found in the JDK path`

| | |
|---|---|
| **When** | `compile` goal on `quarkus-messaging-kotlin` |
| **Build tool** | Maven / `kotlin-maven-plugin` 2.4.0 |

**Error message:**

```
[ERROR] Failed to execute goal
  org.jetbrains.kotlin:kotlin-maven-plugin:2.4.0:compile (compile)
  on project quarkus-messaging-kotlin: Compilation failure
  No class roots are found in the JDK path:
  /home/…/jdk/build/release-linux-x86_64/jdk
```

**Root cause:**

The custom JDK 28 was built with `make` (not `make images`), producing an
**exploded module** layout:

```
jdk/
  modules/
    java.base/
    java.compiler/
    …
```

The standard JDK layout produced by `make images` is:

```
jdk/
  lib/
    modules    ← single jimage file
```

The Kotlin compiler expects the `lib/modules` jimage file to discover JDK
class roots. When it finds only the `modules/` directory of exploded class
files, it reports "No class roots are found."

**Fix — build JDK images and use the images path:**

```bash
cd /home/…/src/jdk && make images CONF=release-linux-x86_64
```

Then point the Quarkus build at the images JDK:

```bash
QUARKUS_JAVA_HOME=$(cd "$JAVA_28_HOME/../images/jdk" && pwd)
```

The `images/jdk` directory has the standard layout with `lib/modules`, which
the Kotlin compiler (and other tools like Gradle's toolchain detection) can
read.

---

### 2.7 `sisu-maven-plugin` — `Unsupported class file major version 72` scanning JDK system classes

| | |
|---|---|
| **When** | `main-index` goal on `quarkus-maven-plugin` and `quarkus-config-doc-maven-plugin` |
| **Build tool** | Maven / `sisu-maven-plugin` 1.0.1 / ASM |

**Error message:**

```
[ERROR] Failed to execute goal
  org.eclipse.sisu:sisu-maven-plugin:1.0.1:main-index (index-project)
  on project quarkus-maven-plugin:
  Execution index-project … failed:
  Problem scanning file:…/PrepareMojo.class:
  Problem scanning jrt:/java.base/java/lang/Deprecated.class:
  Unsupported class file major version 72
```

**Root cause:**

The `sisu-maven-plugin` scans compiled Maven plugin classes to build a
component index (`META-INF/sisu/javax.inject.Named`). During scanning, it
follows annotation references back to the JDK system modules via the `jrt:`
filesystem. When Maven runs on JDK 28, the system classes at
`jrt:/java.base/java/lang/Deprecated.class` have major version 72, which
ASM (bundled with sisu 1.0.1) cannot read.

The sisu-maven-plugin has **no skip property** — there is no
`-Dsisu.skip=true` or equivalent.

This issue affects only modules that are Maven plugins themselves
(`quarkus-maven-plugin`, `quarkus-config-doc-maven-plugin`). Regular library
modules are not affected.

**Fix — exclude the affected Maven plugin modules:**

```bash
EXCL_MODS+=",!io.quarkus:quarkus-maven-plugin"
EXCL_MODS+=",!io.quarkus:quarkus-config-doc-maven-plugin"
```

These are developer tooling plugins not needed for the Hibernate ORM preview
runtime test.

---

### 2.8 Kotlin test compilation fails on custom JDK

| | |
|---|---|
| **When** | `test-compile` on various Kotlin modules |
| **Build tool** | Maven / `kotlin-maven-plugin` 2.4.0 |

**Error message:**

```
[ERROR] Failed to execute goal
  org.jetbrains.kotlin:kotlin-maven-plugin:2.4.0:test-compile (test-compile)
  on project arc-tests: Compilation failure
  No class roots are found in the JDK path: /…/jdk
```

**Root cause:**

Same as [2.6](#26-kotlin-compiler--no-class-roots-are-found-in-the-jdk-path) —
the Kotlin compiler cannot find JDK class roots — but for test compilation
specifically.

**Fix — skip test compilation entirely:**

```bash
build_args+=(-Dmaven.test.skip=true)
```

This is stronger than `-DskipTests` (which only skips test *execution*).
`-Dmaven.test.skip=true` also skips test *compilation*, preventing the Kotlin
test-compile goal from running at all.

---

## Summary of all modified files

| File | Changes |
|------|---------|
| `enable-preview.gradle` | Complete rewrite: skip `local-build-plugins`; use `source`/`target` instead of `release`; set `forkOptions.javaHome` to JDK 28; replace `forkOptions.jvmArgs` with `-J`-prefixed `--add-exports` and `--enable-preview`; clear inherited JVM args |
| `build-custom-hibernate-quarkus.sh` | Run Gradle on JDK 25 with fork to JDK 28; skip spotless/generateMavenPluginDescriptor; post-process Hibernate JARs to strip preview flag; run Maven on JDK 28 images build; skip test compilation; exclude kapt Kotlin modules, Maven plugin modules |

## Environment

| Component | Version |
|-----------|---------|
| JDK 28 (custom Valhalla build) | `28-internal-adhoc` |
| JDK 25 (standard) | `/usr/lib/jvm/java-25` |
| Gradle | 9.5.0 |
| Maven | 3.9.16 |
| Hibernate ORM | 7.4.5 (tag `7.4.5`) |
| Quarkus | `999-SNAPSHOT` (main branch) |
| Kotlin | 2.4.0 |
| ASM | 9.9.1 (latest available) |
| Groovy | bundled with Gradle 9.5 |
