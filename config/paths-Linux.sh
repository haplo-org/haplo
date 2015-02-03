
KHOST_OPERATING_SYSTEM=Linux
export KHOST_OPERATING_SYSTEM

JAVA_HOME=/usr/lib/jvm/java-7-openjdk-amd64
JAVA_EXECUTABLE=$JAVA_HOME/bin/java
export JAVA_EXECUTABLE

JRUBY_HOME=~/haplo-dev-support/vendor/jruby
export JRUBY_HOME
JRUBY_JFFI_LIB_PATH=$JRUBY_HOME/lib/jni/Darwin/libjffi-1.2.jnilib
export JRUBY_JFFI_LIB_PATH

POSTGRESQL_HOME=/usr/lib/postgresql/9.3
POSTGRESQL_SHARE=/usr/share/postgresql/9.3
POSTGRESQL_INCLUDE=/usr/include/postgresql/9.3/server
export POSTGRESQL_HOME
export POSTGRESQL_SHARE
export POSTGRESQL_INCLUDE

PATH=$POSTGRESQL_HOME/bin:$PATH
export PATH

FONTS_DIRECTORY=/opt/oneis/platform/fonts
export FONTS_DIRECTORY

CLASSPATH=`cat target/classpath.txt`
export CLASSPATH

# Hostnames
KSERVER_HOSTNAME=`hostname`
export KSERVER_HOSTNAME

