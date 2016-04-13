# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# Simple session support; stores sessions in memory in the AppInfo object, so will be lost on restart.

# Controller support
#   session_create - create a new session (everything stored  ignored before this is called)
#   session - returns a Hash for the session data
#   session_commit - call at the end of a successful request to commit the changes in session


# Add support to the AppInfo object
module KApp
  class AppInfo
    attr_accessor :sessions_last_expire_time
    def all_sessions
      @_all_sessions ||= Hash.new
    end
  end
end

module Ingredient
  module Sessions
    SESSION_COOKIE_NAME = 's'
    MAX_AGE             = 21600   # A session gets deleted 6 hours after it was last used
    EXPIRE_EVERY        = 600     # Expire sessions every 10 minutes
    MAX_SESSIONS        = 10000   # If there's more than this number of sessions for an app, dump them all to avoid attackers using lots of memory.

    # Class to manage the contents of the session
    # Will be created even is a session is not set
    class Session < Hash
      attr_reader :session_key
      # Make a copy of the source data and record the session key
      def initialize(source, session_key = nil)
        x = super(nil)
        @session_key = session_key
        @dirty = false
        # Merge the session data in to get a proper copy
        self.merge!(source) if source != nil
        x
      end
      # Set a key, marking it as dirty
      def []=(key,value)
        @dirty = true
        super
      end
      def delete(key)
        @dirty = true
        super
      end
      # Should the session object be written back?
      def write_required?
        @session_key != nil && @dirty
      end
      # Is this a session which was just created to avoid errors?
      def discarded_after_request?
        @session_key == nil
      end
      # Get a Hash containing the keys for storage
      def for_storage
        h = Hash.new
        h.merge!(self)
        h
      end
      # Should it be deleted?
      def should_delete?
        empty? || has_key?(:RESET)
      end
    end

    # -------------------------------------------------------------------------------------------------------------------------

    # Starts a new session. Only dummy sessions will be available until it exists
    def session_create
      session_key = nil
      app_info = KApp.current_app_info
      app_info.lock.synchronize do
        retries = 16
        while true
          retries -= 1
          raise "Couldn't find a new session key" if retries <= 0
          # Get a random key
          session_key = [File.read('/dev/urandom', 24)].pack('m')
          session_key.gsub!(/[\r\n\s]+/,'')
          session_key.tr!('+/','_-')
          raise "Bad session key generation" unless session_key.length > 24
          break unless app_info.all_sessions.has_key?(session_key)
        end
        # Create a new blank session
        app_info.all_sessions[session_key] = {}
        # Check that there aren't too many sessions created
        if app_info.all_sessions.length > MAX_SESSIONS
          # To avoid having lots and lots of memory used up by malicious session creation by attackers, dump all the sessions
          app_info.all_sessions.clear
          KApp.logger.error("Cleared all sessions for #{app_info.app_id} due to exceeding limit of #{MAX_SESSIONS} sessions")
        end
      end
      @_frm_session = Session.new({:_frm_last_use => Time.now.to_i}, session_key)
      # Set a cookie in the response
      exchange.response.set_cookie({
        'name' => SESSION_COOKIE_NAME,
        'value' => session_key,
        'path' => '/',
        'http_only' => true,
        'secure' => exchange.request.ssl?
      })
      nil
    end

    # -------------------------------------------------------------------------------------------------------------------------

    def session_reset
      # Blank the current session and commit it back to make sure it's caught by requests in the future
      @_frm_session.clear
      @_frm_session[:RESET] = true
      @_frm_session[:_frm_last_use] = 0
      session_commit
    end

    # -------------------------------------------------------------------------------------------------------------------------

    # Return the session object, lazily creating/loading it
    # The session object will have it's last use time updated on the first read in this request, so it's
    # not thrown out because it doesn't appear to have changed during the request.
    def session
      @_frm_session ||= begin
        session_key = exchange.request.cookies[SESSION_COOKIE_NAME]
        if session_key != nil && session_key.length > 24 && session_key =~ /\A[a-zA-Z0-9_-]+\z/
          # Time now for age and expiry
          tnow = Time.now.to_i
          # Got a valid looking session key, now find the session data
          data = nil
          # Get the data from the session store for this application
          app_info = KApp.current_app_info
          app_info.lock.synchronize do
            last_expiry = (app_info.sessions_last_expire_time || 0)
            if last_expiry < (tnow - EXPIRE_EVERY)
              # Delete old sessions
              app_info.all_sessions.delete_if do |k,v|
                last_use = v[:_frm_last_use]
                (last_use == nil) || (last_use < (tnow - MAX_AGE))
              end
              app_info.sessions_last_expire_time = tnow
            end
            data = app_info.all_sessions[session_key]
            # Update the last use time in the session (on read so it doesn't get thrown out accidently)
            data[:_frm_last_use] = tnow if data != nil
          end
          # If there's no data, forget the session key
          session_key = nil if data == nil
          Session.new(data, session_key)
        else
          Session.new(nil, nil)  # no source, no session key
        end
      end
    end

    # -------------------------------------------------------------------------------------------------------------------------

    def session_commit
      if @_frm_session != nil && @_frm_session.write_required?
        app_info = KApp.current_app_info
        app_info.lock.synchronize do
          if @_frm_session.should_delete?
            # Not required any more, delete it
            app_info.all_sessions.delete(@_frm_session.session_key)
          else
            # Copy back into storage
            app_info.all_sessions[@_frm_session.session_key] = @_frm_session.for_storage
          end
        end
      end
    end

    # -------------------------------------------------------------------------------------------------------------------------

    # Session preservation

    def self.load_preserved_sessions
      begin
        sessions_loaded = 0
        if File.exist?(SESSIONS_PRESERVED_DATA)
          File.open(SESSIONS_PRESERVED_DATA,"rb") do |f|
            header = Marshal.load(f)
            if header != [:sessions_v0]
              KApp.logger.errors("Preserved session data had wrong header (change of format?). Not loading session data.")
              return
            end
            while true
              cmd, app_id = Marshal.load(f)
              if cmd == :app && app_id.kind_of?(Integer)
                app_info = KApp.get_app_info_for(app_id)
                while true
                  session_id, session_data = Marshal.load(f)
                  break if session_id == :end_app
                  app_info.lock.synchronize do
                    app_info.all_sessions[session_id] = session_data
                  end
                  sessions_loaded += 1
                end
              else
                # Anything else; stop the loading
                break
              end
            end
          end
        end
        KApp.logger.info("#{sessions_loaded} preserved sessions loaded.")
      rescue => e
        # Log but otherwise ignore errors
        KApp.logger.error("Exception while loading session data: #{e.to_s}")
      end
    end

    def self.save_sessions
      write_pathname = "#{SESSIONS_PRESERVED_DATA}.write"
      written_count = 0
      File.open(write_pathname,"wb") do |f|
        Marshal.dump([:sessions_v0], f)
        KApp.in_every_application do |app_id|
          begin
            app_info = KApp.current_app_info
            # Get a copy of the sessions, with a short lock
            all_sessions = nil
            app_info.lock.synchronize do
              all_sessions = app_info.all_sessions.dup
            end
            # Save them all out
            if all_sessions != nil && all_sessions.length > 0
              Marshal.dump([:app, app_id], f)
              all_sessions.each do |session_id, session_data|
                Marshal.dump([session_id, session_data], f)
              end
              Marshal.dump([:end_app], f)
              written_count += all_sessions.length
            end
          rescue => e
            # Log but otherwise ignore errors
            KApp.logger.error("Exception while saving session data for app #{app_id}: #{e.to_s}")
          end
        end
        Marshal.dump([:end], f)
      end
      File.rename(write_pathname, SESSIONS_PRESERVED_DATA)
      written_count
    end

    class SessionsBackgroundTask < KFramework::BackgroundTask
      def initialize
        @stop_flag = Java::OrgHaploCommonUtils::WaitingFlag.new
        @do_background = true
      end
      def start
        # Make sure all the usage counts are correct on startup
        Sessions.load_preserved_sessions
        KApp.logger.flush_buffered
        # Save the data every 15 minutes, or on shutdown of the application server
        while @do_background
          @stop_flag.waitForFlag(900000)  # 15 mins in ms
          count = Sessions.save_sessions
          KApp.logger.info("Session data saved at #{Time.now.to_iso8601_s} (#{count} sessions)")
          KApp.logger.flush_buffered
        end
      end
      def stop
        @do_background = false
        @stop_flag.setFlag()
      end
      def description
        "Session data preservation"
      end
    end
    KFramework.register_background_task(SessionsBackgroundTask.new)

  end
end

