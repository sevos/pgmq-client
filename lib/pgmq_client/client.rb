# frozen_string_literal: true

require "json"

module PGMQ
  # Main client for interacting with PGMQ (PostgreSQL Message Queue)
  #
  # Provides methods for queue management, sending/receiving messages,
  # and queue utilities. Works in both synchronous and asynchronous contexts
  # via Ruby's Fiber Scheduler.
  #
  # @example Basic usage
  #   client = PGMQ::Client.new(host: "localhost", database: "mydb")
  #   client.create_queue("orders")
  #   msg_id = client.send("orders", { order_id: 123 })
  #   messages = client.read("orders", vt: 30, qty: 1)
  #   client.delete("orders", messages.first.msg_id)
  #   client.close
  class Client
    # Create a new PGMQ client
    #
    # @param host [String] PostgreSQL host
    # @param port [Integer] PostgreSQL port (default: 5432)
    # @param username [String] Database username (default: "postgres")
    # @param password [String] Database password
    # @param database [String] Database name (default: "postgres")
    # @param url [String] Connection URL (alternative to individual params)
    def initialize(host: nil, port: nil, username: nil, password: nil, database: nil, url: nil)
      @connection = Connection.new(
        host: host,
        port: port,
        username: username,
        password: password,
        database: database
      )
    end

    # Close the connection
    def close
      @connection.close
    end

    # Check if connection is active
    # @return [Boolean]
    def connected?
      @connection.connected?
    end

    # =========================================================================
    # Queue Management
    # =========================================================================

    # Create a standard queue
    # @param queue_name [String] Name of the queue
    # @return [void]
    def create_queue(queue_name)
      @connection.exec("SELECT pgmq.create($1)", [queue_name])
      nil
    end

    # Create an unlogged queue (faster, less durable)
    # @param queue_name [String] Name of the queue
    # @return [void]
    def create_unlogged_queue(queue_name)
      @connection.exec("SELECT pgmq.create_unlogged($1)", [queue_name])
      nil
    end

    # Create a partitioned queue (for high volume)
    # @param queue_name [String] Name of the queue
    # @param partition_interval [String] e.g., "1 day"
    # @param retention_interval [String] e.g., "30 days" (optional)
    # @return [void]
    def create_partitioned_queue(queue_name, partition_interval, retention_interval = nil)
      if retention_interval
        @connection.exec(
          "SELECT pgmq.create_partitioned($1, $2, $3)",
          [queue_name, partition_interval, retention_interval]
        )
      else
        @connection.exec(
          "SELECT pgmq.create_partitioned($1, $2)",
          [queue_name, partition_interval]
        )
      end
      nil
    end

    # List all queues
    # @return [Array<QueueInfo>]
    def list_queues
      result = @connection.exec("SELECT * FROM pgmq.list_queues()")
      result.map { |row| QueueInfo.from_pg_row(row) }
    end

    # Drop a queue
    # @param queue_name [String] Name of the queue
    # @return [Boolean] true if dropped successfully
    def drop_queue(queue_name)
      result = @connection.exec("SELECT pgmq.drop_queue($1)", [queue_name])
      result.first["drop_queue"] == "t"
    end

    # Purge all messages from a queue
    # @param queue_name [String] Name of the queue
    # @return [Integer] Number of messages purged
    def purge_queue(queue_name)
      result = @connection.exec("SELECT pgmq.purge_queue($1)", [queue_name])
      result.first["purge_queue"].to_i
    end

    # =========================================================================
    # Sending Messages
    # =========================================================================

    # Send a single message
    # @param queue_name [String] Name of the queue
    # @param message [Hash] Message payload (will be converted to JSON)
    # @param delay [Integer] Delay in seconds before message becomes visible (default: 0)
    # @return [Integer] Message ID
    def send(queue_name, message, delay: 0)
      json_message = JSON.generate(message)
      result = if delay > 0
                 @connection.exec(
                   "SELECT pgmq.send($1::text, $2::jsonb, $3::integer)",
                   [queue_name, json_message, delay]
                 )
               else
                 @connection.exec(
                   "SELECT pgmq.send($1::text, $2::jsonb)",
                   [queue_name, json_message]
                 )
               end
      result.first["send"].to_i
    end

    # Send multiple messages
    # @param queue_name [String] Name of the queue
    # @param messages [Array<Hash>] Array of message payloads
    # @param delay [Integer] Delay in seconds (default: 0)
    # @return [Array<Integer>] Array of message IDs
    def send_batch(queue_name, messages, delay: 0)
      return [] if messages.empty?

      # Convert messages to JSON array
      json_array = messages.map { |m| JSON.generate(m) }
      pg_array = "{#{json_array.map { |j| "\"#{j.gsub('\\', '\\\\\\\\').gsub('"', '\\"')}\"" }.join(',')}}"

      result = if delay > 0
                 @connection.exec(
                   "SELECT * FROM pgmq.send_batch($1::text, $2::jsonb[], $3::integer)",
                   [queue_name, pg_array, delay]
                 )
               else
                 @connection.exec(
                   "SELECT * FROM pgmq.send_batch($1::text, $2::jsonb[])",
                   [queue_name, pg_array]
                 )
               end

      result.map { |row| row["send_batch"].to_i }
    end

    # =========================================================================
    # Reading Messages
    # =========================================================================

    # Read messages from queue
    # @param queue_name [String] Name of the queue
    # @param vt [Integer] Visibility timeout in seconds (default: 30)
    # @param qty [Integer] Number of messages to read (default: 1)
    # @return [Array<Message>]
    def read(queue_name, vt: 30, qty: 1)
      result = @connection.exec(
        "SELECT * FROM pgmq.read($1, $2, $3)",
        [queue_name, vt, qty]
      )
      result.map { |row| Message.from_pg_row(row) }
    end

    # Read messages with polling (waits for messages if queue is empty)
    # @param queue_name [String] Name of the queue
    # @param vt [Integer] Visibility timeout in seconds (default: 30)
    # @param qty [Integer] Number of messages to read (default: 1)
    # @param max_poll_seconds [Integer] Maximum time to poll (default: 5)
    # @param poll_interval_ms [Integer] Polling interval in milliseconds (default: 100)
    # @return [Array<Message>]
    def read_with_poll(queue_name, vt: 30, qty: 1, max_poll_seconds: 5, poll_interval_ms: 100)
      result = @connection.exec(
        "SELECT * FROM pgmq.read_with_poll($1, $2, $3, $4, $5)",
        [queue_name, vt, qty, max_poll_seconds, poll_interval_ms]
      )
      result.map { |row| Message.from_pg_row(row) }
    end

    # Pop a message (read and delete atomically)
    # @param queue_name [String] Name of the queue
    # @return [Message, nil] Message or nil if queue is empty
    def pop(queue_name)
      result = @connection.exec("SELECT * FROM pgmq.pop($1)", [queue_name])
      return nil if result.ntuples.zero?

      Message.from_pg_row(result.first)
    end

    # =========================================================================
    # Deleting and Archiving
    # =========================================================================

    # Delete a single message
    # @param queue_name [String] Name of the queue
    # @param msg_id [Integer] Message ID
    # @return [Boolean] true if deleted
    def delete(queue_name, msg_id)
      result = @connection.exec("SELECT pgmq.delete($1, $2)", [queue_name, msg_id])
      result.first["delete"] == "t"
    end

    # Delete multiple messages
    # @param queue_name [String] Name of the queue
    # @param msg_ids [Array<Integer>] Array of message IDs
    # @return [Array<Integer>] Array of deleted message IDs
    def delete_batch(queue_name, msg_ids)
      return [] if msg_ids.empty?

      pg_array = "{#{msg_ids.join(',')}}"
      result = @connection.exec(
        "SELECT * FROM pgmq.delete($1, $2::bigint[])",
        [queue_name, pg_array]
      )
      result.map { |row| row["delete"].to_i }
    end

    # Archive a single message
    # @param queue_name [String] Name of the queue
    # @param msg_id [Integer] Message ID
    # @return [Boolean] true if archived
    def archive(queue_name, msg_id)
      result = @connection.exec("SELECT pgmq.archive($1, $2)", [queue_name, msg_id])
      result.first["archive"] == "t"
    end

    # Archive multiple messages
    # @param queue_name [String] Name of the queue
    # @param msg_ids [Array<Integer>] Array of message IDs
    # @return [Array<Integer>] Array of archived message IDs
    def archive_batch(queue_name, msg_ids)
      return [] if msg_ids.empty?

      pg_array = "{#{msg_ids.join(',')}}"
      result = @connection.exec(
        "SELECT * FROM pgmq.archive($1, $2::bigint[])",
        [queue_name, pg_array]
      )
      result.map { |row| row["archive"].to_i }
    end

    # Detach archive table
    # @param queue_name [String] Name of the queue
    # @return [void]
    def detach_archive(queue_name)
      @connection.exec("SELECT pgmq.detach_archive($1)", [queue_name])
      nil
    end

    # =========================================================================
    # Utilities
    # =========================================================================

    # Set visibility timeout for a message
    # @param queue_name [String] Name of the queue
    # @param msg_id [Integer] Message ID
    # @param vt [Integer] New visibility timeout in seconds
    # @return [Message] Updated message
    def set_vt(queue_name, msg_id, vt)
      result = @connection.exec(
        "SELECT * FROM pgmq.set_vt($1, $2, $3)",
        [queue_name, msg_id, vt]
      )
      Message.from_pg_row(result.first)
    end

    # Get metrics for a queue
    # @param queue_name [String] Name of the queue
    # @return [Metrics]
    def metrics(queue_name)
      result = @connection.exec("SELECT * FROM pgmq.metrics($1)", [queue_name])
      Metrics.from_pg_row(result.first)
    end

    # Get metrics for all queues
    # @return [Array<Metrics>]
    def metrics_all
      result = @connection.exec("SELECT * FROM pgmq.metrics_all()")
      result.map { |row| Metrics.from_pg_row(row) }
    end
  end
end
