#!/usr/bin/env bash

set -ex

SRC=$HOME/src
REPO=$SRC/spring-quarkus-perf-comparison
BRANCH=main
QDUP_USER=$USER
# requires `make images`
JAVA_HOME=$HOME/src/jdk/build/release-linux-x86_64/images/jdk
WITH_PREVIEW=false

# ── argument parsing ─────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
    case "$1" in
        --src)              SRC="$2";            shift 2 ;;
        --with-preview)     WITH_PREVIEW=true;   shift ;;
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

cd $REPO/scripts/perf-lab

#  --quarkus-build-config-args "-Dquarkus.platform.group-id=io.quarkus" \

jvm_args+=(-XX:+UseNUMA)
jvm_args+=(-Dserver.tomcat.threads.max=50 -Dserver.tomcat.threads.min-spare=50)
if [[ "$WITH_PREVIEW" == true ]]; then
    jvm_args+=(--enable-preview)
fi

quarkus_build_args=()
if [[ "$WITH_PREVIEW" == true ]]; then
    quarkus_build_args+=(-Dmaven.compiler.enablePreview=true)
    quarkus_build_args+=(-Dmaven.compiler.release=28)
fi

./run-benchmarks.sh \
  --cpus-app 28,29,30,31 \
  --cpus-db 24,25,26 \
  --cpus-first-request 5 \
  --cpus-load-gen 20,21,22 \
  --cpus-monitoring 9 \
  --cpus-otel 16,17,18 \
  --description "Local Test" \
  --drop-fs-caches \
  --graalvm-version 25.0.2-graalce \
  --host 127.0.0.1 \
  --iterations 1 \
  --java-home $JAVA_HOME \
  --jvm-args "${jvm_args[*]}" \
  --jvm-memory "-Xmx512m -Xms512m" \
  --repo-branch $BRANCH \
  --repo-url $REPO \
  --scenario tuned \
  --springboot3-version 3.5.13 \
  --springboot4-version 4.0.5 \
  --output-dir run \
  --profiler none \
  --quarkus-version 999-SNAPSHOT \
  --quarkus-build-config-args "${quarkus_build_args[*]}" \
  --runtimes quarkus3-jvm \
  --run-identifier local-1 \
  --tests run-load-test \
  --user $QDUP_USER \
  --use-container-host-network \
  --wait-time 30
