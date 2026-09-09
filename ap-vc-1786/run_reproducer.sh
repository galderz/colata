#!/usr/bin/env bash

set -euo pipefail

# Compile
$JAVA_HOME/bin/javac --enable-preview --source 28 AllocReproducer.java

# Run
$JAVA_HOME/bin/java --enable-preview -agentpath:$HOME/src/async-profiler/build/lib/libasyncProfiler.so=start,event=alloc,file=target/alloc_profile.jfr AllocReproducer

# Check the recording
jfr print --events jdk.ObjectAllocationInNewTLAB target/alloc_profile.jfr | grep 'objectClass = ' | sed 's/.*objectClass = //' | sort | uniq -c | sort -rn
