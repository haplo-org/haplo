# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# TODO: Turn the dynamic CSS files into a methods which can be executed without the use of lots of evals

module KDynamicFiles
  include Java::OrgHaploFramework::Application::DynamicFileFactory

  extend KPlugin::HookSite

  CSS_SOURCE_DIR = "#{KFRAMEWORK_ROOT}/static/stylesheets"
  IMAGES_SOURCE_DIR = "#{KFRAMEWORK_ROOT}/static/images_r"

  # REMOVE_ON_PROCESS_BEGIN
  CSS_PREPROCESS_RUBY = "#{CSS_SOURCE_DIR}/stylesheet_preprocess.rb"
  require CSS_PREPROCESS_RUBY
  # REMOVE_ON_PROCESS_END

  APPLICATION_MAIN_CSS_FILES = ['a.css', 'app.css']

  CSS_MIME_TYPE = 'text/css; charset=utf-8'

  # Called by the Java app server
  def self.generate(app_id, filename)
    response = nil

    KApp.in_application(app_id) do
      evaluator = KApplicationColours.make_colour_evaluator

      if filename =~ /\A(\d+)\z/
        # App static file, stored in database
        file = AppStaticFile.find_by_id($1)
        if file != nil
          mime_type = file.mime_type
          # allow compression if the file isn't an image
          response = Java::OrgHaploAppserver::StaticFileResponse.new(file.data.to_java_bytes, mime_type, mime_type !~ /\Aimage/i)
        else
          # Return a placeholder otherwise
          response = Java::OrgHaploAppserver::StaticFileResponse.new("(not found)".to_java_bytes, 'text/plain', false)
        end

      elsif filename =~ /\A([a-z]+)\/(.+)\z/
        # File from a plugin
        response = KPlugin.generate_plugin_static_file_response(filename)

      elsif filename =~ /\.css\z/
        css = nil
        css_method = STYLESHEET_FILENAME_TO_METHOD[filename]
        css = evaluator.send(css_method) if css_method != nil

        # If it's the main application CSS file, then it might need some extra CSS appended.
        if APPLICATION_MAIN_CSS_FILES.include?(filename)
          begin
            call_hook(:hMainApplicationCSS) do |hooks|
              r = hooks.run()
              css << r.css
            end
          rescue => e
            KApp.logger.error("While calling hook hMainApplicationCSS for app_id #{app_id}, got exception #{e}")
            KApp.logger.flush_buffered
            # Add some text to the CSS file so if a developer looks there, they'll get a hit about what they did wrong.
            css << "\n\n\n/* Error calling hMainApplicationCSS hook */\n\n\n"
          end
          # Add in the user's CSS
          css << KApp.global(:appearance_css)
        end

        response = Java::OrgHaploAppserver::StaticFileResponse.new(css.to_java_bytes, CSS_MIME_TYPE, true) # allow compression
      else
        # Re-colour an image
        virtual_file_method = VIRTUAL_IMAGE_FILENAME_TO_METHOD[filename]
        if virtual_file_method != nil
          real_filename, jpeg_quality, colouring_method, colours = evaluator.send(virtual_file_method)

          imagedata = String.from_java_bytes(COLOURING.colourImage(
            "#{IMAGES_SOURCE_DIR}/#{real_filename}",      # Input filename
            colouring_method,                           # What colouring method to use
            colours.to_java(:int),                            # Colours for recolouring
            jpeg_quality                                      # Quality of output
          ))

          filename =~ /\.(\w+)\z/
          kind = $1
          kind = 'jpeg' if kind == 'jpg'
          response = Java::OrgHaploAppserver::StaticFileResponse.new(imagedata.to_java_bytes, "image/#{kind}", false) # no compression

        end

      end
    end

    raise "Couldn't generate dynamic file response" if response == nil

    # Set headers so it doesn't expire
    # NOTE: same headers as set in kframework.rb for non-dynamic static files
    response.addHeader('Expires', 'Sat, 01 Jan 2050 00:00:01 GMT')
    response.addHeader('Cache-Control', 'public, max-age=252288000')

    response
  end

  def self.number_of_app_static_files_for(app_id)
    # Actually returns the highest ID + 1
    num = 0
    KApp.in_application(:no_app) do
      db = KApp.get_pg_database
      r = db.exec("SELECT MAX(id) FROM a#{app_id.to_i}.app_static_files")
      if r.length > 0
        num = (r.first.first.to_i + 1)
      end
      r.clear
    end
    num
  end

  def self.get_plugin_pathnames(app_id)
    pathnames = nil
    KApp.in_application(app_id) do
      pathnames = KPlugin.get_all_plugin_static_file_pathnames
    end
    pathnames
  end

  # Called to set up dynamic files
  def self.setup
    dyn = Java::OrgHaploFramework::Application
    # Load and transform stylesheets, and tell the framework which filenames are allowed
    Dir.new(CSS_SOURCE_DIR).each do |filename|
      next unless filename =~ /\A[^\.].*?\.css\z/ # make sure files beginning with a dot are ignored so ._ files created in development don't cause problems
      load_stylesheet_source(filename)
      dyn.addAllowedFilename(filename)
    end
    # Parse the virtual.txt file and mark the files as allowed
    load_virtual_image_specifications
    VIRTUAL_IMAGE_FILENAME_TO_METHOD.each_key { |filename| dyn.addAllowedFilename(filename) }
  end

  # -------------------------------------------------------------------------------------------------------

  STYLESHEET_FILENAME_TO_METHOD = Hash.new

  def self.load_stylesheet_source(filename)
    css = File.open("#{CSS_SOURCE_DIR}/#{filename}") { |f| f.read }
    # REMOVE_ON_PROCESS_BEGIN
    css = StylesheetPreprocess.process(css)
    # REMOVE_ON_PROCESS_END
    css.gsub!(/COLOUR\[(.+?)\]/) do |m|
      %Q!<%= colour_hex(#{KColourEvaluator.expression_to_ruby($1)}) %>!
    end
    css.gsub!(/DYNAMIC_IMAGE\[(.+?)\]/) do |m|
      "/~<%= dynamic_image_serial %>/#{$1}"
    end
    # Choose which web font to use
    has_webfonts = false
    css.gsub!(/WEBFONT\[(\d+)\,(.+?)\]/) do
      n = $1
      name = $2
      has_webfonts = true
      %Q!<%= webfont_size == #{n} ? "#{name}" : '' %>!
    end
    # Define method for this CSS file
    css_method = "__kdynamicfiles_css_#{filename.gsub(/[^a-z0-9]/,'_')}".to_sym
    source = "def #{css_method}\n"
    if has_webfonts
      source << "webfont_size = (KApp.global(:appearance_webfont_size) || 0)\n"
    end
    source << "#{ERB.new(css).src}\n"
    if has_webfonts
      # Remove font face declaration altogether if web fonts aren't set
      # This doesn't remove any declaractions if the font name begins with 'ONEIS', so the special fonts are always included.
      source << "_erbout.gsub!(/@font-face[^\}]+?font-family:\s*'(?!ONEIS)[^\}]*?\}\s*/m,'') if webfont_size == 0\n"
    end
    source << "_erbout\nend"
    KColourEvaluator.module_eval(source, filename, -1)
    STYLESHEET_FILENAME_TO_METHOD[filename] = css_method
  end

  # -------------------------------------------------------------------------------------------------------

  # Cache management

  def self.invalidate_all_cached_files_in_current_app
    japp = KApp.current_java_app_info
    japp.invalidateAllDynamicFiles()
    # Update the appearance serial number *after* invalidating the cache to force updates in clients
    KApp.set_global(:appearance_update_serial, KApp.global(:appearance_update_serial) + 1)
  end

  # When the application is upgraded, increment all the version numbers to invalidate any files
  # cached on the clients.
  KNotificationCentre.when(:server, :post_upgrade) do
    KApp.in_every_application do
      KApp.set_global(:appearance_update_serial, KApp.global(:appearance_update_serial) + 1)
    end
  end

  # Invalidate plugin files -- fairly expensive, so shouldn't happen in the normal course of operation
  KNotificationCentre.when_each([
    [:plugin, :install],
    [:plugin, :uninstall]
  ]) do
    # Removes all the allowed plugin file paths, so they're recalculated
    KApp.current_java_app_info.resetAllowedPluginFilePaths()
    # Then invalidate all the other info and bump the serial number, so browsers reload everything
    invalidate_all_cached_files_in_current_app
  end

  def self.invalidate_app_static_count
    japp = KApp.current_java_app_info
    japp.resetNumAppSpecificStaticFiles()
  end

  # -------------------------------------------------------------------------------------------------------

  COLOURING = Java::OrgHaploUtils::ImageColouring
  METHOD_LOOKUP = {
    'blend' => COLOURING::METHOD_BLEND,
    'avg' => COLOURING::METHOD_AVG,
    'max' => COLOURING::METHOD_MAX
  }
  DEFAULT_JPEG_QUALITY = 60

  VIRTUAL_IMAGE_FILENAME_TO_METHOD = Hash.new
  def self.load_virtual_image_specifications
    VIRTUAL_IMAGE_FILENAME_TO_METHOD.clear
    File.open("#{IMAGES_SOURCE_DIR}/virtual.txt") do |virtual|
      virtual.each do |line|
        next if line =~ /\A\s*\#/ || line !~ /\S/
        fileinfo = line.chomp.split(/\s*\|\s*/)

        jpeg_quality = DEFAULT_JPEG_QUALITY

        colour_exprs = Array.new
        3.upto(fileinfo.length - 1) do |i|
          x = fileinfo[i]
          if x =~ /\A-/    # options begin with a -
            if x =~ /\A-q(\d+)\z/
              jpeg_quality = $1.to_i
            else
              raise "Bad option #{x} in virtual.txt"
            end
          else
            colour_exprs << KColourEvaluator.expression_to_ruby(x)
          end
        end
        # Got a sensible number of colours?
        if colour_exprs.length < 1 || colour_exprs.length > 3
          raise "Wrong number of colours specified for #{fileinfo[0]} in virtual.txt"
        end
        # Make a method.
        virtual_file_method = "__kdynamicfiles_css_#{fileinfo[0].gsub(/[^a-z0-9]/,'_')}".to_sym
        KColourEvaluator.module_eval(<<__E, fileinfo[0], -1)
          def #{virtual_file_method}
            ['#{fileinfo[1]}', #{jpeg_quality}, #{METHOD_LOOKUP[fileinfo[2]]}, [#{colour_exprs.join(', ')}]]
          end
__E
        VIRTUAL_IMAGE_FILENAME_TO_METHOD[fileinfo[0]] = virtual_file_method
      end
    end
  end

end

# Register so the app server can use this module to generate files
KFramework.register_dynamic_file_factory(KDynamicFiles)

