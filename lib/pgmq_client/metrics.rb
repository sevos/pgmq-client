# frozen_string_literal: true

require "time"

module PGMQ
  # Represents queue metrics from the metrics() function
  class Metrics
    attr_reader :queue_name, :queue_length, :newest_msg_age_sec,
                :oldest_msg_age_sec, :total_messages, :scrape_time

    # @param queue_name [String] Name of the queue
    # @param queue_length [Integer] Current number of messages in queue
    # @param newest_msg_age_sec [Integer, nil] Age of newest message in seconds
    # @param oldest_msg_age_sec [Integer, nil] Age of oldest message in seconds
    # @param total_messages [Integer] Total messages processed by queue
    # @param scrape_time [Time] When the metrics were collected
    def initialize(queue_name:, queue_length:, newest_msg_age_sec:,
                   oldest_msg_age_sec:, total_messages:, scrape_time:)
      @queue_name = queue_name
      @queue_length = queue_length
      @newest_msg_age_sec = newest_msg_age_sec
      @oldest_msg_age_sec = oldest_msg_age_sec
      @total_messages = total_messages
      @scrape_time = scrape_time
    end

    # Create Metrics from a PostgreSQL result row
    # @param row [Hash] A row from PG::Result
    # @return [Metrics]
    def self.from_pg_row(row)
      new(
        queue_name: row["queue_name"],
        queue_length: row["queue_length"].to_i,
        newest_msg_age_sec: row["newest_msg_age_sec"]&.to_i,
        oldest_msg_age_sec: row["oldest_msg_age_sec"]&.to_i,
        total_messages: row["total_messages"].to_i,
        scrape_time: Time.parse(row["scrape_time"])
      )
    end

    # Convert the metrics to a hash representation
    # @return [Hash]
    def to_h
      {
        queue_name: @queue_name,
        queue_length: @queue_length,
        newest_msg_age_sec: @newest_msg_age_sec,
        oldest_msg_age_sec: @oldest_msg_age_sec,
        total_messages: @total_messages,
        scrape_time: @scrape_time
      }
    end

    # @return [Boolean] Whether the queue is empty
    def empty?
      @queue_length.zero?
    end
  end
end
