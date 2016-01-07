/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    var t1 = O.text(O.T_TEXT_PARAGRAPH, "Ping");
    // Removed property
    TEST.assert_exceptions(function() { var x = t1.isIdentifier; }, "isIdentifier property is no longer implemented");
    // NOTE: toHTML and toString interleaved to check caching works
    TEST.assert_equal("<p>Ping</p>", t1.toHTML());
    TEST.assert_equal("Ping", t1.toString());
    TEST.assert_equal("Ping", t1.toString());   // cached
    TEST.assert_equal("Ping", t1.s());  // abbreviation
    TEST.assert_equal("<p>Ping</p>", t1.toHTML());  // cached
    TEST.assert(_.isEqual(t1.toFields(), {"typecode":O.T_TEXT_PARAGRAPH})); // check toFields() only returns a typecode

    // Telephone number formatting
    var phone1 = O.text(O.T_IDENTIFIER_TELEPHONE_NUMBER, {guess_number:"+442070471111", guess_country:"GB"});
    // Repeats to check caching
    TEST.assert_equal("(United Kingdom) +44 20 7047 1111", phone1.toString());
    TEST.assert_equal("(United Kingdom) +44 20 7047 1111", phone1.toString());
    TEST.assert_equal("+442070471111", phone1.toString("dial"));
    TEST.assert_equal("(United Kingdom) +44 20 7047 1111", phone1.toString());

    // Try again in a different order, again, to make sure caching isn't a problem
    var phone2 = O.text(O.T_IDENTIFIER_TELEPHONE_NUMBER, {guess_number:"+442070471112", guess_country:"GB"});
    TEST.assert_equal("+442070471112", phone2.toString("dial"));
    TEST.assert_equal("(United Kingdom) +44 20 7047 1112", phone2.toString());
    TEST.assert_equal("+442070471112", phone2.toString("dial"));
    TEST.assert_equal("(United Kingdom) +44 20 7047 1112", phone2.toString());
    TEST.assert(_.isEqual(phone2.toFields(), {"typecode":O.T_IDENTIFIER_TELEPHONE_NUMBER,"country":"GB","number":"02070471112"}));

    // Other formats
    TEST.assert_equal("+44 20 7047 1111", phone1.toString("short"));
    TEST.assert_equal("+44 20 7047 1111", phone1.toString("export"));

    // Strict arguments + extension
    var phone3 = O.text(O.T_IDENTIFIER_TELEPHONE_NUMBER, {country:"GB", number:"02070471113", extension:"XYZ_ -987"});
    TEST.assert_equal("+442070471113", phone3.toString("dial"));
    TEST.assert_equal("(United Kingdom) +44 20 7047 1113 ext XYZ_ -987", phone3.toString());
    TEST.assert(_.isEqual(phone3.toFields(), {"typecode":O.T_IDENTIFIER_TELEPHONE_NUMBER,"country":"GB","number":"02070471113","extension":"XYZ_ -987"}));

    // Test creation and toFields of other text types
    var addr1 = O.text(O.T_IDENTIFIER_POSTAL_ADDRESS, {"street1":"s1", "street2":"s2", "city":"ci", "county":"co", "postcode":"pc", "country":"GB"});
    TEST.assert(_.isEqual(addr1.toFields(), {"typecode":O.T_IDENTIFIER_POSTAL_ADDRESS, "street1":"s1", "street2":"s2", "city":"ci", "county":"co", "postcode":"pc", "country":"GB"}));
    var person1 = O.text(O.T_TEXT_PERSON_NAME, {"first":"f", "middle":"m", "last":"l", "suffix":"s", "title":"t"});
    TEST.assert(_.isEqual(person1.toFields(), {"typecode":O.T_TEXT_PERSON_NAME, "culture":"western", "first":"f", "middle":"m", "last":"l", "suffix":"s", "title":"t"}));

    // Email addresses are identifiers
    var email1 = O.text(O.T_IDENTIFIER_EMAIL_ADDRESS, "test@example.com");

    // Configuration name identifiers
    var configName1 = O.text(O.T_IDENTIFIER_CONFIGURATION_NAME, "test_plugin:hello");
    TEST.assert_equal("test_plugin:hello", configName1.toString());
    TEST.assert_exceptions(function() {
        O.text(O.T_IDENTIFIER_CONFIGURATION_NAME, {text:"test_plugin:hello"});
    }, "O.text(O.T_IDENTIFIER_CONFIGURATION_NAME,...) must be passed a String.");
    _.each([
        ":hello", "hello:", "ping!:pong", "carrots:*", "*:carrots"
    ], function(bad) {
        TEST.assert_exceptions(function() {
            O.text(O.T_IDENTIFIER_CONFIGURATION_NAME, bad);
        }, "O.text(O.T_IDENTIFIER_CONFIGURATION_NAME,...) must be formed of a-zA-Z0-9_ and contain at least one : separator.");
    });

    // Bad format
    TEST.assert_exceptions(function() { phone1.toString("random format"); });

});
