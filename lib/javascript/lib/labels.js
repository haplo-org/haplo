/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


(function() {

    // TODO: Consider renaming these constructor functions? eg O.label.list(), O.label.statementsBuilder() ?
    O.labelList = function() {
        if(arguments.length == 1 && arguments[0] instanceof $LabelList) {
            return arguments[0];
        }
        return new $LabelList(_.flatten(_.toArray(arguments)));
    };
    O.labelChanges = function(add, remove) {
        return new $LabelChanges(add ? _.flatten([add]) : null, remove ? _.flatten([remove]) : null);
    };
    O.labelStatementsBuilder = function() {
        return new $LabelStatementsBuilder();
    };

    // Used for hUserPermissionRules response.rules
    // There's no Ruby equivalent, and it's serialised to JSON for sending back to the Ruby code.
    $LabelStatementsBuilder = function() {
        this.rules = [];
    };
    _.extend($LabelStatementsBuilder.prototype, {
        rule: function(label, statement, permissions) {
            if(label instanceof $Ref) {
                label = label.objId;
            }
            if((typeof(label) !== "number") || (label <= 0)) {
                throw new Error("Bad label value");
            }
            // TODO: Better checking of values for statement and permissions
            if(arguments.length !== 3) {
                throw new Error("Bad permission rule statement");
            }
            this.rules.push([$host.getCurrentlyExecutingPluginName(), 1*label, 1*statement, 1*permissions]);
        },
        toLabelStatements: function() {
            var json = JSON.stringify(this);
            return $LabelStatements.fromBuilder(json);
        }
    });
    // Alias to make some code read a bit more nicely
    $LabelStatementsBuilder.prototype.add = $LabelStatementsBuilder.prototype.rule;

    // Used for hLabellingUserInterface
    // There's no Ruby equivalent, and it's serialised to JSON for sending back to the Ruby code.
    $LabellingUserInterface = function() {
        this.labels = [];
    };
    _.extend($LabellingUserInterface.prototype, {
        label: function(label, offerAsDefault) {
            if(!(label instanceof $Ref)) {
                throw new Error("label must be a Ref");
            }
            this.labels.push([$host.getCurrentlyExecutingPluginName(), label.objId, !!(offerAsDefault)]);
        }
    });

})();
