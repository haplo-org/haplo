/*global KApp,KFileUpload */

/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


(function($) {

    KApp.j__onPageLoad(function() {

        if(!KFileUpload.p__haveBrowserSupport) { return; }

        var formEnabled = false;

        // Don't allow early form submission
        $('#z__file_upload_form form').on('submit', function(evt) {
            if(!formEnabled) {
                evt.preventDefault();
            }
        });

        // When changing the filename, select it
        $('input[name=basename]').on('keyup', function(evt) {
            $('input[name=rename]').val(['1']);
        });

        var splitFilename = function(filename) {
            var m = filename.match(/^(.+)\.([^\.]+?)$/);
            if(!m) { return {f:filename,e:''}; }
            return {f:m[1], e:m[2]};
        };

        // File upload logic
        var delegate = {
            p__targetTitle: "to upload a new version",
            p__singleFileOnly: true,
            j__onStart: function(id, file, icon) {
                $('.z__file_target').hide();
                $('#z__file_upload_form').show();
                $('#z__file_upload_form .z__focus_candidate').focus();
                $('#z__upload_files').empty().append("<div>"+icon+" "+_.escape(file.name)+"</div>");
                var fileNameParts = splitFilename(file.name);
                $('input[name=basename]').val(fileNameParts.f);
                $('input[name=version]').val(KFileUpload.j__nextVersionNumber($('.z__file_version_info span').first().text()));
                $('.file_extension').text(fileNameParts.e);
            },
            j__onFinish: function(id, file, json) {
                $('#z__file_upload_form input[type=submit]').prop('disabled', false).val("Create new version");
                $('#z__file_upload_form input[name=file]').val(json);
                formEnabled = true;
            },
            j__onUploadFailed: function(id, file, error, userData) {
                $('.z__file_target').show();
                $('#z__file_upload_form').hide();
                target.j__resetFileTarget();
            }
        };
        var target = KFileUpload.j__newTarget(delegate);
        $('#z__upload_target').html(target.j__generateHTML());

    });

})(jQuery);
