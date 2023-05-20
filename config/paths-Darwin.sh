# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2018    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


KHOST_OPERATING_SYSTEM=Darwin
export KHOST_OPERATING_SYSTEM

KINFORMATION_HOME=~/haplo-dev-support/information
export KINFORMATION_HOME

# JAVA_HOME=$(/usr/libexec/java_home -v 1.8)
JAVA_EXECUTABLE=$JAVA_HOME/bin/java
export JAVA_EXECUTABLE

# JRUBY_HOME=~/haplo-dev-support/haplo-plugin/jruby
export JRUBY_HOME
JRUBY_JFFI_LIB_PATH=$JRUBY_HOME/lib/jni/Darwin/libjffi-1.2.jnilib
export JRUBY_JFFI_LIB_PATH

POSTGRESQL_BIN=`pg_config --bindir`
POSTGRESQL_SHARE=`pg_config --sharedir`
POSTGRESQL_INCLUDE=`pg_config --includedir-server`
export POSTGRESQL_BIN
export POSTGRESQL_SHARE
export POSTGRESQL_INCLUDE

PATH=$POSTGRESQL_BIN:$PATH
export PATH

#GCC_HOME=/opt/gcc-4.7.2
#export GCC_HOME

FONTS_DIRECTORY=/opt/haplo/platform/fonts
export FONTS_DIRECTORY

CLASSPATH=`cat target/classpath.txt`
export CLASSPATH

# Hostnames
KSERVER_HOSTNAME=`hostname`
export KSERVER_HOSTNAME

