#!/bin/sh

# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

set -e

DEV_SUPPORT_DIR=~/haplo-dev-support

JRUBY_VERSION=1.7.19
JRUBY_DIGEST=a3296d1ae9b9aa78825b8d65a0d2498b449eaa3d
JRUBY_DOWNLOAD_URL=https://s3.amazonaws.com/jruby.org/downloads/${JRUBY_VERSION}/jruby-bin-${JRUBY_VERSION}.tar.gz

XAPIAN_VERSION=1.2.15
XAPIAN_DIGEST=3d2ea66e9930451dcac4b96f321284f3dee98d51
XAPIAN_DOWNLOAD_URL=http://oligarchy.co.uk/xapian/1.2.15/xapian-core-${XAPIAN_VERSION}.tar.gz

# NOTE: Gem names and digests below

# ----------------------------------------------------------------------------------
DARWIN_OXP_LINK="-dynamiclib -undefined suppress -flat_namespace"
DARWIN_XAPIAN_LIB_EXT=a
OTHER_OXP_LINK="-shared"
OTHER_XAPIAN_LIB_EXT=so

# ----------------------------------------------------------------------------------

CODE_DIR=`pwd`
VENDOR_DIR=$DEV_SUPPORT_DIR/vendor

# ----------------------------------------------------------------------------------

echo "Checking environment..."
if ! which curl; then
    echo curl is not available, cannot fetch archives
    exit 1
fi
if ! which gcc; then
    echo gcc is not available, have you installed the developer tools?
    exit 1
fi
if ! which patch; then
    echo patch is not available
    exit 1
fi
if ! which java; then
    echo java is not available
    exit 1
fi
if ! which mvn; then
    echo Maven is not available
    exit 1
fi
if ! which pg_config; then
    echo pg_config is not available, make sure it is installed, and the PostgreSQL bin directory is on your PATH
    exit 1
fi

if [ `uname` = Darwin ]; then
    OXP_LINK=$DARWIN_OXP_LINK
    XAPIAN_LIB_EXT=$DARWIN_XAPIAN_LIB_EXT
else
    OXP_LINK=$OTHER_OXP_LINK
    XAPIAN_LIB_EXT=$OTHER_XAPIAN_LIB_EXT
fi

POSTGRESQL_INCLUDE=`pg_config --includedir-server`
POSTGRESQL_LIB=`pg_config --libdir`
if ! [ -d $POSTGRESQL_INCLUDE ]; then
    echo "Can't find PostgreSQL include directory, is it installed? Tried ${POSTGRESQL_INCLUDE}"
    exit 1
fi

# Check for RVM, which does weird things to the shell
if [ -d ~/.rvm ]; then
    echo
    echo "RVM appears to be installed. It will probably break this installation script."
    echo "If this script fails, disable RVM for your session, remove ${DEV_SUPPORT_DIR}"
    echo "then try again."
    echo
    sleep 5
fi

# ----------------------------------------------------------------------------------

mkdir -p app/views/object
mkdir -p log
mkdir -p tmp/properties
mkdir -p tmp/properties-test
mkdir -p target
# Create a blank classpath so config/paths-*.sh works before Maven runs
touch target/classpath.txt

# ----------------------------------------------------------------------------------

if ! [ -d $VENDOR_DIR/archive ]; then
    mkdir -p $VENDOR_DIR/archive
fi

get_file() {
    GET_NAME=$1
    GET_URL=$2
    GET_FILE=$3
    GET_DIGEST=$4
    if [ -f $GET_FILE ]; then
        echo "${GET_NAME} already downloaded."
    else
        echo "Downloading ${GET_NAME}..."
        curl -L $GET_URL > _tmp_download
        DOWNLOAD_DIGEST=`openssl sha1 < _tmp_download`
        if [ "$GET_DIGEST" = "$DOWNLOAD_DIGEST" -o "(stdin)= $GET_DIGEST" = "$DOWNLOAD_DIGEST" ]; then
            mv _tmp_download $GET_FILE
        else
            rm _tmp_download
            echo "Digest of ${GET_NAME} download was incorrect, expected ${GET_DIGEST}, got ${DOWNLOAD_DIGEST}"
            exit 1
        fi
    fi
}

# ----------------------------------------------------------------------------------

JRUBY_FILENAME=jruby-bin-${JRUBY_VERSION}.tar.gz
get_file JRuby $JRUBY_DOWNLOAD_URL $VENDOR_DIR/archive/$JRUBY_FILENAME $JRUBY_DIGEST

if ! [ -d ${VENDOR_DIR}/jruby ]; then
    echo "Unpacking JRuby..."
    cd $VENDOR_DIR
    gunzip -c archive/$JRUBY_FILENAME | tar xf -
    mv jruby-${JRUBY_VERSION} jruby
    cd $CODE_DIR
fi

# ----------------------------------------------------------------------------------

ALL_GEMS=""
get_gem() {
    GEM_NAME=$1
    GEM_VERSION=$2
    GEM_DIGEST=$3
    get_file "${GEM_NAME} (ruby gem)" "https://rubygems.org/gems/${GEM_NAME}-${GEM_VERSION}.gem" "$VENDOR_DIR/archive/${GEM_NAME}-${GEM_VERSION}.gem" $GEM_DIGEST
    ALL_GEMS="${ALL_GEMS} ${GEM_NAME}-${GEM_VERSION}.gem"
}

get_gem "RedCloth" "4.2.9-java" "698688bb64b73a0477855902aaf0844cb1b0dd2c"
get_gem "activemodel" "3.0.20" "80c7d881ed64ed7a66f4d82b12c2b98b43f6fbde"
get_gem "activerecord" "3.0.20" "d8fc6e02bf46f9b5f86c3a954932d67da211302b"
get_gem "activerecord-jdbc-adapter" "1.2.7" "0937ed7d87f5d305a3a63f3b0abd3ae5297856e7"
get_gem "activerecord-jdbcpostgresql-adapter" "1.2.7" "625179f518868f35b28b3dde14087a12e7e980ba"
get_gem "activeresource" "3.0.20" "e465e7d582c6d72c487d132e5fac3c3af4626353"
get_gem "activesupport" "3.0.20" "5bc7b2f1ad70a2781c4a41a2f4eaa75b999750e4"
get_gem "arel" "2.0.10" "758e4172108a517d91c526dcab90355a7d07c527"
get_gem "builder" "2.1.2" "d0ea89ea793c75853abd636ab86a79b7b57d6993"
get_gem "haml" "4.0.0" "dd35eda28a98d70d75f4a0c07cdb20f6920e5a2d"
get_gem "hoe" "3.6.3" "7f2323e812efd292cdca7ebd0e44266c55814995"
get_gem "i18n" "0.5.0" "74ec4aeb2c46d6d59864e5fceecd3cd496963a3f"
get_gem "jdbc-postgres" "9.2.1002.1" "927e9e24f86d4d785ddb0fcf58bce3e89b3c87e4"
get_gem "json" "1.8.0-java" "1288feae1fe8aa8e3b93a2d32bc232ba7ad0749c"
get_gem "mail" "2.2.19" "d117d132cf6f28f914ee32eb1343d6ffcdca49ea"
get_gem "mime-types" "1.21" "4a8ff499e52a92b0c3a7354717c6ac920fd8024d"
get_gem "railties" "3.0.20" "42b0025e4cb483d491a809b9d9deb6fd182c2a57"
get_gem "rdoc" "3.12.2" "687cd1bc56c2ad79fd9e2e3854d0a6db575e2aa2"
get_gem "rmail" "1.0.0" "0c946e2e7daf5468a338ce42177f52bd4f89eb82"
get_gem "test-unit" "1.2.3" "9ad7eefe7d289713a072130d51312ebe0529d48b"
get_gem "thor" "0.14.6" "cb09bba64959b0ea470d1b8c266c42858a8f7e11"
get_gem "tilt" "1.3.5" "ae2951246c258b60826de66256467d379acf363b"
get_gem "tzinfo" "1.0.1" "fc4c6f1c140dcf2634726ed5dddb568aa07dfec2"
get_gem "tzinfo-data" "1.2013.4" "84a532b59c313ab9b484ea84041c95ed9de434b8"

if ! [ -f ${VENDOR_DIR}/.gems-installed ]; then
    echo "Installing gems..."
    OLD_PATH=$PATH
    PATH=$VENDOR_DIR/jruby/bin:$PATH
    cd $VENDOR_DIR/archive
    jgem install --ignore-dependencies --force --local $ALL_GEMS
    PATH=$OLD_PATH
    cd $CODE_DIR
    GEM_PATCH_DIR=`pwd`/deploy/dependency-patches/gems
    JRUBY_GEMS_DIR=${VENDOR_DIR}/jruby/lib/ruby/gems/shared/gems
    . deploy/dependency-patches/gems/_patch.sh
    cd $CODE_DIR
    touch ${VENDOR_DIR}/.gems-installed
    echo "Gem patching complete."
fi

# ----------------------------------------------------------------------------------

XAPIAN_FILENAME=xapian-core-${XAPIAN_VERSION}.tar.gz
get_file Xapian $XAPIAN_DOWNLOAD_URL $VENDOR_DIR/archive/$XAPIAN_FILENAME $XAPIAN_DIGEST

if ! [ -d ${VENDOR_DIR}/xapian-core ]; then
    echo "Unpacking Xapian..."
    cd ${VENDOR_DIR}
    gunzip -c archive/$XAPIAN_FILENAME | tar xf -
    mv xapian-core-${XAPIAN_VERSION} xapian-core
    cd $CODE_DIR
fi

XAPIAN_LIB=${VENDOR_DIR}/xapian-core/.libs/libxapian.$XAPIAN_LIB_EXT
if ! [ -f $XAPIAN_LIB ]; then
    echo "Compiling Xapian..."
    cd ${VENDOR_DIR}/xapian-core
    ./configure
    make
    cd $CODE_DIR
fi

# ----------------------------------------------------------------------------------

if ! [ -d $DEV_SUPPORT_DIR/certificates ]; then
    echo "Create test certificates..."
    deploy/setup_developer_vm
fi

# ----------------------------------------------------------------------------------

echo "Compiling PostgreSQL/Xapian extension..."
OXP_DIR=lib/xapian_pg
cat $OXP_DIR/OXPFunctions.cpp $OXP_DIR/OXPController.cpp $OXP_DIR/KXapianWriter.cpp > $OXP_DIR/_all.cpp
g++ -Wall -Wno-format-security -Wno-tautological-compare -fPIC -O2 -I${VENDOR_DIR}/xapian-core/include -I$POSTGRESQL_INCLUDE -c $OXP_DIR/_all.cpp -o $OXP_DIR/_all.o
rm $OXP_DIR/_all.cpp
g++ $OXP_LINK $OXP_DIR/_all.o $XAPIAN_LIB -lz -L$POSTGRESQL_LIB -o $OXP_DIR/oxp.so

# ----------------------------------------------------------------------------------

echo "Compiling runner utility..."
g++ framework/support/oneis.cpp -O2 -o framework/oneis

# ----------------------------------------------------------------------------------

echo "Compiling Java sources with maven..."
mvn package
cp target/haplo-3.20150522.1712.adcec6a801.jar framework/oneis.jar

mvn -Dmdep.outputFile=target/classpath.txt dependency:build-classpath

# ----------------------------------------------------------------------------------

echo "Done."
