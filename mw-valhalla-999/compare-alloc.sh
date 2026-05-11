#!/usr/bin/env bash

set -ex

SRD_DIR=${1:-$HOME/src}
BRANCH=main
QDUP_USER=$USER

cd $SRC_DIR/spring-quarkus-perf-comparison/scripts/perf-lab

GC="-Xlog:gc*:file=gc.log:level,time,tags,uptime"
PROFILER="jfr"

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
  --java-version 25.0.2-tem \
  --jvm-args "-XX:+UseNUMA -Dserver.tomcat.threads.max=50 -Dserver.tomcat.threads.min-spare=50 $GC" \
  --jvm-memory "-Xmx512m -Xms512m" \
  --repo-branch $BRANCH \
  --repo-url $REPO \
  --scenario tuned \
  --springboot3-version 3.5.13 \
  --springboot4-version 4.0.5 \
  --output-dir run \
  --profiler $PROFILER \
  --quarkus-version 3.34.1 \
  --runtimes quarkus3-jvm \
  --run-identifier local-1 \
  --tests run-load-test \
  --user $QDUP_USER \
  --use-container-host-network \
  --wait-time 30
