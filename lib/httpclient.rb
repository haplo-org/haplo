# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

KNotificationCentre.when(:server, :starting) do
  KeychainCredential::MODELS.push({
    :kind => 'HTTP',
    :instance_kind => "Basic",
    :account => {"Username" => ""},
    :secret => {"Password" => ""}
  })
end
