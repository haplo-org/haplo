# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module KApp

  # ----------------------------------------------------------------------------------------------------

  class ThreadContext
    attr_accessor :current_application_id, :current_app_info
    attr_accessor :pg_database, :jdbc_database
    attr_accessor :cache_checkouts, :app_globals
    def initialize
    end
  end

  # Return the current thread context, or create a new one
  def self._thread_context(reset = false)
    if reset
      Thread.current[:_frm_thread_context] = nil
    end
    Thread.current[:_frm_thread_context] ||= ThreadContext.new
  end

  # ----------------------------------------------------------------------------------------------------

  # Which application (customer) is currently selected
  # Will return nil if nothing selected.
  def self.current_application
    self._thread_context.current_application_id
  end

  # Perform an operation with an application selected.
  def self.in_application(app_id)
    begin
      switch_by_id(app_id)
      yield
    rescue => e
      # Abort any database transaction in progress, to avoid making the next use of this connection problematic
      conn = ActiveRecord::Base.connection_pool.current_connection
      if conn != nil
        KApp.logger.warn("Exception during in KApp.in_application(), performing database ROLLBACK")
        self.get_pg_database.perform("ROLLBACK")
      end
      # Propagate the exception
      raise
    ensure
      clear_app
    end
  end

  # Perform an operation in every application.
  def self.in_every_application
    in_application(:no_app) do
      # Get all the app IDs
      r = get_pg_database.exec("SELECT application_id FROM applications GROUP BY application_id ORDER BY application_id")
      apps = r.result.map { |a| a.first.to_i }
      r.clear
      # Stop being in an application
      clear_app(:do_not_check_in_database)
      # Setup for each application, using a single database connection for efficiency.
      # There's quite a cost to setting up a database connection, so don't use them unnecessarily.
      # Given the typical use of in_every_application, this should not be a problem regarding
      # the resources used in the database server process.
      begin
        # Set database for each
        apps.each do |app_id|
          begin
            # Set up the database connection for this app
            set_database_connection_for_app(ActiveRecord::Base.connection_pool().current_connection.raw_connection.connection, app_id)
            # Switch to this application
            switch_by_id(app_id)
            # Yield to the caller
            yield app_id
          ensure
            # Make sure the app is cleared, but don't return the database connection so it's reused
            clear_app(:do_not_check_in_database)
          end
        end
      ensure
        # Make sure the database connection is reset
        set_database_connection_for_app(ActiveRecord::Base.connection_pool().current_connection.raw_connection.connection, :no_app)
        switch_by_id(:no_app)
      end
    end
  end

  # Get an app_id given a hostname. Will exception if the hostname isn't known.
  def self.hostname_to_app_id(hostname)
    application = Java::ComOneisFramework::Application.fromHostname(hostname.downcase)
    raise "No application for hostname #{hostname}" if application == nil
    application.getApplicationID()
  end

  def self.all_hostnames
    hostnames = nil
    in_application(:no_app) do
      r = get_pg_database.exec("SELECT application_id,hostname FROM applications ORDER BY hostname")
      hostnames = r.result.map { |a| [a.first.to_i,a.last] }
      r.clear
    end
    hostnames
  end

  # ----------------------------------------------------------------------------------------------------
  # App globals

  def self.global(sym)
    ag = get_app_globals
    ag[sym]
  end

  def self.global_bool(sym)
    global(sym) == 1
  end

  def self.set_global(sym, value)
    ag = get_app_globals
    # New value is required to be a string or an integer
    value = value.to_i if value.class != String
    return nil if value == self.global(sym)
    # Duplicate the value, just in case, then freeze it
    value = value.dup.freeze if value.class == String
    # Update app_globals table
    pg = get_pg_database
    tbl = "a#{KApp.current_application}.app_globals"
    key = sym.to_s
    if value.class == String
      pg.update("BEGIN; DELETE FROM #{tbl} WHERE key=$1; INSERT INTO #{tbl}(key,value_string,value_int) VALUES($2,$3,NULL); COMMIT", key, key, value)
    else
      pg.update("BEGIN; DELETE FROM #{tbl} WHERE key=$1; INSERT INTO #{tbl}(key,value_string,value_int) VALUES($2,NULL,#{value}); COMMIT", key, key)
    end
    # Update the local copy of the global
    ag[sym] = value
    # Update the global app_globals
    app_info = self._thread_context.current_app_info
    app_info.lock.synchronize do
      app_info.globals[sym] = value
    end
    KNotificationCentre.notify(:app_global_change, sym, value)
  end

  # Boolean version of set global
  def self.set_global_bool(sym, value)
    set_global(sym, value ? 1 : 0)
  end

  # ----------------------------------------------------------------------------------------------------
  # Framework integration

  # Inform the Java framework which applications are defined in the database.
  def self.update_app_server_mappings
    # Read the application mapping from the database, and tell the com.oneis.framework.Application class about it.
    in_application(:no_app) do
      pg = get_pg_database
      results = pg.exec('SELECT hostname,application_id FROM applications')
      map = Java::ComOneisFramework::Application.createEmptyHostnameMapping()
      results.each do |hostname, app_id|
        map.setMapping(hostname, app_id.to_i)
      end
      results.clear
      Java::ComOneisFramework::Application.setHostnameMapping(map)
    end
  end

  # Get the current app info object
  def self.current_app_info
    self._thread_context.current_app_info
  end

  # Get the current java app info object
  def self.current_java_app_info
    thread_context = self._thread_context
    raise "No valid app set" unless thread_context.current_application_id.kind_of?(Integer)
    Java::ComOneisFramework::Application.fromApplicationID(thread_context.current_application_id)
  end

  # ----------------------------------------------------------------------------------------------------
  # Databases

  def self.set_database_connection_for_app(jdbc_connection, app_id)
    search_path = ((app_id == :no_app) ? 'public' : "a#{app_id.to_i},public")
    jdbc_connection.createStatement().executeUpdate("SET search_path TO #{search_path}")
  end

  def self.get_jdbc_database
    thread_context = self._thread_context
    # Check there's an application selected already
    raise "KApp: No application selected" if thread_context.current_application_id == nil
    # Get the database - the app aware connection pool will take care of setting everything
    thread_context.jdbc_database ||= ActiveRecord::Base.connection().raw_connection.connection
  end

  def self.get_pg_database
    # Wraps the jdbc database to provide an old-style PG interface
    self._thread_context.pg_database ||= begin
      PostgresConnWrapper.new(get_jdbc_database)
    end
  end

  # Methods to give more control over database connections when required

  def self.make_unassigned_jdbc_database
    ActiveRecord::Base.connection_pool().create_new_unassigned_connection.raw_connection.connection
  end

  def self.make_unassigned_pg_database
    PostgresConnWrapper.new(make_unassigned_jdbc_database)
  end

  # ----------------------------------------------------------------------------------------------------
  # Logging

  def self.logger
    $_kapp_logger
  end

  def self.logger_configure(*args)
    $_kapp_logger_config = args
  end

  def self.logger_open
    $_kapp_logger = BufferingLogger.__send__(:new, *$_kapp_logger_config)
    # Redirect STDOUT to the logger
    $stdout = StdoutRedirector.new($stdout)
    $stdout.write_proc = proc do |data|
      $_kapp_logger.info(data)
    end
  end

  class BufferingLogger < Logger
    # Slightly hacked version of the add() function
    def add(severity, message = nil, progname = nil)
      severity ||= UNKNOWN
      if @logdev.nil? or severity < @level
        return true
      end
      progname ||= @progname
      if message.nil?
        if block_given?
          message = yield
        else
          message = progname
          progname = @progname
        end
      end
      m = format_message(format_severity(severity), Time.now, progname, message)
      buffer = Thread.current[:_frm_logger_buffer]
      if buffer == nil
        buffer = ''
        Thread.current[:_frm_logger_buffer] = buffer
      end
      buffer << m
      true
    end
    alias :log :add
    # Call to flush the buffered output
    def flush_buffered
      buffer = Thread.current[:_frm_logger_buffer]
      if buffer != nil
        @logdev.write(buffer)
        Thread.current[:_frm_logger_buffer] = nil
      end
    end
    # Additional functionality
    def log_exception(e)
      error("EXCEPTION #{e.inspect}\n  #{e.backtrace.join("\n  ")}")
    end
  end

  # ----------------------------------------------------------------------------------------------------
  # PRIVATE app switching

private
  CREATE_APP_INFO_MUTEX = Mutex.new

  # Info about the current application
  class AppInfo
    attr_reader :app_id
    attr_reader :lock
    attr_reader :caches
    attr_accessor :globals  # lazily loaded
    def initialize(app_id)
      @lock = Mutex.new
      @app_id = app_id
      # Set up list of caches
      @caches = Array.new
      KApp::CACHE_INFO.length.times { @caches << CacheList.new(Array.new, 0) }
      # Counters (for KAccounting)
      @counters_lock = Mutex.new
      @counters = Array.new
    end
    # Access counters, via a lock
    def using_counters
      @counters_lock.synchronize do
        yield @counters
      end
    end
  end

  # Set thread globals for an application
  def self.switch_by_id(app_id)
    # NOTE: Postgres search_path is set by the app aware ConnectionPool object.
    raise "Already in app" unless KApp.current_application == nil
    raise "Bad app_id" unless (app_id == :no_app) || (app_id.kind_of? Integer)
    # Store ID in thread local storage
    thread_context = self._thread_context(true)
    thread_context.current_application_id = app_id
    # Start the notification centre
    KNotificationCentre.start_on_thread
    # Retrieve the application info object
    begin
      if app_id != :no_app
        app_info = get_app_info_for(app_id)
        raise "No app info object" unless app_info != nil
        thread_context.current_app_info = app_info
        # Select the application in the object store
        # The notification centre is not used for selecting the store, because the store needs to be
        # cleared *after* any buffered notifications have been sent.
        KObjectStore.select_store(app_id)
        # Set default user
        AuthContext.set_as_system
      end
    rescue => e
      # If there are any errors setting up the database, then make sure the globals aren't set wrongly
      clear_app
      raise
    end
  end

  def self.get_app_info_for(app_id)
    # Get the AppInfo object, or create a new one if it doesn't exist
    japp = Java::ComOneisFramework::Application.fromApplicationID(app_id)
    app_info = japp.getRubyObject()
    if app_info == nil
      # Not defined, create one
      CREATE_APP_INFO_MUTEX.synchronize do
        # Check again inside the mutex (avoid race conditions)
        app_info = japp.getRubyObject()
        if app_info == nil
          app_info = AppInfo.new(app_id)
          app_info = japp.setRubyObject(app_info)
        end
      end
    end
    app_info
  end

  def self.clear_app(db_action = :check_in_database)
    # NOTE: Be very careful about modifying, order is important, thread locals must be cleaned up, and everything must happen
    # Finish with the notification centre
    KNotificationCentre.send_buffered_then_end_on_thread
  ensure
    begin
      if KApp.current_application != :no_app
        AuthContext.clear_state
      else
        raise "AuthContext state set for :no_app when clearing app" if AuthContext.has_state?
      end
    ensure
      begin
        KObjectStore.select_store(nil)
      ensure
        begin
          # Clear the request handling context BEFORE the caches are checked in, making sure
          # that the lifetimes of requests vs caches are correct.
          KFramework.clear_request_context # won't exception
          KApp.cache_checkin_all_caches
        ensure
          Thread.current[:_frm_thread_context] = nil
          # Must be after clearing thread context so an exception won't prevent it from being cleared
          ActiveRecord::Base.clear_active_connections! unless db_action == :do_not_check_in_database
        end
      end
    end
  end

  # ----------------------------------------------------------------------------------------------------
  # PRIVATE app_global management

  def self.get_app_globals
    self._thread_context.app_globals ||= begin
      # Try and make a copy of the global app_globals from the AppInfo object
      global_ag_copy = nil
      app_info = current_app_info
      app_info.lock.synchronize do
        if app_info.globals != nil
          global_ag_copy = app_info.globals.dup # shallow copy, deliberately
        end
      end
      # Was a copy obtained?
      if global_ag_copy == nil
        # No - load from database outside the lock (might race with another thread, but that's OK)
        globals = Hash.new
        pg = get_pg_database
        r = pg.exec("SELECT key,value_int,value_string FROM a#{KApp.current_application}.app_globals")
        r.each do |row|
          k = row[0].to_sym
          i = row[1]
          if i != nil
            globals[k] = i.to_i
          else
            s = row[2]
            raise "Bad global defn, no int and no string" if s == nil
            globals[k] = s
          end
        end
        r.clear
        # Loaded, now apply to app globals if another thread didn't beat us to it
        app_info.lock.synchronize do
          app_info.globals = globals if app_info.globals == nil
          # Prefer to use the older version, as it might have had updates applied to it
          global_ag_copy = app_info.globals.dup # shallow copy
        end
      end
      # Use the copy of the global app_globals
      global_ag_copy
    end
  end
end
