/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


P.hook("hUserPermissionRules", function(response, user) {
    // Check that impersonating system doesn't cause a problem here
    O.impersonating(O.SYSTEM, function() {});

    if(!(user.nameLast) == "permission-rules") { return; }
    switch(user.nameFirst) {
        case "deny-common":
            // Use rule() rather than add() to check compatibility
            response.rules.rule(LABEL["std:label:common"], O.STATEMENT_DENY, O.PERM_ALL);
            break;
        case "rcommon-cubook":
            response.rules.add(LABEL["std:label:common"], O.STATEMENT_ALLOW, O.PERM_READ);
            response.rules.add(TYPE["std:type:book"], O.STATEMENT_ALLOW, O.PERM_CREATE | O.PERM_UPDATE);
            break;
        case "conflicting":
            response.rules.add(LABEL["std:label:common"], O.STATEMENT_DENY, O.PERM_READ | O.PERM_CREATE );
            response.rules.add(LABEL["std:label:common"], O.STATEMENT_RESET, O.PERM_READ | O.PERM_UPDATE);
            response.rules.add(LABEL["std:label:common"], O.STATEMENT_ALLOW, O.PERM_READ | O.PERM_DELETE);
            break;
        case "bad-1":
            response.rules.add();
            break;
        case "bad-2":
            response.rules.add("TEXT", O.STATEMENT_ALLOW, O.PERM_READ);
            break;
        case "bad-3":
            response.rules.add(LABEL["std:label:common"], 55, O.PERM_READ);
            break;
        case "bad-4":
            response.rules.add(LABEL["std:label:common"], O.STATEMENT_DENY, 99);
            break;
        case "bad-5":
            response.rules.add(LABEL["std:label:common"], O.STATEMENT_DENY, O.PERM_READ, "FOO");
            break;
        case "bad-6":
            response.rules.add(undefined, O.STATEMENT_DENY, O.PERM_READ);
            break;
        case "bad-7":
            response.rules.add(LABEL["std:label:common"], undefined, O.PERM_READ);
            break;
        case "bad-8":
            response.rules.add(LABEL["std:label:common"], O.STATEMENT_DENY, undefined);
            break;
        case "laptop-title":
            var laptops = O.query().link(TYPE["std:type:equipment:laptop"], ATTR.Type).execute();
            if(laptops.length == 0) return;
            console.log(laptops[0].firstTitle().toString());
            if(laptops[0].firstTitle().toString() == "DENY") {
                response.rules.add(LABEL["std:label:common"], O.STATEMENT_DENY, O.PERM_ALL);
            } else {
                response.rules.add(LABEL["std:label:common"], O.STATEMENT_ALLOW, O.PERM_ALL);
            }
    }
});

P.hook('hUserLabelStatements', function(response, user) {
    // Check that impersonating system doesn't cause a problem here
    O.impersonating(O.SYSTEM, function() {});

    if(!(user.nameLast) === "permission-rules") { return; }
    if(user.nameFirst === "modify-statements") {
        var builder = O.labelStatementsBuilder();
        builder.rule(99774422, O.STATEMENT_ALLOW, O.PERM_READ);
        response.statements = response.statements.or(builder.toLabelStatements());
    }
});
