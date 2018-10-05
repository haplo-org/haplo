#!/bin/bash

# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2018    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

#
# This script installs the entire haplo stack, along with any necessary
# packages and system configuration
#
# If an argument is supplied, it will be interpreted as a hostname or URL
# and used to configure an initial application if one has not already been
# configured.
#

#
# The following assumptions are made:
#
# that we're running Ubuntu 16.04LTS or later
#   (16.04LTS is the only tested configuration at this time)
# that the system architecture is 64-bit
# that the system is dedicated to Haplo
# that the current user can use sudo to manage the system
# that we install to /haplo (persistent data) and /opt/haplo (code)
#
cd $HOME

echo ""
echo "  *** Welcome to the Haplo installation script ***"
echo ""
echo " This script will install any required packages, download any"
echo " necessary additional software, and build Haplo. It will also"
echo " configure postgres for Haplo's use, install Haplo, and enable"
echo " port forwarding."
echo ""
echo " If you supply an argument to this script, which should be the name"
echo " on the network you will use to connect to the application, this script"
echo " will generate a self-signed certificate, create an application, and"
echo " start Haplo ready for use."
echo ""

#
# we would like the system to be secure and kept up to date but doing
# this by default may interfere with local administrative policy
#
#if [ -x /usr/bin/apt-get ]; then
#    sudo apt-get update
#    sudo apt-get upgrade
#fi

#
# Need to work out which version of postgres goes with which version of Ubuntu
#
echo " *** Haplo installing packages ***"
PG_VERSION=9.5
XAPIAN_PKG=libxapian22v5
XAPIAN_DEV_PKG=libxapian-dev
OPENJDK_PKG=openjdk-8-jdk-headless
if [ -f /etc/os-release ]; then
    LNAME=`grep '^NAME=' /etc/os-release | awk -F= '{print $2}' | sed 's:"::g'`
    if [ "X$LNAME" != "XUbuntu" ]; then
	echo "Unsupported OS platform $LNAME"
	exit 1
    fi
    UVER=`grep '^VERSION_ID=' /etc/os-release | awk -F= '{print $2}' | sed 's:"::g'`
    case $UVER in
	'16.04')
	    PG_VERSION=9.5
	    ;;
	'18.04')
	    PG_VERSION=10
	    XAPIAN_PKG=libxapian30
	    # headless jdk on bionic isn't
	    OPENJDK_PKG=openjdk-8-jdk
	    echo "WARN: Ubuntu $UVER is not yet fully supported."
	    sleep 5
	    ;;
	'*')
	    echo "Unsupported OS version $UVER"
	    exit 1
	    ;;
    esac
else
    echo "Unrecognized OS platform"
    exit 1
fi
#
# check that we are 64-bit
#
if [ "X`uname -i`" != "Xx86_64" ]; then
    echo "ERROR: system must be 64-bit"
    exit 1
fi

#
# start installing packages
#
sudo apt-get -y install openssh-server
sudo apt-get -y install software-properties-common
sudo apt-get update
#
# we need:
#  g++ make to compile the xapian code
#  java to run the application
#  maven to build the java code
#  avahi for mdns in development
#  curl to download files
#  patch to apply patches
#  git to check out our source code
#  zlib1g-dev for the libz.so compilation symlink
#
sudo apt-get -y install g++ make ${OPENJDK_PKG} maven avahi-daemon uuid-dev curl patch git zlib1g-dev ${XAPIAN_PKG} ${XAPIAN_DEV_PKG}
sudo apt-get -y install postgresql-${PG_VERSION} postgresql-server-dev-${PG_VERSION} postgresql-contrib-${PG_VERSION}
#
# supervisord is used by the application to control worker processes
#
sudo apt-get -y install supervisor
if [ ! -f /usr/bin/supervisord ]; then
    echo "ERROR: package installation failed"
    exit 1
fi
echo " *** Haplo finished package installation ***"

#
# we use java 8, so force that to be the default
#
echo " *** Haplo setting java 8 as default ***"
if [ -x /usr/sbin/update-java-alternatives ]; then
    sudo /usr/sbin/update-java-alternatives -s java-1.8.0-openjdk-amd64 > /dev/null 2>&1
else
    sudo update-alternatives --set java /usr/lib/jvm/java-8-openjdk-amd64/jre/bin/java > /dev/null 2>&1
    sudo update-alternatives --set jar /usr/lib/jvm/java-8-openjdk-amd64/jre/bin/jar > /dev/null 2>&1
    sudo update-alternatives --set javac /usr/lib/jvm/java-8-openjdk-amd64/jre/bin/javac > /dev/null 2>&1
fi
echo " *** Haplo done setting java 8 as default ***"

#
# java needs the cacerts file populating correctly
#
echo " *** Haplo updating system CA certificate store ***"
sudo update-ca-certificates -f
echo " *** Haplo system CA certificate store updated ***"

#
# no longer need to configure maven
#
mkdir -p ${HOME}/.m2

#
# configure initial development postgres instance
# note that we create it here just in case, we configure and run
# a production postgresql instance by default
#
if [ ! -d ${HOME}/haplo-dev-support/pg ]; then
    echo " *** Haplo setting up development postgresql ***"
    sudo /etc/init.d/postgresql stop
    sudo update-rc.d postgresql disable
    mkdir -p ${HOME}/haplo-dev-support/pg
    /usr/lib/postgresql/${PG_VERSION}/bin/initdb -E UTF8 -D ~/haplo-dev-support/pg
    echo " *** Haplo development postgresql set up ***"
fi

#
# now download haplo if we haven't already
#
if [ ! -f haplo/fetch-and-compile.sh ]; then
    echo " *** Haplo cloning from github ***"
    git clone https://github.com/haplo-org/haplo.git
    echo " *** Haplo github clone done ***"
fi
#
# run the haplo build script, which will download all the components it
# needs, patch some known problems, and build our software
#
if [ -f haplo/fetch-and-compile.sh ]; then
    cd haplo
    echo " *** Building Haplo ***"
    ./fetch-and-compile.sh
    echo " *** Haplo build done ***"
else
    echo "ERROR: unable to find haplo"
    exit 1
fi

#
# create users
#  postgres should already exist from the postgres install
#  haplo is the user we use to run the application in production
#
echo " *** Haplo setting up accounts ***"
if grep -q '^postgres:' /etc/group
then
    echo "postgres group already exists"
else
    sudo groupadd postgres
fi
if grep -q '^postgres:' /etc/passwd
then
    echo "postgres account already exists"
else
    sudo useradd -s /bin/bash -g postgres -d /var/lib/postgresql -c "PostgreSQL administrator" postgres
fi
if grep -q '^haplo:' /etc/group
then
    echo "haplo group already exists"
else
    sudo groupadd haplo
fi
if grep -q '^haplo:' /etc/passwd
then
    echo "haplo account already exists"
else
    sudo useradd -s /bin/bash -g haplo -d /haplo -c "Haplo server" haplo
fi
#
# postgres needs to be in the haplo group so it can read the xapian files
#
sudo usermod -a -G haplo postgres
#
# and create all the locations we use
# data will be under /haplo (persistent)
# postgres database is under /haplo/database
# code will be under /opt/haplo (replaced on updates)
#
if [ ! -d /haplo ]; then
    sudo mkdir /haplo
    sudo chown haplo:haplo /haplo
fi
for subdir in log tmp generated-downloads files textweighting plugins messages messages/app_create messages/app_modify messages/spool sslcerts
do
    if [ ! -d /haplo/$subdir ]; then
	sudo mkdir /haplo/$subdir
	sudo chown haplo:haplo /haplo/$subdir
    fi
done
if [ ! -d /haplo/textidx ]; then
    sudo mkdir /haplo/textidx
    sudo chown postgres:postgres /haplo/textidx
fi
if [ ! -d /opt/haplo ]; then
    sudo mkdir /opt/haplo
    sudo chown haplo:haplo /opt/haplo
fi
echo " *** Haplo account setup done ***"

#
# we use the normal postgres service for production use
#  redirect the location of the data to /haplo/database
#  use the /haplo/database/pg_hba.conf file for access conrol
#
if grep -q /var/lib/postgresql /etc/postgresql/${PG_VERSION}/main/postgresql.conf
then
    echo " *** Haplo modifying postgres database location ***"
    sudo sed -i -e s:/var/lib/postgresql/${PG_VERSION}/main:/haplo/database: -e s:/etc/postgresql/${PG_VERSION}/main/pg_hba.conf:/haplo/database/pg_hba.conf: /etc/postgresql/${PG_VERSION}/main/postgresql.conf
    echo " *** Haplo postgres database location modified ***"
fi
if [ ! -d /haplo/database ]; then
    echo " *** Haplo setting up production postgresql ***"
    sudo mkdir /haplo/database
    sudo chown $USER /haplo/database
    /usr/lib/postgresql/${PG_VERSION}/bin/initdb -E UTF8 -D /haplo/database
    sudo chown -hR postgres:postgres /haplo/database
    sudo update-rc.d postgresql enable
    sudo /etc/init.d/postgresql start
    sleep 5
    ./db/init_production_db.sh
    # add haplo user and permissions for production
    psql -d haplo < db/prod_perm.sql
    echo " *** Haplo production postgresql done ***"
fi

#
# set up port forwarding using iptables, the app listens on ports 8080/8443
# but users connect to the well known ports 80/443
#
if [ ! -f /etc/iptables/rules.v4 ]; then
    echo " *** Haplo setting up port forwarding ***"
    #
    # this is to disable the interactive prompt
    #
    echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections
    echo iptables-persistent iptables-persistent/autosave_v6 boolean true | sudo debconf-set-selections
    sudo apt-get -y install iptables-persistent
    sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080
    sudo iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 8443
    sudo iptables-save > /tmp/rules.v4
    sudo cp /tmp/rules.v4 /etc/iptables/rules.v4
    rm -f /tmp/rules.v4
    echo " *** Haplo port forwarding set up ***"
else
    #
    # iptables-persistent is already installed, need to configure
    #
    if grep -q 8443 /etc/iptables/rules.v4
    then
	echo " *** Port forwarding already configured ***"
    else
	echo " *** Haplo configuring port forwarding ***"
	sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080
	sudo iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 8443
	sudo iptables-save > /tmp/rules.v4
	sudo cp /tmp/rules.v4 /etc/iptables/rules.v4
	rm -f /tmp/rules.v4
	echo " *** Haplo port forwarding configured ***"
    fi
fi

#
# generate a deployable tarball
# to deploy this, you need to
#  cd /opt/haplo ; tar xf /tmp/haplo-build.tar
#
echo " *** Generating deployable archive ***"
./deploy/release
echo " *** Deployable archive generated ***"

#
# iff the target code area is empty, for example if this is the first
# time this script has been run, unpack the tarball in the right place
#
if [ ! -d /opt/haplo/app ]; then
    echo " *** Deploying build to /opt/haplo ***"
    sudo su haplo -c 'cd /opt/haplo ; tar xf /tmp/haplo-build.tar'
    echo " *** Build deployed to /opt/haplo ***"
fi

#
# if we have an argument, and there are no existing certificates,
# create a self-signed certificate with the argument as the hostname
#
case $# in
1)
    if [ ! -f /haplo/sslcerts/server.crt ]; then
	echo " *** Haplo creating server certificate ***"
	./deploy/make_cert.sh $1 > /dev/null
	chmod a+r /tmp/haplo-sslcerts/*
	sudo su haplo -c 'cd /tmp/haplo-sslcerts ; cp server.crt  server.crt.csr  server.key /haplo/sslcerts'
	rm -fr /tmp/haplo-sslcerts
	echo " *** Haplo server certificate created and installed ***"
    fi
    ;;
esac

#
# manage startup
# only manage startup if the certificates exist
# if systemd, check for the service
# otherwise, use standard init
#
if [ -f /haplo/sslcerts/server.crt ]; then
    if [ -x /bin/systemd ]; then
	if [ ! -f /etc/systemd/system/haplo.service ]; then
	    echo " *** Haplo enabling application startup ***"
	    sudo cp deploy/haplo.service /etc/systemd/system
	    sudo systemctl daemon-reload
	    sudo systemctl enable /etc/systemd/system/haplo.service
	    sudo systemctl start haplo.service
	    sleep 5
	    echo " *** Haplo startup enabled ***"
	else
	    sudo systemctl start haplo.service
	    sleep 5
	fi
    else
	if [ ! -f /etc/init.d/haplo ]; then
	    echo " *** Haplo enabling application startup ***"
	    sudo cp deploy/haplo.rc /etc/init.d/haplo
	    sudo update-rc.d haplo defaults 95 15
	    sudo update-rc.d haplo enable
	    sudo /etc/init.d/haplo start
	    sleep 5
	    echo " *** Haplo startup enabled ***"
	fi
    fi
fi

#
# if we have an argument, and there are no existing applications,
# create an initial application matching the argument
#
# the application server must be running for this to succeed,
# it will take a few seconds for the application server to start
# so rely on the user not typing too fast
#
case $# in
1)
    if [ ! -d /haplo/files/4000/ ]; then
	echo " *** Haplo initializing application for $1 ***"
	APPNAME=""
	APPUNAME=""
	APPUMAIL=""
	APPUPASS=""
	while [ -z "$APPNAME" ]
	do
	    read -p "Enter the name for this site: " APPNAME
	done
	while [ -z "$APPUNAME" ]
	do
	    read -p "Enter the name of the first user: " APPUNAME
	done
	while [ -z "$APPUMAIL" ]
	do
	    read -p "Enter the email of the first user: " APPUMAIL
	done
	while [ -z "$APPUPASS" ]
	do
	    read -p "Enter the password of the first user: " APPUPASS
	done
	echo " *** Configuring application for $1"
	rm -f /tmp/haplo-appinit.sh
	cat > /tmp/haplo-appinit.sh <<EOF
#!/bin/sh
cd /opt/haplo
db/init_app.sh haplo $1 "${APPNAME}" sme 4000
sleep 1
db/create_app_user.sh $1 "${APPUNAME}" ${APPUMAIL} ${APPUPASS}
EOF
	chmod a+x /tmp/haplo-appinit.sh
	sudo su haplo -c "/tmp/haplo-appinit.sh"
	rm -f /tmp/haplo-appinit.sh
	echo " *** Haplo application for $1 initialized ***"
	echo ""
	echo "Browse to"
	echo "  http://$1/"
	echo "And log in as the user you created above."
	echo ""
	echo "   *** Welcome to Haplo ***"
	echo ""
    fi
    ;;
esac
