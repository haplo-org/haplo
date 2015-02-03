# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# Implement loading of standard JavaScript templates for the Java Runtime.
# Called only once when initialising the runtime environment.

module JsTemplateLoader
  STANDARD_TEMPLATE_DIR = "#{KFRAMEWORK_ROOT}/app/js_template/"
  def self.standardTemplateJSON()
    templates = []
    Dir.glob("#{STANDARD_TEMPLATE_DIR}**/*.*") do |filename|
      if filename[STANDARD_TEMPLATE_DIR.length,filename.length] =~ /\A(.+?)\.([a-z0-9A-Z]+)\z/
        kind = $2
        name = "std:#{$1.gsub('___',':')}"
        File.open(filename) do |f|
          templates << {:name => name, :template => f.read.strip, :kind => kind}
        end
      end
    end
    templates.to_json
  end
end

Java::ComOneisJavascript::Runtime.setStandardTemplateLoader(JsTemplateLoader)