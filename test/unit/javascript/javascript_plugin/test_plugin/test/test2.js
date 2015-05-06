
t.test(function() {
    t.assert(42 == 42);
    // This test fails
    t.assert(false, "test2 fail msg");
});
