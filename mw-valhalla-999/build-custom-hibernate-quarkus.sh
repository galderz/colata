#!/usr/bin/env bash
#
# Builds Hibernate ORM from source with a custom version suffix,
# builds Quarkus against it, creates a sample app, and verifies
# the custom Hibernate ORM is loaded at runtime.
#
# Usage:
#   ./build-custom-hibernate-quarkus.sh [OPTIONS]
#
# Options:
#   --hibernate-repo <path>   Path to hibernate-orm git repo   (default: ../../hibernate-orm)
#   --quarkus-repo <path>     Path to quarkus git repo         (default: ../../quarkus)
#   --quickstart-repo <path>  Path to quarkus-quickstarts repo (default: ../../quarkus-quickstarts)
#   --output-dir <path>       Where to create the sample app   (default: ./sample-app, next to this script)
#   --version-suffix <str>    Suffix appended to the Hibernate version (default: custom)
#   --marker <str>            Marker string injected into Version.getVersionString()
#                             (default: CUSTOM-BUILD-MARKER)
#   --skip-hibernate          Skip the Hibernate ORM build (reuse previous)
#   --skip-quarkus            Skip the Quarkus build (reuse previous)
#   --skip-sample             Skip creating/building the sample app
#   --skip-verify             Skip the runtime verification step
#   --help                    Show this help message

set -euo pipefail

# ── defaults ─────────────────────────────────────────────────────────────────
# Resolve paths relative to the script's location so the script works
# regardless of the caller's working directory.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

HIBERNATE_REPO="$ROOT_DIR/hibernate-orm"
QUARKUS_REPO="$ROOT_DIR/quarkus"
QUICKSTART_REPO="$ROOT_DIR/quarkus-quickstarts"
OUTPUT_DIR="$SCRIPT_DIR/sample-app"
VERSION_SUFFIX="custom"
MARKER="CUSTOM-BUILD-MARKER"
SKIP_HIBERNATE=false
SKIP_QUARKUS=false
SKIP_SAMPLE=false
SKIP_VERIFY=false

# ── argument parsing ─────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
    case "$1" in
        --hibernate-repo)   HIBERNATE_REPO="$2";  shift 2 ;;
        --quarkus-repo)     QUARKUS_REPO="$2";    shift 2 ;;
        --quickstart-repo)  QUICKSTART_REPO="$2"; shift 2 ;;
        --output-dir)       OUTPUT_DIR="$2";       shift 2 ;;
        --version-suffix)   VERSION_SUFFIX="$2";   shift 2 ;;
        --marker)           MARKER="$2";           shift 2 ;;
        --skip-hibernate)   SKIP_HIBERNATE=true;   shift ;;
        --skip-quarkus)     SKIP_QUARKUS=true;     shift ;;
        --skip-sample)      SKIP_SAMPLE=true;      shift ;;
        --skip-verify)      SKIP_VERIFY=true;      shift ;;
        --help)
            sed -n '2,/^$/{ s/^# \{0,1\}//; p }' "$0"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# ── resolve paths ────────────────────────────────────────────────────────────

HIBERNATE_REPO="$(cd "$HIBERNATE_REPO" && pwd)"
QUARKUS_REPO="$(cd "$QUARKUS_REPO" && pwd)"
QUICKSTART_REPO="$(cd "$QUICKSTART_REPO" && pwd)"
OUTPUT_DIR="$(mkdir -p "$OUTPUT_DIR" && cd "$OUTPUT_DIR" && pwd)"

# ── detect the Hibernate ORM version Quarkus expects ─────────────────────────
# Read from git's committed pom.xml so we always get the unpatched version,
# even if the working tree was modified by a previous run.

ORIGINAL_VERSION=$(
    git -C "$QUARKUS_REPO" show HEAD:pom.xml \
        | grep -oP '<hibernate-orm\.version>\K[^<]+' \
        | head -1
)
if [[ -z "$ORIGINAL_VERSION" ]]; then
    echo "ERROR: Could not find <hibernate-orm.version> in $QUARKUS_REPO/pom.xml" >&2
    exit 1
fi

CUSTOM_VERSION="${ORIGINAL_VERSION}-${VERSION_SUFFIX}"

# The original version without the ".Final" qualifier is the git tag name
# e.g. "7.3.3.Final" -> tag "7.3.3"
TAG_NAME="${ORIGINAL_VERSION%.Final}"

echo "============================================================"
echo " Hibernate ORM version Quarkus expects: $ORIGINAL_VERSION"
echo " Custom version to build:               $CUSTOM_VERSION"
echo " Git tag to checkout:                    $TAG_NAME"
echo " Marker:                                 $MARKER"
echo "============================================================"
echo

# ── Phase 1: Build custom Hibernate ORM ──────────────────────────────────────

if [[ "$SKIP_HIBERNATE" == false ]]; then
    echo ">>> Phase 1: Building custom Hibernate ORM ($CUSTOM_VERSION)"
    echo

    cd "$HIBERNATE_REPO"

    # Checkout the matching tag
    echo "    Checking out tag $TAG_NAME ..."
    git checkout "$TAG_NAME" --quiet

    # Patch the version
    echo "    Setting version to $CUSTOM_VERSION ..."
    sed -i "s|^hibernateVersion=.*|hibernateVersion=${CUSTOM_VERSION}|" gradle/version.properties

    # Inject the marker into Version.getVersionString()
    # We modify getVersionString(), NOT initVersion(), because the
    # version-injection Gradle plugin overwrites initVersion() bytecode.
    VERSION_JAVA="hibernate-core/src/main/java/org/hibernate/Version.java"
    echo "    Injecting marker into $VERSION_JAVA ..."
    sed -i 's|return VERSION;|return VERSION + " ['"$MARKER"']";|' "$VERSION_JAVA"

    # Build and publish to local Maven repository
    echo "    Running: ./gradlew publishToMavenLocal -x test -x javadoc --no-build-cache"
    echo
    ./gradlew publishToMavenLocal -x test -x javadoc --no-build-cache

    # Verify the artifact was published
    ARTIFACT_DIR="$HOME/.m2/repository/org/hibernate/orm/hibernate-core/$CUSTOM_VERSION"
    if [[ ! -d "$ARTIFACT_DIR" ]]; then
        echo "ERROR: Expected artifact directory not found: $ARTIFACT_DIR" >&2
        exit 1
    fi
    echo
    echo "    Hibernate ORM $CUSTOM_VERSION published to local Maven repo."
    echo
else
    echo ">>> Phase 1: SKIPPED (--skip-hibernate)"
    echo
fi

# ── Phase 2: Build Quarkus ───────────────────────────────────────────────────

if [[ "$SKIP_QUARKUS" == false ]]; then
    echo ">>> Phase 2: Building Quarkus with hibernate-orm.version=$CUSTOM_VERSION"
    echo

    cd "$QUARKUS_REPO"

    # Patch the Hibernate ORM version property (match any existing value)
    echo "    Updating hibernate-orm.version in pom.xml ..."
    sed -i "s|<hibernate-orm.version>[^<]*</hibernate-orm.version>|<hibernate-orm.version>${CUSTOM_VERSION}</hibernate-orm.version>|" pom.xml

    # Build Quarkus
    echo "    Running: mvn clean install -DskipTests -DskipDocs -Dquickly ..."
    echo
    MAVEN_OPTS="-Xmx4g" mvn clean install \
        -DskipTests -DskipDocs -Dquickly \
        -Dinvoker.skip -DskipExtensionValidation \
        -Dskip.gradle.tests -Dskip.gradle.build \
        -Dtruststore.skip -Dinsecure.repositories=WARN

    # Verify the BOM references our custom version
    BOM_POM="$HOME/.m2/repository/io/quarkus/quarkus-bom/999-SNAPSHOT/quarkus-bom-999-SNAPSHOT.pom"
    if ! grep -q "$CUSTOM_VERSION" "$BOM_POM" 2>/dev/null; then
        echo "ERROR: Quarkus BOM does not reference $CUSTOM_VERSION" >&2
        exit 1
    fi
    echo
    echo "    Quarkus 999-SNAPSHOT built with hibernate-orm.version=$CUSTOM_VERSION."
    echo
else
    echo ">>> Phase 2: SKIPPED (--skip-quarkus)"
    echo
fi

# ── Phase 3: Create sample application ───────────────────────────────────────

if [[ "$SKIP_SAMPLE" == false ]]; then
    echo ">>> Phase 3: Creating sample application at $OUTPUT_DIR"
    echo

    # Copy quickstart (overwrite if exists)
    rm -rf "$OUTPUT_DIR"
    cp -r "$QUICKSTART_REPO/hibernate-orm-quickstart" "$OUTPUT_DIR"
    cd "$OUTPUT_DIR"

    # Patch pom.xml: point to local Quarkus build
    sed -i 's|<quarkus.platform.group-id>io.quarkus.platform</quarkus.platform.group-id>|<quarkus.platform.group-id>io.quarkus</quarkus.platform.group-id>|' pom.xml
    sed -i 's|<quarkus.platform.version>[^<]*</quarkus.platform.version>|<quarkus.platform.version>999-SNAPSHOT</quarkus.platform.version>|' pom.xml

    # Switch from PostgreSQL to H2 (no external database needed)
    sed -i 's|<artifactId>quarkus-jdbc-postgresql</artifactId>|<artifactId>quarkus-jdbc-h2</artifactId>|' pom.xml

    # Remove legacy source/target compiler settings
    sed -i '/<source>11<\/source>/d' pom.xml
    sed -i '/<target>11<\/target>/d' pom.xml

    # Write H2-based application.properties
    cat > src/main/resources/application.properties <<'PROPS'
quarkus.datasource.db-kind=h2
quarkus.datasource.jdbc.url=jdbc:h2:mem:testdb
quarkus.hibernate-orm.schema-management.strategy=drop-and-create
quarkus.hibernate-orm.log.sql=true
quarkus.hibernate-orm.sql-load-script=import.sql
PROPS

    # Create the version-check REST endpoint
    ENDPOINT_DIR="src/main/java/org/acme/hibernate/orm"
    mkdir -p "$ENDPOINT_DIR"
    cat > "$ENDPOINT_DIR/HibernateVersionResource.java" <<'JAVA'
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
JAVA

    # Build the sample app
    echo "    Building sample app ..."
    mvn package -DskipTests -q

    echo "    Sample app built at $OUTPUT_DIR"
    echo
else
    echo ">>> Phase 3: SKIPPED (--skip-sample)"
    echo
fi

# ── Phase 4: Verify ─────────────────────────────────────────────────────────

if [[ "$SKIP_VERIFY" == false ]]; then
    echo ">>> Phase 4: Verification"
    echo

    cd "$OUTPUT_DIR"

    # Check 1: dependency tree
    echo "    [Check 1] Maven dependency tree:"
    DEP_LINE=$(mvn dependency:tree 2>/dev/null | grep "hibernate-core" || true)
    echo "      $DEP_LINE"
    if echo "$DEP_LINE" | grep -q "$CUSTOM_VERSION"; then
        echo "      PASS: dependency tree shows $CUSTOM_VERSION"
    else
        echo "      FAIL: $CUSTOM_VERSION not found in dependency tree" >&2
    fi
    echo

    # Check 2: start the app and hit the endpoint
    echo "    [Check 2] Runtime verification:"
    echo "      Starting Quarkus app ..."

    java -jar target/quarkus-app/quarkus-run.jar &>/tmp/quarkus-verify.log &
    APP_PID=$!

    # Wait for the app to start (poll for up to 30 seconds)
    READY=false
    for i in $(seq 1 30); do
        if curl -s -o /dev/null -w '' http://localhost:8080/hibernate-version 2>/dev/null; then
            READY=true
            break
        fi
        sleep 1
    done

    if [[ "$READY" == true ]]; then
        RESPONSE=$(curl -s http://localhost:8080/hibernate-version)
        echo "      GET /hibernate-version => $RESPONSE"

        if echo "$RESPONSE" | grep -q "$MARKER"; then
            echo "      PASS: custom build marker detected"
        else
            echo "      FAIL: marker '$MARKER' not found in response" >&2
        fi

        if echo "$RESPONSE" | grep -q "$CUSTOM_VERSION"; then
            echo "      PASS: custom version string detected"
        else
            echo "      FAIL: version '$CUSTOM_VERSION' not found in response" >&2
        fi
    else
        echo "      FAIL: app did not start within 30 seconds" >&2
        echo "      Log output:"
        cat /tmp/quarkus-verify.log >&2
    fi

    # Clean up
    kill "$APP_PID" 2>/dev/null || true
    wait "$APP_PID" 2>/dev/null || true
    rm -f /tmp/quarkus-verify.log

    echo
    echo "============================================================"
    echo " Done."
    echo "============================================================"
else
    echo ">>> Phase 4: SKIPPED (--skip-verify)"
    echo
    echo "============================================================"
    echo " Done. Run the app manually to verify:"
    echo "   cd $OUTPUT_DIR"
    echo "   java -jar target/quarkus-app/quarkus-run.jar"
    echo "   curl http://localhost:8080/hibernate-version"
    echo "============================================================"
fi
