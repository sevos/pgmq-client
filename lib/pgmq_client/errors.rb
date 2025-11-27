# frozen_string_literal: true

module PGMQ
  # Base error class for all PGMQ errors
  class Error < StandardError; end

  # Raised when database connection fails or is lost
  class ConnectionError < Error; end

  # Raised when attempting to operate on a queue that doesn't exist
  class QueueNotFoundError < Error; end

  # Raised when attempting to create a queue that already exists
  class QueueAlreadyExistsError < Error; end

  # Raised when a message cannot be found
  class MessageNotFoundError < Error; end

  # Raised when message payload is invalid (e.g., not valid JSON)
  class InvalidMessageError < Error; end

  # Raised when connection pool times out waiting for available connection
  class PoolTimeoutError < Error; end
end
