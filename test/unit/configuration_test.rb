# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  def teardown
    # Clean up environment variables after each test
    %w[
      PGMQ_HOST PGMQ_PORT PGMQ_USERNAME PGMQ_PASSWORD PGMQ_DATABASE
      PG_HOST PG_PORT PG_USERNAME PG_PASSWORD PG_DATABASE
      DATABASE_URL
    ].each { |var| ENV.delete(var) }
  end

  def test_initializes_with_defaults
    config = PGMQ::Configuration.new

    assert_equal "localhost", config.host
    assert_equal 5432, config.port
    assert_equal "postgres", config.username
    assert_nil config.password
    assert_equal "postgres", config.database
  end

  def test_initializes_with_explicit_params
    config = PGMQ::Configuration.new(
      host: "db.example.com",
      port: 5433,
      username: "myuser",
      password: "secret",
      database: "mydb"
    )

    assert_equal "db.example.com", config.host
    assert_equal 5433, config.port
    assert_equal "myuser", config.username
    assert_equal "secret", config.password
    assert_equal "mydb", config.database
  end

  def test_loads_from_pgmq_environment_variables
    ENV["PGMQ_HOST"] = "pgmq-host.example.com"
    ENV["PGMQ_PORT"] = "5434"
    ENV["PGMQ_USERNAME"] = "pgmq_user"
    ENV["PGMQ_PASSWORD"] = "pgmq_pass"
    ENV["PGMQ_DATABASE"] = "pgmq_db"

    config = PGMQ::Configuration.from_env

    assert_equal "pgmq-host.example.com", config.host
    assert_equal 5434, config.port
    assert_equal "pgmq_user", config.username
    assert_equal "pgmq_pass", config.password
    assert_equal "pgmq_db", config.database
  end

  def test_loads_from_pg_environment_variables
    ENV["PG_HOST"] = "pg-host.example.com"
    ENV["PG_PORT"] = "5435"
    ENV["PG_USERNAME"] = "pg_user"
    ENV["PG_PASSWORD"] = "pg_pass"
    ENV["PG_DATABASE"] = "pg_db"

    config = PGMQ::Configuration.from_env

    assert_equal "pg-host.example.com", config.host
    assert_equal 5435, config.port
    assert_equal "pg_user", config.username
    assert_equal "pg_pass", config.password
    assert_equal "pg_db", config.database
  end

  def test_prefers_pgmq_env_vars_over_pg_env_vars
    ENV["PGMQ_HOST"] = "pgmq-host.example.com"
    ENV["PG_HOST"] = "pg-host.example.com"

    config = PGMQ::Configuration.from_env

    assert_equal "pgmq-host.example.com", config.host
  end

  def test_parses_database_url
    ENV["DATABASE_URL"] = "postgres://user:pass@dbhost.example.com:5436/mydb"

    config = PGMQ::Configuration.from_env

    assert_equal "dbhost.example.com", config.host
    assert_equal 5436, config.port
    assert_equal "user", config.username
    assert_equal "pass", config.password
    assert_equal "mydb", config.database
  end

  def test_database_url_with_default_port
    ENV["DATABASE_URL"] = "postgres://user:pass@dbhost.example.com/mydb"

    config = PGMQ::Configuration.from_env

    assert_equal "dbhost.example.com", config.host
    assert_equal 5432, config.port
  end

  def test_prefers_explicit_params_over_database_url
    ENV["DATABASE_URL"] = "postgres://url_user:url_pass@url_host:5436/url_db"

    config = PGMQ::Configuration.new(
      host: "explicit-host.example.com",
      port: 5437,
      username: "explicit_user",
      password: "explicit_pass",
      database: "explicit_db"
    )

    assert_equal "explicit-host.example.com", config.host
    assert_equal 5437, config.port
    assert_equal "explicit_user", config.username
    assert_equal "explicit_pass", config.password
    assert_equal "explicit_db", config.database
  end

  def test_converts_to_pg_params_hash
    config = PGMQ::Configuration.new(
      host: "db.example.com",
      port: 5433,
      username: "myuser",
      password: "secret",
      database: "mydb"
    )

    pg_params = config.to_pg_params

    assert_equal "db.example.com", pg_params[:host]
    assert_equal 5433, pg_params[:port]
    assert_equal "myuser", pg_params[:user]
    assert_equal "secret", pg_params[:password]
    assert_equal "mydb", pg_params[:dbname]
  end

  def test_to_pg_params_omits_nil_password
    config = PGMQ::Configuration.new(
      host: "localhost",
      password: nil
    )

    pg_params = config.to_pg_params

    refute pg_params.key?(:password)
  end

  def test_url_parameter_overrides_defaults
    config = PGMQ::Configuration.new(
      url: "postgres://url_user:url_pass@url_host:5438/url_db"
    )

    assert_equal "url_host", config.host
    assert_equal 5438, config.port
    assert_equal "url_user", config.username
    assert_equal "url_pass", config.password
    assert_equal "url_db", config.database
  end

  def test_explicit_params_override_url_parameter
    config = PGMQ::Configuration.new(
      url: "postgres://url_user:url_pass@url_host:5438/url_db",
      host: "explicit-host"
    )

    assert_equal "explicit-host", config.host
    assert_equal 5438, config.port  # From URL
  end
end
