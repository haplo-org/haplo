/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


var x = [AA.DateAlias, T.CreatedType, A.Type, Q.OptionalAlternative];

if("OptionalOne" in Q) {
    throw new Error("Unexpected optional qualifier present");
}
if(!Group || ("OptionalGroup" in Group)) {
    throw new Error("Group local not present or unexpected optional group present");
}
