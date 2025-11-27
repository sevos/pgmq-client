# frozen_string_literal: true

require "uri"

module PGMQ
  # Configuration for PGMQ client connections
  #
  # Supports multiple configuration methods:
  # 1. Explicit parameters
  # 2. Environment variables (PGMQ_* or PG_*)
  # 3. DATABASE_URL connection string
  class Configuration
    attr_accessor :host, :port, :username, :password, :database

    DEFAULT_HOST = "localhost"
    DEFAULT_PORT = 5432
    DEFAULT_USERNAME = "postgres"
    DEFAULT_DATABASE = "postgres"

    # @param host [String, nil] PostgreSQL host
    # @param port [Integer, nil] PostgreSQL port
    # @param username [String, nil] Database username
    # @param password [String, nil] Database password
    # @param database [String, nil] Database name
    # @param url [String, nil] Connection URL (postgres://user:pass@host:port/db)
    def initialize(host: nil, port: nil, username: nil, password: nil, database: nil, url: nil)
      # Parse URL first if provided
      url_config = url ? parse_url(url) : {}

      @host = host || url_config[:host] || DEFAULT_HOST
      @port = port || url_config[:port] || DEFAULT_PORT
      @username = username || url_config[:username] || DEFAULT_USERNAME
      @password = password || url_config[:password]
      @database = database || url_config[:database] || DEFAULT_DATABASE
    end

    # Create configuration from environment variables
    #
    # Priority:
    # 1. PGMQ_* variables (highest priority)
    # 2. PG_* variables
    # 3. DATABASE_URL
    # 4. Defaults
    #
    # @return [Configuration]
    def self.from_env
      # Try PGMQ_* first, then PG_*, then DATABASE_URL
      url = ENV["DATABASE_URL"]
      url_config = url ? parse_url_class(url) : {}

      new(
        host: ENV["PGMQ_HOST"] || ENV["PG_HOST"] || url_config[:host],
        port: parse_port(ENV["PGMQ_PORT"] || ENV["PG_PORT"]) || url_config[:port],
        username: ENV["PGMQ_USERNAME"] || ENV["PG_USERNAME"] || url_config[:username],
        password: ENV["PGMQ_PASSWORD"] || ENV["PG_PASSWORD"] || url_config[:password],
        database: ENV["PGMQ_DATABASE"] || ENV["PG_DATABASE"] || url_config[:database]
      )
    end

    # Convert configuration to hash suitable for PG.connect
    # @return [Hash]
    def to_pg_params
      params = {
        host: @host,
        port: @port,
        user: @username,
        dbname: @database
      }
      params[:password] = @password if @password
      params
    end

    private

    # Parse a PostgreSQL connection URL
    # @param url [String] Connection URL
    # @return [Hash] Parsed components
    def parse_url(url)
      self.class.parse_url_class(url)
    end

    # Class method to parse URL (used by from_env before instance exists)
    def self.parse_url_class(url)
      return {} unless url

      uri = URI.parse(url)
      {
        host: uri.host,
        port: uri.port || DEFAULT_PORT,
        username: uri.user ? URI.decode_www_form_component(uri.user) : nil,
        password: uri.password ? URI.decode_www_form_component(uri.password) : nil,
        database: uri.path&.delete_prefix("/")
      }.compact
    end

    # Parse port string to integer
    def self.parse_port(port_str)
      return nil unless port_str

      port_str.to_i
    end
  end
end
