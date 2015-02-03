/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.jsinterface.app;

public interface AppStoredFile {
    public int id();

    public long jsGetCreatedAt();

    public String digest();

    public long size();

    public String upload_filename();

    public String jsGetBasename();

    public String mime_type();

    public String disk_pathname();

    // TODO: Make stored file dimensions and thumbnail info available in JS API

    public String generate_secret();

    public boolean compare_secret_to(String givenSecret);
}
