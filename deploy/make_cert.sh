#!/bin/sh
#
# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# a reliable variant of make_cert
#

# we have 1 argument, the name of the site
case $# in
    1)
	SITENAME="$1"
	;;
    *)
	echo "Usage: $0 site.name"
	exit 1
	;;
esac

# and it must be fully qualified
case $SITENAME in
    *.*)
	printf ""
	;;
    *)
	echo "Site name must not be unqualified"
	exit 1
	;;
esac

#
# create the cert in a known location
#
rm -fr /tmp/haplo-sslcerts
mkdir -p /tmp/haplo-sslcerts

openssl genrsa -out /tmp/haplo-sslcerts/server.key 1024

openssl req -new -batch -subj "/CN=${SITENAME}" -key /tmp/haplo-sslcerts/server.key -out /tmp/haplo-sslcerts/server.crt.csr

openssl x509 -req -sha1 -days 3650 -in /tmp/haplo-sslcerts/server.crt.csr -out /tmp/haplo-sslcerts/server.crt -signkey /tmp/haplo-sslcerts/server.key
