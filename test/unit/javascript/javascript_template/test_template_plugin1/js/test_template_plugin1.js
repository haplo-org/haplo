/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


P.globalTemplateFunction("test1:staticquoted", function() {
    return '<b>';
});

P.globalTemplateFunction("test1:hello", function(x) {
    this.unsafeWriteHTML("<b>");
    this.write(x);
    this.unsafeWriteHTML("</b>");
});
