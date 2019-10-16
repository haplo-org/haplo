# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# Additional behaviours for the framework object in development mode
if KFRAMEWORK_ENV == 'development'

  class KFramework

    # --------------------------------------------------------------------------------------------
    # Reloading of source files

    def devmode_setup
      @dev_mode_files = @application_source.map do |filename|
        [filename, File.mtime(filename).to_i]
      end
      @dev_mode_js_plugin_files = Dir.glob("app/plugins/**/*.{json,js,html}").map do |filename|
        [filename, File.mtime(filename).to_i]
      end
      @dev_mode_locale_files = Dir.glob("app/locale/**/*.strings").map do |filename|
        [filename, File.mtime(filename).to_i]
      end
    end

    def devmode_check_reload
      # Application code
      @_devmode_to_reload = @dev_mode_files.select do |filename,time|
        time != File.mtime(filename).to_i
      end
      # Static files
      @_devmode_static_files_to_reload = @_devmode_static_files.select do |e|
        mtime,details = e
        mtime != File.mtime(e.last[1])
      end
      # Locale files
      @_devmode_reload_locale = false
      @dev_mode_locale_files.each do |e|
        t = File.mtime(e.first)
        if t != e.last
          @_devmode_reload_locale = true
          e[1] = t
        end
      end
      # JS plugin files
      @_devmode_invalidate_js_runtimes = nil
      @dev_mode_js_plugin_files.each do |e|
        mtime = File.mtime(e.first).to_i
        if mtime != e.last
          e[1] = mtime
          @_devmode_invalidate_js_runtimes = true
        end
      end
      # Templates
      @_devmode_templates_to_reload = Ingredient::Templates.devmode_reload_info
      # Dynamic files
      @_devmode_dynamic_files_to_reload = KDynamicFiles.devmode_check
      # Got anything?
      (! @_devmode_to_reload.empty?) || (! @_devmode_templates_to_reload.empty?) || (! @_devmode_static_files_to_reload.empty?) || @_devmode_dynamic_files_to_reload || @_devmode_reload_locale || @_devmode_invalidate_js_runtimes
    end

    def devmode_do_reload
      begin
        # Set notification centre for reloading
        KNotificationCentre.begin_reload
        # Application code
        @_devmode_to_reload.each do |e|
          puts "Reloading #{e[0]}..."
          load e[0]
          e[1] = File.mtime(e[0]).to_i
        end
        # Static files
        @_devmode_static_files_to_reload.each do |e|
          puts "Reloading static file #{e.last[1]}"
          # NOTE: This isn't actually thread safe as the underlying Java Map isn't protected. But should be OK for dev mode.
          Java::OrgHaploAppserver::GlobalStaticFiles.__send__(:addStaticFile, *e.last)
          e[0] = File.mtime(e.last[1])
        end
        # Locales
        if @_devmode_reload_locale
          puts "Reloading locale strings..."
          load "app/locale/locales.rb"
          @_devmode_reload_locale = nil
        end
        # Templates
        Ingredient::Templates.devmode_do_reload(@_devmode_templates_to_reload)
        @_devmode_to_reload = nil
        @_devmode_templates_to_reload = nil
        # Dynamic files
        if @_devmode_dynamic_files_to_reload
          KDynamicFiles.devmode_reload
          @_devmode_dynamic_files_to_reload = nil
        end
      rescue Exception => e
        puts "================================================================================="
        puts "                               ERROR RELOADING"
        puts "================================================================================="
        puts
        puts e.message
        puts
        puts e.backtrace.join("\n")
        puts "================================================================================="
        raise
      ensure
        # Make sure the notification centre is ready for normal use
        KNotificationCentre.end_reload
      end
      # Invalidate JS plugin files? (must be done after the notification centre has been reloaded because notifications are sent)
      if @_devmode_invalidate_js_runtimes
        @_devmode_invalidate_js_runtimes = nil
        KApp.in_every_application { KApp.cache_invalidate(KJSPluginRuntime::RUNTIME_CACHE) }
      end
      nil
    end

    # --------------------------------------------------------------------------------------------
    # Reporting errors

    def make_error_response(exception, exchange)
      # Dump useful info into the browser
      message = <<__HTML
        <html>
          <head>
            <title>ERR: #{ exchange.request.path } / #{ exception.class.name }</title>
          </head>
          <body>
            <h1>Error: #{ exception.class.name }</h1>
            <p><b>#{ exchange.request.path }</b></p>
            <p>#{ ERB::Util.h(exception.message) }</p>
            <h2>Params</h2>
            <pre>#{ ERB::Util.h(YAML::dump(exchange.params)).gsub(' ','&nbsp;') }</pre>
            <h2>Backtrace</h2>
            <pre>#{ exception.backtrace.join("\n") }</pre>
          </body>
        </html>
__HTML
      KFramework::DataResponse.new(message, 'text/html; charset=utf-8', 500)
    end

  end

end

