/* Haplo Platform                                     http://haplo.org
 * (c) Avalara, Inc 2021
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */
P.hook('hHelpPage', function(response) {
    response.redirectPath = '/help-test'
});