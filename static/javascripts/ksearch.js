/*global KApp,KTray,KSchema,KEdType,KEditorSchema,KEditor,KCtrlFormAttacher,KTree,KTreeSource,KDLList */

/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


var Ks = (function($) {

    var initialQuery = '',
        searchExplainerDisplayDiv,
        searchExplainerLastQueryExplained = '',
        searchExplainerDelayCounter = 0,
        searchExplainerIsVisible = false,
        searchExplainerAjaxRequest,
        lastDemandLoadingResults,
        pendingDemandLoadSetup,
        selectedSubset,
        subjectTree;

    // ----------------------------------------------------------------------------------------------------
    //             Tray handling
    // ----------------------------------------------------------------------------------------------------

    // If the user is anonymous, ktray.js probably won't be loaded. However, there will be no checkboxes,
    // so the inner loop won't be executed and the handler never called, so it won't matter that
    // KTray isn't defined.

    var setUpTrayCheckboxes = function(container,to_check) {
        // Find all input buttons within the container
        $('input[type="checkbox"]', container).each(function() {
            var c = this;
            if(KTray.j__contains(c.name)) {
                c.checked = true;
                if(to_check) {
                    to_check.push(c);
                }
            }
            $(c).click(function() {
                KTray.j__startChange(this.name, this, !this.checked);  // remove?
            });
        });
    };

    // ----------------------------------------------------------------------------------------------------
    //             Demand loading of results
    // ----------------------------------------------------------------------------------------------------

    var demandLoadCallback = function(i, items) {
        var c = ((/MSIE/.test(navigator.userAgent)) ? [] : null); // array of things to check later?
        setUpTrayCheckboxes(items,c);
        if(c !== null && c.length > 0) {
            // IE has a bug where you can't check an input checkbox until it's in the DOM.
            // So check them later after they're safely in.
            window.setTimeout(function() {
                _.each(c, function(input) { input.checked = true; });
            },10);
        }
        KApp.j__setupForSpawning(items);
    };

    var setUpDemandLoadingOfResults = function(container_element_id, nav_element, number_items, url) {
        if(KApp.p__ajaxSupported) {
            lastDemandLoadingResults = KDLList.j__addList(container_element_id, number_items, url, demandLoadCallback);
            // Remove the navigation
            if(nav_element) {
                $('#'+nav_element).hide();
            }
        } else {
            // Setup for calling later
            if(!pendingDemandLoadSetup) {
                pendingDemandLoadSetup = [];
                KApp.j__callWhenAjaxProved(function() {
                    // Called when KApp has proof ajax works
                    for(var l = 0; l < pendingDemandLoadSetup.length; l++) {
                        setUpDemandLoadingOfResults.apply(this, pendingDemandLoadSetup[l]);
                    }
                    pendingDemandLoadSetup = null;
                });
            }
            // Make a new array, to be paranoid
            var a = [];
            for(var c = 0; c < arguments.length; c++) { a.push(arguments[c]); }
            pendingDemandLoadSetup.push(a);
        }
    };

    // ----------------------------------------------------------------------------------------------------
    //             Search explainer for normal search form
    // ----------------------------------------------------------------------------------------------------

    var updateSearchExplainer = function() {
        // Should the explaination be displayed?
        var should_display = !!(searchExplainerDisplayDiv);  // been displayed already?
        var ct = $('#z__search_query_id').val();
        if(/([\|&:\/\(\)'"\>\*_!]|\bnot\b|\band\b|\bor\b)/i.test(ct)) {
            // Got something boolean about it
            should_display = true;
        }
        if(ct == initialQuery && !searchExplainerDisplayDiv) {
            // Don't display whatever if we haven't displayed it yet and it's not modified
            should_display = false;
        }
        // Display?
        if(should_display) {
            if(!searchExplainerDisplayDiv) {
                // Create the holder div
                var div = document.createElement('div');
                div.className = 'z__search_explanation';
                div.style.display = 'none';
                $('#z__search_form_explaination_holder').append(div);
                searchExplainerDisplayDiv = div;
            }
            // Start a new AJAX query, if one isn't in progress and the text is different this time
            if(!searchExplainerAjaxRequest && searchExplainerLastQueryExplained != ct) {
                if(searchExplainerDelayCounter <= 0) {
                    searchExplainerAjaxRequest = $.ajax('/api/search/explain?q='+encodeURIComponent(ct), {
                        success:function(rtext) {
                            if(searchExplainerAjaxRequest) {
                                // Check query so that on_submit can avoid things being shown later
                                searchExplainerDisplayDiv.innerHTML = rtext;
                            }
                            if(!searchExplainerIsVisible) {
                                $(searchExplainerDisplayDiv).show();
                                searchExplainerIsVisible = true;
                            }
                            searchExplainerAjaxRequest = undefined;
                            searchExplainerDelayCounter = 3;
                        }
                    });
                    searchExplainerLastQueryExplained = ct;
                } else {
                    searchExplainerDelayCounter --;
                }
            }
        }
        // Call again soon!
        window.setTimeout(updateSearchExplainer, 150);
    };

    // ----------------------------------------------------------------------------------------------------
    //             Search by fields
    // ----------------------------------------------------------------------------------------------------

    var loadFieldsSearchStarted, searchByFieldsEditorAttributes;

    // This function doesn't really belong here. When needed elsewhere, move it somewhere more central.
    var demandLoadClientSideResources = function(css, javascript, finished_callback) {
        // Load CSS files - just put them all in, order of loading isn't important
        _.each(css, function(urlpath) {
            var link = document.createElement('link');
            link.rel = 'stylesheet';
            link.type = 'text/css';
            link.href = urlpath;
            document.body.appendChild(link);
        });
        // Javascript files do need to be loaded in order, otherwise they fail because they depend on stuff in other files which isn't loaded yet.
        // Note: Firefox will execute the scripts in DOM order, so it could load them in parallel. However, it's probably not worth
        // the trouble of giving it a special case.
        var next_function = finished_callback;
        // Reverse order so that when functions are executed they come out in the original order.
        _.each(javascript.reverse(), function(urlpath) {
            var this_scripts_callback = next_function;  // make a copy NOW, otherwise the contents of the critical var is changed underneath the code
            next_function = function() {
                // Create a script element with a suitable callback
                var script = document.createElement('script');
                script.src = urlpath;
                if(KApp.p__runningMsie) {
                    // IE doesn't do onload on script elements
                    script.onreadystatechange = function() {
                        if(script.readyState === 'loaded' || script.readyState === 'complete') {
                            this.onreadystatechange = null;
                            this_scripts_callback();
                        }
                    };
                } else {
                    script.onload = this_scripts_callback;
                }
                // Insert the script element into the DOM to start the load
                document.body.appendChild(script);
            };
        });
        // Load the first script
        next_function();
    };

    var postEditorLoadForSearchByFieldsHandler = function() {
        // Setup schema
        // TODO: Make reuse of keditor for search by fields much less ugly
        KSchema.types = [[[],'0-0','0-0',0]];
        KEdType.q__defaultTypeObjref = '0-0';
        KEditorSchema.j__prepare();
        _.each(KEditorSchema.p__allAttrDefns, function(defn) {
            if(defn.p__aliasOf) {
                // Add in names of aliases to attribues, so it's clear all the fields they will search
                var alias_of_defn = KEditorSchema.j__attrDefn(defn.p__aliasOf);
                if(alias_of_defn) {
                    alias_of_defn.p__name = alias_of_defn.p__name + ' / ' + defn.p__name;
                }
            } else {
                // If it's a datetime type, turn it into a normal text field so all the various date search options can be used
                if(defn.p__normalDataType == T_DATETIME) {
                    defn.p__normalDataType = T_TEXT;
                    defn.p__newCreationData = [T_TEXT,''];
                }
            }
        });

        // Display the editor
        var keditor = new KEditor(searchByFieldsEditorAttributes, {q__withPreview:false, q__disableAddUi:true, q__noCreateNewObjects:true});
        $('#z__search_form_advanced_container_fields').html('<div id="z__search_form_advanced_container_fields_form_holder">'+keditor.j__generateHtml()+'</div>');
        keditor.j__attach();
        // Remove the Show examples bit at the bottom
        $('#z__search_form_advanced_container_fields .z__editor_tool_bar').hide();
        // Finish attaching UI
        var a = new KCtrlFormAttacher('z__search_form_id');
        a.j__attach(keditor,'f',$('#z__search_encoded_form_fields_id')[0]);
    };

    var loadSearchByFields = function(encoded_fields_data) {
        // Prevent this from being run twice - can easily happen if the user clicks on the tab again
        if(loadFieldsSearchStarted) { return; }
        loadFieldsSearchStarted = true;

        $('z__search_form_advanced_container_fields').innerHTML = '<div class="z__search_form_fields_text_display_holder">'+KApp.p__spinnerHtml+'</div>';

        var url = '/api/search/fields';
        if(encoded_fields_data) {
            url += '?f='+encodeURIComponent(encoded_fields_data);
        }
        $.ajax(url, {
            dataType: "json",
            success: function(response) {
                // Store attribtues for later
                searchByFieldsEditorAttributes = response.f;
                // Load all the resources then show the editor.
                demandLoadClientSideResources(response.c, response.j, postEditorLoadForSearchByFieldsHandler);
            }
        });
    };

    // ----------------------------------------------------------------------------------------------------
    //             Subject browsing
    // ----------------------------------------------------------------------------------------------------

    var historyReplaceStateSupported;

    var subjectTreeDelegate = {
        j__treeSelectionChange: function(tree, ref, depth) {   // tree delegate function
            if(!ref) {return;}
            if(ref === 'TYPES') {
                // If it's the root of the types, don't display any search
                $('#z__browse_term_search_result_container').html(''); // remove any current search
                return;
            }
            // Begin search
            $('#z__browse_term_search_result_container').html((KApp.p__spinnerHtml)+' Searching...');
            var ss = (selectedSubset) ? 'subset='+selectedSubset+'&': '';
            // Build the query, which depends on whether it's for classification objects or types
            var node_type = tree.j__typeOf(ref);
            var query_encoded = '%23L'+ref+'%23';
            // node_type should never be null, but it could be if one of the Types is the initial selection
            // in a Browse. In this case, it has to be demand loaded, and when we call j__typeOf() it can't
            // return anything because it doesn't know anything yet. This would be a problem for anything other
            // than browsing the Types.
            if(node_type && (node_type !== 'TYPES')) { query_encoded += '%20not%20%23L'+(node_type)+'%23'; }
            // Request new search results
            $.ajax('/api/search/insertable?'+ss+'q='+query_encoded, {success:function(rtext, textStatus, jqXHR) {
                // Stop the previous list from running otherwise any queries in progress will mess up the display
                // There will only be one for subject browsing, so it's safe to use the last one added.
                if(lastDemandLoadingResults !== undefined) {
                    KDLList.j__removeList(lastDemandLoadingResults);
                    lastDemandLoadingResults = undefined;
                }
                // Replace the search results
                var c = $('#z__browse_term_search_result_container');
                c.html(rtext);
                // Setup demand loading?
                var hdr = jqXHR.getResponseHeader("X-Haplo-SDL");
                if(hdr !== undefined && hdr !== null) {
                    setUpDemandLoadingOfResults.apply(this, $.parseJSON(hdr));
                }
                setUpTrayCheckboxes(c[0]);
                KApp.j__setupForSpawning(c[0]);
            }});
            // Adjust browser's URL so back & forward buttons retain the place, if supported by the browser
            if(historyReplaceStateSupported) {
                window.history.replaceState({ref:ref}, document.title, '/search/browse/'+ref);
            }
        },
        j__treeMakeFakeNodeHref: function(tree, ref, depth) {
            // Although it's never clicked, use the path of the browse page in the tree node so it looks nice
            return '/search/browse' + ((ref === 'TYPES') ? '' : '/'+ref);
        }
    };

    // ----------------------------------------------------------------------------------------------------
    //             Search specification
    // ----------------------------------------------------------------------------------------------------

    // TODO: Be able to generate search specifications for embedded when fields have been used

    // Used by KApp when inserting text from spawned sub-tasks
    var getSearchSpecification = function() {
        // Get query string and title
        var spec = {};
        if(subjectTree) {
            // Browse by subject
            var ref = subjectTree.p__currentSelection;
            if(!ref) {
                alert("Please select a subject to perform a search.");
                return null;
            }
            spec.q = '#L'+ref+'# not #L'+(subjectTree.j__typeOf(ref))+'#';
            spec.title = 'Subject: '+subjectTree.j__displayNameOf(ref);
        } else {
            // Normal search
            spec.q = $('#z__search_query_id').val();
            if(!spec.q || spec.q === '') {
                alert("Please enter a search query.");
                $('z__search_query_id').focus();
                return null;
            }
        }
        // Make up title?
        if(!spec.title) { spec.title = 'Search: ' + spec.q; }

        // Sort order?
        var sm = /[\?\&]sort=([^\&]+)(\&|$)/.exec(window.location);
        if(sm) {spec.sort = sm[1];}

        // Subset
        if(selectedSubset) {
            spec.subset = selectedSubset;
        }

        // Return spec
        return spec;
    };

    // ----------------------------------------------------------------------------------------------------
    //             Subset change handler
    // ----------------------------------------------------------------------------------------------------

    var subsetChangeHandler = function() {
        var s = $('#z__search_subset_selection').val();
        if(s != selectedSubset) {
            selectedSubset = s;
            if(subjectTree) {
                subjectTreeDelegate.j__treeSelectionChange(subjectTree, subjectTree.p__currentSelection, null);
            }
        }
    };

    // ----------------------------------------------------------------------------------------------------
    //             On-load handler
    // ----------------------------------------------------------------------------------------------------

    KApp.j__onPageLoad(function() {
        // Work out which form we're on
        var searchQueryInput = $('#z__search_query_id');
        if(searchQueryInput.length !== 0) {
            // Normal search form
            // Record the query's initial value
            initialQuery = searchQueryInput.val();

            // Hide search explainations when form submitted
            $('#z__search_form_id').submit(function() {
                searchExplainerAjaxRequest = undefined;    // stop requests being shown
                if(searchExplainerIsVisible) {
                    $(searchExplainerDisplayDiv).hide();
                    searchExplainerIsVisible = false;
                }
            });

            // Start listening for changes in search query
            updateSearchExplainer();
        }

        // Search by subjects needs to listen for subset changes
        var subset = $('#z__search_subset_selection');
        if(subset.length !== 0) {
            selectedSubset = subset.val();
            subset.change(subsetChangeHandler);
        }
        // NOTE: If there aren't any subsets, then selectedSubset can be null on pages where they might be expected.

        // Add in tray buttons to search results
        if(KApp.p__ajaxSupported) {
            $('.z__search_results_container').each(function() {
                setUpTrayCheckboxes(this);
            });
        }

        // Advanced button?
        var advanced = $('#z__search_form_advanced_toggle');
        var advancedContainerHidden = true;
        var ensureAdvancedContainerOpen = function() {
            if(advancedContainerHidden) {
                $('#z__search_form_advanced_container').show();
                advancedContainerHidden = false;
                // Stop the hover effect on the 'tab' button
                advanced.addClass('z__search_form_advanced_toggle_disabled');
                loadSearchByFields();
            }
        };
        if(advanced.length !== 0) {
            advanced.click(function(event) {
                event.preventDefault();
                ensureAdvancedContainerOpen();
            });
            // TODO: More elegant and non-temporary way of showing search by fields by default
            if(advanced[0].getAttribute("data-show-fields") === "1") {
                ensureAdvancedContainerOpen();
            }
        }
        // Fields display?
        var fields_text_display = $('#z__search_form_fields_text_display');
        if(fields_text_display.length !== 0) {
            var show_form_handler = function(event) {
                event.preventDefault();
                var field_hidden_input = $('#z__search_encoded_form_fields_id');
                loadSearchByFields((field_hidden_input.length !== 0) ? field_hidden_input.val() : null);  // hidden form field
            };
            fields_text_display.click(show_form_handler);
            // Also allow a click on the toggle button to show the form
            $('#z__search_form_advanced_toggle').click(show_form_handler);
        }

        // Search tips?
        $('#z__search_tips_button').click(function(event) {
            event.preventDefault();
            var w = window.open('/search/tips', 'haplo_search_tips',
                'scrollbars=1,toolbar=0,status=0,location=0,menubar=0,scrollbars=0,resizable=1,left=120000,top=120000,width=560,height=360');
            w.focus();  /* bring to top if it's already open and covered */
        });

        // Browse?
        var browseInfo = $('#z__browse_info');
        if(browseInfo.length > 0) {
            // Get initial selection info
            var initial_selection = browseInfo[0].getAttribute('data-sel');
            // Check replaceState support
            historyReplaceStateSupported = !!(window.history && window.history.replaceState);
            // Display tree and initial selection
            subjectTree = new KTree(KTreeSource.j__fromDOM(), subjectTreeDelegate);
            subjectTree.j__attach('z__search_by_subjects_browser');
            if(initial_selection) {
                subjectTree.j__setSelection(initial_selection);
                subjectTreeDelegate.j__treeSelectionChange(subjectTree, initial_selection, null);   // initial display
            }
            // Create some blank space at the bottom of the page, so that clicks on the taxonomy don't
            // tend to change the scroll position.
            $('#z__browse_term_enough_space_to_keep_scroll_position').css('height', ((($(window).height())*2)/3)+'px');
        }

        // Set up demand loading?
        $('.z__search_demand_load_params').each(function() {
            setUpDemandLoadingOfResults.apply(Ks, $.parseJSON(this.getAttribute('data-sdl')));
        });
    });

    // ----------------------------------------------------------------------------------------------------
    //             API for other scripts
    // ----------------------------------------------------------------------------------------------------

    return {
        j__getSearchSpecification: getSearchSpecification
    };

})(jQuery);
