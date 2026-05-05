#!/usr/bin/env bash

set -ex

REPO=$HOME/src/spring-quarkus-perf-comparison
BRANCH=main
QDUP_USER=$USER

cd $REPO/scripts/perf-lab

./run-benchmarks.sh \
  --repo-branch $BRANCH \
  --scenario tuned \
  --output-dir run \
  --graalvm-version 25.0.2-graalce \
  --host 127.0.0.1 \
  --iterations 1 \
  --java-version 25.0.2-tem \
  --repo-url $REPO \
  --profiler none \
  --quarkus-version 3.34.1 \
  --springboot3-version 3.5.13 \
  --springboot4-version 4.0.5 \
  --user $QDUP_USER \
  --wait-time 30 \
  --run-identifier local-1 \
  --drop-fs-caches \
  --jvm-args "-XX:+UseNUMA -Dserver.tomcat.threads.max=50 -Dserver.tomcat.threads.min-spare=50" \
  --description "Local Test" \
  --cpus-app 28,29,30,31 \
  --cpus-db 24,25,26 \
  --cpus-first-request 5 \
  --cpus-load-gen 20,21,22 \
  --cpus-monitoring 9 \
  --cpus-otel 16,17,18 \
  --jvm-memory "-Xmx512m -Xms512m" \
  --runtimes quarkus3-jvm,spring4-jvm \
  --tests run-load-test
