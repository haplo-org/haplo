# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module KInstallProperties

  @@properties = {}

  def self.load_from(properties_dir, overrides = {})
    props = {}
    Dir.open(properties_dir).entries.each do |name|
      if name !~ /\A\./
        props[name.to_sym] = File.open("#{properties_dir}/#{name}") { |f| f.read } .strip
      end
    end
    @@properties = props.merge(overrides)
  end

  def self.get(name, default_value = nil)
    value = @@properties[name] || default_value
    raise "Installation property #{name} not set" unless value
    value
  end

end
