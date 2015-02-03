
T.test(function() {
    T.assert(42 == 42);
    // This test fails
    T.assert(false, "test2 fail msg");
});
