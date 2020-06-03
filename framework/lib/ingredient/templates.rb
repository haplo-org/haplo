# frozen_string_literal: true

# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

module Ingredient
  module Templates

    def self.load(templates_module, path, args, method_name)
      # If the templates have been pre-compiled, this is a no-op
      return templates_module if templates_module.const_defined?("FRM_#{method_name.to_s.upcase}_IS_PRECOMPILED")

      compiled_code = nil
      if @@_compilation_mode
        @@_compiled_modules << templates_module
        @@_template_root_paths << path
        compiled_code = ["FRM_#{method_name.to_s.upcase}_IS_PRECOMPILED = true"]
      end

      # Create constants in the module
      templates_module.const_set(:KINDS, Hash.new)

      # Find all templates
      template_filenames = Dir.glob("#{path}/**/*.erb").map { |n| n.slice(path.length + 1, n.length) } .sort

      # Acceptable method names and mapping names
      acceptable_template_methods = Hash.new
      name_to_method = Hash.new

      # Load them into the module
      template_filenames.each do |template_pathname|
        Templates.load_template(path, args, method_name, template_pathname, templates_module, acceptable_template_methods, name_to_method, compiled_code)
      end

      # Make the acceptable methods and mapping available to the module
      templates_module.const_set("FRM__#{method_name.to_s.upcase}_METHODS".to_sym, acceptable_template_methods)
      templates_module.const_set("FRM__#{method_name.to_s.upcase}_MAP".to_sym, name_to_method)

      # Define the basic method plus a kind accessor
      comma_args = "#{args.empty? ? '' : ', '}#{args}"
      render_code = <<-__E
        def #{method_name}(template_name#{comma_args})
          template_method = "_#{method_name}_\#{template_name.gsub(/\\.[^\\.]+\\z/,'').gsub(/\\//,'_')}"
          m = FRM__#{method_name.to_s.upcase}_METHODS[template_method]
          raise "Bad template method \#{template_method}" unless m != nil
          self.send(m#{comma_args})
        end
        def #{method_name}_kind(template_name)
          KINDS[template_name.gsub(/\\.[^\\.]+\\z/,'').gsub(/[\\/-]/,'_')]
        end
        def self.map_of_name_to_method
          FRM__#{method_name.to_s.upcase}_MAP
        end
      __E
      templates_module.module_eval(render_code)

      # In development mode, store the info for later reloads
      Templates.devmode_post_load(path, args, method_name, templates_module, template_filenames)

      # Store compiled code, if in compilation mode
      if compiled_code != nil
        [
          ["FRM__#{method_name.to_s.upcase}_METHODS", acceptable_template_methods],
          ["FRM__#{method_name.to_s.upcase}_MAP", name_to_method],
          ["KINDS", templates_module.const_get(:KINDS)]
        ].each do |name,value|
          compiled_code << name + " = {\n" + (value.map { |k,v| "  #{k.inspect} => #{v.inspect}"} .join(",\n")) + "\n}"
        end
        compiled_code << render_code
        templates_module.const_set(:FRM_COMPILED_CODE, compiled_code)
      end

      templates_module
    end

    def self.devmode_post_load(*args)
      # Do nothing
    end

    # In a separate function so it can be called again by the development mode reloader
    def self.load_template(path, args, method_name, template_pathname, templates_module, acceptable_template_methods, name_to_method, compiled_code = nil)
      # Get the info from the template pathname
      raise "Bad template filename #{template_pathname}" unless template_pathname =~ /\A(.+?)\.([^\.]+)\.erb\z/
      template_pathname_without_ext = $1
      template_content_kind = $2
      # Make a method name for the template
      template_name = template_pathname_without_ext.gsub(/\//,'_')
      template_method = "_#{method_name}_#{template_name}"
      # Collect together a hash of string -> symbol for checking that templates existing before calling them
      if acceptable_template_methods != nil
        acceptable_template_methods[template_method] = template_method.to_sym
        if template_pathname_without_ext =~ /_/
          # Add alternative with - mapped to _ in last element
          raise "bad name" unless template_pathname_without_ext =~ /\A(.+)\/([^\/]+)/
          dirname = $1
          filename = $2
          acceptable_template_methods["_#{method_name}_#{dirname.gsub(/\//,'_')}_#{filename.gsub('_','-')}"] = template_method.to_sym
        end
      end
      # Collect together a map of name to method name
      if name_to_method
        name_to_method[template_pathname_without_ext] = template_method.to_sym
      end
      # Compile the template and create the method
      # '-' option is for newline omission after -%>
      template_src = File.open("#{path}/#{template_pathname}") { |file| ERB.new(file.read, nil, '-') } .src
      method_def = "def #{template_method}(#{args})\n#{template_src}\nend"
      templates_module.module_eval(method_def, template_pathname, -1)
      compiled_code << method_def if compiled_code != nil
      # Store the kind of template in the const
      templates_module.const_get(:KINDS)[template_name] = template_content_kind.to_sym
    end

    # -------------------------------------------------------------------------------------------------------
    # Precompilation of templates

    MAX_FILE_SIZE = (1024*64)

    @@_compilation_mode = false
    def self.enable_compilation_mode
      @@_compilation_mode = true
      @@_compiled_modules = []
      @@_template_root_paths = []
    end

    def self.get_template_root_paths
      @@_template_root_paths
    end

    def self.write_compiled_templates(path)
      @@_compiled_modules.each do |template_module|
        base_filename = "#{path}/#{template_module.name.downcase.gsub(/[^a-z]+/,'_')}"
        name_elements = template_module.name.split('::')
        file_preamble = name_elements.map { |n| "module #{n}\n" } .join
        file_postamble = "end\n" * name_elements.length
        file_count = 0
        output_file = nil
        template_module.const_get(:FRM_COMPILED_CODE).each do |chunk|
          if output_file == nil
            output_file = File.open("#{base_filename}#{file_count += 1}.rb", 'w')
            output_file.write "# coding: utf-8\n\n"
            output_file.write file_preamble
          end
          output_file.write chunk
          output_file.write "\n\n"
          if output_file.pos > MAX_FILE_SIZE
            output_file.write file_postamble
            output_file.close
            output_file = nil
          end
        end
        if output_file != nil
          output_file.write file_postamble
          output_file.close
        end
      end
    end

  end
end
