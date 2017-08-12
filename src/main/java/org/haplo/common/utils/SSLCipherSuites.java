/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.common.utils;

import org.eclipse.jetty.util.ssl.SslContextFactory;

public class SSLCipherSuites {
    static public void configureCipherSuites(SslContextFactory factory) {
        factory.setExcludeCipherSuites(
                // Disable suites which prevent use of forward secrecy
                "TLS_RSA_WITH_AES_256_CBC_SHA",
                "TLS_RSA_WITH_AES_256_CBC_SHA256",
                // Disable RC4, as it's broken
                "TLS_RSA_WITH_RC4_128_MD5", "SSL_RSA_WITH_RC4_128_MD5",
                "TLS_RSA_WITH_RC4_128_SHA", "SSL_RSA_WITH_RC4_128_SHA",
                "TLS_ECDHE_RSA_WITH_RC4_128_SHA",
                "TLS_ECDHE_ECDSA_WITH_RC4_128_SHA",
                "TLS_ECDH_ECDSA_WITH_RC4_128_SHA",
                "TLS_ECDH_RSA_WITH_RC4_128_SHA",
                // Disable other weak suites
                "TLS_DHE_RSA_WITH_AES_128_CBC_SHA",
                "TLS_DHE_RSA_WITH_AES_128_CBC_SHA256",
                "SSL_DHE_RSA_WITH_3DES_EDE_CBC_SHA", "TLS_DHE_RSA_WITH_3DES_EDE_CBC_SHA" // need to have the 'SSL' prefix as well
        );
        // SSLv3 is too broken
        factory.addExcludeProtocols("SSLv3");
    }
}
