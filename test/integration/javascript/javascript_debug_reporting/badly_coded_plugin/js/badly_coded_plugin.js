

P.hook('hGetReportsList', function(response) {
    this.ping(); // org.mozilla.javascript.EcmaError
});




P.respond("GET", "/do/test_error/ruby_api", [], function(E) {
    $host.getApplicationInformation("--bad-info"); // JavaScriptAPIError
});

P.respond("GET", "/do/test_error/java_api", [], function(E) {
    $host.registerPlugin("carrots", {}); // org.haplo.javascript.OAPIException
});

P.respond("GET", "/do/test_error/js_throw", [], function(E) {
    new DBTime(); // org.mozilla.javascript.JavaScriptException
});

//    P.respond("GET", "/do/test_error/ar_notfound", [], function(E) {
//        O.group(12346); // ActiveRecord::RecordNotFound
//    });

P.respond("GET", "/do/test_error/stackoverflow", [], function(E) {
    var x = function() {
        x(); // java.lang.StackOverflowError
    };
    x();
});

P.respond("GET", "/do/test_error/nullpointerexception", [], function(E) {
    var x = function() {
        O.query().$kquery.link(undefined); // java.lang.NullPointerException
    };
    x();
});

P.respond("GET", "/do/test_error/bad_standard_layout", [], function(E) {
    E.response.body = '<p>X</>';
    E.response.kind = 'html';
    E.response.layout = 'std:randomness';
});

P.respond("POST", "/do/test_error/no_file_upload", [], function(E) {
    E.response.kind = 'text'; E.response.body = "no files";
});

P.respond("GET", "/do/test_error/bad_schema_name", [], function(E) {
    var x = TYPE["test:type:which-does-not-exist"];
});

