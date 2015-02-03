/*global confirm,KApp */

/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


/*CONST*/ KCLEDIT_OBJ_REF = 0;
/*CONST*/ KCLEDIT_TITLES  = 1;

(function($) {

    var p__objects = 0;
    var p__inflightAdds = 0;
    var q__csrfToken;

    var escapeHTML = function(str) {
        return str.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g, '&quot;');
    };

    var j__objToInnerHtml = function(oinfo) {
        var ref = oinfo[KCLEDIT_OBJ_REF];
        var titles = oinfo[KCLEDIT_TITLES];
        var html = '<a href="#" class="z__classification_edit_action" data-ref="'+ref+'" data-act="1">edit</a> <a href="#" class="z__classification_edit_action" data-ref="'+ref+'" data-act="2">del</a> <span>'+escapeHTML(titles[0]);
        if(titles.length > 0) {
            html += '</span><span class="z__mng_classify_alt_titles">';
            for(var n = 1; n < titles.length; n++) {
                html += ', '+escapeHTML(titles[n]);
            }
        }

        return html+'</span>';
    };

    var j__updateCount = function(delta) {
        p__objects += delta;
        $('#z__mng_classify_count').html(''+p__objects);
    };

    var j__formSubmit = function(event) {
        // Don't actually submit the form
        event.preventDefault();

        // Setup
        var title_field = $('#z__mng_classify_title');

        // Get data
        var title = title_field.val();
        if(!title.match(/\S/)) {
            alert("You must enter a title.");
            return;
        }

        // Run query
        $.ajax('/do/setup/classification/quick_add',
            {
                type:'POST',
                dataType:'json',
                data: $('#z__mng_classify_quick_add_form').serialize(),
                success: function(info) {
                    if(info.error) {
                        // Server reports error
                        alert(info.error);
                    } else {
                        // Success
                        var div = document.createElement('div');
                        $('#z__mng_classify_object_container').append(div);
                        div.id = 'obj'+info.obj[KCLEDIT_OBJ_REF];
                        div.innerHTML = j__objToInnerHtml(info.obj);
                        // Count
                        j__updateCount(1);
                    }
                    // Spinner display
                    if((p__inflightAdds--) <= 1) {
                        $('#z__adding_spinner').hide();
                    }
                }
            });

        // Reset fields and focus back
        $('#z__mng_classify_quick_add_form input[type="text"]').val('');
        title_field.focus();

        // Show spinner?
        if((p__inflightAdds++) <= 1) {
            $('#z__adding_spinner').show();
        }
    };

    var j__kcleditHandleLink = function(ref,act) {
        if(act == 2) {
            // Delete
            var div_id = 'obj'+ref;
            // Get title
            var title = $('#'+div_id+' span').first().text();
            if(confirm("Really delete "+title+"?")) {
                // Do AJAX query to server
                $.ajax('/do/setup/classification/delete/'+ref,
                    {
                        type:'POST',
                        data:{__:q__csrfToken},
                        success: function(response) {
                            // On success or failure
                            if(response == 'DELETED') {
                                // Delete node
                                var d = $('#'+div_id).remove();
                                j__updateCount(-1);
                            } else {
                                alert(response);
                            }
                        }
                    });
            }
        } else {
            // Edit
            KApp.j__spawn(function(data_type,ref,titles) { $('#obj'+ref).html(j__objToInnerHtml([ref,titles])); },
                '','o',{p__maxwidth:748, p__url:'/do/edit/'+ref+'?pop=1'});
        }
        return false;
    };

    // Setup and document.write HTML for the type editing
    // Attach everything and setup
    var j__start = function() {
        // Get info from the DOM
        var container = $('#z__mng_classify_object_container');
        var types = $.parseJSON(container[0].getAttribute('data-types'));
        var html = '';
        _.each(types, function(oinfo) { html += '<div id="obj'+oinfo[KCLEDIT_OBJ_REF]+'">'+j__objToInnerHtml(oinfo)+'</div>'; });
        container.html(html);
        p__objects = types.length;
        q__csrfToken = $('input[name="__"]').val();

        // Attach form handler
        $('#z__mng_classify_quick_add_form').submit(j__formSubmit);

        // Setup handlers
        container.on('click', '.z__classification_edit_action', function(evt) {
            evt.preventDefault();
            j__kcleditHandleLink(this.getAttribute('data-ref'), this.getAttribute('data-act') * 1);
        });

        // Focus into the first field
        $('#z__mng_classify_title').focus();
    };

    KApp.j__onPageLoad(j__start);

})(jQuery);

