#!/usr/bin/ksh

# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


. ../../config/paths-`uname`.sh

X_FILENAMES="OXPFunctions OXPController KXapianWriter"

X_GCC_FLAGS="-m64 -Wall -fpic -I${POSTGRESQL_INCLUDE}/server -I/usr/local/include -I${XAPIAN_HOME}/include"
X_GCC_RELEASE_FLAGS="-O2"
X_GCC_DEBUG_FLAGS="-g -DDEBUG"

X_LINK_FLAGS="-m64 -L${XAPIAN_HOME}/lib -R${XAPIAN_HOME}/lib -lxapian -shared "

# Use the PATH which xapian was compiled with, to make sure we get the right compiler
PATH=`cat /opt/oneis/platform/xapian/COMPILER-PATH`
export PATH

if [ X$1 = Xdebug ]
then

    echo "DEBUG MODE"
    X_O_FILES=""
    for f in $X_FILENAMES
    do
        echo "${f}..."
        g++ $X_GCC_FLAGS $X_GCC_DEBUG_FLAGS -c ${f}.cpp
        X_O_FILES="${X_O_FILES} ${f}.o"
    done

    echo "link..."
    # -z muldefs  is a bit of a hack to stop complaints about multiply defined stdlib symbols
    g++ $X_LINK_FLAGS -z muldefs -o oxp_debug.so $X_O_FILES

else
    
    echo "RELEASE MODE"
    echo > _all.cpp
    for f in $X_FILENAMES
    do
        echo "concat ${f}..."
        cat ${f}.cpp >> _all.cpp
    done
    echo "compile..."
    g++ $X_GCC_FLAGS $X_GCC_RELEASE_FLAGS -c _all.cpp
    echo "link..."
    g++ $X_LINK_FLAGS -o oxp.so _all.o
    rm _all.cpp
    rm _all.o

fi

