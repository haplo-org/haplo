
T.test(function() {
    // Last test left the user logged in, but everything should have been reset
    T.assert(!O.isHandlingRequest);
});
