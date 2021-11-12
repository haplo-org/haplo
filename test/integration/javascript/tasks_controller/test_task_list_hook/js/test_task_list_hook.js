/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * (c) Avalara, Inc 2021
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */
P.hook('hTaskList', function(response) {
    response.redirectPath = '/test'
});
