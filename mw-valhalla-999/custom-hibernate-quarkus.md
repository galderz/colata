# Custom Hibernate ORM + Quarkus Build

## What was done

Built Hibernate ORM from source with a custom version marker, built Quarkus against it, and created a sample Quarkus application that proves the custom Hibernate ORM is in use.

### Artifacts produced

- **Hibernate ORM 7.3.3.Final-custom** installed in `~/.m2/repository/org/hibernate/orm/`
- **Quarkus 999-SNAPSHOT** installed in `~/.m2/repository/io/quarkus/`, referencing the custom Hibernate ORM
- **Sample app** at `/home/agentuser/sample-app` with a `/hibernate-version` endpoint that returns the Hibernate version string

### Verification results

| Method | Result |
|--------|--------|
| `curl http://localhost:8080/hibernate-version` | `Hibernate ORM Version: 7.3.3.Final-custom [CUSTOM-BUILD-MARKER]` |
| `mvn dependency:tree \| grep hibernate-core` | `org.hibernate.orm:hibernate-core:jar:7.3.3.Final-custom:compile` |
| Quarkus startup log | `powered by Quarkus 999-SNAPSHOT` with `hibernate-orm` feature installed |

---

## Steps to reproduce

### Prerequisites

- JDK 25 (required by Hibernate ORM main/7.3 branches)
- Maven 3.9+
- Gradle (bundled via wrapper in the Hibernate ORM repo)
- Repos cloned at `/home/agentuser/hibernate-orm`, `/home/agentuser/quarkus`, `/home/agentuser/quarkus-quickstarts`

### Step 1: Build custom Hibernate ORM

Quarkus `main` expects Hibernate ORM `7.3.3.Final` (set in `quarkus/pom.xml` property `hibernate-orm.version`). The Hibernate ORM `main` branch is at `8.0.0-SNAPSHOT` which is API-incompatible, so we must use a matching version.

```bash
cd /home/agentuser/hibernate-orm

# Checkout the tag that matches what Quarkus expects
git checkout 7.3.3

# Change the version to a custom identifier
# File: gradle/version.properties
# Change: hibernateVersion=7.3.3.Final -> hibernateVersion=7.3.3.Final-custom
```

Optionally, add a marker to prove the custom build is being loaded at runtime. Edit `hibernate-core/src/main/java/org/hibernate/Version.java` and modify `getVersionString()` (not `initVersion()` — the build's `version-injection` Gradle plugin overwrites `initVersion()` bytecode):

```java
public static String getVersionString() {
    return VERSION + " [CUSTOM-BUILD-MARKER]";
}
```

Build and install to the local Maven repository:

```bash
./gradlew publishToMavenLocal -x test -x javadoc --no-build-cache
```

Verify:

```bash
ls ~/.m2/repository/org/hibernate/orm/hibernate-core/7.3.3.Final-custom/
```

### Step 2: Build Quarkus with the custom Hibernate ORM

Update the Hibernate ORM version property in `quarkus/pom.xml` (line 74):

```xml
<!-- was: <hibernate-orm.version>7.3.3.Final</hibernate-orm.version> -->
<hibernate-orm.version>7.3.3.Final-custom</hibernate-orm.version>
```

No other version properties need changing — the transitive dependency versions (antlr, bytebuddy, hibernate-models, geolatte, Jakarta APIs) all match between Hibernate ORM 7.3.3 and what Quarkus expects.

Build Quarkus:

```bash
cd /home/agentuser/quarkus
MAVEN_OPTS="-Xmx4g" mvn clean install -DskipTests -DskipDocs -Dquickly \
  -Dinvoker.skip -DskipExtensionValidation -Dskip.gradle.tests \
  -Dskip.gradle.build -Dtruststore.skip -Dinsecure.repositories=WARN
```

Verify the BOM references the custom version:

```bash
grep "7.3.3.Final-custom" ~/.m2/repository/io/quarkus/quarkus-bom/999-SNAPSHOT/quarkus-bom-999-SNAPSHOT.pom
```

### Step 3: Create and run a sample application

Copy the hibernate-orm quickstart:

```bash
cp -r /home/agentuser/quarkus-quickstarts/hibernate-orm-quickstart /home/agentuser/sample-app
```

Edit `sample-app/pom.xml`:

1. Point to the local Quarkus build:
   ```xml
   <quarkus.platform.group-id>io.quarkus</quarkus.platform.group-id>
   <quarkus.platform.version>999-SNAPSHOT</quarkus.platform.version>
   ```
2. Replace `quarkus-jdbc-postgresql` with `quarkus-jdbc-h2` (no external DB needed)
3. Remove the explicit `<source>11</source><target>11</target>` from the compiler plugin (the `<maven.compiler.release>17</maven.compiler.release>` property is sufficient)

Replace `src/main/resources/application.properties`:

```properties
quarkus.datasource.db-kind=h2
quarkus.datasource.jdbc.url=jdbc:h2:mem:testdb
quarkus.hibernate-orm.schema-management.strategy=drop-and-create
quarkus.hibernate-orm.log.sql=true
quarkus.hibernate-orm.sql-load-script=import.sql
```

Add a version endpoint at `src/main/java/org/acme/hibernate/orm/HibernateVersionResource.java`:

```java
package org.acme.hibernate.orm;

import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;

@Path("/hibernate-version")
public class HibernateVersionResource {

    @GET
    @Produces(MediaType.TEXT_PLAIN)
    public String getVersion() {
        return "Hibernate ORM Version: " + org.hibernate.Version.getVersionString();
    }
}
```

Build and run:

```bash
cd /home/agentuser/sample-app
mvn package -DskipTests
java -jar target/quarkus-app/quarkus-run.jar
```

Verify:

```bash
curl http://localhost:8080/hibernate-version
# Expected: Hibernate ORM Version: 7.3.3.Final-custom [CUSTOM-BUILD-MARKER]

mvn dependency:tree | grep hibernate-core
# Expected: org.hibernate.orm:hibernate-core:jar:7.3.3.Final-custom:compile
```

---

## Key details and gotchas

- **Version compatibility**: Hibernate ORM `main` (8.0.0-SNAPSHOT) is not API-compatible with Quarkus `main`. Always check `hibernate-orm.version` in `quarkus/pom.xml` and checkout the matching Hibernate ORM tag or branch.
- **Version injection plugin**: Hibernate ORM's Gradle build uses `org.hibernate.build.version-injection` to overwrite `initVersion()` bytecode. Any source changes to `initVersion()` are silently lost. Modify `getVersionString()` instead.
- **Gradle wrapper**: Always use `./gradlew` in the Hibernate ORM repo, not the system Gradle — the wrapper version is pinned to what the project expects.
- **Full Quarkus build is needed**: The sample app depends on `quarkus-bom`, `quarkus-maven-plugin`, and many transitive modules at version `999-SNAPSHOT`. Partial builds are fragile.
- **Group ID difference**: The quickstart uses `io.quarkus.platform` as the BOM group ID (for released versions). The local build uses `io.quarkus`. Update `quarkus.platform.group-id` accordingly.

## Files modified

| File | Change |
|------|--------|
| `hibernate-orm/gradle/version.properties` | Version changed to `7.3.3.Final-custom` |
| `hibernate-orm/hibernate-core/src/main/java/org/hibernate/Version.java` | Marker appended in `getVersionString()` |
| `quarkus/pom.xml` | `hibernate-orm.version` set to `7.3.3.Final-custom` |
| `sample-app/pom.xml` | BOM pointed to `io.quarkus:quarkus-bom:999-SNAPSHOT`, PostgreSQL replaced with H2 |
| `sample-app/src/main/resources/application.properties` | H2 in-memory datasource config |
| `sample-app/src/main/java/org/acme/hibernate/orm/HibernateVersionResource.java` | New REST endpoint returning Hibernate version |
