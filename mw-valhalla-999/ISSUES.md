# Valhalla Preview Build Issues

Status: **Full pipeline working** — Hibernate ORM → Quarkus → Sample App → Runtime verification

## Environment

| Component | Version / Path |
|-----------|---------------|
| JDK 25 (standard) | `$JAVA_25_HOME` → `/usr/lib/jvm/java-25` |
| JDK 28 (Valhalla, compiler) | `$JAVA_28_HOME` → `~/src/jdk/build/release-linux-x86_64/images/jdk` |
| Hibernate ORM | `7.4.5.Final-custom` (tag `7.4.5`, preview branch) |
| Quarkus | `999-SNAPSHOT` |
| Gradle | 9.5.0 |
| bnd (OSGi) plugin | 7.2.1 |
| ASM | 9.10.1 |

Build command: `./build-custom-hibernate-quarkus.sh --with-preview`

---

## Issue 1 — bnd OSGi plugin: `Unrecognized stack map frame type 246` (FIXED)

**Phase:** Hibernate ORM build (Gradle `:hibernate-core:jar`)

### Symptom

```
error  : Invalid class file org/hibernate/engine/spi/EntityKey.class
         (Unrecognized stack map frame type 246)
> Bundle hibernate-core-7.4.5.Final-custom.jar has errors
```

The Gradle `:hibernate-core:jar` task fails.  The bnd OSGi bundle plugin
(v7.2.1) scans compiled class files to generate `Import-Package` /
`Export-Package` manifest headers.  Its class-file parser throws an
`IOException` when it encounters stack map frame type 246.

JDK 28 with `--enable-preview` (Valhalla value types) emits **frame type 246**
in the `StackMapTable` attribute of certain classes (e.g. `EntityKey`).  This is
a valid preview-feature bytecode extension, but bnd 7.2.1 predates it.

### Root Cause

In `aQute.bnd.classfile.StackMapTableAttribute.read()`
(biz.aQute.bnd.util-7.2.1.jar), frame types are dispatched in ranges:

```
0–63       → same_frame
64–127     → same_locals_1_stack_item_frame
128–246    → RESERVED → throws IOException     ← problem
247        → same_locals_1_stack_item_frame_extended
248–250    → chop_frame
251        → same_frame_extended
252–254    → append_frame
255        → full_frame
```

The relevant code:

```java
} else if (frame_type <= RESERVED) {  // RESERVED = 246
    throw new IOException("Unrecognized stack map frame type " + frame_type);
}
```

Frame type 246 sits at the upper boundary of the RESERVED range and is now used
by Valhalla preview bytecode.

### Approaches That Did Not Work

Before arriving at the jar-patching solution, several bnd configuration
approaches were tried:

1. **`-fixupmessages` via jar manifest attributes** — Added to the jar task's
   manifest in `enable-preview.gradle`:
   ```groovy
   jarTask.manifest {
       attributes('-fixupmessages': '"Invalid class file";is:=warning')
   }
   ```
   This successfully downgraded the "Invalid class file" message to a warning,
   but the underlying `IOException` was reported as a separate `error` line by
   bnd.  The `BundleTaskExtension$BuildAction` calls `Builder.isOk()` which
   checks the error list and still returns `false`, failing the build.

2. **`-failok: true` via manifest attributes** — Added alongside fixupmessages:
   ```groovy
   attributes('-failok': 'true')
   ```
   bnd's `-failok` instruction is supposed to make `isOk()` return `true`
   despite errors.  However, the Gradle plugin's `BuildAction` appears to
   check the error count independently, so the build still failed.

3. **`-failok` via `BundleTaskExtension.bnd()` API** — Accessed the extension
   directly from the init script:
   ```groovy
   def bundleExt = jarTask.extensions.findByName('bundle')
   if (bundleExt != null) {
       bundleExt.bnd('-failok: true')
       bundleExt.bnd('-fixupmessages: "Invalid class file";is:=warning')
   }
   ```
   Same result — `Builder.isOk()` still returned `false`.

4. **Removing the bnd `doLast("buildBundle", ...)` action from the jar task** —
   The bnd plugin registers its action in `BndBuilderPlugin.apply()` via:
   ```java
   task.doLast("buildBundle", extension.buildAction());
   ```
   Several approaches to remove this action from an init script were tried:
   - Filtering `jarTask.actions` by class name in a `doFirst` block
   - Filtering in `gradle.taskGraph.whenReady`
   - Pattern-matching on `action.toString()`

   All failed because Gradle wraps task actions in internal
   `TaskActionWrapper` objects.  The wrapper's `toString()` and `class.name`
   do not expose the original `BundleTaskExtension$BuildAction` class name,
   making pattern-based removal unreliable.

### Fix Applied — Binary Patch of bnd Jar

The fix patches `StackMapTableAttribute.class` directly in the cached bnd jars.
This is implemented in [`patch-bnd-stackmap.sh`](patch-bnd-stackmap.sh), which
is called automatically by the build script when `--with-preview` is used.

#### What the patch changes

One line in `StackMapTableAttribute.read()`:

```diff
 } else if (frame_type <= RESERVED) {
-    throw new IOException("Unrecognized stack map frame type " + frame_type);
+    entries[i] = new SameFrame(frame_type); // skip unknown Valhalla frame types
 }
```

This creates a no-op `SameFrame` entry for any reserved/unknown frame type,
allowing bnd to continue analyzing the rest of the class file.  The OSGi
metadata generation (package imports/exports) is unaffected since it depends on
the constant pool and method descriptors, not stack map frame contents.

#### How the patch is applied

The script ([`patch-bnd-stackmap.sh`](patch-bnd-stackmap.sh)) performs these
steps:

1. **Locate** all `biz.aQute.bnd.util-*.jar` files under
   `~/.gradle/caches/modules-2/` (the original downloaded artifacts).

2. **Detect** whether each jar needs patching by extracting
   `StackMapTableAttribute.class` and searching for the string literal
   `"Unrecognized stack map frame type"` in the class constant pool (using
   `unzip -p | strings | grep`).  If the string is absent, the jar is already
   patched.

3. **Extract** the embedded Java source from the jar's `OSGI-OPT/src/`
   directory.

4. **Apply** a `sed` substitution replacing the `throw new IOException(…)` line
   with `entries[i] = new SameFrame(frame_type);`.

5. **Compile** the patched source against the bnd jar (any JDK ≥ 17 works).

6. **Update** each unpatched jar in-place using `jar uf`.

7. **Clear** Gradle's instrumented-jar transform cache
   (`~/.gradle/caches/*/transforms/*/instrumented-biz.aQute.bnd.util-*.jar`).
   These are derived copies that Gradle creates from the originals; deleting
   them forces regeneration from the now-patched originals on the next build.

After patching, the Gradle daemon must be restarted (`./gradlew --stop`)
because it caches loaded classes in memory.

#### Idempotency

The script is idempotent.  On subsequent runs it detects that all jars are
already patched and exits immediately:

```
$ ./patch-bnd-stackmap.sh
    All bnd util jars already patched. Nothing to do.
```

#### Manual usage

```bash
./patch-bnd-stackmap.sh              # uses $JAVA_25_HOME or $JAVA_HOME
./patch-bnd-stackmap.sh /path/to/jdk # explicit JDK for compilation
```

### Long-Term Fix

A proper upstream fix would be for bnd to support JDK 28+ class file
extensions.  This could be:
- An update to `StackMapTableAttribute` to handle new Valhalla frame types
  with their correct structure, or
- A more lenient fallback that skips unknown frame types (similar to our patch)
- Hibernate upgrading to a newer bnd version that includes such a fix

---

## Issue 2 — Maven plugin descriptor generator: `Unsupported class file major version 72` (FIXED)

**Phase:** Hibernate ORM build (Gradle `:hibernate-maven-plugin:generateMavenPluginDescriptor`)

### Symptom

```
Execution failed for task ':hibernate-maven-plugin:generateMavenPluginDescriptor'
> Unsupported class file major version 72
```

### Root Cause

The `org.gradlex.maven-plugin-development` Gradle plugin generates Maven plugin
descriptors by inspecting compiled class files.  JDK 28 produces class files
with major version 72, which the descriptor generator does not recognize.

### Fix Applied

Added to [`enable-preview.gradle`](enable-preview.gradle):

```groovy
project.tasks.matching { it.name == 'generateMavenPluginDescriptor' }.configureEach {
    it.enabled = false
}
```

This disables the descriptor generation for preview builds.  The
`hibernate-maven-plugin` module is not critical for the library's core
functionality.

---

## Issue 3 — Quarkus: `--enable-preview` conflicts with `--release` in non-Hibernate modules (FIXED)

**Phase:** Quarkus build (Maven compilation of `quarkus-enforcer-rules` and other modules)

### Symptom

```
[ERROR] Failed to execute goal org.apache.maven.plugins:maven-compiler-plugin:3.15.0:compile
  on project quarkus-enforcer-rules: Compilation failure
```

Compiler invocation shows: `javac [forked debug deprecation parameters preview release 21]`

### Root Cause

The initial approach passed `-Dmaven.compiler.enablePreview=true` globally
across all of Quarkus, but individual modules (e.g. `quarkus-enforcer-rules`)
set `<release>21</release>`.  `javac --enable-preview` requires `--release` to
match the running JDK version (28).  When `--release 21` and `--enable-preview`
are both active, the compiler rejects the combination.

### Approaches Tried

1. **Build all of Quarkus with `--enable-preview`** — Failed because many
   modules have `<release>21</release>` or other non-28 release settings that
   conflict with `--enable-preview`.

### Fix Applied

Instead of building all of Quarkus with preview, the build now targets **only
the `extensions/hibernate-orm` module and its dependents**:

```bash
mvn install \
  -pl extensions/hibernate-orm --also-make-dependents \
  -Dmaven.compiler.enablePreview=true \
  -Dmaven.compiler.release=28 \
  ...
```

This limits the reactor to ~122 modules that actually depend on Hibernate ORM,
avoiding the conflict with unrelated modules that target older Java releases.

The rest of Quarkus is expected to have been built beforehand without preview
features (a standard `mvn install -Dquickly`).

---

## Issue 4 — impsort plugin: `No enum constant ... LanguageLevel.JAVA_28` (FIXED)

**Phase:** Quarkus build (Maven `process-sources` phase on `quarkus-hibernate-orm-parent`)

### Symptom

```
Failed to execute goal net.revelc.code:impsort-maven-plugin:1.13.0:sort
  on project quarkus-hibernate-orm-parent:
  No enum constant com.github.javaparser.ParserConfiguration.LanguageLevel.JAVA_28
```

### Root Cause

The impsort Maven plugin (import sorting) uses JavaParser internally, which
enumerates supported Java language levels.  JavaParser 3.x does not have a
`JAVA_28` enum constant, so the plugin fails when it detects the compiler
release is 28.

### Approaches Tried

1. **`-Dimpsort.skip=true`** — The plugin uses `${format.skip}` not
   `${impsort.skip}`, so this had no effect.  (The Quarkus `quickly` profile
   also does not set `format.skip=true` — only `quickly-ci` does.)

### Fix Applied

Added `-Dformat.skip=true` to the Quarkus build args for preview builds.
This skips both impsort and other formatting plugins.

---

## Issue 5 — Annotation processor: `Preview features are not enabled for hibernate-processor` (FIXED)

**Phase:** Quarkus build (Maven compilation of `quarkus-hibernate-orm-panache` and other modules using Hibernate annotation processor)

### Symptom

```
java.lang.UnsupportedClassVersionError: Preview features are not enabled
  for org/hibernate/processor/Context (class file version 72.65535).
  Try running with '--enable-preview'
```

### Root Cause

The Hibernate annotation processor (`hibernate-processor`) was compiled with
JDK 28 preview features (class file version 72.65535).  When Maven's compiler
plugin forks a javac process, the annotation processor runs inside that javac
JVM.  If the JVM doesn't have `--enable-preview`, it refuses to load the
preview-enabled class files.

The initial build command used:
- `JAVA_HOME=$JAVA_25_HOME` (standard JDK 25 runs Maven)
- `-Dmaven.compiler.fork=true -Dmaven.compiler.executable=$JAVA_28_HOME/bin/javac`

This means Maven itself ran on JDK 25, and forked JDK 28's javac for
compilation.  The forked javac received `--enable-preview` as a compiler flag,
but the **JVM running javac** did not have `--enable-preview` enabled, so it
could not load the annotation processor's preview-enabled classes.

### Approaches Tried

1. **`-J--enable-preview` via `-Dmaven.compiler.compilerArgs`** — Attempted to
   pass JVM args to the forked javac via the `-J` prefix:
   ```
   -Dmaven.compiler.compilerArgs=-J--enable-preview
   ```
   This did not work because the POM's `<compilerArgs>` list (configured in
   `independent-projects/parent/pom.xml`) takes precedence over the system
   property.  Maven's compiler plugin does not merge `<compilerArgs>` from
   both sources — the POM wins.

2. **Forked javac with `JAVA_HOME=$JAVA_28_HOME`** — Using the Valhalla JDK
   as Maven's JAVA_HOME while still forking:
   ```
   JAVA_HOME=$JAVA_28_HOME mvn ... -Dmaven.compiler.fork=true
   ```
   This still failed because the forked javac process was launched without
   `--enable-preview` as a JVM flag.  The `-Dmaven.compiler.enablePreview=true`
   flag only adds `--enable-preview` to javac's *compiler arguments*, not to
   its *JVM arguments*.

### Fix Applied

Changed the Quarkus preview build to run Maven itself on the Valhalla JDK with
`--enable-preview` in MAVEN_OPTS, **without forking**:

```bash
MAVEN_OPTS="-Xmx4g --enable-preview" JAVA_HOME=$JAVA_28_HOME mvn install \
  -Dmaven.compiler.enablePreview=true \
  -Dmaven.compiler.release=28 \
  ...
```

This ensures that:
- The Maven JVM itself runs with `--enable-preview`, so it can load any
  preview-enabled classes (including annotation processors)
- The in-process javac compiler (no fork) inherits the JVM's `--enable-preview`
  flag and can compile and process annotations correctly
- `--release 28` matches the JDK version, satisfying javac's requirement that
  `--enable-preview` must be paired with the current release

---

## Issue 6 — Kotlin modules fail with preview features (EXCLUDED)

**Phase:** Quarkus build (Kotlin compilation)

### Symptom

Various compilation failures in Kotlin-based Hibernate Panache modules.

### Root Cause

The Kotlin compiler does not support JDK 28 preview features.

### Fix Applied

The following modules are excluded from the preview build via `-pl !...`:

| Module | Reason |
|--------|--------|
| `io.quarkus:quarkus-hibernate-orm-panache-kotlin` | Kotlin compiler incompatible |
| `io.quarkus:quarkus-hibernate-orm-panache-kotlin-deployment` | Depends on above |
| `io.quarkus:quarkus-hibernate-reactive-panache-kotlin` | Kotlin compiler incompatible |
| `io.quarkus:quarkus-hibernate-reactive-panache-kotlin-deployment` | Depends on above |
| `io.quarkus:quarkus-integration-test-hibernate-orm-panache-kotlin` | Integration test for above |
| `io.quarkus:quarkus-integration-test-hibernate-reactive-panache-kotlin` | Integration test for above |
| `io.quarkus:quarkus-integration-test-mongodb-panache-kotlin` | Kotlin integration test |
| `io.quarkus:quarkus-integration-test-logging-panache-kotlin` | Kotlin integration test |

---

## Issue 7 — ASM: `Unsupported class file major version 72` (FIXED)

**Phase:** Sample app build (Quarkus augmentation / `ClassTransformingBuildStep`)

### Symptom

```
java.lang.IllegalArgumentException: Unsupported class file major version 72
  at org.objectweb.asm.ClassReader.<init>(ClassReader.java:200)
  ...
  at io.quarkus.deployment.steps.ClassTransformingBuildStep.transformClass(...)
```

The Quarkus Maven plugin's `build` goal (augmentation phase) fails when it
tries to transform Hibernate classes compiled with JDK 28.

### Root Cause

ASM 9.10.1 (used by Quarkus for bytecode transformation at build time) only
supports class file major versions up to 71 (JDK 27).  JDK 28 produces class
files with major version 72.

The version check is in `ClassReader.<init>([BIZ)`:

```
bipush 71          ; max supported class file major version
if_icmple <ok>     ; if classVersion <= 71, continue normally
new IllegalArgumentException
...
athrow             ; otherwise, throw
```

### Approaches Tried

1. **Upgrading ASM** — The latest available version (9.10.1) is already in use
   and does not support version 72.  No newer release exists.

### Fix Applied — Binary Patch of ASM Jar

The fix patches `ClassReader.class` directly in the cached ASM jars.  This is
implemented in [`patch-asm-classreader.sh`](patch-asm-classreader.sh), which is
called automatically by the build script when `--with-preview` is used.

#### What the patch changes

A single-byte change in `ClassReader.<init>`:

```diff
- bipush 71    ; 0x10 0x47 — max class version = 71 (JDK 27)
+ bipush 72    ; 0x10 0x48 — max class version = 72 (JDK 28)
```

The bytecode sequence `0x10 0x47 0xA4` (`bipush 71`, `if_icmple`) becomes
`0x10 0x48 0xA4` (`bipush 72`, `if_icmple`).  This is a direct binary patch
— no recompilation needed.

#### How the patch is applied

The script ([`patch-asm-classreader.sh`](patch-asm-classreader.sh)) performs
these steps:

1. **Locate** all `asm-*.jar` files under `~/.m2/repository/org/ow2/asm/`
   (excluding `-sources.jar` and `-javadoc.jar`).

2. **Detect** whether each jar needs patching by extracting
   `ClassReader.class` and searching for the byte sequence `0x10 0x47 0xA4`
   (`bipush 71`, `if_icmple`) using `od` and `grep`.  If the sequence is
   `0x10 0x48 0xA4` (`bipush 72`), the jar is already patched.

3. **Extract** `ClassReader.class` from the jar.

4. **Apply** the binary patch using Python: find the byte pattern
   `[0x10, 71, 0xa4]` and replace the `71` with `72`.

5. **Update** the jar in-place using `jar uf`.

#### Idempotency

The script is idempotent.  On subsequent runs it detects that all jars are
already patched and exits immediately:

```
$ ./patch-asm-classreader.sh
    All ASM jars already patched (or max version >= 72). Nothing to do.
```

#### Manual usage

```bash
./patch-asm-classreader.sh  # no arguments needed
```

### Long-Term Fix

ASM typically adds support for new class file versions in minor releases.  Once
an ASM version supporting major version 72 is released, the patch will no
longer be necessary.

---

## Issue 8 — Sample app: class file version mismatch and preview requirements (FIXED)

**Phase:** Sample app build and runtime

### Symptom (build)

```
error: cannot access org.hibernate.Version
  bad class file: hibernate-core-7.4.5.Final-custom.jar(/org/hibernate/Version.class)
    class file has wrong version 72.0, should be 69.0
```

### Symptom (test)

```
java.lang.UnsupportedClassVersionError: Preview features are not enabled for
  org/acme/hibernate/orm/FruitResourceTest (class file version 72.65535)
```

### Root Cause

The sample app (from `quarkus-quickstarts/hibernate-orm-quickstart`) defaulted
to `--release 17` for compilation.  This cannot read Hibernate classes compiled
with JDK 28 (class version 72).

Additionally, tests forked by Maven Surefire run in a separate JVM that also
needs `--enable-preview` to load preview-enabled classes.

### Fix Applied

The sample app build and run commands now use the Valhalla JDK with preview:

**Build:**
```bash
MAVEN_OPTS="-Xmx2g --enable-preview" JAVA_HOME=$JAVA_28_HOME mvn package \
    -Dmaven.compiler.enablePreview=true \
    -Dmaven.compiler.release=28 \
    -DskipTests
```

Tests are skipped during `mvn package` because Surefire's forked JVM would also
need `--enable-preview` configuration, and the quickstart's tests are not
essential for verification.

**Run:**
```bash
$JAVA_28_HOME/bin/java --enable-preview -jar target/quarkus-app/quarkus-run.jar
```

---

## Summary

| # | Issue | Phase | Status | Fix |
|---|-------|-------|--------|-----|
| 1 | bnd `StackMapTableAttribute` — frame type 246 | Hibernate build | ✅ Fixed | [`patch-bnd-stackmap.sh`](patch-bnd-stackmap.sh) |
| 2 | Maven plugin descriptor — class version 72 | Hibernate build | ✅ Fixed | [`enable-preview.gradle`](enable-preview.gradle) |
| 3 | `--enable-preview` + `--release 21` conflict | Quarkus build | ✅ Fixed | Build only hibernate-orm dependents |
| 4 | impsort JavaParser — no `JAVA_28` level | Quarkus build | ✅ Fixed | `-Dformat.skip=true` |
| 5 | Annotation processor preview class loading | Quarkus build | ✅ Fixed | `MAVEN_OPTS=--enable-preview`, no fork |
| 6 | Kotlin modules incompatible with preview | Quarkus build | ⚠️ Excluded | `-pl !...` exclusions |
| 7 | ASM `ClassReader` — class version 72 | Sample app build | ✅ Fixed | [`patch-asm-classreader.sh`](patch-asm-classreader.sh) |
| 8 | Sample app compilation & runtime | Sample app | ✅ Fixed | JDK 28 + `--enable-preview` + `-DskipTests` |

### File inventory

| File | Purpose |
|------|---------|
| [`build-custom-hibernate-quarkus.sh`](build-custom-hibernate-quarkus.sh) | Main build orchestration script |
| [`enable-preview.gradle`](enable-preview.gradle) | Gradle init script for JDK 28 preview compilation |
| [`patch-bnd-stackmap.sh`](patch-bnd-stackmap.sh) | Idempotent patch for bnd OSGi plugin (Issue 1) |
| [`patch-asm-classreader.sh`](patch-asm-classreader.sh) | Idempotent patch for ASM ClassReader (Issue 7) |
| [`ISSUES.md`](ISSUES.md) | This document |
