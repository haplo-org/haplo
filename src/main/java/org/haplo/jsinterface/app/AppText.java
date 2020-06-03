/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.jsinterface.app;

public interface AppText {
    // Conversion to String done through Ruby support code in KText.java
    public String to_html();

    public int k_typecode();

    // For KIdentifierFile -- JRuby doesn't allow a KText subclass to implement another interface
    public String digest();

    public long size();

    public String mime_type();

    public String tracking_id();

    public String log_message();

    public String version_string();

    // Mutability

    public AppText dup(); // used for copy

    public void setMime_type(String mimeType);

    public void setPresentation_filename(String filename);

    public void setTracking_id(String trackingId);

    public void setLog_message(String log);

    public void setVersion_string(String version);
}
