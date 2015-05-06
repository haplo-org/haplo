
t.test(function() {
    // Last test left the user logged in, but everything should have been reset
    t.assert(!O.isHandlingRequest);
});
