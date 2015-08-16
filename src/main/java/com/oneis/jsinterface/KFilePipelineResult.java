/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.jsinterface;

import com.oneis.javascript.Runtime;
import com.oneis.javascript.OAPIException;
import com.oneis.jsinterface.app.AppFilePipelineResult;
import com.oneis.jsinterface.app.AppStoredFile;
import com.oneis.jsinterface.KStoredFile;

public class KFilePipelineResult extends KScriptable {
    private AppFilePipelineResult result;

    // Interface from Ruby
    public static void callback(AppFilePipelineResult appResult) {
        Runtime runtime = Runtime.getCurrentRuntime();
        KFilePipelineResult result = (KFilePipelineResult)runtime.createHostObject("$FilePipelineResult");
        result.setResult(appResult);
        runtime.callSharedScopeJSClassFunction("O", "$fileTransformPipelineCallback", new Object[] { result });
    }

    public KFilePipelineResult() {
    }

    public void setResult(AppFilePipelineResult result) {
        this.result = result;
    }

    // --------------------------------------------------------------------------------------------------------------
    public void jsConstructor() {
    }

    public String getClassName() {
        return "$FilePipelineResult";
    }

    // --------------------------------------------------------------------------------------------------------------

    public String jsGet_name() {
        return this.result.name();
    }

    public boolean jsGet_success() {
        return this.result.success();
    }

    public Object jsGet_data() throws org.mozilla.javascript.json.JsonParser.ParseException {
        return Runtime.getCurrentRuntime().makeJsonParser().parseValue(this.result.dataJSON());
    }

    public String jsGet_errorMessage() {
        return this.result.error_message();
    }

    public KStoredFile jsFunction_file(String name, String filename) {
        AppStoredFile file = this.result.get_stored_file(name, filename);
        if(file == null) {
            throw new OAPIException("No file from pipeline with name '"+name+"'");
        }
        return KStoredFile.fromAppStoredFile(file);
    }

}
