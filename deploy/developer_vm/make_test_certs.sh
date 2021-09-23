#!/bin/bash

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2021            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

#

# Hostname (in the mDNS .local domain)
HOSTNAME=`hostname`
HOSTNAME="${HOSTNAME/.local/}.local"

# override for a development zone
ZONE_NAME=`/usr/bin/zonename`
if [ $ZONE_NAME != "global" ]; then
 	HOSTNAME=${ZONE_NAME}.net.oneis.co.uk
fi

# Root of cert directory
CERTS_DIR="${HOME}/.oneis-dev-certs"
if [ -d "${CERTS_DIR}" ]; then
    echo "${CERTS_DIR} already exists"
    if [ -f "${CERTS_DIR}/messages.crt" ]; then
        echo "All certificates exist, not rerunning"
        exit 1
    else
        echo "Appears to be a rerun, starting over"
    fi
fi
mkdir -p ${CERTS_DIR}

make_key() {
	openssl genrsa -out ${CERTS_DIR}/$1 2048
}

make_cert() {
	openssl req -new -batch -subj "$3" -key ${CERTS_DIR}/$2 -out ${CERTS_DIR}/${1}.csr
	openssl x509 -req -sha256 -days 3650 -in ${CERTS_DIR}/${1}.csr -out ${CERTS_DIR}/${1} -signkey ${CERTS_DIR}/${2}
}

make_ca_cert() {
	openssl req -new -batch -subj "$3" -key ${CERTS_DIR}/$2 -out ${CERTS_DIR}/${1}.csr
	openssl x509 -req -sha256 -extensions v3_ca -days 3650 -in ${CERTS_DIR}/${1}.csr -out ${CERTS_DIR}/${1} -signkey ${CERTS_DIR}/${2}
}

make_messaging_certs() {
    make_key messages.key
    openssl req -new -batch -subj "$1" -key ${CERTS_DIR}/messages.key -out ${CERTS_DIR}/messages.csr
    openssl x509 -req -sha256 -days 3650 -in ${CERTS_DIR}/messages.csr -out ${CERTS_DIR}/messages.crt -signkey ${CERTS_DIR}/messages.key -extensions usr_crt -CA ${CERTS_DIR}/messagesca/messagesca.crt -CAkey ${CERTS_DIR}/messagesca/messagesca.key -CAserial ${CERTS_DIR}/messagesca/messagesca.srl
}

# Self-signed key & cert for main application
make_key server.key
make_cert server.crt server.key "/CN=*.${HOSTNAME}"
if [ ! -f "${CERTS_DIR}/server.crt" ]; then
    echo "Sign server cert failed"
    exit 1
fi

# Make an alternative application certificate for testing SNI support
make_key testsni.local.key
make_cert testsni.local.crt testsni.local.key "/CN=testsni.local"
if [ ! -f "${CERTS_DIR}/testsni.local.crt" ]; then
    echo "Sign testsni cert failed"
    exit 1
fi

# Make messages CA
mkdir -p ${CERTS_DIR}/messagesca
make_key "messagesca/messagesca.key"
make_ca_cert "messagesca/messagesca.crt" "messagesca/messagesca.key" "/CN=Haplo Messaging CA"
echo "10" > ${CERTS_DIR}/messagesca/messagesca.srl
# put the cert where the app expects it
cp ${CERTS_DIR}/messagesca/messagesca.crt ${CERTS_DIR}/messagesca.crt
# and a messaging cert for this node
make_messaging_certs "/CN=${HOSTNAME}"
if [ ! -f "${CERTS_DIR}/messages.crt" ]; then
    echo "Sign messages cert failed"
    exit 1
fi

# CA for management-app clients (no longer used)
make_key "management-app-clientca.key"
make_ca_cert "management-app-clientca.crt" "management-app-clientca.key" "/CN=management-app client CA"
echo "10" > ${CERTS_DIR}/management-app-clientca.srl

echo "Done."
