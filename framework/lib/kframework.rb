# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class KFramework
  include Java::OrgHaploFramework::Framework

  def initialize
  end

  def load_application
    # Load the templates, using the pre-compiled version if they're available
    compiled_templates_dir = "#{KFRAMEWORK_ROOT}/app/compiled_templates"
    if File.directory?(compiled_templates_dir)
      puts "Templates have been pre-compiled."
      Dir.glob("#{compiled_templates_dir}/*.rb").sort.each { |f| require f }
    end
    require "#{KFRAMEWORK_ROOT}/config/template_sets.rb"
    # Find all the ruby files within the app folder, in the right order for inclusion
    files = Array.new
    ['models','policy','helpers','base','hooks','controllers','auditing','plugins'].each do |dirname|
      path = "app/#{dirname}"
      files << Dir.glob("#{path}/**/*.rb").sort
    end
    @application_source = files.flatten
    do_require_application
  end

  def get_current_application_id
    KApp.current_application
  end

  STATIC_MIME_TYPES = {
    'html' => 'text/html; charset=utf-8',
    'txt' => 'text/plain; charset=utf-8',
    'js' => 'text/javascript; charset=utf-8',
    'json' => 'application/json; charset=utf-8',
    'css' => 'text/css; charset=utf-8',
    'gif' => 'image/gif',
    'jpeg' => 'image/jpeg', 'jpg' => 'image/jpeg',
    'png' => 'image/png',
    'ico' => 'image/vnd.microsoft.icon',
    # Web fonts:
    'eot' => 'application/vnd.ms-fontobject',
    'woff' => 'application/x-font-woff',
    'ttf' => 'application/x-font-ttf',
    'svg' => 'image/svg+xml'
    # TODO: Update web font mime types when things have settled down.
    # application/x-font-woff has been replaced by application/font-woff, but browsers don't like it yet. Also check TTF fonts.
    # Remember to update mime.types too.
  }
  # woff files are already compressed, so shouldn't be compressed again
  ALREADY_COMPRESSED_WEB_FONT_MIME_TYPE = STATIC_MIME_TYPES['woff']
  # but svg files really need compressing, as they're a all text
  SHOULD_BE_COMPRESSED_WEB_FONT_MIME_TYPE = STATIC_MIME_TYPES['svg']

  def set_static_files
    jfrm = Java::OrgHaploAppserver::GlobalStaticFiles
    # In dev mode, we'll want to check the files and reload them!
    @_devmode_static_files = Array.new if KFRAMEWORK_ENV == 'development'
    # Read the names of all static files
    [
      ['static', false],
      ['static/images', true],
      ['static/javascripts', false]
    ].each do |basic_path, recursive|
      path = "#{KFRAMEWORK_ROOT}/#{basic_path}/"
      sp_start = path.length
      pattern = path + (recursive ? '**/*' : '*')
      Dir.glob(pattern).each do |file_pathname|
        next if File.directory? file_pathname
        server_pathname = file_pathname[sp_start, file_pathname.length]
        raise "No extension" unless file_pathname =~ /\.(\w+)\z/
        mime_type = STATIC_MIME_TYPES[$1]
        allow_compression = mime_type !~ /\Aimage/ && mime_type != ALREADY_COMPRESSED_WEB_FONT_MIME_TYPE
        allow_compression = true if mime_type == SHOULD_BE_COMPRESSED_WEB_FONT_MIME_TYPE
        # Tell the java framework, and set the headers accordingly
        static_file = jfrm.addStaticFile(server_pathname, file_pathname, mime_type, allow_compression)
        static_file.addHeader('Expires', 'Sat, 01 Jan 2050 00:00:01 GMT')
        static_file.addHeader('Cache-Control', 'public, max-age=252288000')
        # In development mode, record the details
        if @_devmode_static_files != nil
          @_devmode_static_files << [File.mtime(file_pathname), [server_pathname, file_pathname, mime_type, allow_compression]]
        end
      end
    end
    # The 404app file needs special headers, so it's not cached by the browser to make retries later work properly
    app_file = jfrm.addStaticFile('404app.html', "#{KFRAMEWORK_ROOT}/static/special/404app.html", STATIC_MIME_TYPES['html'], true)
    app_file.addHeader('Cache-Control', 'private, no-cache')
    # The OPTIONS file needs to have no special headers but a 405 resposne code
    options_file = jfrm.addStaticFile('OPTIONS.html', "#{KFRAMEWORK_ROOT}/static/special/OPTIONS.html", STATIC_MIME_TYPES['html'], true)
    options_file.setResponseCode(405)
  end

  def load_namespace
    namespace = File.open("#{KFRAMEWORK_ROOT}/config/namespace.rb") { |f| eval(f.read) }
    raise "Bad config/namespace.rb, should return object responding to resolve()" unless namespace.respond_to?(:resolve)
    @namespace = namespace
  end

  # Called by the java code to do the final starting tasks which need to be left until an old app server has shut down properly
  def start_application
    @start_time = Time.now
    KApp.logger_open
    ActiveRecord::Base.logger = KApp.logger
    KNotificationCentre.notify(:server, :starting)
    scheduled_tasks_start
    KApp.logger.flush_buffered
  end

  # Called by the installer after it's upgraded the application
  def perform_post_upgrade_tasks
    KNotificationCentre.notify(:server, :post_upgrade)
  end

  # Dynamic file factory handling for the app server.
  def get_dynamic_file_factory
    @@dynamic_file_factory
  end
  def self.register_dynamic_file_factory(factory)
    @@dynamic_file_factory = factory
  end

  # Called by the java code on JVM shutdown
  def stop_application
    KNotificationCentre.notify(:server, :stopping)
    stop_background_tasks
    KApp.logger.flush_buffered
  end

  # Get the time when this object was created
  def get_start_time
    @start_time
  end

  def devmode_setup
    # Empty for production mode (overridden in kframework_devmode)
  end
  def devmode_check_reload
    false
  end
  def devmode_do_reload
  end

private
  def do_require_application
    @application_source.each { |r| require r }
  end

end
