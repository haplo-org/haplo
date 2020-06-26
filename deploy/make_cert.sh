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

#
# See
# https://support.apple.com/en-us/HT210176
# for certificate requirements
#

cat > /tmp/haplo-sslcerts/ssl.cnf <<EOF
[ req ]
default_bits       = 2048
distinguished_name = req_distinguished_name
req_extensions     = req_ext
[ req_distinguished_name ]
commonName                 = ${SITENAME}
[ req_ext ]
subjectAltName = @alt_names
[alt_names]
DNS.1   = ${SITENAME}
EOF

openssl genrsa -out /tmp/haplo-sslcerts/server.key 2048

openssl req -new -batch -subj "/CN=${SITENAME}" -config /tmp/haplo-sslcerts/ssl.cnf -key /tmp/haplo-sslcerts/server.key -out /tmp/haplo-sslcerts/server.crt.csr

cat > /tmp/haplo-sslcerts/ssl.cnf <<EOF
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
[alt_names]
DNS.1   = ${SITENAME}
EOF

openssl x509 -req -sha256 -days 800 -extfile /tmp/haplo-sslcerts/ssl.cnf -in /tmp/haplo-sslcerts/server.crt.csr -out /tmp/haplo-sslcerts/server.crt -signkey /tmp/haplo-sslcerts/server.key

rm -f /tmp/haplo-sslcerts/ssl.cnf
