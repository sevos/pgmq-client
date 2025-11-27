# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "pgmq_client"

require "minitest/autorun"
require "minitest/reporters"
require "securerandom"

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new

# Load Docker helper for integration tests
require_relative "support/docker_helper"

# Base class for integration tests
class IntegrationTest < Minitest::Test
  def setup
    DockerHelper.start_postgres unless DockerHelper.container_running?
    @client = PGMQ::Client.new(**DockerHelper.connection_params)
    @test_queue = "test_queue_#{SecureRandom.hex(4)}"
  end

  def teardown
    # Clean up test queues
    if @client&.connected?
      begin
        @client.drop_queue(@test_queue)
      rescue PGMQ::QueueNotFoundError
        # Queue may not exist, ignore
      rescue PG::ObjectNotInPrerequisiteState => e
        # Archive table may have been detached, ignore this specific error
        raise unless e.message.include?("is not a member of extension")
      end
      @client.close
    end
  end
end
