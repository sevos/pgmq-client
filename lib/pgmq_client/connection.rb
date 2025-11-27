# frozen_string_literal: true

require "pg"

module PGMQ
  # Low-level PostgreSQL connection wrapper for PGMQ operations
  #
  # Handles connection management, reconnection, and SQL execution.
  # Uses PG gem which supports Ruby's Fiber Scheduler for async I/O.
  class Connection
    # Create a new connection
    #
    # @param config [Configuration] Configuration object
    # @param host [String] PostgreSQL host
    # @param port [Integer] PostgreSQL port
    # @param username [String] Database username
    # @param password [String] Database password
    # @param database [String] Database name
    def initialize(config = nil, host: nil, port: nil, username: nil, password: nil, database: nil)
      if config.is_a?(Configuration)
        @config = config
      else
        @config = Configuration.new(
          host: host,
          port: port,
          username: username,
          password: password,
          database: database
        )
      end

      @conn = nil
      connect
    end

    # Execute a SQL query
    #
    # @param sql [String] SQL query with optional $1, $2 placeholders
    # @param params [Array] Parameters to bind to the query
    # @return [PG::Result] Query result
    # @raise [ConnectionError] If connection is lost and cannot reconnect
    def exec(sql, params = [])
      ensure_connected
      @conn.exec_params(sql, params)
    rescue PG::ConnectionBad => e
      @conn = nil
      raise ConnectionError, "Database connection lost: #{e.message}"
    end

    # Close the connection
    def close
      @conn&.close
      @conn = nil
    end

    # Check if connection is active
    #
    # @return [Boolean] true if connected
    def connected?
      @conn && !@conn.finished?
    end

    private

    # Establish database connection
    def connect
      @conn = PG.connect(@config.to_pg_params)
    rescue PG::ConnectionBad => e
      raise ConnectionError, "Failed to connect to database: #{e.message}"
    end

    # Ensure connection is active, reconnect if needed
    def ensure_connected
      return if connected?

      connect
    end
  end
end
