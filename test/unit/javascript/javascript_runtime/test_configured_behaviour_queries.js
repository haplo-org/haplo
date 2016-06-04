/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    var foo = O.ref(FOO);
    TEST.assert_equal('test:behaviour:foo', O.ref(FOO).behaviour);
    var foo = O.ref(FOO);
    TEST.assert_equal('test:behaviour:foo', foo.behaviour);
    TEST.assert_equal('test:behaviour:foo', foo.behaviour);

    TEST.assert(O.behaviourRef('test:behaviour:foo') instanceof $Ref);
    TEST.assert_equal(FOO, O.behaviourRef('test:behaviour:foo').objId);

    TEST.assert_equal('test:behaviour:foo', O.ref(FOOCHILD).behaviour);
    TEST.assert_equal('test:behaviour:foo', O.ref(FOOCHILD2).behaviour);
    TEST.assert_equal('test:behaviour:foo', O.ref(FOOCHILD3).behaviour);
    TEST.assert_equal('test:behaviour:bar', O.ref(BAR).behaviour);
    TEST.assert_equal('test:behaviour:bar', O.ref(BARCHILD).behaviour);
    TEST.assert_equal(null, O.ref(NOTHING).behaviour);

    TEST.assert_equal(FOO, O.behaviourRef('test:behaviour:foo').objId);
    TEST.assert_equal(FOO, O.behaviourRef('test:behaviour:foo').objId); // repeated
    TEST.assert(O.behaviourRef('test:behaviour:foo') === O.behaviourRef('test:behaviour:foo')); // Identical objects from cache
    TEST.assert_equal(BAR, O.behaviourRef('test:behaviour:bar').objId);
    TEST.assert_equal(FOOCHILD3, O.behaviourRef('test:behaviour:foochild3').objId);

    TEST.assert_exceptions(function() { O.behaviourRef('test:nothing'); }, "Unknown behaviour: test:nothing");
    TEST.assert_equal(null, O.behaviourRefMaybe('test:nothing'));
    TEST.assert_equal(null, O.behaviourRefMaybe('test:nothing')); // repeated

    TEST.assert_exceptions(function() { O.behaviourRef(2); }, "Must pass String to O.behaviourRef()");
    TEST.assert_exceptions(function() { O.behaviourRefMaybe(2); }, "Must pass String to O.behaviourRefMaybe()");

});
