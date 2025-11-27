# frozen_string_literal: true

require "json"
require "time"

module PGMQ
  # Represents a message retrieved from a PGMQ queue
  class Message
    attr_reader :msg_id, :read_ct, :enqueued_at, :vt, :message

    # @param msg_id [Integer] Unique message identifier
    # @param read_ct [Integer] Number of times message has been read
    # @param enqueued_at [Time] When the message was added to the queue
    # @param vt [Time] Visibility timeout - when message becomes visible again
    # @param message [Hash] The message payload
    def initialize(msg_id:, read_ct:, enqueued_at:, vt:, message:)
      @msg_id = msg_id
      @read_ct = read_ct
      @enqueued_at = enqueued_at
      @vt = vt
      @message = message
    end

    # Create a Message from a PostgreSQL result row
    # @param row [Hash] A row from PG::Result
    # @return [Message]
    def self.from_pg_row(row)
      new(
        msg_id: row["msg_id"].to_i,
        read_ct: row["read_ct"].to_i,
        enqueued_at: Time.parse(row["enqueued_at"]),
        vt: Time.parse(row["vt"]),
        message: JSON.parse(row["message"])
      )
    end

    # Access the message payload
    # @return [Hash]
    def payload
      @message
    end

    # Access a value in the message payload by key
    # @param key [String, Symbol] The key to look up
    # @return [Object, nil]
    def [](key)
      @message[key.to_s]
    end

    # Convert the message to a hash representation
    # @return [Hash]
    def to_h
      {
        msg_id: @msg_id,
        read_ct: @read_ct,
        enqueued_at: @enqueued_at,
        vt: @vt,
        message: @message
      }
    end
  end
end
