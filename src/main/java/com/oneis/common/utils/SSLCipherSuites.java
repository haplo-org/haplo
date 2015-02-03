/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.common.utils;

import org.eclipse.jetty.util.ssl.SslContextFactory;

public class SSLCipherSuites {
    static public void configureCipherSuites(SslContextFactory factory) {
        factory.setExcludeCipherSuites(
                // Disable suites which are weak with Java SSL implementation (small and unchangeable DH key size)
                "TLS_DHE_RSA_WITH_AES_128_CBC_SHA",
                "TLS_DHE_RSA_WITH_AES_128_CBC_SHA256",
                "SSL_DHE_RSA_WITH_3DES_EDE_CBC_SHA", "TLS_DHE_RSA_WITH_3DES_EDE_CBC_SHA", // need to have the 'SSL' prefix as well
                "TLS_DHE_RSA_WITH_AES_256_CBC_SHA",
                "TLS_DHE_RSA_WITH_AES_256_CBC_SHA256"
        );
        // SSLv3 is too broken
        factory.addExcludeProtocols("SSLv3");
    }
}
