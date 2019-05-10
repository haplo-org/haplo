/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.common.utils;

import java.io.*;
import java.util.ArrayList;

import org.apache.commons.io.FileUtils;

import javax.net.ssl.*;
import java.security.*;
import java.security.cert.*;
import java.security.spec.RSAPrivateCrtKeySpec;

import org.bouncycastle.jce.provider.BouncyCastleProvider;
import org.bouncycastle.openssl.PEMParser;
import org.bouncycastle.openssl.PEMKeyPair;
import org.bouncycastle.util.io.pem.PemReader;
import org.bouncycastle.util.io.pem.PemObject;
import org.bouncycastle.util.io.pem.PemGenerationException;
import org.bouncycastle.openssl.jcajce.JcaPEMKeyConverter;


public class SSLCertificates {
    static {
        Security.addProvider(new BouncyCastleProvider());
    }

    public static SSLContext load(String keysDirectory, String certsName, String clientCAName) throws Exception {
        return load(keysDirectory, certsName, clientCAName, false);
    }

    public static SSLContext load(String keysDirectory, String certsName, String clientCAName, boolean quiet) throws Exception {
        // For some indiciation of what's going on early in the boot process
        if(!quiet) {
            System.out.println("Loading " + certsName + " SSL certificates from " + keysDirectory);
        }

        // Get filenames
        String keyPathname = keysDirectory + "/" + certsName + ".key";
        String certPathname = keysDirectory + "/" + certsName + ".crt";
        final String intermediateCertPathnameBase = keysDirectory + "/" + certsName + "-intermediate";
        String clientCAPathname = null;
        if(clientCAName != null) {
            clientCAPathname = keysDirectory + "/" + clientCAName + ".crt";
        }

        if(!new File(keyPathname).exists()) {
            System.out.println("Doesn't exist: " + keyPathname);
            return null;
        }
        if(!new File(certPathname).exists()) {
            System.out.println("Doesn't exist: " + certPathname);
            return null;
        }
        if(clientCAPathname != null) {
            if(!new File(clientCAPathname).exists()) {
                System.out.println("Doesn't exist: " + clientCAPathname);
                return null;
            }
        }

        char[] nullPassword = {};

        PrivateKey privateKey = readPEMPrivateKey(keyPathname);

        CertificateFactory cf = CertificateFactory.getInstance("X.509");
        // Server certificate
        ArrayList<java.security.cert.Certificate> certList = new ArrayList<java.security.cert.Certificate>(4);
        java.security.cert.Certificate cert = cf.generateCertificate(readPEM(certPathname));
        certList.add(cert);
        // Optional intermediate certificates
        int intermediateCounter = 1;
        while(true) {
            String intermediateCertPathname = intermediateCertPathnameBase;
            if(intermediateCounter != 1) {
                intermediateCertPathname += "-" + intermediateCounter;
            }
            intermediateCounter++;
            intermediateCertPathname += ".crt";
            if(new File(intermediateCertPathname).exists()) {
                certList.add(cf.generateCertificate(readPEM(intermediateCertPathname)));
            } else {
                // End of cert list
                break;
            }
        }
        // Optional client CA certificate
        java.security.cert.Certificate clientCACert = null;
        if(clientCAPathname != null) {
            clientCACert = cf.generateCertificate(readPEM(clientCAPathname));
        }
        if(clientCAName != null && clientCACert == null) {
            throw new RuntimeException("Logic error, failed to load client CA cert when required");
        }

        KeyStore ks = KeyStore.getInstance("JKS", "SUN");
        ks.load(null, nullPassword);
        ks.setKeyEntry("ONEIS", (Key)privateKey, "".toCharArray(), certList.toArray(new java.security.cert.Certificate[certList.size()]));

        if(clientCACert != null) {
            KeyStore.TrustedCertificateEntry tce = new KeyStore.TrustedCertificateEntry(clientCACert);
            ks.setEntry("CLIENTCA", tce, null);
        }

        // Generate some random Java API stuff, just for entertainment
        KeyManagerFactory kmf = KeyManagerFactory.getInstance("SunX509");
        kmf.init(ks, nullPassword);
        TrustManagerFactory tmf = TrustManagerFactory.getInstance("SunX509");
        tmf.init(ks);

        SSLContext sslContext = SSLContext.getInstance("TLS");
        sslContext.init(kmf.getKeyManagers(), tmf.getTrustManagers(), null);

        if(!quiet) {
            System.out.println(" - server cert chain length " + certList.size() + (clientCACert != null ? ", requires client cert" : ", public server"));
        }
        return sslContext;
    }

    public static ByteArrayInputStream readPEM(Reader reader, String source) throws java.io.IOException {
        PemReader pemReader = new PemReader(reader);
        PemObject object = pemReader.readPemObject();
        return new ByteArrayInputStream(object.getContent());
    }

    public static ByteArrayInputStream readPEM(String filename) throws java.io.IOException {
        try(FileReader reader = new FileReader(filename)) {
            return readPEM(reader, filename);
        }
    }

    public static PrivateKey readPEMPrivateKey(Reader reader) throws java.io.IOException, PemGenerationException {
        PEMParser parser = new PEMParser(reader);
        Object object = parser.readObject();
        JcaPEMKeyConverter converter = new JcaPEMKeyConverter().setProvider("BC");
        KeyPair kp = converter.getKeyPair((PEMKeyPair)object);
        return kp.getPrivate();
    }

    public static PrivateKey readPEMPrivateKey(String filename) throws java.io.IOException, PemGenerationException {
        try(FileReader reader = new FileReader(filename)) {
            return readPEMPrivateKey(reader);
        }
    }
}
