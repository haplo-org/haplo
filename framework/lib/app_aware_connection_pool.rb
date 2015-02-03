
# Reimplementation of ConnectionPool to be application aware.


# Remove all methods defined by the default implementation in ActiveRecord
ActiveRecord::ConnectionAdapters::ConnectionPool.instance_methods(false).each do |method_name|
  ActiveRecord::ConnectionAdapters::ConnectionPool.__send__(:remove_method, method_name)
end


# New implementation
module ActiveRecord

  module ConnectionAdapters
    # Connection pool base class for managing ActiveRecord database
    # connections.
    #
    # Compatible implementation with the default ActiveRecord behaviour, but
    # prefers to reuse databases for the same application and sets the postgres
    # search path appropraitely.
    #
    class ConnectionPool
      attr_reader :spec

      REUSE_OLDER_CONNECTIONS_THRESHOLD = 8
      MAX_APPLICATIONS_PER_CONNECTION   = 12
      MAX_CONNECTIONS_IN_RECENT         = 16
      MAX_TIME_IN_RECENT                = 1024

      class ConnectionInfo
        attr_accessor :last_checkout  # from @checkout_counter
        attr_accessor :last_app_id    # Last application ID this was set for
        attr_accessor :thread_id      # ID of thread it got checked out into
        attr :connection              # underlying AR connection
        attr :app_ids                 # Array of app IDs which this connection has been used for (may have items removed later)
        def initialize(conn)
          @last_checkout = -1
          @connection = conn
          @app_ids = Array.new
        end
        def info_as_text
          sprintf("%-6d %-6d %-6d %-6s %-6d %s", self.object_id, connection.object_id, last_checkout,
            (last_app_id || '-').to_s, thread_id, app_ids.join(','))
        end
      end

      # Creates a new ConnectionPool object. +spec+ is a ConnectionSpecification
      # object which describes database connection information (e.g. adapter,
      # host name, username, password, etc), as well as the maximum size for
      # this ConnectionPool.
      #
      # The default ConnectionPool maximum size is 5.
      def initialize(spec)
        @spec = spec

        # The key we'll use for the current connection in Thread.current
        @thread_key = "_frm_connpool_#{self.object_id}".to_sym

        # Not protected by a mutex, but doesn't really matter
        @checkout_counter = 0

        # Map of app ID to the most recently used connection
        #  * max entries MAX_CONNECTIONS_IN_RECENT
        #  * shouldn't contain anything older than MAX_TIME_IN_RECENT checkouts
        @recent_mutex = Mutex.new   # protects the vars below
        @recently_used_by_app = Hash.new

        # List of older connections, used for reuse.
        @list_mutex = Mutex.new     # protects the vars below
        @older_connections = Array.new
        @all_connections = Array.new
      end

      # Retrieve the connection associated with the current thread, or call
      # #checkout to obtain one if necessary.
      #
      # #connection can be called any number of times; the connection is
      # held in a hash keyed by the thread id.
      def connection
        conn_info = Thread.current[@thread_key]
        if conn_info == nil
          conn_info = (Thread.current[@thread_key] = do_checkout)
        end
        conn_info.connection
      end

      # Returns current connection for this thread, or nil if no connection
      def current_connection
        conn_info = Thread.current[@thread_key]
        (conn_info != nil) ? conn_info.connection : nil
      end

      # Signal that the thread is finished with the current connection.
      # #release_connection releases the connection-thread association
      # and returns the connection to the pool.
      def release_connection
        conn_info = Thread.current[@thread_key]
        if conn_info != nil
          do_checkin(conn_info)
          Thread.current[@thread_key] = nil
        end
        nil
      end

      # Reserve a connection, and yield it to a block. Ensure the connection is
      # checked back in when finished.
      def with_connection
        r = nil
        begin
          conn_info = do_checkout
          r = yield conn_info.connection
        ensure
          do_checkin conn_info
        end
        r
      end

      # Returns true if a connection has already been opened.
      def connected?
        @list_mutex.synchronize do
          @all_connections.empty?
        end
      end

      # Disconnects all connections in the pool, and clears the pool.
      def disconnect!
        raise "disconnect! is not implemented"
      end

      # Clears the cache which maps classes
      def clear_reloadable_connections!
        raise "clear_reloadable_connections! is not implemented"
      end

      # Verify active connections and remove and disconnect connections
      # associated with stale threads.
      def verify_active_connections! #:nodoc:
        # TODO: Implement?
        raise "verify_active_connections! is not implemented"
      end

      # Return any checked-out connections back to the pool by threads that
      # are no longer alive.
      def clear_stale_cached_connections!
        # TODO: Implement clear_stale_cached_connections! and call it now and again
        raise "clear_stale_cached_connections! is not implemented"
      end

      # Check-out a database connection from the pool, indicating that you want
      # to use it. You should call #checkin when you no longer need this.
      #
      # Returns: an AbstractAdapter object.
      #
      def checkout
        raise "checkout has not been tested"
        conn_info = do_checkout
        conn_info.connection
      end

      # Check-in a database connection back into the pool, indicating that you
      # no longer need this connection.
      #
      # +conn+: an AbstractAdapter object, which was obtained by earlier by
      # calling +checkout+ on this pool.
      def checkin(conn)
        raise "checkin has not been tested"
        tid = conn.object_id
        conn_info = nil
        @list_mutex.synchronize do
          conn_info = @all_connections.find { |ci| ci.connection.object_id == tid }
        end
        raise "Couldn't find connection info for connection passed to checkin" if conn_info == nil
        do_checkin(conn_info)
        nil
      end

      def create_new_unassigned_connection
        ActiveRecord::Base.send(spec.adapter_method, spec.config)
      end

      def dump_info
        puts "==============================================================="
        puts "POOLED DATABASE CONNECTIONS"
        puts "  Checkout counter = #{@checkout_counter}"
        recent = Hash.new
        @recent_mutex.synchronize do
          puts "RECENTLY USED"
          puts "  APPID     ID     CONNID LASTCO LAPPID TID    APPS"
          @recently_used_by_app.each do |ai,ci|
            puts sprintf("  %-6s -> %s", ai.to_s, ci.info_as_text)
            recent[ci.object_id] = true
          end
        end
        @list_mutex.synchronize do
          older = Hash.new
          puts "OLDER CONNECTIONS"
          puts "  ID     CONNID LASTCO LAPPID TID    APPS"
          @older_connections.each do |ci|
            puts "  #{ci.info_as_text}"
            older[ci.object_id] = true
          end
          puts "ALL CONNECTIONS"
          puts "  ST ID     CONNID LASTCO LAPPID TID    APPS"
          states = Hash.new(0)
          @all_connections.each do |ci|
            cio = ci.object_id
            state = if recent.has_key?(cio) && older.has_key?(cio)
              'X!'
            elsif recent.has_key?(cio)
              'r'
            elsif older.has_key?(cio)
              'o'
            elsif ci.last_app_id == nil
              # If it's not in recent or older, and doesn't have last_app_id, then it's been lost
              'L!'
            else
              'A'
            end
            states[state] += 1
            puts sprintf("  %-2s %s", state, ci.info_as_text)
          end
          puts "STATES"
          puts sprintf("%6d  X!  BAD STATE (has recent + older)", states['X!'])
          puts sprintf("%6d  L!  LOST (not recent or order, but has last_app_id set)", states['L!'])
          puts sprintf("%6d  r   recent", states['r'])
          puts sprintf("%6d  o   old", states['o'])
          puts sprintf("%6d  A   active", states['A'])
          if states['X!'] != 0 || states['L!'] != 0
            puts " ********************************** HAS BAD STATES **********************************"
            puts " (but may be spurious due to other threads changing state between structure locking, try again)"
          end
          puts "  (#{@all_connections.length} connections)"
        end
        puts "==============================================================="
      end

    private
      def make_new_connection
        underlying_connection = ActiveRecord::Base.send(spec.adapter_method, spec.config)
        raise "Database adaptor couldn't connect to database" unless underlying_connection != nil
        conn_info = ConnectionInfo.new(underlying_connection)
        @list_mutex.synchronize { @all_connections << conn_info }
        conn_info
      end

      # ===================
      #  CHECK OUT
      # ===================

      # Returns a ConnectionInfo
      def do_checkout
        app_id = KApp.current_application
        raise "No app_id set" unless (app_id.kind_of? Integer) || (app_id == :no_app)

        # Easy step, try and obtain the connection from the recently used list
        conn_info = nil
        @recent_mutex.synchronize do
          conn_info = @recently_used_by_app.delete(app_id)
        end

        # If that's not there, let's look at the old ones
        if conn_info == nil
          @list_mutex.synchronize do
            # Scan the older connections
            @older_connections.delete_if do |ci|
              if conn_info == nil && ci.app_ids.include?(app_id)
                # Use this one, store it and remove it from the array
                conn_info = ci
                true
              else
                # Don't remove this
                false
              end
            end
            # Didn't find anything? Try finding an older connection which hasn't been used with too many applications so far.
            if conn_info == nil && @older_connections.length >= REUSE_OLDER_CONNECTIONS_THRESHOLD
              # Scan through and find the connection with the lowest number of app_ids
              fewest = MAX_APPLICATIONS_PER_CONNECTION # initialise to this so items with this or more aren't considered
              @older_connections.each do |ci|
                if ci.app_ids.length < fewest
                  conn_info = ci
                  fewest = ci.app_ids.length
                end
              end
              # Remove it from the list of older connections -- use equal? to ensure we get the right one
              if conn_info != nil
                @older_connections.delete_if { |ci| ci.equal?(conn_info) }
              end
            end
          end
        end

        # Finally, if nothing was found in all that, create a new connection
        if conn_info == nil
          conn_info = make_new_connection
        end

        # Check internal state
        raise "conn_info.last_app_id != nil when choosing connection" if conn_info.last_app_id != nil

        # Set the search path in the database connection
        # This does the equivalent of verify!
        db_test_retries = 16
        begin
          KApp.set_database_connection_for_app(conn_info.connection.raw_connection.connection, app_id)
        rescue => e
          # This connection is bad. Replace it underneath by using the adaptor's verify! method
          puts "Database connection failed with #{e.inspect}, reestablishing it"
          db_test_retries -= 1
          if db_test_retries <= 0
            raise "Couldn't get a working database connection"
          end
          conn_info.connection.verify!
          retry
        end

        # Update connection state
        conn_info.app_ids << app_id unless conn_info.app_ids.include?(app_id)
        conn_info.last_app_id = app_id
        # Store the thread ID for stale thread tracking
        conn_info.thread_id = Thread.current.object_id
        # Store the connection age
        conn_info.last_checkout = @checkout_counter
        @checkout_counter += 1  # don't worry about race conditions

        # Return the info object
        conn_info
      end

      # ===================
      #  CHECK IN
      # ===================

      # Check in a ConnectionInfo
      def do_checkin(conn_info)
        raise "ConnectionInfo passed to do_checkin was nil" if conn_info == nil
        c_app_id = conn_info.last_app_id
        raise "last_app_id not set on connection info" if c_app_id == nil
        conn_info.last_app_id = nil # set it to nil to be safe

        # Put the connection back in the recently used list, and find anything else which might be removable
        old_connections_for_returning = Array.new
        @recent_mutex.synchronize do
          # Add this one to the recently used list, and if it replaces one, move that one to the older connections
          x = @recently_used_by_app.delete(c_app_id)
          old_connections_for_returning << x if x != nil
          @recently_used_by_app[c_app_id] = conn_info
          # Too many in the list?
          if @recently_used_by_app.length > MAX_CONNECTIONS_IN_RECENT
            # Select the oldest one
            ai = nil
            lage = nil
            @recently_used_by_app.each do |a,ci|
              if lage == nil || ci.last_checkout < lage
                lage = ci.last_checkout
                ai = a
              end
            end
            if ai != nil
              y = @recently_used_by_app.delete(ai)
              old_connections_for_returning << y if y != nil
            end
          end
          # Remove any connections which have been hanging around for a while, so they can get reused
          @recently_used_by_app.delete_if do |a,ci|
            if ci.last_checkout < (@checkout_counter - MAX_TIME_IN_RECENT)
              # Remove this one
              old_connections_for_returning << ci
              true
            else
              # Leave this one in
              false
            end
          end
        end

        # Add connections back to the recently used list
        unless old_connections_for_returning.empty?
          @list_mutex.synchronize do
            # Place old connections at the beginning of the list, so they're chosen first
            old_connections_for_returning.each { |ci| @older_connections.unshift ci }
          end
        end

        nil
      end

    end

  end
end

