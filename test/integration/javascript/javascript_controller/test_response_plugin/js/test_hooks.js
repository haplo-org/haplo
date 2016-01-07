/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


    P.hook("hLabellingUserInterface", function(response, object, user, operation) {
        var type = object.firstType();
        var type_obj = type.load();
        var title = type_obj.firstTitle().toString().split("-");
        if(title[0] !== "add_label_option"){ return; }
        switch(title[1]) {
            case "book":
                response.ui.label(TYPE["std:type:book"], false);
                break;
            case "book_selected":
                response.ui.label(TYPE["std:type:book"], true);
                break;
            case "nonexistant":
                response.ui.label(O.ref(9999), true);
                break;
            case "multiple":
                response.ui.label(TYPE["std:type:book"], false);
                response.ui.label(TYPE["std:type:equipment:laptop"], true);
                break;
            case "invalid":
                response.ui.label("FOO");
                break;
        }
    });
