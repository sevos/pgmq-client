# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
  t.warning = false
end

namespace :test do
  Rake::TestTask.new(:unit) do |t|
    t.libs << "test"
    t.libs << "lib"
    t.test_files = FileList["test/unit/**/*_test.rb"]
    t.warning = false
  end

  Rake::TestTask.new(:integration) do |t|
    t.libs << "test"
    t.libs << "lib"
    t.test_files = FileList["test/integration/**/*_test.rb"]
    t.warning = false
  end
end

namespace :docker do
  desc "Start PostgreSQL with PGMQ for testing"
  task :up do
    sh "docker-compose up -d"
    puts "Waiting for PostgreSQL to be ready..."
    require_relative "test/support/docker_helper"
    DockerHelper.wait_for_postgres
    DockerHelper.ensure_extension_created
    puts "PostgreSQL with PGMQ is ready!"
  end

  desc "Stop PostgreSQL container"
  task :down do
    sh "docker-compose down"
  end

  desc "Reset test database"
  task :reset do
    require_relative "test/support/docker_helper"
    DockerHelper.reset_database
    puts "Database reset complete."
  end
end

task default: :test
