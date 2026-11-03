#!/usr/bin/env bash

set -ex

CLASS=$1

JAVA28=$HOME/src/jdk/build/release-linux-x86_64/images/jdk

HIBERNATE_JAR=$HOME/.m2/repository/org/hibernate/orm/hibernate-core/7.4.5.Final-custom/hibernate-core-7.4.5.Final-custom.jar                                                                                                                                                 
MOCKITO_JAR=$HOME/.m2/repository/org/mockito/mockito-core/5.21.0/mockito-core-5.21.0.jar                                                                                                                                                                                     
BYTEBUDDY_JAR=$HOME/.m2/repository/net/bytebuddy/byte-buddy/1.18.8/byte-buddy-1.18.8.jar                                                                                                                                                                                     
BYTEBUDDY_AGENT_JAR=$HOME/.m2/repository/net/bytebuddy/byte-buddy-agent/1.18.8/byte-buddy-agent-1.18.8.jar                                                                                                                                                                   
OBJENESIS_JAR=$HOME/.m2/repository/org/objenesis/objenesis/3.3/objenesis-3.3.jar                                                                                                                                                                                             
JBOSS_LOG_JAR=$HOME/.m2/repository/org/jboss/logging/jboss-logging/3.6.3.Final/jboss-logging-3.6.3.Final.jar                                                                                                                                                                 
JPA_JAR=$HOME/.m2/repository/jakarta/persistence/jakarta.persistence-api/3.2.0/jakarta.persistence-api-3.2.0.jar                                                                                                                                                             
JTA_JAR=$HOME/.m2/repository/jakarta/transaction/jakarta.transaction-api/2.0.1/jakarta.transaction-api-2.0.1.jar                                                                                                                                                             

CP=".:$HIBERNATE_JAR:$MOCKITO_JAR:$BYTEBUDDY_JAR:$BYTEBUDDY_AGENT_JAR:$OBJENESIS_JAR:$JBOSS_LOG_JAR:$JPA_JAR:$JTA_JAR"                                                                                                                                                                 

$JAVA28/bin/javac --enable-preview --source 28 -cp "$CP" "$CLASS".java

$JAVA28/bin/java --enable-preview -cp "$CP" "$CLASS"
