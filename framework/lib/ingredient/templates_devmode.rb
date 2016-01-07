# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# Additional behaviours for the templates modules in development mode
if KFRAMEWORK_ENV == 'development'

  $_frm__templates = Array.new

  module Ingredient
    module Templates

      def self.devmode_post_load(path, args, method_name, templates_module, template_filenames)
        files = template_filenames.map do |filename|
          [filename, File.mtime("#{path}/#{filename}").to_i]
        end
        info = [path, args, method_name, templates_module, files]
        $_frm__templates << info
      end

      def self.devmode_reload_info
        info = Array.new
        $_frm__templates.each do |path, args, method_name, templates_module, files|
          files.each do |e|
            et = File.mtime("#{path}/#{e.first}").to_i
            if e.last != et
              info << [path, args, method_name, e.first, templates_module, e, et]
            end
          end
        end
        info
      end

      def self.devmode_do_reload(reload_info)
        reload_info.each do |path, args, method_name, template_pathname, templates_module, e, et|
          puts "Reloading #{method_name} template #{template_pathname}..."
          load_template(path, args, method_name, template_pathname, templates_module, nil, nil)
          e[1] = et
        end
      end

    end
  end
end
