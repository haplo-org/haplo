/*global KApp */

/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


// This code is written in a way which can be used with a plugin which just includes jQuery.
// The fallback code uses the KApp object to provide the iframe container for the fallback upload UI.

var KFileUpload = (function($) {

    var TEXT_UPGRADE_MESSAGE = 'Your browser is too old to support to support all features. Please upgrade.';

    // Requires: File and JSON objects, and drag and drop events.
    var browserSupportsFileUpload = (function() {
        if(!window.File || !window.JSON) { return false; }
        var div = document.createElement('div');
        return ('draggable' in div) || ('ondragstart' in div && 'ondrop' in div);
    })();

    var targets = [];
    var nextUploadId = 0;
    var uploads = [];
    var uploadsTotalSize = 0;
    var uploadsCompleteSize = 0;
    var isUploading = false;
    var lastProgressStartTime;      // time in ms when showProgress last started a new progress display
    var progressBarElement;

    // ------------------------------------------------------------------------------------------------------------------------

    var bytesText = function(numberOfBytes) {
        return (numberOfBytes / 1048576).toFixed(2)+' MB';
    };

    var showProgress = function(bytesInCurrent) {
        if(!progressBarElement) {
            progressBarElement = $('<div id="z__file_target_process" style="display:none"><div class="z__file_target_process_bar"><div class="z__file_target_process_bar_progress"></div></div><div class="z__file_target_process_text"></div></div>');
            $(document.body).append(progressBarElement);
        }
        if(bytesInCurrent !== undefined) {
            var timeNow = (new Date()).getTime();
            // Don't show progress for first second (including animation time)
            var shouldShow = false;
            if(lastProgressStartTime) {
                if((timeNow - lastProgressStartTime) > 500) { shouldShow = true; }
            } else {
                lastProgressStartTime = timeNow;
            }
            if(shouldShow) {
                // Animate on screen (start this first for width:0 setting)
                if(!progressBarElement.is(':visible')) {
                    $('.z__file_target_process_bar_progress',progressBarElement).css({width:"0"});
                    progressBarElement.animate({bottom:"+=36"}, 500);
                    progressBarElement.show();
                }
                // Update progress display
                var completeBytes = uploadsCompleteSize + bytesInCurrent;
                var width = Math.round(progressBarElement[0].offsetWidth * (completeBytes / (uploadsTotalSize ? uploadsTotalSize : 1)));
                // Duration of 250 seems to work nicely with typical update frequency, stop() before to avoid them all queuing up if rapid updates
                $('.z__file_target_process_bar_progress',progressBarElement).stop(true,true).animate({width:width}, 250, "linear");
                // ... and as text...
                var display = "Uploading: "+bytesText(completeBytes)+' of '+bytesText(uploadsTotalSize);
                $('.z__file_target_process_text',progressBarElement).text(display);
            }
        } else {
            // Animate off screen
            $('.z__file_target_process_bar_progress',progressBarElement).stop(true).css({width:'100%'});  // show full upload during transition out
            if(progressBarElement.is(':visible')) {
                progressBarElement.animate({bottom:"-=36"}, 500, function() {
                    progressBarElement.hide();
                });
            }
            lastProgressStartTime = undefined;
        }
    };

    var uploadNext = function() {
        if(uploads.length === 0) {
            showProgress();
            isUploading = false;
            uploadsTotalSize = 0;
            uploadsCompleteSize = 0;
            return;
        }
        var uploadInfo = uploads.shift();
        var formData = new FormData();
        formData.append('__', $('input[name=__]').val());
        formData.append('file', uploadInfo.p__file);
        var xhr = new XMLHttpRequest();
        xhr.open('POST', '/api/edit/upload-file/'+uploadInfo.p__serverToken);
        var onError = xhr.onerror = function(e) {
            // Ask user if they'd like to retry it?
            if(window.confirm("An error occurred when uploading\n\n    "+uploadInfo.p__file.name+"\n\nWould you like to try uploading it again?")) {
                uploads.unshift(uploadInfo);
            } else {
                // User gave up, tell delegate
                uploadInfo.p__target.q__delegate.j__onUploadFailed(uploadInfo.p__id, uploadInfo.p__file, e, uploadInfo.p__userData);
            }
            uploadNext();
        };
        xhr.onload = function(e) {
            uploadsCompleteSize += uploadInfo.p__file.size;
            showProgress(0);    // done!
            if(xhr.status === 200) {
                // Tell target delegate it's uploaded, passing the JSON encoded response (don't decode it)
                uploadInfo.p__target.q__delegate.j__onFinish(uploadInfo.p__id, uploadInfo.p__file, xhr.responseText, uploadInfo.p__userData);
                uploadNext();
            } else {
                onError(e);
            }
        };
        if(xhr.upload) {
            xhr.upload.onprogress = function(progressEvent) {
                if(progressEvent.lengthComputable) {
                    showProgress(progressEvent.position || progressEvent.loaded);   // different browsers use different properties
                }
            };
        }
        xhr.send(formData);
        isUploading = true;
    };

    var queueUpload = function(uploadInfo) {
        uploadInfo.p__target.q__uploadCount++;
        // Tell the delegate
        uploadInfo.p__target.q__delegate.j__onStart(uploadInfo.p__id, uploadInfo.p__file, uploadInfo.p__icon, uploadInfo.p__userData);
        // Queue and possibly start the upload
        uploads.push(uploadInfo);
        uploadsTotalSize += uploadInfo.p__file.size;
        if(!isUploading) {
            showProgress(0);
            uploadNext();
        }
    };

    var userHasSelectedFilesForUpload = function(targetIndex, files, userData) {
        // Check upload allowed
        var target = targets[targetIndex];
        if(target.q__delegate.p__singleFileOnly) {
            if(target.q__uploadCount > 0) {
                return; // ignore future files
            }
            files = [files[0]]; // use first one only
        }
        var infos = [];
        for(var f = 0; f < files.length; ++f) {
            infos.push({
                p__id: nextUploadId++,
                p__target: target,
                p__userData: userData,
                p__file: files[f]
            });
        }
        var checkUpload = function() {
            var uploadInfo = infos.shift();
            $.post("/api/edit/upload-check", {
                __: $('input[name=__]').val(),
                name: uploadInfo.p__file.name,
                type: uploadInfo.p__file.type,
                size: uploadInfo.p__file.size
            }, function(json) {
                if(json.ok) {
                    // Update info from server
                    uploadInfo.p__icon = json.icon;
                    uploadInfo.p__serverToken = json.token;
                    // Queue the upload
                    queueUpload(uploadInfo);
                }
                // Check next file
                if(infos.length > 0) {
                    checkUpload();
                }
            });
        };
        checkUpload();
    };

    var getTargetIndex = function(fileTarget) {
        var targetIndex;
        if(fileTarget && fileTarget.getAttribute) {
            var attr = fileTarget.getAttribute('data-target');
            if(attr) { targetIndex = parseInt(attr,10); }
        }
        return targetIndex;
    };

    // ------------------------------------------------------------------------------------------------------------------------

    // Given any element in the document, return the relevant file target
    var targetForElement = function(element) {
        if(element === targetForElementLastTestedElement) {
            return targetForElementLastResult;
        }
        var target, scan = element;
        while(scan) {
            if(scan.className && (-1 !== _.indexOf(scan.className.split(/\s+/g), 'z__file_target'))) {
                target = scan;
                break;
            }
            scan = scan.parentNode;
        }
        // If no specific target, and only one on the page, use that one
        if(!target) {
            var allVisibleTargets = $('.z__file_target:visible');
            if(allVisibleTargets.length === 1) {
                target = allVisibleTargets[0];
            }
        }
        // Internet Explorer is typically bonkers, and may return the parent div of the file target, not the file target.
        // So if there's an immediate child node which is a file target, accept that.
        if(!target) {
            var children = element.childNodes;
            for(var i = 0; i < children.length; ++i) {
                var n = children[i];
                if(n.className && (-1 !== n.className.split(/\s+/g).indexOf('z__file_target'))) {
                    target = n;
                    break;
                }
            }
        }
        // Cache result and return
        targetForElementLastTestedElement = element;
        targetForElementLastResult = target;
        return target;
    };
    var targetForElementLastTestedElement, targetForElementLastResult;

    // ------------------------------------------------------------------------------------------------------------------------

    // Update hover effects for file targets
    var updateFileTargetHover = function(target, isHovering) {
        var fileTarget = target ? targetForElement(target) : undefined;
        if(fileTarget !== lastHoveredFileTarget) {
            removeHoverEffect();
            if(isHovering && fileTarget) {
                $(fileTarget).addClass('z__file_target_will_drop_here');
            }
            lastHoveredFileTarget = fileTarget;
        }
    };
    var removeHoverEffect = function() {
        if(lastHoveredFileTarget) {
            $('.z__file_target_will_drop_here').removeClass('z__file_target_will_drop_here');
            lastHoveredFileTarget = undefined;
        }
    };
    var lastHoveredFileTarget;

    // ------------------------------------------------------------------------------------------------------------------------

    // Event handlers
    // This is a little bit fragile because browsers are a bit touchy about this stuff.
    // If you change things, make sure it still works in all the browsers.
    if(browserSupportsFileUpload) {
        $(document).on('change', '.z__file_target input[type=file]', function() {
            var targetIndex = getTargetIndex(targetForElement(this));
            userHasSelectedFilesForUpload(targetIndex, this.files);
            this.value = '';
            if(targets[targetIndex].q__delegate.p__singleFileOnly) {
                this.disabled = true;
            }
        }).on('dragenter', function(evt) {
            // Highlight the file target
            updateFileTargetHover(evt.target, true);
        }).on('dragover', function(evt) {
            if(evt.originalEvent.dataTransfer) { evt.originalEvent.dataTransfer.dropEffect = 'copy'; }
            // Stop Firefox navigating to the file
            evt.stopPropagation();
            evt.preventDefault();
        }).on('drop', function(evt) {
            removeHoverEffect();
            evt.preventDefault();

            var fileTarget = targetForElement(evt.target);
            if(!fileTarget) {
                // Multiple visible targets on the page, so ignore any drops on the page
                window.alert("To upload, drop the file onto one of the boxes marked 'Drag files here'.");
                return;
            }
            // If we're going to handle this, stop anything else handling it -- don't want multiple uploads of the same thing.
            evt.stopImmediatePropagation();
            // Go!
            userHasSelectedFilesForUpload(getTargetIndex(fileTarget), evt.originalEvent.dataTransfer.files);
        }).on('dragend', function(evt) {
            // Unhighlight any file target
            updateFileTargetHover(undefined, false);
        });
    } else {
        // Fallback implementation
        $(document).on('click', '.z__file_target a', function(evt) {
            evt.preventDefault();
            var target = targets[getTargetIndex(targetForElement(this))];
            window.k__fileUploadFallbackFile = function(json, icon) {
                var uploadId = nextUploadId++;
                KApp.j__closeCovering();
                var infoParsed = $.parseJSON(json); // may not have JSON interface on legacy browsers
                var fakeFile = {name:infoParsed.filename};
                target.q__delegate.j__onStart(uploadId, fakeFile, icon, undefined);
                target.q__delegate.j__onFinish(uploadId, fakeFile, json, undefined);
            };
            KApp.j__openCovering('/do/edit/fallback_file_upload', 'Cancel', 400, 700);
        });
    }

    // ------------------------------------------------------------------------------------------------------------------------

    // Main API object
    var FileUploadAPI = {
        p__haveFullBrowserSupport: browserSupportsFileUpload,
        j__browserFullSupportCheckWithAlert: function() {
            if(!browserSupportsFileUpload) { window.alert(TEXT_UPGRADE_MESSAGE); }
            return browserSupportsFileUpload;
        },
        j__newTarget: function(delegate) {
            var target = {
                q__index: targets.length,
                q__uploadCount: 0,
                q__delegate: delegate,
                j__generateHTML: function() {
                    var html = '<div data-target="'+this.q__index+'" class="z__file_target">';
                    if(!browserSupportsFileUpload) {
                        return html + '<a href="#">Upload file...</a></div>';
                    }
                    html += this.q__delegate.p__singleFileOnly ? 'Drag a file here ' : 'Drag files here ';
                    if(delegate.p__targetTitle) {
                        html += _.escape(delegate.p__targetTitle)+' ';
                    }
                    html += 'or <a href="#"><input type="file"';
                    if(!this.q__delegate.p__singleFileOnly) { html += ' multiple="multiple"'; }
                    html += '>choose file...</a></div>';
                    return html;
                },
                j__uploadFiles: function(files, userData) {
                    userHasSelectedFilesForUpload(this.q__index, files, userData);
                },
                j__resetFileTarget: function() {
                    this.q__uploadCount = 0;
                    $('.z__file_target[data-target='+target.q__index+'] input[type=file]').each(function() {
                        this.disabled = false;
                    });
                }
            };
            targets.push(target);
            return target;
        },
        j__nextVersionNumber: function(versionNumber) {
            if(!versionNumber) { return '1'; }
            var match, chars;
            _.each(['0123456789', 'abcdefghijklmnopqrstuvwxyz', 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'], function(ch) {
                var m = (new RegExp('^(.*?)(['+ch+']+)$')).exec(versionNumber);
                if(m) {
                    match = m;
                    chars = ch.split('');
                }
            });
            if(!chars) { return versionNumber+'2'; } // reasonable?
            var incs = match[2].split('');
            for(var i = incs.length - 1; i >= 0; --i) {
                var n = _.indexOf(chars, incs[i]);
                if(n === (chars.length - 1)) {
                    // At end of the set of chars, so start at the beginning and let the previous char be incremented too
                    incs[i] = chars[0];
                    // And if it's the first char, need to add an additional digit to the version number.
                    if(i === 0) {
                        incs.unshift((chars[0] === '0') ? chars[1] : chars[0]);
                    }
                } else {
                    incs[i] = chars[n+1];
                    break;
                }
            }
            return match[1]+incs.join('');
        }
    };

/*
        // Version number mini-test suite
        console.log("VERSION NUMBER TESTS");
        var versionNumberTestFail = _.once(function() { window.alert("Next version tests failed"); });
        _.each([
            [undefined, '1'],
            ['', '1'],
            ['1', '2'],
            ['9', '10'],
            ['1.59', '1.60'],
            ['1.99', '1.100'],
            ['4.D', '4.E'],
            ['9.AZ', '9.BA'],
            ['9.aZ', '9.aAA'],
            ['9.aZZ', '9.aAAA'],
            ['10.zzz', '10.aaaa'],
            ['A#38', 'A#39'],
            ['A.', 'A.2'],
            ['.', '.2'],
        ], function(t) {
            var next = FileUploadAPI.j__nextVersionNumber(t[0]);
            console.log("TEST:", t[0], "->", next, "expected", t[1], next === t[1] ? 'PASS' : 'FAIL');
            if(next !== t[1]) { versionNumberTestFail(); }
        });
*/

    // ------------------------------------------------------------------------------------------------------------------------

    // oForms support
    var oFormsRenderFile = function(icon, file) {
        // NOTE: Rendering of file should match that in js_file_support.rb
        return icon+' '+_.escape(file.name);
    };
    var oFormsRenderInProgress = function(html) {
        return '<span class="z__oforms_file_uploading">'+html+'</span>';
    };
    var oFormsTarget;
    window.oFormsFileDelegate = {

        fileRepeatingSectionInitTarget: function(element, addRowWithUpload) {
            var uploads = {};
            var sectionTarget = FileUploadAPI.j__newTarget({
                j__onStart: function(id, file, icon, userData) {
                    var info = uploads[id] = {
                        q__fileHTML: oFormsRenderFile(icon, file),
                        q__callbacks: addRowWithUpload(file)
                    };
                    info.q__callbacks.updateDisplay(oFormsRenderInProgress(info.q__fileHTML));
                },
                j__onFinish: function(id, file, json, userData) {
                    var info = uploads[id];
                    if(info) {
                        var f = $.parseJSON(json);
                        info.q__callbacks.onFinish(JSON.stringify({d:f.digest, s:f.fileSize, x:f.secret}), info.q__fileHTML);
                        delete uploads[id];
                    }
                },
                j__onUploadFailed: function(id, file, error, userData) {
                    var info = uploads[id];
                    if(info) {
                        info.q__callbacks.onError();
                        delete uploads[id];
                    }
                }
            });
            $(element).html(sectionTarget.j__generateHTML());
        },

        uploadFile: function(file, callbacks) {
            // Hidden target for uploading oForms files
            var fileHTML = '';
            if(!oFormsTarget) { oFormsTarget = FileUploadAPI.j__newTarget({
                    j__onStart: function(id, file, icon, userData) {
                        fileHTML = oFormsRenderFile(icon, file);
                        userData.updateDisplay(oFormsRenderInProgress(fileHTML));
                    },
                    j__onFinish: function(id, file, json, userData) {
                        var f = $.parseJSON(json);
                        userData.onFinish(JSON.stringify({d:f.digest, s:f.fileSize, x:f.secret}), fileHTML);
                    },
                    j__onUploadFailed: function(id, file, error, userData) {
                        userData.onError();
                    }
                });
            }
            // Start the upload
            oFormsTarget.j__uploadFiles([file], callbacks);
        }
    };

    // Disable the oForms UI for uploading individual files:
    //  * show an error when the user clicks the 'Upload file...' link.
    //  * remove the remove file X so that the user can't delete files and then get a non-functional upload link.
    // File targets for file repeating sections work.
    if(!browserSupportsFileUpload) {
        $('<style type="text/css">.oforms-file-prompt input, .oforms-file-remove { display:none !important } </style>').appendTo('head');
        $(document).ready(function() {
            $('.oform').on('click', '.oforms-file-prompt a', function(evt) {
                evt.preventDefault();
                FileUploadAPI.j__browserFullSupportCheckWithAlert();
            });
        });
    }

    // ------------------------------------------------------------------------------------------------------------------------

    return FileUploadAPI;

})(jQuery);

