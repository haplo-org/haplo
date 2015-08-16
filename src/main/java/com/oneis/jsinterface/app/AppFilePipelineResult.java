/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


package com.oneis.jsinterface.app;

public interface AppFilePipelineResult {

    public String name();

    public boolean success();

    public String dataJSON();

    public String error_message();

    public AppStoredFile get_stored_file(String name, String filename);
}
