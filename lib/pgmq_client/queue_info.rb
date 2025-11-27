# frozen_string_literal: true

require "time"

module PGMQ
  # Represents queue metadata from list_queues
  class QueueInfo
    attr_reader :queue_name, :created_at, :is_partitioned, :is_unlogged

    # @param queue_name [String] Name of the queue
    # @param created_at [Time] When the queue was created
    # @param is_partitioned [Boolean] Whether the queue is partitioned
    # @param is_unlogged [Boolean] Whether the queue is unlogged (faster, less durable)
    def initialize(queue_name:, created_at:, is_partitioned:, is_unlogged:)
      @queue_name = queue_name
      @created_at = created_at
      @is_partitioned = is_partitioned
      @is_unlogged = is_unlogged
    end

    # Create a QueueInfo from a PostgreSQL result row
    # @param row [Hash] A row from PG::Result
    # @return [QueueInfo]
    def self.from_pg_row(row)
      new(
        queue_name: row["queue_name"],
        created_at: Time.parse(row["created_at"]),
        is_partitioned: parse_boolean(row["is_partitioned"]),
        is_unlogged: parse_boolean(row["is_unlogged"])
      )
    end

    # Convert the queue info to a hash representation
    # @return [Hash]
    def to_h
      {
        queue_name: @queue_name,
        created_at: @created_at,
        is_partitioned: @is_partitioned,
        is_unlogged: @is_unlogged
      }
    end

    # @return [Boolean] Whether the queue is partitioned
    def partitioned?
      @is_partitioned
    end

    # @return [Boolean] Whether the queue is unlogged
    def unlogged?
      @is_unlogged
    end

    private

    # Parse PostgreSQL boolean values
    # @param value [String, Boolean, nil] The value to parse
    # @return [Boolean]
    def self.parse_boolean(value)
      case value
      when true, "t", "true", "1"
        true
      when false, "f", "false", "0", nil
        false
      else
        !!value
      end
    end
  end
end
