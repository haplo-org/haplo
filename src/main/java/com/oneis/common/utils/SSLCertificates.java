/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.common.utils;

import java.io.*;
import java.util.ArrayList;

import org.apache.commons.io.FileUtils;

import javax.net.ssl.*;
import java.security.*;
import java.security.cert.*;
import java.security.spec.RSAPrivateCrtKeySpec;

import org.bouncycastle.asn1.ASN1InputStream;
import org.bouncycastle.asn1.ASN1Sequence;
import org.bouncycastle.asn1.DERInteger;
import org.bouncycastle.util.encoders.Base64;

public class SSLCertificates {
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

    private static byte[] readPEMBytes(Reader inputReader, String source) throws java.io.IOException {
        BufferedReader reader = new BufferedReader(inputReader);
        String line = reader.readLine();
        if(line == null && !line.startsWith("-----BEGIN ")) {
            throw new RuntimeException("Doesn't look like a PEM file: " + source);
        }
        StringBuffer buffer = new StringBuffer();
        while((line = reader.readLine()) != null && !line.startsWith("-----END ")) {
            buffer.append(line.trim());
        }
        if(line == null) {
            throw new RuntimeException("End marker not found in PEM file: " + source);
        }
        reader.close();
        inputReader.close();
        return Base64.decode(buffer.toString());
    }

    public static ByteArrayInputStream readPEM(Reader reader, String source) throws java.io.IOException {
        return new ByteArrayInputStream(readPEMBytes(reader, source));
    }

    public static ByteArrayInputStream readPEM(String filename) throws java.io.IOException {
        return readPEM(new FileReader(filename), filename);
    }

    private static PrivateKey readPEMPrivateKey(String filename) throws java.io.IOException, java.security.GeneralSecurityException {
        ByteArrayInputStream bIn = readPEM(filename);
        ASN1InputStream aIn = new ASN1InputStream(bIn);
        ASN1Sequence seq = (ASN1Sequence)aIn.readObject();
        if(!(seq.getObjectAt(1) instanceof DERInteger)) {
            throw new RuntimeException("Can't read RSA private key from " + filename + " - if file starts '-----BEGIN PRIVATE KEY-----' then it needs converting to RSA format with 'openssl rsa -in server-in.key -out server.key'.");
        }
        DERInteger mod = (DERInteger)seq.getObjectAt(1);
        DERInteger pubExp = (DERInteger)seq.getObjectAt(2);
        DERInteger privExp = (DERInteger)seq.getObjectAt(3);
        DERInteger p1 = (DERInteger)seq.getObjectAt(4);
        DERInteger p2 = (DERInteger)seq.getObjectAt(5);
        DERInteger exp1 = (DERInteger)seq.getObjectAt(6);
        DERInteger exp2 = (DERInteger)seq.getObjectAt(7);
        DERInteger crtCoef = (DERInteger)seq.getObjectAt(8);

        RSAPrivateCrtKeySpec privSpec = new RSAPrivateCrtKeySpec(mod.getValue(),
                pubExp.getValue(), privExp.getValue(), p1.getValue(), p2.getValue(),
                exp1.getValue(), exp2.getValue(), crtCoef.getValue());

        KeyFactory factory = KeyFactory.getInstance("RSA");
        return factory.generatePrivate(privSpec);
    }
}
