/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

TEST(function() {

    console.log("__L_O_G__");
    console.debug("__D_E_B_U_G__");
    console.info("__I_N_F_O__");
    console.warn("__W_A_R_N__");
    console.error("__E_R_R_O_R__");
    console.dir("__D_I_R__");
    console.time("__T1__");
    console.timeEnd("__T1__");
    console.log("X1:%s X2:%d X3:%j", "ping", 56, [42], "LAST");
    console.log([32], [53], "pong");

    console.log(O.ref(633807));
    console.log(null);
    var refDict = O.refdict();
    refDict.set(O.ref(1), {});
    refDict.set(O.ref(2), "Hello");
    refDict.set(O.ref(3), "World");
    refDict.set(O.ref(0xfa), false);
    refDict.set(O.ref(0xfb), O.refdict());
    console.log(refDict);
    console.log(SCHEMA);

    console.log("labelList:", O.labelList([O.ref(9999), O.ref(8888)]));
    console.log("labelChanges:", O.labelChanges([O.ref(9999)], [O.ref(8888)]));

    console.log(O.user(41));
    console.log(O.query());
});
