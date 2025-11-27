# frozen_string_literal: true

require "open3"

module DockerHelper
  CONTAINER_NAME = "pgmq-test-db"

  class << self
    def start_postgres
      unless container_running?
        system("docker-compose up -d", chdir: gem_root)
        wait_for_postgres
      end
      ensure_extension_created
    end

    def stop_postgres
      system("docker-compose down", chdir: gem_root)
    end

    def container_running?
      output, status = Open3.capture2("docker ps -q -f name=#{CONTAINER_NAME}")
      status.success? && !output.strip.empty?
    end

    def wait_for_postgres(timeout: 30)
      start_time = Time.now
      loop do
        break if postgres_ready?

        if Time.now - start_time > timeout
          raise "Timed out waiting for PostgreSQL to be ready"
        end

        sleep 1
      end
    end

    def postgres_ready?
      _output, status = Open3.capture2(
        "docker exec #{CONTAINER_NAME} pg_isready -U postgres -d pgmq_test"
      )
      status.success?
    end

    def reset_database
      system("docker exec #{CONTAINER_NAME} psql -U postgres -c 'DROP DATABASE IF EXISTS pgmq_test'")
      system("docker exec #{CONTAINER_NAME} psql -U postgres -c 'CREATE DATABASE pgmq_test'")
      ensure_extension_created
    end

    def ensure_extension_created
      system("docker exec #{CONTAINER_NAME} psql -U postgres -d pgmq_test -c 'CREATE EXTENSION IF NOT EXISTS pgmq'")
    end

    def connection_params
      {
        host: ENV.fetch("PGMQ_TEST_HOST", "localhost"),
        port: ENV.fetch("PGMQ_TEST_PORT", 5435).to_i,
        username: ENV.fetch("PGMQ_TEST_USER", "postgres"),
        password: ENV.fetch("PGMQ_TEST_PASSWORD", "postgres"),
        database: ENV.fetch("PGMQ_TEST_DATABASE", "pgmq_test")
      }
    end

    private

    def gem_root
      File.expand_path("../..", __dir__)
    end
  end
end
