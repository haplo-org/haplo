/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

TEST(function() {

    // Random integers
    TEST.assert(O.security.random.int32() != O.security.random.int32());
    var v = O.security.random.int32();
    TEST.assert(v >= 0);
    TEST.assert(v < 4294967295);
    TEST.assert_equal(Math.round(v), v);    // is integer

    // Random hex strings
    var checkHexRandom = function(h) {
        TEST.assert(/^[0-9a-f]+$/.test(h));
        return h;
    };
    TEST.assert_equal(48, checkHexRandom(O.security.random.hex()).length); // default
    TEST.assert_equal(60, checkHexRandom(O.security.random.hex(30)).length);
    TEST.assert(checkHexRandom(O.security.random.hex()) != checkHexRandom(O.security.random.hex()));
    TEST.assert(checkHexRandom(O.security.random.hex(25)) != checkHexRandom(O.security.random.hex(25)));

    // Random API keys
    var checkAPIKeyRandom = function(k) {
        TEST.assert(/^[a-zA-Z0-9_\-]+$/.test(k));
        return k;
    };
    TEST.assert_equal(44, checkAPIKeyRandom(O.security.random.identifier()).length); // default
    TEST.assert_equal(34, checkAPIKeyRandom(O.security.random.identifier(25)).length);
    TEST.assert(checkAPIKeyRandom(O.security.random.identifier()) != checkAPIKeyRandom(O.security.random.identifier()));
    TEST.assert(checkAPIKeyRandom(O.security.random.identifier(25)) != checkAPIKeyRandom(O.security.random.identifier(25)));

    // Base 64
    TEST.assert_equal(45, O.security.random.base64().length);
    TEST.assert_equal(163, O.security.random.base64(120).length);
    TEST.assert(O.security.random.base64() != O.security.random.base64());
    TEST.assert(O.security.random.base64(244) != O.security.random.base64(244));

    // --------------------------------------------------------------------------------------------
    // BCrypt

    // Check known encoded password
    var PASSWORD_BCRYPTED = '$2a$10$PtSNGlLXC5mgTrTcTioJuezprtYzfsrX3OYsc.4/8wNWPIJVxS28u';
    TEST.assert(O.security.bcrypt.verify('password', PASSWORD_BCRYPTED));
    TEST.assert(!(O.security.bcrypt.verify('afd98fij', PASSWORD_BCRYPTED)));

    // Encode a new password
    var encode1 = O.security.bcrypt.create('hello123');
    TEST.assert(encode1 != PASSWORD_BCRYPTED);
    TEST.assert(/^\$\w+\$/.test(encode1));  // check it looks about right
    TEST.assert(O.security.bcrypt.verify('hello123', encode1));
    TEST.assert(!(O.security.bcrypt.verify('password', encode1)));
    TEST.assert(!(O.security.bcrypt.verify('afd98fij', encode1)));

    // Encoding again shouldn't have the same output
    var encode2 = O.security.bcrypt.create('hello123');
    TEST.assert(encode2 != encode1);

    // Check bad calls throw exceptions
    // create()
    TEST.assert_exceptions(function() { O.security.bcrypt.create(''); });
    TEST.assert_exceptions(function() { O.security.bcrypt.create(null); });
    TEST.assert_exceptions(function() { O.security.bcrypt.create(undefined); });
    TEST.assert_exceptions(function() { O.security.bcrypt.create({pants:true}); });
    // verify()
    TEST.assert_exceptions(function() { O.security.bcrypt.verify('password', ''); });
    TEST.assert_exceptions(function() { O.security.bcrypt.verify('password', null); });
    TEST.assert_exceptions(function() { O.security.bcrypt.verify('password', undefined); });
    TEST.assert_exceptions(function() { O.security.bcrypt.verify('password', {pants:true}); });
    TEST.assert_exceptions(function() { O.security.bcrypt.verify('password', "not a BCrypt encoding"); });
    // But verify() is a little more tolerant of bad passwords for ease of use
    TEST.assert_equal(false, O.security.bcrypt.verify('', PASSWORD_BCRYPTED));
    TEST.assert_equal(false, O.security.bcrypt.verify(null, PASSWORD_BCRYPTED));
    TEST.assert_equal(false, O.security.bcrypt.verify(undefined, PASSWORD_BCRYPTED));
    TEST.assert_equal(false, O.security.bcrypt.verify({carrots:false}, PASSWORD_BCRYPTED));

    // Check non-ASCII passwords work
    var encode_na = O.security.bcrypt.create('abc日本語');
    TEST.assert(encode_na != PASSWORD_BCRYPTED);
    TEST.assert(encode_na != encode1);
    TEST.assert(O.security.bcrypt.verify('abc日本語', encode_na));
    TEST.assert(!(O.security.bcrypt.verify('abc???', encode_na))); // old version of library had security flaw which converted non-ASCII chars to ?


    // --------------------------------------------------------------------------------------------
    // Digests

    TEST.assert_exceptions(function() { O.security.digest.hexDigestOfString("ping", "b"); }, "Error generating digest with algorithm ping");

    TEST.assert_equal("d41d8cd98f00b204e9800998ecf8427e", O.security.digest.hexDigestOfString("MD5", ""));
    TEST.assert_equal("9e107d9d372bb6826bd81d3542a419d6", O.security.digest.hexDigestOfString("MD5", "The quick brown fox jumps over the lazy dog"));

    TEST.assert_equal("da39a3ee5e6b4b0d3255bfef95601890afd80709", O.security.digest.hexDigestOfString("SHA1", ""));
    TEST.assert_equal("2fd4e1c67a2d28fced849ee1bb76e7391b93eb12", O.security.digest.hexDigestOfString("SHA1", "The quick brown fox jumps over the lazy dog"));
    TEST.assert_equal("da39a3ee5e6b4b0d3255bfef95601890afd80709", O.security.digest.hexDigestOfString("SHA-1", ""));
    TEST.assert_equal("2fd4e1c67a2d28fced849ee1bb76e7391b93eb12", O.security.digest.hexDigestOfString("SHA-1", "The quick brown fox jumps over the lazy dog"));

    TEST.assert_equal("e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", O.security.digest.hexDigestOfString("SHA256", ""));
    TEST.assert_equal("d7a8fbb307d7809469ca9abcb0082e4f8d5651e46d3cdb762d02d0bf37c9e592", O.security.digest.hexDigestOfString("SHA256", "The quick brown fox jumps over the lazy dog"));
    TEST.assert_equal("e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", O.security.digest.hexDigestOfString("SHA-256", ""));
    TEST.assert_equal("d7a8fbb307d7809469ca9abcb0082e4f8d5651e46d3cdb762d02d0bf37c9e592", O.security.digest.hexDigestOfString("SHA-256", "The quick brown fox jumps over the lazy dog"));

    // Check UTF-8 conversion
    TEST.assert_equal("19ca3d2a39765ef3cc3d7c58e38e1ade6127022d63c793d39a4051954a8cbb4c", O.security.digest.hexDigestOfString("SHA256", "UNICODE SNOWMAN ☃ 123456789123456789"));

    // --------------------------------------------------------------------------------------------
    // HMAC

    var hmac_secret = "secret secret 123456789123456789";

    TEST.assert_exceptions(function() { O.security.hmac.sign("ping", hmac_secret, "b"); }, "Unknown algorithm passed to O.security.hmac.sign()");
    TEST.assert_exceptions(function() { O.security.hmac.sign("SHA1", "12345", "c"); }, "Secret passed to O.security.hmac.sign() must be at least 32 characters long");

    // Generate test signatures with commands like
    //   echo -n "Input document" | openssl dgst -md5 -hex -hmac "secret secret 123456789123456789"

    var md5_signature = O.security.hmac.sign("MD5", hmac_secret, "Input document");
    TEST.assert_equal("73b0b86c744e6ae4883213f0cbdf9390", md5_signature);

    var sha1_signature = O.security.hmac.sign("SHA1", hmac_secret, "Input document 2");
    TEST.assert_equal("62492313dac3e80e3f6d980f2ebcafa5d774f336", sha1_signature);

    var sha256_signature = O.security.hmac.sign("SHA256", hmac_secret, "Input document 3");
    TEST.assert_equal("62dd12b5ee7d68c5ad78df4a0a6caa5729155647276791f49981400779be2369", sha256_signature);

    // Test UTF-8 encoding is used
    var sha256_signature2 = O.security.hmac.sign("SHA256", "UNICODE SNOWMAN ☃ 123456789123456789", "Input document with snowman ☃");
    TEST.assert_equal("a8c7d8ccb2c057fc97a5a1df6bc30bdd08d91ee716ae2321104e3cbd9c768b55", sha256_signature2);

});
