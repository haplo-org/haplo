# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# Provide utility functions to various JavaScript objects

module JSObjRefSupport

  def self.constructObjRef(objID)
    KObjRef.new(objID)
  end

end

Java::ComOneisJsinterface::KObjRef.setRubyInterface(JSObjRefSupport)

