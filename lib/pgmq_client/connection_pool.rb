# frozen_string_literal: true

require "thread"

module PGMQ
  # Thread/Fiber-safe connection pool for concurrent PGMQ access
  #
  # Uses Ruby's Queue class which is fiber-safe with the Fiber Scheduler,
  # making it suitable for both threaded and async contexts.
  #
  # @example Basic usage
  #   pool = PGMQ::ConnectionPool.new(size: 5, host: "localhost", database: "mydb")
  #   pool.with_connection do |client|
  #     client.send("my_queue", { data: "value" })
  #   end
  #   pool.close
  #
  # @example Async usage
  #   Sync do
  #     pool = PGMQ::ConnectionPool.new(size: 5, host: "localhost")
  #     Async { pool.with_connection { |c| c.send("queue", {id: 1}) } }
  #     Async { pool.with_connection { |c| c.send("queue", {id: 2}) } }
  #     pool.close
  #   end
  class ConnectionPool
    attr_reader :size

    # Create a new connection pool
    #
    # @param size [Integer] Maximum number of connections in the pool
    # @param client_class [Class] Class to instantiate for connections (default: PGMQ::Client)
    # @param options [Hash] Connection options passed to client_class.new
    def initialize(size:, client_class: nil, **options)
      @size = size
      @options = options
      @client_class = client_class || default_client_class
      @mutex = Mutex.new
      @available = Queue.new
      @all = []
    end

    # Execute a block with a connection from the pool
    #
    # Automatically checks out a connection, yields it to the block,
    # and returns it to the pool when done (even if an exception is raised).
    #
    # @yield [client] The client connection
    # @return The return value of the block
    # @raise [PoolTimeoutError] If no connection becomes available
    def with_connection
      conn = checkout
      yield conn
    ensure
      checkin(conn) if conn
    end

    # Close all connections in the pool
    def close
      @mutex.synchronize do
        @all.each(&:close)
        @all.clear
        # Drain the queue
        @available.clear if @available.respond_to?(:clear)
      end
    end

    # Current number of connections created
    # @return [Integer]
    def current_size
      @mutex.synchronize { @all.size }
    end

    private

    # Check out a connection from the pool
    def checkout
      # Try to get from available pool first (non-blocking)
      begin
        return @available.pop(true) # non_block = true
      rescue ThreadError
        # Queue is empty, try to create new connection
      end

      # Try to create a new connection if under limit
      @mutex.synchronize do
        if @all.size < @size
          conn = create_connection
          @all << conn
          return conn
        end
      end

      # Wait for available connection (blocking)
      @available.pop
    end

    # Return a connection to the pool
    def checkin(conn)
      return unless conn

      @available.push(conn)
    end

    # Create a new client connection
    def create_connection
      @client_class.new(**@options)
    end

    # Default client class when none specified
    def default_client_class
      # Delay loading to avoid circular dependency
      require_relative "client"
      Client
    end
  end
end
