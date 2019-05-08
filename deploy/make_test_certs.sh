#!/bin/bash
#
# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2019    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# a reliable variant of make_test_certs.rb
#

# Hostname (in the mDNS .local domain)
HOSTNAME=`hostname`
HOSTNAME="${HOSTNAME/.local/}.local"

# Root of certs directorys
CERTS_DIR="${HOME}/haplo-dev-support/certificates"
if [ -d "${CERTS_DIR}" ]; then
    echo "${CERTS_DIR} already exists"
    exit 1
fi
mkdir -p ${CERTS_DIR}

openssl genrsa -out ${CERTS_DIR}/server.key 2048

openssl req -new -batch -subj "/CN=*.${HOSTNAME}" -key ${CERTS_DIR}/server.key -out ${CERTS_DIR}/server.csr

openssl x509 -req -sha256 -days 3650 -in ${CERTS_DIR}/server.csr -out ${CERTS_DIR}/server.crt -signkey ${CERTS_DIR}/server.key

if [ ! -f "${CERTS_DIR}/server.crt" ]; then
    echo "Sign cert failed"
    exit 1
fi

echo "Done."
