# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# Java exceptions don't inherit from Exception, so turn off that check

module Test::Unit::Assertions
  def _check_exception_class(args)
    args.partition do |klass|
      next if klass.instance_of?(Module)
      # assert(Exception >= klass, "Should expect a class of exception, #{klass}")
      true
    end
  end
end
