#!/bin/sh

# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2020    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

set -e

REQUIRE_MAXMIND="yes"
case $1 in
-n)
    REQUIRE_MAXMIND="no"
    ;;
esac

DEV_SUPPORT_DIR=~/haplo-dev-support

JRUBY_VERSION=9.2.11.1
JRUBY_DIGEST=cceb81635fe3cd39f895c7632428e94b503e8e3d
JRUBY_DOWNLOAD_URL=https://s3.amazonaws.com/jruby.org/downloads/${JRUBY_VERSION}/jruby-bin-${JRUBY_VERSION}.tar.gz

XAPIAN_VERSION=1.2.25
XAPIAN_DIGEST=4c305585c3f1d9f595eec875549406b4650fd29d
XAPIAN_DOWNLOAD_URL=http://oligarchy.co.uk/xapian/${XAPIAN_VERSION}/xapian-core-${XAPIAN_VERSION}.tar.xz

# NOTE: Gem names and digests below

# ----------------------------------------------------------------------------------
DARWIN_OXP_LINK="-dynamiclib -undefined suppress -flat_namespace"
DARWIN_XAPIAN_LIB_EXT=a
OTHER_OXP_LINK="-shared"
OTHER_XAPIAN_LIB_EXT=so

# ----------------------------------------------------------------------------------

CODE_DIR=`pwd`
VENDOR_DIR=$DEV_SUPPORT_DIR/vendor
INFORMATION_DIR=$DEV_SUPPORT_DIR/information

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
if ! which g++; then
    echo g++ is not available, have you installed the developer tools?
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
get_gem "builder" "3.2.4" "3581f146308130f5b23b4f0348e68333288267f8"
get_gem "rake" "10.5.0" "6ffffeadda619a727fe154272d5080f8dd85cf25"
get_gem "hoe" "3.6.3" "7f2323e812efd292cdca7ebd0e44266c55814995"
get_gem "rmail" "1.1.3" "c48a81f89db6af1e7c2afe91640dee86f95581d0"
get_gem "test-unit" "1.2.3" "9ad7eefe7d289713a072130d51312ebe0529d48b"

if ! [ -f ${VENDOR_DIR}/.gems-installed ]; then
    echo "Installing gems..."
    OLD_PATH=$PATH
    PATH=$VENDOR_DIR/jruby/bin:$PATH
    cd $VENDOR_DIR/archive
    jgem install --ignore-dependencies --force --local $ALL_GEMS
    PATH=$OLD_PATH
    cd $CODE_DIR
    touch ${VENDOR_DIR}/.gems-installed
    echo "Gem patching complete."
fi

# ----------------------------------------------------------------------------------

# https://dev.maxmind.com/geoip/geoip2/geolite2/
# NOTE: this is a continually moving target

MAXMIND_DB_VERSION=20191210
MAXMIND_DB_DIGEST=4f0f57500d43aec1bf4f340316d4c2e2d67563e8
MAXMIND_DB_FILENAME=GeoLite2-Country_${MAXMIND_DB_VERSION}.tar.gz
MAXMIND_DB_URL=http://geolite.maxmind.com/download/geoip/database/$MAXMIND_DB_FILENAME

mkdir -p ${INFORMATION_DIR}/maxmind-geolite2
if ! [ -f ${INFORMATION_DIR}/maxmind-geolite2/GeoLite2-Country.mmdb ]; then
    #
    # As a result of the CCPA, there are no more anonymous downloads
    # of the maxmind databases. Anyone needing this functionality
    # will need to obtain a copy separately.
    #
    # https://blog.maxmind.com/2019/12/18/significant-changes-to-accessing-and-using-geolite2-databases/
    #
    # Workaround of a special flag to allow the build to continue.
    #
    echo "WARN: Unable to find MaxMind GeoLite2 database."
    echo "Expect a test failure in HaploInfoGeoipTest."
    echo "If you need IP lookup functionality, please register and download"
    echo "your own copy of the GeoLite2 Country database, and place the"
    echo "database in this file:"
    echo "${INFORMATION_DIR}/maxmind-geolite2/GeoLite2-Country.mmdb"
    if [ "X${REQUIRE_MAXMIND}" != "Xyes" ]; then
	echo "WARN: Continuing without MaxMind support"
    else
	echo ""
	echo "If you wish to continue without MaxMind support, please"
	echo "rerun this script with the -n option, like so:"
	echo ""
	echo "$0 -n"
	exit 1
    fi
    #
    #echo "Fetching IP information database..."
    #get_file "MaxMind GeoLite2 DB" $MAXMIND_DB_URL ${INFORMATION_DIR}/${MAXMIND_DB_FILENAME} $MAXMIND_DB_DIGEST
    #cd $INFORMATION_DIR
    #tar xvzf $MAXMIND_DB_FILENAME
    #mv GeoLite2-Country_${MAXMIND_DB_VERSION}/* maxmind-geolite2/
    #rm -fr GeoLite2-Country_${MAXMIND_DB_VERSION}
    #rm -f $MAXMIND_DB_FILENAME
    #cd $CODE_DIR
fi

# ----------------------------------------------------------------------------------

if [ -f /usr/bin/xapian-config ]; then
    XAPIAN_INCLUDE=/usr/include/xapian
    XAPIAN_LIB=-lxapian
else
    XAPIAN_FILENAME=xapian-core-${XAPIAN_VERSION}.tar.gz
    get_file Xapian $XAPIAN_DOWNLOAD_URL $VENDOR_DIR/archive/$XAPIAN_FILENAME $XAPIAN_DIGEST

    if ! [ -d ${VENDOR_DIR}/xapian-core ]; then
	echo "Unpacking Xapian..."
	cd ${VENDOR_DIR}
	# not everything has the xz utils, but tar usually handles it direct
        tar xf archive/$XAPIAN_FILENAME
	mv xapian-core-${XAPIAN_VERSION} xapian-core
	cd $CODE_DIR
    fi

    XAPIAN_INCLUDE=${VENDOR_DIR}/xapian-core/include
    XAPIAN_LIB=${VENDOR_DIR}/xapian-core/.libs/libxapian.$XAPIAN_LIB_EXT
    if ! [ -f $XAPIAN_LIB ]; then
	echo "Compiling Xapian..."
	cd ${VENDOR_DIR}/xapian-core
	./configure
	make
	cd $CODE_DIR
    fi
fi

# ----------------------------------------------------------------------------------

if ! [ -d $DEV_SUPPORT_DIR/certificates ]; then
    echo "Create test certificates..."
    deploy/make_test_certs.sh
fi

# ----------------------------------------------------------------------------------

echo "Compiling PostgreSQL/Xapian extension..."
OXP_DIR=lib/xapian_pg
cat $OXP_DIR/OXPFunctions.cpp $OXP_DIR/OXPController.cpp $OXP_DIR/KXapianWriter.cpp > $OXP_DIR/_all.cpp
g++ -Wall -Wno-format-security -Wno-tautological-compare -fPIC -O2 -I$XAPIAN_INCLUDE -I$POSTGRESQL_INCLUDE -c $OXP_DIR/_all.cpp -o $OXP_DIR/_all.o
rm $OXP_DIR/_all.cpp
g++ $OXP_LINK $OXP_DIR/_all.o $XAPIAN_LIB -lz -L$POSTGRESQL_LIB -o $OXP_DIR/oxp.so

# ----------------------------------------------------------------------------------

echo "Compiling runner utility..."
g++ framework/support/haplo.cpp -O2 -o framework/haplo

# ----------------------------------------------------------------------------------

echo "Compiling Java sources with maven..."
mvn package
cp target/haplo-3.20200608.1154.38f1801744.jar framework/haplo.jar

mvn -Dmdep.outputFile=target/classpath.txt dependency:build-classpath

# ----------------------------------------------------------------------------------

echo "Done."
