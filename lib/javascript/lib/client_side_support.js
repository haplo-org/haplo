/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


(function() {

    O.editor = {};

    O.editor.decode = function(encoded, object) {
        if(!(object instanceof $StoreObject) || !(object.firstType())) {
            throw new Error("O.editor.decode() must be passed a StoreObject which has a type attribute.");
        }
        $StoreObject._clientSideEditorDecode(encoded, object);
        return object;
    };

    O.editor.encode = function(object) {
        if(!(object instanceof $StoreObject) || !(object.firstType())) {
            throw new Error("O.editor.encode() must be passed a StoreObject.");
        }
        return $StoreObject._clientSideEditorEncode(object);
    };

})();
