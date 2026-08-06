#!/bin/bash
set -e
set -x

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HIBERNATE_JAR="$HOME/.m2/repository/org/hibernate/orm/hibernate-core/7.4.5.Final-custom/hibernate-core-7.4.5.Final-custom.jar"
JBOSS_LOG_JAR="$HOME/.m2/repository/org/jboss/logging/jboss-logging/3.6.3.Final/jboss-logging-3.6.3.Final.jar"
CP="$HIBERNATE_JAR:$JBOSS_LOG_JAR"

echo "Print major/minor version"
javap -verbose -classpath "$HIBERNATE_JAR" org.hibernate.Version | grep -E 'major version|minor version'

echo "Compiling PrintHibernateVersion.java..."
#"$JAVA_HOME/bin/javac" -cp "$CP" "$SCRIPT_DIR/PrintHibernateVersion.java"
"$JAVA_HOME/bin/javac" -cp "$CP" --enable-preview --release 28 "$SCRIPT_DIR/PrintHibernateVersion.java"

#echo "Running PrintHibernateVersion..."
#"$JAVA_HOME/bin/java" -cp "$SCRIPT_DIR:$CP" PrintHibernateVersion

echo "Running PrintHibernateVersion with --enable-preview..."
"$JAVA_HOME/bin/java" -cp "$SCRIPT_DIR:$CP" --enable-preview PrintHibernateVersion
