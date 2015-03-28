/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


(function() {

    // TODO: Finish off the slightly experimental API for customising object rendering for search results
    // Quite a few of the operations could be 'static' as they specify what should happen, rather than doing anything immediately.

    var SearchResultRenderer = O.$private.SearchResultRenderer = function(plugin, object) {
        this.$plugin = plugin;
        this.object = object;
        this.$actions = [];
    };
    _.extend(SearchResultRenderer.prototype, {
        AUTO: {},   // unique object
        VALID_DESTINATIONS: ["subtitle", "subtitle-right", "column"],
        preventDefault: function() {
            this.$actions.push({action: "no-default"});
            return this;
        },
        hide: function(descs) {
            if(!(descs && _.isArray(descs))) {
                throw new Error("Must pass array to hide()");
            }
            this.$actions.push({action: "hide-descs", descs:descs});
            return this;
        },
        text: function(text, destination, caption, width) {
            return this._pushAction({action:"text", text:text}, destination, caption, width);
        },
        html: function(html, destination, caption, width) {
            return this._pushAction({action:"html", html:html}, destination, caption, width);
        },
        render: function(view, templateName, destination, width) {
            return this._pushAction({action:"html", html:this.$plugin.template(templateName).render(view)}, destination, view.caption, width);
        },
        firstValue: function(desc, destination, caption, width, showQualifiers) {
            return this._pushAction({action:"values", all:false, showQualifiers:!!(showQualifiers), desc:1*desc}, destination, caption, width);
        },
        allValues: function(desc, destination, caption, width, showQualifiers) {
            return this._pushAction({action:"values", all:true, showQualifiers:!!(showQualifiers), desc:1*desc}, destination, caption, width);
        },
        appendTextToSubtitleIfSubtitlePresent: function(text) {
            this.$actions.push({action:"subtitle-append-if", text:text});
            return this;
        },
        _pushAction: function(action, destination, caption, width) {
            if(-1 === this.VALID_DESTINATIONS.indexOf(destination)) {
                throw new Error("Unknown destination: "+destination);
            }
            action.destination = destination;
            if(caption === this.AUTO) {
                action.autoCaption = true;
            } else {
                if(caption && typeof(caption) === "string") {
                    action.caption = caption;
                }
            }
            if(width && typeof(width) === "number") {
                action.width = width;
            }
            this.$actions.push(action);
            return this;
        }
    });

    // ---------------------------------------------------------------------------------------------------------------

    var renderSearchResult = O.$private.renderSearchResult = function(object) {
        var i = $registry.renderSearchResultLookup.get(object.firstType());
        if(!i) { return; }
        var plugin = i[0], render = i[1];
        var renderer = new SearchResultRenderer(plugin, object);
        render.call(plugin, object, renderer);
        var actions = renderer.$actions;
        return (actions.length > 0) ? JSON.stringify(actions) : null;
    };

    // ---------------------------------------------------------------------------------------------------------------

    $Plugin.prototype.renderSearchResult = function(type, render) {
        if(!(type instanceof $Ref)) { throw new Error("type argument to renderSearchResult() must be a Ref"); }
        if(typeof(render) !== "function") { throw new Error("render argument to renderSearchResult() must be a function"); }
        // Setup required?
        var lookup = $registry.renderSearchResultLookup;
        if(!lookup) {
            lookup = $registry.renderSearchResultLookup = new $RefKeyDictionaryHierarchical();
            $host.setRenderSearchResult(renderSearchResult);
        }
        lookup.set(type, [this, render]);
    };

})();

